import Foundation
@testable import Pitstop
import Testing

/// SYS-002: the handler behind `RememberInPitStopIntent`, over the real pipeline and an in-memory
/// SwiftData store. Only the Siri prompt is faked; it answers as the person would.
private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(30 * 86400)

enum PromptStep {
    case choice(RememberChoice)
    case answer(RememberAnswer)
    case failure(any Error)
}

final class FakePrompter: RememberPrompting, @unchecked Sendable {
    private let lock = NSLock()
    private var steps: [PromptStep]
    private var recorded: [RememberQuestion] = []

    init(_ choices: RememberChoice...) {
        steps = choices.map(PromptStep.choice)
    }

    init(steps: [PromptStep]) {
        self.steps = steps
    }

    init(failingWith error: any Error) {
        steps = [.failure(error)]
    }

    var questions: [RememberQuestion] {
        lock.withLock { recorded }
    }

    func choose(_ question: RememberQuestion) async throws -> RememberChoice {
        switch next(question) {
        case let .choice(choice)?: return choice
        case let .failure(error)?: throw error
        case .answer?:
            Issue.record("expected an answer prompt for \(question)")
            return .cancel
        case nil: return .cancel
        }
    }

    func answer(_ question: RememberQuestion) async throws -> RememberAnswer {
        switch next(question) {
        case let .answer(answer)?: return answer
        case let .failure(error)?: throw error
        case .choice?:
            Issue.record("expected a choice prompt for \(question)")
            return .cancel
        case nil: return .cancel
        }
    }

    private func next(_ question: RememberQuestion) -> PromptStep? {
        lock.withLock {
            recorded.append(question)
            return steps.isEmpty ? nil : steps.removeFirst()
        }
    }
}

/// Records what reached the interpreter, then interprets it as Pit would.
actor RecordingInterpreter: SemanticInterpreting {
    private(set) var inputs: [CaptureInput] = []
    private let makeProposal: (@Sendable (CaptureInput) -> MemoryProposal?)?

    /// Without a closure it interprets with the same rules as Pit.
    init(_ makeProposal: (@Sendable (CaptureInput) -> MemoryProposal?)? = nil) {
        self.makeProposal = makeProposal
    }

    func interpret(_ input: CaptureInput) async throws -> MemoryProposal? {
        inputs.append(input)
        guard let makeProposal else { return try await RuleBasedInterpreter().interpret(input) }
        return makeProposal(input)
    }
}

extension RecordingInterpreter {
    /// A proposal of `kind` with every detail missing but the ones given, as a model might return it.
    static func missing(
        _ kind: ProposalKind,
        odometerKm: Double? = nil,
        operation: MaintenanceOperationID? = nil
    ) -> RecordingInterpreter {
        RecordingInterpreter { input in
            MemoryProposal(
                sourceInputID: input.id,
                kind: kind,
                rawText: input.payload.rawContent,
                extractedOdometerKm: odometerKm,
                extractedOperationID: operation
            )
        }
    }
}

/// Shared with `RememberVoiceClarificationTests`.
struct RememberHarness {
    let store: any CarMemoryStore
    let interpreter: RecordingInterpreter
    let stages: StageSpy
    let handler: RememberIntentHandler

    init(
        persistence: PersistenceMode = .durable,
        store: (any CarMemoryStore)? = nil,
        interpreter: RecordingInterpreter = RecordingInterpreter()
    ) throws {
        let store = try store ?? SwiftDataCarMemoryStore(modelContainer: PersistenceContainer.make(storeURL: nil))
        let stages = StageSpy()
        self.store = store
        self.interpreter = interpreter
        self.stages = stages
        handler = RememberIntentHandler(
            pipeline: RememberPipeline(store: store, interpreter: interpreter, observer: stages, now: { now }),
            persistence: persistence,
            now: { now }
        )
    }

    func say(
        _ words: String,
        prompter: FakePrompter = FakePrompter(),
        locale: Locale = Locale(identifier: "ru_RU")
    ) async throws -> RememberReply {
        try await handler.remember(words, locale: locale, prompter: prompter)
    }

    func notes() async throws -> [Note] {
        try await store.notes()
    }

    func completions() async throws -> [MaintenanceCompletion] {
        try await store.maintenanceCompletions()
    }

    func readings() async throws -> [OdometerReading] {
        try await store.odometerReadings()
    }

    func events() async throws -> [HistoryEvent] {
        try await store.historyEvents()
    }

