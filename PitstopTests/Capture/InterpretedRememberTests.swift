import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate

/// Records whether it was asked, and answers with whatever the test decided.
private actor StubInterpreter: SemanticInterpreting {
    private let answer: @Sendable (CaptureInput) throws -> MemoryProposal?
    private(set) var callCount = 0

    init(answer: @escaping @Sendable (CaptureInput) throws -> MemoryProposal?) {
        self.answer = answer
    }

    static func unavailable() -> StubInterpreter {
        StubInterpreter { _ in throw CarMemoryStoreError.storageFailure }
    }

    func interpret(_ input: CaptureInput) async throws -> MemoryProposal? {
        callCount += 1
        return try answer(input)
    }
}

private func input(_ text: String, source: CaptureSource = .pitVoice, feature: VisibleFeature? = nil) -> CaptureInput {
    CaptureInput(payload: .transcript(text), source: source, capturedAt: now, visibleFeature: feature)
}

private func pipeline(
    _ store: FakeCarMemoryStore,
    interpreter: any SemanticInterpreting = RuleBasedInterpreter()
) -> RememberPipeline {
    RememberPipeline(store: store, interpreter: interpreter, now: { now })
}

@Suite("Interpreted Remember")
struct InterpretedRememberTests {
    @Test("REQ-CAPTURE-001: raw mode never calls the interpreter and saves the wording")
    func rawModeCallsNoInterpreter() async throws {
        let store = FakeCarMemoryStore()
        let interpreter = StubInterpreter { _ in Issue.record("the interpreter was called in raw mode"); return nil }
        let capture = input("поменял масло на 85000")

        let outcome = try await pipeline(store, interpreter: interpreter).remember(capture, mode: .raw)

        #expect(await interpreter.callCount == 0)
        guard case let .saved(result, preservedRaw) = outcome, case let .noteCreated(note) = result else {
            Issue.record("expected a saved note, got \(outcome)")
            return
        }
        #expect(preservedRaw && note.rawText == "поменял масло на 85000")
        #expect(await store.completions.isEmpty)
    }

