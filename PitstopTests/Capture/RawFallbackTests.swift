import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate

/// Never answers on its own; it only stops when its task is cancelled.
private struct HangingInterpreter: SemanticInterpreting {
    func interpret(_: CaptureInput) async throws -> MemoryProposal? {
        try await Task.sleep(for: .seconds(3600))
        return nil
    }
}

/// Answers at once with a completion draft for the given wording.
private struct CompletionInterpreter: SemanticInterpreting {
    func interpret(_ input: CaptureInput) async throws -> MemoryProposal? {
        try await RuleBasedInterpreter().interpret(input)
    }
}

private func input(_ text: String) -> CaptureInput {
    CaptureInput(payload: .transcript(text), source: .pitVoice, capturedAt: now)
}

private func pipeline(
    _ store: FakeCarMemoryStore,
    interpreter: any SemanticInterpreting,
    deadline: InterpretationDeadline,
    observer: any CaptureStageObserving = NoCaptureStageObserver()
) -> RememberPipeline {
    RememberPipeline(store: store, interpreter: interpreter, observer: observer, deadline: deadline, now: { now })
}

/// A deadline whose timer fires at once, so the interpreter always loses the race.
private let expiredDeadline = InterpretationDeadline(limit: .seconds(1)) { _ in }
/// A deadline whose timer never fires first, so any interpreter that answers wins.
private let distantDeadline = InterpretationDeadline(limit: .seconds(3600))

/// A broken race would hang rather than fail; the limit turns that into a failure.
@Suite("Raw-preservation fallback", .timeLimit(.minutes(1)))
struct RawFallbackTests {
    @Test("REQ-CAPTURE-007: an interpreter that never answers is abandoned at the deadline and the wording is saved")
    func hungInterpreterFallsBackToRaw() async throws {
        let store = FakeCarMemoryStore()
        let spy = StageSpy()
        let flow = pipeline(store, interpreter: HangingInterpreter(), deadline: expiredDeadline, observer: spy)

        let outcome = try await flow.remember(input("поменял масло на 85000"), mode: .interpreted)

        guard case let .saved(_, preservedRaw) = outcome else {
            Issue.record("expected a saved note, got \(outcome)")
            return
        }
        #expect(preservedRaw)
        #expect(await store.storedNotes.map(\.rawText) == ["поменял масло на 85000"])
        #expect(await store.completions.isEmpty)
        // A timed-out interpretation is a degradation, counted like an unavailable interpreter.
        #expect(spy.events.map(\.stage).contains(.rawPreserved))
    }

    @Test("ADR-0015: an interpreter that answers before the deadline is not cut short")
    func timelyInterpreterIsUsed() async throws {
        let store = FakeCarMemoryStore()
        let flow = pipeline(store, interpreter: CompletionInterpreter(), deadline: distantDeadline)

        let outcome = try await flow.remember(input("поменял масло на 85000"), mode: .interpreted)

        guard case .needsConfirmation = outcome else {
            Issue.record("expected the interpreted completion to ask for confirmation, got \(outcome)")
            return
        }
        #expect(await store.storedNotes.isEmpty)
    }

    @Test("REQ-CAPTURE-005: a capture cancelled while it is being interpreted writes nothing")
    func cancelledDuringInterpretationWritesNothing() async throws {
        let store = FakeCarMemoryStore()
        let spy = StageSpy()
        let flow = pipeline(store, interpreter: HangingInterpreter(), deadline: distantDeadline, observer: spy)

        let task = Task { try await flow.remember(input("поменял масло на 85000"), mode: .interpreted) }
        // Cancel once interpretation is under way; the hanging interpreter cannot answer before it.
        while !spy.events.map(\.stage).contains(.interpretationStarted) {
            await Task.yield()
        }
        task.cancel()
        let outcome = try await task.value

        #expect(outcome == .nothingToSave)
        #expect(await store.storedNotes.isEmpty)
        #expect(spy.events.last?.stage == .captureDiscarded)
        #expect(!spy.events.map(\.stage).contains(.mutationCompleted))
        // It stops before validation, so no store read can turn the cancellation into a failure.
        #expect(!spy.events.map(\.stage).contains(.proposalValidated))
    }

    @Test("REQ-CAPTURE-005: a raw capture whose task is already cancelled writes nothing")
    func cancelledRawCaptureWritesNothing() async throws {
        let store = FakeCarMemoryStore()
        let flow = RememberPipeline(store: store, now: { now })

        let outcome = try await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await flow.rememberRaw(input("проверить давление в шинах"))
        }.value

        #expect(outcome == .nothingToSave)
        #expect(await store.storedNotes.isEmpty)
    }

    @Test("ADR-0015: an interpreter that throws still falls back before the deadline")
    func failingInterpreterDoesNotWaitForTheDeadline() async throws {
        struct Unavailable: SemanticInterpreting {
            func interpret(_: CaptureInput) async throws -> MemoryProposal? {
                throw CarMemoryStoreError.storageFailure
            }
        }
        let store = FakeCarMemoryStore()
        let flow = pipeline(store, interpreter: Unavailable(), deadline: distantDeadline)

        let outcome = try await flow.remember(input("стук справа"), mode: .interpreted)

        guard case .saved(_, preservedRaw: true) = outcome else {
            Issue.record("expected a raw save, got \(outcome)")
            return
        }
        #expect(await store.storedNotes.map(\.rawText) == ["стук справа"])
    }
}
