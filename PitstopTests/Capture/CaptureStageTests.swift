import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate

private final class StageSpy: CaptureStageObserving, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [CaptureStageEvent] = []

    var events: [CaptureStageEvent] {
        lock.withLock { recorded }
    }

    func record(_ event: CaptureStageEvent) {
        lock.withLock { recorded.append(event) }
    }
}

@Suite("Capture pipeline observability")
struct CaptureStageTests {
    private let secret = "VIN WVWZZZ3HZKE012345, стук справа, 84200 км"

    @Test(
        "REQ-CAPTURE-024: every stage of one capture carries the input's correlation ID",
        arguments: CaptureSource.allCases
    )
    func correlationIDSpansThePipeline(source: CaptureSource) async throws {
        let spy = StageSpy()
        let input = CaptureInput(payload: .text(secret), source: source, capturedAt: now)

        _ = try await RememberPipeline(store: FakeCarMemoryStore(), observer: spy, now: { now }).rememberRaw(input)

        #expect(spy.events.map(\.stage) == [
            .captureReceived, .proposalValidated, .domainCommandCreated, .mutationCompleted,
        ])
        #expect(Set(spy.events.map(\.correlationID)) == [input.id])
        #expect(Set(spy.events.map(\.source)) == [source])
    }

    @Test("REQ-CAPTURE-025: no observed event carries the raw content in any form")
    func eventsExcludeRawContent() async throws {
        let spy = StageSpy()
        let input = CaptureInput(payload: .transcript(secret), source: .pitVoice, capturedAt: now)

        _ = try await RememberPipeline(store: FakeCarMemoryStore(), observer: spy, now: { now }).rememberRaw(input)

        for event in spy.events {
            let dump = String(reflecting: event)
            #expect(!dump.contains("WVWZZZ") && !dump.contains("стук") && !dump.contains("84200"))
            // Every stored field is an ID or a closed enum. A new field of any other type fails here,
            // so "no raw content by construction" is checked, not assumed.
            for child in Mirror(reflecting: event).children {
                let isAllowed = child.value is UUID || child.value is CaptureStage || child.value is CaptureSource
                    || child.value is ProposalKind? || child.value is ConfirmationOutcome?
                #expect(isAllowed, "unexpected field \(child.label ?? "?") of type \(type(of: child.value))")
            }
        }
    }

    @Test("ADR-0006: a write that fails is observed as pipeline_failed and never as a completed mutation")
    func failedWriteIsObserved() async {
        let spy = StageSpy()
        let store = FakeCarMemoryStore()
        await store.failCommands()
        let input = CaptureInput(payload: .text("мысль"), source: .widget, capturedAt: now)

        _ = try? await RememberPipeline(store: store, observer: spy, now: { now }).rememberRaw(input)

        #expect(spy.events.map(\.stage) == [
            .captureReceived,
            .proposalValidated,
            .domainCommandCreated,
            .pipelineFailed,
        ])
        #expect(await store.storedNotes.isEmpty)
    }

    @Test("ADR-0006: a store that cannot be read fails the pipeline before any proposal exists")
    func unreadableStoreIsObserved() async {
        let spy = StageSpy()
        let store = FakeCarMemoryStore()
        await store.failEverything()

        _ = try? await RememberPipeline(store: store, observer: spy, now: { now })
            .rememberRaw(CaptureInput(payload: .text("мысль"), source: .siri, capturedAt: now))

        #expect(spy.events.map(\.stage) == [.captureReceived, .pipelineFailed])
    }

    @Test("ADR-0006: blank input ends with capture_discarded, so it is not mistaken for a stalled pipeline")
    func blankInputHasATerminalStage() async throws {
        let spy = StageSpy()
        let outcome = try await RememberPipeline(store: FakeCarMemoryStore(), observer: spy, now: { now })
            .rememberRaw(CaptureInput(payload: .text("  "), source: .pitText, capturedAt: now))
        #expect(outcome == .nothingToSave)
        #expect(spy.events.map(\.stage) == [.captureReceived, .captureDiscarded])
    }

    @Test("REQ-CAPTURE-024: the stage names are the contract's observability list plus the proposed capture_discarded")
    func stageNamesMatchContract() {
        #expect(CaptureStage.allCases.map(\.rawValue) == [
            "capture_received", "interpretation_started", "interpretation_completed", "proposal_validated",
            "confirmation_required", "clarification_required", "domain_command_created", "mutation_completed",
            "raw_preserved", "pipeline_failed", "capture_discarded",
        ])
    }
}