    @Test("REQ-CAPTURE-016: an interpreted completion waits for confirmation and resets no cycle")
    func completionNeedsConfirmation() async throws {
        let store = FakeCarMemoryStore()
        let capture = input("поменял масло на 85000")

        let outcome = try await pipeline(store).remember(capture, mode: .interpreted)

        guard case let .needsConfirmation(pending) = outcome else {
            Issue.record("expected a confirmation, got \(outcome)")
            return
        }
        #expect(pending.kind == .maintenanceCompletion)
        #expect(pending.rawText == "поменял масло на 85000")
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-CAPTURE-005: cancelling a pending proposal performs no mutation")
    func cancellationMutatesNothing() async throws {
        let store = FakeCarMemoryStore()
        let capture = input("поменял масло на 85000")
        let flow = pipeline(store)
        guard case let .needsConfirmation(pending) = try await flow.remember(capture, mode: .interpreted) else {
            Issue.record("expected a confirmation")
            return
        }

        flow.cancel(pending.input, kind: pending.kind)

        #expect(await store.executed.isEmpty)
        #expect(await store.storedNotes.isEmpty)
    }

    @Test("REQ-CAPTURE-016: confirming writes exactly the confirmed completion")
    func confirmingWritesTheCompletion() async throws {
        let store = FakeCarMemoryStore()
        let flow = pipeline(store)
        guard case let .needsConfirmation(pending) = try await flow.remember(
            input("поменял масло на 85000"),
            mode: .interpreted
        ) else {
            Issue.record("expected a confirmation")
            return
        }

        let outcome = try await flow.confirm(pending)

        guard case let .saved(result, preservedRaw) = outcome, case let .completionConfirmed(completion) = result else {
            Issue.record("expected a confirmed completion, got \(outcome)")
            return
        }
        #expect(!preservedRaw)
        #expect(completion.operationID == .engineOilService && completion.odometerKm == 85000)
        #expect(await store.completions.count == 1)
        #expect(await store.storedNotes.isEmpty)
    }

    @Test("REQ-CAPTURE-008: declining the proposed meaning still saves the wording, marked as raw")
    func decliningPreservesTheWording() async throws {
        let store = FakeCarMemoryStore()
        let flow = pipeline(store)
        guard case let .needsConfirmation(pending) = try await flow.remember(
            input("помыл машину за 1200"),
            mode: .interpreted
        ) else {
            Issue.record("expected a confirmation")
            return
        }

        let outcome = try await flow.preserveRaw(pending.input, kind: pending.kind)

        guard case let .saved(result, preservedRaw) = outcome, case let .noteCreated(note) = result else {
            Issue.record("expected a saved note, got \(outcome)")
            return
        }
        #expect(preservedRaw && note.rawText == "помыл машину за 1200")
        #expect(await store.events.isEmpty)
    }

    @Test("REQ-CAPTURE-006: unsupported meaning is saved raw without asking anything")
    func unsupportedMeaningIsSavedRaw() async throws {
        let store = FakeCarMemoryStore()
        let text = "Стук в подвеске справа спереди"

        let outcome = try await pipeline(store).remember(input(text), mode: .interpreted)

        guard case let .saved(_, preservedRaw) = outcome else {
            Issue.record("expected a saved note, got \(outcome)")
            return
        }
        #expect(preservedRaw)
        #expect(await store.storedNotes.map(\.rawText) == [text])
    }

    @Test("REQ-CAPTURE-007: an unavailable interpreter preserves the input without loss")
    func unavailableInterpreterPreservesInput() async throws {
        let store = FakeCarMemoryStore()
        let flow = pipeline(store, interpreter: StubInterpreter.unavailable())

        let outcome = try await flow.remember(input("поменял масло на 85000"), mode: .interpreted)

        guard case let .saved(_, preservedRaw) = outcome else {
            Issue.record("expected a saved note, got \(outcome)")
            return
        }
        #expect(preservedRaw)
        #expect(await store.storedNotes.map(\.rawText) == ["поменял масло на 85000"])
    }

    @Test("REQ-CAPTURE-014: an intention is saved as a note and confirms no work")
    func intentionStaysANote() async throws {
        let store = FakeCarMemoryStore()

        _ = try await pipeline(store).remember(input("надо поменять масло"), mode: .interpreted)

        #expect(await store.storedNotes.map(\.rawText) == ["надо поменять масло"])
        #expect(await store.completions.isEmpty)
        #expect(await store.events.isEmpty)
    }

    @Test("REQ-CAPTURE-020: a missing field is asked on its own, and answering it continues the same capture")
    func clarificationAsksOneThing() async throws {
        let store = FakeCarMemoryStore()
        let capture = input("записал показания")
        let draft = MemoryProposal(
            sourceInputID: capture.id,
            kind: .odometerReading,
            rawText: capture.payload.rawContent
        )
        let flow = pipeline(store, interpreter: StubInterpreter { _ in draft })

        guard case let .needsClarification(request) = try await flow.remember(capture, mode: .interpreted) else {
            Issue.record("expected a clarification")
            return
        }
        #expect(request.question == .odometerKm && request.remaining.isEmpty)
        #expect(await store.executed.isEmpty)

        let outcome = try await flow.answer(request, with: .odometerKm(84200))

        guard case let .saved(result, _) = outcome, case let .readingRecorded(reading) = result else {
            Issue.record("expected a recorded reading, got \(outcome)")
            return
        }
        #expect(reading.value == 84200)
    }

    @Test("REQ-CAPTURE-006: answering \"I don't know\" keeps the wording and writes no structure")
    func unknownAnswerPreservesRaw() async throws {
        let store = FakeCarMemoryStore()
        let capture = input("записал показания")
        let draft = MemoryProposal(
            sourceInputID: capture.id,
            kind: .odometerReading,
            rawText: capture.payload.rawContent
        )
        let flow = pipeline(store, interpreter: StubInterpreter { _ in draft })
        guard case let .needsClarification(request) = try await flow.remember(capture, mode: .interpreted) else {
            Issue.record("expected a clarification")
            return
        }

        _ = try await flow.answer(request, with: .unknown)

        #expect(await store.storedNotes.map(\.rawText) == ["записал показания"])
        #expect(await store.readings.isEmpty)
    }

    @Test("REQ-CAPTURE-022: the visible surface does not force the proposal kind", arguments: VisibleFeature.allCases)
    func visibleFeatureIsOnlyAPrior(feature: VisibleFeature) async throws {
        let store = FakeCarMemoryStore()
        let capture = input("пробег 84 200", feature: feature)

        let outcome = try await pipeline(store).remember(capture, mode: .interpreted)

        guard case let .saved(result, _) = outcome, case .readingRecorded = result else {
            Issue.record("expected a recorded reading on \(feature), got \(outcome)")
            return
        }
    }

    @Test("REQ-CAPTURE-009: a write that fails is reported as an error, not as a saved memory")
    func failedWriteIsNotSaved() async throws {
        let store = FakeCarMemoryStore()
        let flow = pipeline(store)
        guard case let .needsConfirmation(pending) = try await flow.remember(
            input("поменял масло на 85000"),
            mode: .interpreted
        ) else {
            Issue.record("expected a confirmation")
            return
        }
        await store.failCommands()

        await #expect(throws: RememberError.notSaved) { try await flow.confirm(pending) }
        #expect(await store.completions.isEmpty)
    }

    @Test("ADR-0006: blank input asks nothing and saves nothing", arguments: [RememberMode.raw, .interpreted])
    func blankInputSavesNothing(mode: RememberMode) async throws {
        let store = FakeCarMemoryStore()
        #expect(try await pipeline(store).remember(input("   "), mode: mode) == .nothingToSave)
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-CAPTURE-017: a reading below the latest known one is confirmed, not written silently")
    func readingBelowLatestIsConfirmed() async throws {
        let store = FakeCarMemoryStore()
        let vehicleID = await store.vehicle.id
        let latest = OdometerReading(vehicleID: vehicleID, value: 84200, recordedAt: now)
        _ = try await store.execute(.recordOdometerReading(.init(reading: latest)), now: now)

        let outcome = try await pipeline(store).remember(input("пробег 8 420"), mode: .interpreted)

        guard case let .needsConfirmation(pending) = outcome else {
            Issue.record("expected a confirmation, got \(outcome)")
            return
        }
        #expect(pending.conflicts == [.odometerBelowLatest(latestKm: 84200)])
        #expect(await store.readings.count == 1)
    }

    @Test("REQ-CAPTURE-004: confirming the same proposal twice writes one record, not two")
    func confirmingTwiceWritesOnce() async throws {
        let store = FakeCarMemoryStore()
        let spy = StageSpy()
        let flow = RememberPipeline(store: store, interpreter: RuleBasedInterpreter(), observer: spy, now: { now })
        guard case let .needsConfirmation(pending) = try await flow.remember(
            input("поменял масло на 85000"),
            mode: .interpreted
        ) else {
            Issue.record("expected a confirmation")
            return
        }

        _ = try await flow.confirm(pending)
        // The second confirmation is refused as already saved, not reported as a lost write.
        await #expect(throws: RememberError.alreadySaved) { try await flow.confirm(pending) }
        #expect(!spy.events.contains { $0.stage == .pipelineFailed })

        #expect(await store.completions.count == 1)
    }

    @Test("REQ-CAPTURE-024: the interpreted path reports its stages under one correlation ID")
    func interpretedStagesAreObserved() async throws {
        let spy = StageSpy()
        let store = FakeCarMemoryStore()
        let capture = input("поменял масло на 85000")
        let flow = RememberPipeline(store: store, interpreter: RuleBasedInterpreter(), observer: spy, now: { now })

        guard case let .needsConfirmation(pending) = try await flow.remember(capture, mode: .interpreted) else {
            Issue.record("expected a confirmation")
            return
        }
        _ = try await flow.confirm(pending)

        #expect(spy.events.map(\.stage) == [
            .captureReceived, .interpretationStarted, .interpretationCompleted, .proposalValidated,
            .confirmationRequired, .domainCommandCreated, .mutationCompleted,
        ])
        #expect(Set(spy.events.map(\.correlationID)) == [capture.id])
    }

