import Foundation
@testable import Pitstop
import Testing

/// SYS-002: the handler behind `RememberInPitStopIntent`, over the real pipeline and an in-memory
/// SwiftData store. Only the Siri prompt is faked; it answers as the person would.
private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(30 * 86400)

private enum PromptStep {
    case choice(RememberChoice)
    case answer(RememberAnswer)
    case failure(any Error)
}

private final class FakePrompter: RememberPrompting, @unchecked Sendable {
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
private actor RecordingInterpreter: SemanticInterpreting {
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

private extension RecordingInterpreter {
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

private struct Harness {
    let store: any CarMemoryStore
    let interpreter: RecordingInterpreter
    let stages: StageSpy
    let handler: RememberIntentHandler

    init(
        persistence: AppEnvironment.Persistence = .durable,
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

private struct PromptDismissed: Error {}

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
        let app = try Harness()
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
        let app = try Harness()

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
        let app = try Harness()
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
        let app = try Harness()

        let reply = try await app.say("поменял масло на 84200", prompter: FakePrompter(.wordsOnly))

        #expect(reply == .saved(.notes, preservedRaw: true))
        #expect(try await app.notes().map(\.rawText) == ["поменял масло на 84200"])
        #expect(try await app.completions().isEmpty)
    }

    @Test("REQ-CAPTURE-005, ADR-0023: choosing Cancel writes nothing")
    func cancelWritesNothing() async throws {
        let app = try Harness()

        let reply = try await app.say("поменял масло на 84200", prompter: FakePrompter(.cancel))

        #expect(reply == .cancelled)
        #expect(try await app.isUnchanged())
        #expect(app.stages.events.last?.stage == .captureDiscarded)
    }

    @Test("REQ-CAPTURE-005, ADR-0023: a dismissed prompt writes nothing and the dismissal reaches the system")
    func dismissedPromptWritesNothing() async throws {
        let app = try Harness()

        await #expect(throws: PromptDismissed.self) {
            try await app.say("поменял масло на 84200", prompter: FakePrompter(failingWith: PromptDismissed()))
        }

        #expect(try await app.isUnchanged())
        #expect(app.stages.events.last?.stage == .captureDiscarded)
    }

    @Test("REQ-CAPTURE-020, ADR-0026: a detail that cannot be said in one step offers to keep the words")
    func clarificationOffersWordsOnly() async throws {
        let app = try Harness(interpreter: RecordingInterpreter { input in
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
        let app = try Harness(interpreter: .missing(.odometerReading))
        let prompter = FakePrompter(steps: [.answer(.cancel)])

        let reply = try await app.say("записал показания", prompter: prompter)

        #expect(reply == .cancelled)
        #expect(try await app.isUnchanged())
        #expect(app.stages.events.filter { $0.stage == .captureDiscarded }.count == 1)
    }

    @Test("ADR-0006, ADR-0023: an ordinary mileage said to Siri is recorded without a question")
    func ordinaryReadingIsAutoAccepted() async throws {
        let app = try Harness()
        let prompter = FakePrompter()

        let reply = try await app.say("пробег 91500", prompter: prompter)

        #expect(prompter.questions.isEmpty)
        #expect(reply == .saved(.carBoard, preservedRaw: false))
        #expect(try await app.readings().map(\.value) == [91500])
    }

    @Test("REQ-CAPTURE-017, ADR-0023: a mileage below the last reading is asked, and cancelling keeps the old one")
    func lowerReadingAsks() async throws {
        let app = try Harness()
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
        let app = try Harness(persistence: .temporary)
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
        let app = try Harness(store: store)

        let reply = try await app.say("стук справа при повороте")

        #expect(reply == .notSaved)
        #expect(await store.storedNotes.isEmpty)
    }

    @Test("REQ-CAPTURE-005: a capture whose intent task was cancelled writes nothing")
    func cancelledTaskWritesNothing() async throws {
        let app = try Harness()
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
        let app = try Harness()

        let reply = try await app.say("   ")

        #expect(reply == .nothingToSave)
        #expect(try await app.isUnchanged())
    }
}

/// SYS-006: the missing detail is asked by voice, one question at a time, and answered through the
/// same pipeline as Pit (ADR 0026).
@Suite("Remember in PitStop voice clarification")
struct RememberVoiceClarificationTests {
    @Test("REQ-CAPTURE-020, ADR-0026: a missing mileage is asked as a number, heard back, and recorded")
    func mileageIsAsked() async throws {
        let app = try Harness(interpreter: .missing(.odometerReading))
        let prompter = FakePrompter(steps: [.answer(.spoken("84 200 km")), .choice(.record)])

        let reply = try await app.say("записал показания", prompter: prompter)

        #expect(prompter.questions == [
            .value(.odometerKm, repeated: false),
            .confirm(.odometerReading(kilometers: 84200, recordedAt: now), conflicts: []),
        ])
        #expect(reply == .saved(.carBoard, preservedRaw: false))
        #expect(try await app.readings().map(\.value) == [84200])
    }

    @Test(
        "REQ-CAPTURE-005, ADR-0026: a spoken mileage is never auto-accepted; cancelling its confirmation writes nothing"
    )
    func spokenMileageIsConfirmed() async throws {
        let app = try Harness(interpreter: .missing(.odometerReading))
        let prompter = FakePrompter(steps: [.answer(.spoken("about 80")), .choice(.cancel)])

        let reply = try await app.say("записал показания", prompter: prompter)

        #expect(prompter.questions.last == .confirm(.odometerReading(kilometers: 80, recordedAt: now), conflicts: []))
        #expect(reply == .cancelled)
        #expect(try await app.isUnchanged())
    }

    @Test("ADR-0026: a mileage the validator would reject is asked again, not kept as words")
    func zeroMileageIsAskedAgain() async throws {
        let app = try Harness(interpreter: .missing(.odometerReading))
        let prompter = FakePrompter(steps: [.answer(.spoken("0")), .answer(.spoken("91500")), .choice(.record)])

        let reply = try await app.say("записал показания", prompter: prompter)

        #expect(prompter.questions.prefix(2) == [
            .value(.odometerKm, repeated: false),
            .value(.odometerKm, repeated: true),
        ])
        #expect(reply == .saved(.carBoard, preservedRaw: false))
        #expect(try await app.readings().map(\.value) == [91500])
    }