    func isUnchanged() async throws -> Bool {
        let notes = try await notes()
        let completions = try await completions()
        let readings = try await readings()
        let events = try await events()
        return notes.isEmpty && completions.isEmpty && readings.isEmpty && events.isEmpty
    }
}

struct PromptDismissed: Error {}

private final class FlushSpy: AnalyticsPipelineControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var flushes: Int {
        lock.withLock { count }
    }

    func flush() async {
        lock.withLock { count += 1 }
    }

    func discardPending() {}
}

@Suite("Remember in PitStop intent")
struct RememberIntentHandlerTests {
    @Test("REQ-CAPTURE-002, REQ-CAPTURE-008: a plain thought is saved to Notes as said, from the Siri source")
    func thoughtIsSavedAsSaid() async throws {
        let app = try RememberHarness()
        let prompter = FakePrompter()

        let reply = try await app.say("стук справа при повороте", prompter: prompter)

        #expect(reply == .saved(.notes, preservedRaw: true))
        #expect(try await app.notes().map(\.rawText) == ["стук справа при повороте"])
        #expect(prompter.questions.isEmpty)
        #expect(app.stages.events.allSatisfy { $0.source == .siri })
        #expect(app.stages.events.map(\.stage).contains(.mutationCompleted))
    }

    @Test("REQ-CAPTURE-002, ADR-0023: the request locale and the Siri source reach the pipeline in the CaptureInput")
    func inputCarriesLocaleAndSource() async throws {
        let app = try RememberHarness()

        _ = try await app.say("check the tyre pressure", locale: Locale(identifier: "en_GB"))

        let inputs = await app.interpreter.inputs
        #expect(inputs.count == 1)
        #expect(inputs.first?.localeIdentifier == "en_GB")
        #expect(inputs.first?.source == .siri)
        #expect(inputs.first?.payload == .text("check the tyre pressure"))
        #expect(inputs.first?.capturedAt == now)
        // Siri has no visible surface to lend as a prior (REQ-CAPTURE-022).
        #expect(inputs.first?.visibleFeature == nil)
    }

    @Test("REQ-CAPTURE-016, ADR-0023: an oil change is asked in place and recorded only after \"Record it\"")
    func completionIsRecordedAfterChoice() async throws {
        let app = try RememberHarness()
        let prompter = FakePrompter(.record)

        let reply = try await app.say("поменял масло на 84200", prompter: prompter)

        guard case let .confirm(content, conflicts)? = prompter.questions.first else {
            Issue.record("expected a confirmation, got \(prompter.questions)")
            return
        }
        #expect(content == .maintenanceCompletion(operationID: .engineOilService, performedAt: now, odometerKm: 84200))
        #expect(conflicts.isEmpty)
        #expect(reply == .saved(.service, preservedRaw: false))
        #expect(try await app.completions().map(\.odometerKm) == [84200])
        #expect(try await app.notes().isEmpty)
    }

    @Test("REQ-CAPTURE-008, ADR-0023: \"Save the words only\" keeps the wording as a note and records no work")
    func wordsOnlyKeepsANote() async throws {
        let app = try RememberHarness()

        let reply = try await app.say("поменял масло на 84200", prompter: FakePrompter(.wordsOnly))

        #expect(reply == .saved(.notes, preservedRaw: true))
        #expect(try await app.notes().map(\.rawText) == ["поменял масло на 84200"])
        #expect(try await app.completions().isEmpty)
    }

    @Test("REQ-CAPTURE-005, ADR-0023: choosing Cancel writes nothing")
    func cancelWritesNothing() async throws {
        let app = try RememberHarness()

        let reply = try await app.say("поменял масло на 84200", prompter: FakePrompter(.cancel))

        #expect(reply == .cancelled)
        #expect(try await app.isUnchanged())
        #expect(app.stages.events.last?.stage == .captureDiscarded)
    }

    @Test("REQ-CAPTURE-005, ADR-0023: a dismissed prompt writes nothing and the dismissal reaches the system")
    func dismissedPromptWritesNothing() async throws {
        let app = try RememberHarness()

        await #expect(throws: PromptDismissed.self) {
            try await app.say("поменял масло на 84200", prompter: FakePrompter(failingWith: PromptDismissed()))
        }