    @Test("REQ-CAPTURE-008: degradation is reported as raw only once the wording is stored")
    func degradationIsReportedAfterTheWrite() async throws {
        let spy = StageSpy()
        let flow = RememberPipeline(
            store: FakeCarMemoryStore(),
            interpreter: RuleBasedInterpreter(),
            observer: spy,
            now: { now }
        )

        _ = try await flow.remember(input("Стук в подвеске справа"), mode: .interpreted)

        #expect(spy.events.map(\.stage).suffix(2) == [.mutationCompleted, .rawPreserved])

        let failing = FakeCarMemoryStore()
        await failing.failCommands()
        let failingSpy = StageSpy()
        let failingFlow = RememberPipeline(
            store: failing,
            interpreter: RuleBasedInterpreter(),
            observer: failingSpy,
            now: { now }
        )
        _ = try? await failingFlow.remember(input("Стук в подвеске справа"), mode: .interpreted)
        #expect(!failingSpy.events.contains { $0.stage == .rawPreserved })
    }

    @Test("ADR-0006: explicit raw mode is not degradation, so no raw_preserved stage is reported")
    func explicitRawModeIsNotDegradation() async throws {
        let spy = StageSpy()
        let flow = RememberPipeline(
            store: FakeCarMemoryStore(),
            interpreter: RuleBasedInterpreter(),
            observer: spy,
            now: { now }
        )

        let outcome = try await flow.remember(input("поменял масло на 85000"), mode: .raw)

        guard case let .saved(_, preservedRaw) = outcome else {
            Issue.record("expected a saved note, got \(outcome)")
            return
        }
        // The user is still told it was saved as it is, but the stage means degradation only.
        #expect(preservedRaw)
        #expect(!spy.events.contains { $0.stage == .rawPreserved })
    }
}