    @Test("ADR-0026: \"80 thousand\" is not read as 80 km; it is asked again")
    func multiplierWordIsAskedAgain() async throws {
        let app = try Harness(interpreter: .missing(.odometerReading))
        let prompter = FakePrompter(steps: [
            .answer(.spoken("I don't know, about 80 thousand")),
            .answer(.unknown),
        ])

        let reply = try await app.say("записал показания", prompter: prompter)

        #expect(prompter.questions == [
            .value(.odometerKm, repeated: false),
            .value(.odometerKm, repeated: true),
        ])
        #expect(reply == .saved(.notes, preservedRaw: true))
        #expect(try await app.readings().isEmpty)
    }

    @Test("REQ-CAPTURE-020, ADR-0026: a missing operation is chosen from the catalog, then confirmed on its own")
    func operationIsChosenThenConfirmed() async throws {
        let app = try Harness(interpreter: .missing(.maintenanceCompletion, odometerKm: 84200))
        let prompter = FakePrompter(steps: [.answer(.picked(.operation(.engineOilService))), .choice(.record)])

        let reply = try await app.say("сделал работу на 84200", prompter: prompter)

        let catalog = MaintenanceOperationID.catalog.map(ClarificationAnswer.operation)
        #expect(prompter.questions == [
            .pick(.operationID, options: catalog),
            .confirm(
                .maintenanceCompletion(operationID: .engineOilService, performedAt: now, odometerKm: 84200),
                conflicts: []
            ),
        ])
        #expect(reply == .saved(.service, preservedRaw: false))
        #expect(try await app.completions().map(\.operationID) == [.engineOilService])
    }

    @Test("REQ-CAPTURE-020, ADR-0026: a missing event kind is chosen from the kinds Pit offers")
    func eventKindIsChosen() async throws {
        let app = try Harness(interpreter: .missing(.vehicleEvent))
        let prompter = FakePrompter(steps: [.answer(.picked(.eventKind(.carWash))), .choice(.record)])

        let reply = try await app.say("было событие", prompter: prompter)

        #expect(prompter.questions.first == .pick(
            .eventKind,
            options: HistoryEventKind.userSelectable.map(ClarificationAnswer.eventKind)
        ))
        #expect(prompter.questions.count == 2)
        #expect(reply == .saved(.history, preservedRaw: false))
        #expect(try await app.events().map(\.kind) == [.carWash])
    }

    @Test("REQ-CAPTURE-020, ADR-0026: a missing amount is asked as a number and read like Pit reads it")
    func amountIsAsked() async throws {
        let app = try Harness(interpreter: .missing(.expense))
        let prompter = FakePrompter(steps: [.answer(.spoken("1 500 ₽")), .choice(.record)])

        let reply = try await app.say("заплатил за мойку", prompter: prompter)

        #expect(prompter.questions.first == .value(.amount, repeated: false))
        #expect(reply == .saved(.history, preservedRaw: false))
        #expect(try await app.events().map(\.amount) == [1500])
    }

    @Test("ADR-0026: an unreadable number is asked once more, and a readable second answer is recorded")
    func unreadableNumberIsAskedAgain() async throws {
        let app = try Harness(interpreter: .missing(.odometerReading))
        let prompter = FakePrompter(steps: [
            .answer(.spoken("около того")),
            .answer(.spoken("91500")),
            .choice(.record),
        ])

        let reply = try await app.say("записал показания", prompter: prompter)

        #expect(prompter.questions.prefix(2) == [
            .value(.odometerKm, repeated: false),
            .value(.odometerKm, repeated: true),
        ])
        #expect(prompter.questions.count == 3)
        #expect(reply == .saved(.carBoard, preservedRaw: false))
        #expect(try await app.readings().map(\.value) == [91500])
    }

    @Test("REQ-CAPTURE-008, ADR-0026: two unreadable numbers keep the words, as \"I don't know\" would")
    func twoUnreadableNumbersKeepWords() async throws {
        let app = try Harness(interpreter: .missing(.odometerReading))
        let prompter = FakePrompter(steps: [.answer(.spoken("много")), .answer(.spoken("84.5"))])

        let reply = try await app.say("записал показания", prompter: prompter)

        #expect(prompter.questions.count == 2)
        #expect(reply == .saved(.notes, preservedRaw: true))
        #expect(try await app.notes().map(\.rawText) == ["записал показания"])
        #expect(try await app.readings().isEmpty)
    }

    @Test(
        "REQ-CAPTURE-008, ADR-0026: \"I don't know\" keeps the words without the structure",
        arguments: [ProposalKind.odometerReading, .maintenanceCompletion]
    )
    func unknownKeepsWords(kind: ProposalKind) async throws {
        let app = try Harness(interpreter: .missing(kind))
        let prompter = FakePrompter(steps: [.answer(.unknown)])

        let reply = try await app.say("что-то сделал", prompter: prompter)

        #expect(prompter.questions.count == 1)
        #expect(reply == .saved(.notes, preservedRaw: true))
        #expect(try await app.notes().map(\.rawText) == ["что-то сделал"])
        #expect(try await app.completions().isEmpty)
        #expect(try await app.readings().isEmpty)
    }

    @Test("REQ-CAPTURE-005, ADR-0026: cancelling the second question writes nothing from the first answer")
    func cancelMidClarificationWritesNothing() async throws {
        let app = try Harness(interpreter: .missing(.maintenancePolicyDraft))
        let prompter = FakePrompter(steps: [.answer(.picked(.operation(.cabinFilter))), .choice(.cancel)])

        let reply = try await app.say("менять фильтр чаще", prompter: prompter)

        #expect(prompter.questions == [
            .pick(.operationID, options: MaintenanceOperationID.catalog.map(ClarificationAnswer.operation)),
            .clarify(.policyInterval),
        ])
        #expect(reply == .cancelled)
        #expect(try await app.isUnchanged())
        #expect(app.stages.events.filter { $0.stage == .captureDiscarded }.count == 1)
    }

    @Test("REQ-CAPTURE-005, ADR-0026: a dismissed number prompt writes nothing and reaches the system")
    func dismissedValuePromptWritesNothing() async throws {
        let app = try Harness(interpreter: .missing(.odometerReading))

        await #expect(throws: PromptDismissed.self) {
            try await app.say("записал показания", prompter: FakePrompter(failingWith: PromptDismissed()))
        }

        #expect(try await app.isUnchanged())
        #expect(app.stages.events.last?.stage == .captureDiscarded)
    }

    @Test("REQ-CAPTURE-025, ADR-0026: no question asked on the way repeats the words, on screen or by voice")
    func askedQuestionsNeverRepeatWords() async throws {
        let words = "стук справа при повороте"
        let app = try Harness(interpreter: .missing(.maintenanceCompletion))
        let prompter = FakePrompter(steps: [
            .answer(.picked(.operation(.brakeFluid))),
            .choice(.wordsOnly),
        ])

        _ = try await app.say(words, prompter: prompter)

        #expect(prompter.questions.count == 2)
        for question in prompter.questions {
            for language in ["en", "ru", "uk"] {
                for voiceOnly in [false, true] {
                    let speech = RememberSpeech(locale: Locale(identifier: language), isVoiceOnly: voiceOnly)
                    #expect(!String(localized: speech.question(question)).contains("стук"))
                }
            }
        }
    }

    @Test(
        "ADR-0026: spoken numbers are read with Pit's parsers",
        arguments: [
            ("84 200 km", ProposalField.odometerKm, ClarificationAnswer.odometerKm(84200)),
            ("84,200", .odometerKm, .odometerKm(84200)),
            ("пробег 91500 км.", .odometerKm, .odometerKm(91500)),
            ("1500 ₽", .amount, .amount(1500)),
            ("1,200", .amount, .amount(1200)),
            ("12,50", .amount, .amount(Decimal(1250) / 100)),
            ("1.234", .amount, .amount(1234)),
            ("84200 kilometres", .odometerKm, .odometerKm(84200)),
            ("84 200 километров", .odometerKm, .odometerKm(84200)),
            ("1500 rubles", .amount, .amount(1500)),
            ("1500 рублей", .amount, .amount(1500)),
            ("1500 р.", .amount, .amount(1500)),
            ("200 грв", .amount, .amount(200)),
            ("200 грн", .amount, .amount(200)),
            ("50 USD", .amount, .amount(50)),
        ] as [(String, ProposalField, ClarificationAnswer?)]
    )
    func spokenNumbersAreRead(text: String, field: ProposalField, expected: ClarificationAnswer?) {
        #expect(RememberIntentHandler.clarificationAnswer(text, for: field) == expected)
    }

    @Test(
        "ADR-0026: what Pit would reject is not guessed",
        arguments: [
            ("84.5", ProposalField.odometerKm),
            ("много", .odometerKm),
            ("9 999 999", .odometerKm),
            ("0", .amount),
            ("12.3.4", .amount),
            ("84k", .odometerKm),
            ("84 thousand", .odometerKm),
            ("84 тысячи", .odometerKm),
            ("1.5 thousand", .amount),
            ("I don't know, about 80 thousand", .odometerKm),
            ("0", .odometerKm),
            ("1500 km", .amount),
            ("", .amount),
        ] as [(String, ProposalField)]
    )
    func unreadableNumbersAreRejected(text: String, field: ProposalField) {
        #expect(RememberIntentHandler.clarificationAnswer(text, for: field) == nil)
    }
}