        #expect(try await app.isUnchanged())
        #expect(app.stages.events.last?.stage == .captureDiscarded)
    }

    @Test("REQ-CAPTURE-020, ADR-0026: a detail that cannot be said in one step offers to keep the words")
    func clarificationOffersWordsOnly() async throws {
        let app = try RememberHarness(
            interpreter: RecordingInterpreter { input in
                MemoryProposal(sourceInputID: input.id, kind: .vehicleFact, rawText: input.payload.rawContent)
            })
        let prompter = FakePrompter(.wordsOnly)

        let reply = try await app.say("поменял данные машины", prompter: prompter)

        #expect(prompter.questions == [.clarify(.vehicleFact)])
        #expect(reply == .saved(.notes, preservedRaw: true))
        #expect(try await app.notes().map(\.rawText) == ["поменял данные машины"])
    }

    @Test("REQ-CAPTURE-005, ADR-0026: cancelling a clarification writes nothing")
    func clarificationCancelWritesNothing() async throws {
        let app = try RememberHarness(interpreter: .missing(.odometerReading))
        let prompter = FakePrompter(steps: [.answer(.cancel)])

        let reply = try await app.say("записал показания", prompter: prompter)

        #expect(reply == .cancelled)
        #expect(try await app.isUnchanged())
        #expect(app.stages.events.filter { $0.stage == .captureDiscarded }.count == 1)
    }

    @Test("ADR-0006, ADR-0023: an ordinary mileage said to Siri is recorded without a question")
    func ordinaryReadingIsAutoAccepted() async throws {
        let app = try RememberHarness()
        let prompter = FakePrompter()

        let reply = try await app.say("пробег 91500", prompter: prompter)

        #expect(prompter.questions.isEmpty)
        #expect(reply == .saved(.carBoard, preservedRaw: false))
        #expect(try await app.readings().map(\.value) == [91500])
    }

    @Test("REQ-CAPTURE-017, ADR-0023: a mileage below the last reading is asked, and cancelling keeps the old one")
    func lowerReadingAsks() async throws {
        let app = try RememberHarness()
        _ = try await app.say("пробег 91500")
        let prompter = FakePrompter(.cancel)

        let reply = try await app.say("пробег 85000", prompter: prompter)

        guard case let .confirm(content, conflicts)? = prompter.questions.first else {
            Issue.record("expected a confirmation, got \(prompter.questions)")
            return
        }
        #expect(content == .odometerReading(kilometers: 85000, recordedAt: now))
        #expect(conflicts == [.odometerBelowLatest(latestKm: 91500)])
        #expect(reply == .cancelled)
        #expect(try await app.readings().map(\.value) == [91500])
    }

    @Test("REQ-CAPTURE-009, ADR-0023: temporary storage refuses to save instead of keeping the words in memory")
    func temporaryStorageRefuses() async throws {
        let app = try RememberHarness(persistence: .temporary)
        let prompter = FakePrompter()

        let reply = try await app.say("стук справа при повороте", prompter: prompter)

        #expect(reply == .storageUnavailable)
        #expect(try await app.isUnchanged())
        #expect(prompter.questions.isEmpty)
        #expect(await app.interpreter.inputs.isEmpty)
    }

    @Test("REQ-CAPTURE-009, ADR-0023: a failed write is reported as not saved, never as saved")
    func failedWriteIsNotSaved() async throws {
        let store = FakeCarMemoryStore()
        await store.failCommands()
        let app = try RememberHarness(store: store)

        let reply = try await app.say("стук справа при повороте")

        #expect(reply == .notSaved)
        #expect(await store.storedNotes.isEmpty)
    }

    @Test("REQ-CAPTURE-005: a capture whose intent task was cancelled writes nothing")
    func cancelledTaskWritesNothing() async throws {
        let app = try RememberHarness()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await app.say("стук справа при повороте")
        }

        let reply = try await task.value

        #expect(reply == .cancelled)
        #expect(try await app.isUnchanged())
    }

    @Test("ADR-0022, ADR-0023: a background run flushes the queued analytics itself")
    func flushesAnalytics() async {
        let pipeline = FlushSpy()
        let handler = RememberIntentHandler(
            pipeline: RememberPipeline(store: FakeCarMemoryStore(), now: { now }),
            persistence: .durable,
            analytics: pipeline,
            now: { now }
        )

        await handler.flushAnalytics().value

        #expect(pipeline.flushes == 1)
    }

    @Test("ADR-0023: blank words save nothing and ask nothing")
    func blankSavesNothing() async throws {
        let app = try RememberHarness()

        let reply = try await app.say("   ")

        #expect(reply == .nothingToSave)
        #expect(try await app.isUnchanged())
    }
}
