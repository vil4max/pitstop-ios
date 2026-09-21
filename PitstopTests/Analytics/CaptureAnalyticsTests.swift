import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate

/// Builds the same composition as the app, around a spy and a consent value.
private struct Harness {
    let spy: RecordingAnalyticsClient
    let clock: ManualClock
    let observer: CaptureAnalyticsObserver

    init(consent: AnalyticsConsent = .granted, interpreter: InterpreterVersion = .ruleBasedV1) {
        let spy = RecordingAnalyticsClient()
        let clock = ManualClock()
        self.spy = spy
        self.clock = clock
        let client = ConsentGatedAnalyticsClient(client: spy, consent: FixedAnalyticsConsent(consent: consent))
        observer = CaptureAnalyticsObserver(
            capture: AnalyticsTracker(client: client),
            notes: AnalyticsTracker(client: client),
            odometer: AnalyticsTracker(client: client),
            interpreter: interpreter,
            now: { clock.now }
        )
    }

    func stages(
        _ stages: [(CaptureStage, ProposalKind?)],
        id: UUID = UUID(),
        source: CaptureSource = .pitText
    ) {
        for (stage, kind) in stages {
            observer.record(CaptureStageEvent(correlationID: id, stage: stage, source: source, proposalKind: kind))
        }
    }
}

@Suite("Capture analytics mapping")
struct CaptureAnalyticsMappingTests {
    @Test("ADR-0021: a raw note is note_created with no context and no interpretation events")
    func rawNote() {
        let harness = Harness()
        harness.stages([
            (.captureReceived, nil), (.proposalValidated, .rawNote), (.domainCommandCreated, .rawNote),
            (.mutationCompleted, .rawNote),
        ], source: .directApp)

        #expect(harness.spy.names == [.noteCreated])
        #expect(harness.spy.last(.noteCreated) == [
            .inputSource: "explicit", .contextCountBucket: "0", .hasCanonicalContext: "false",
        ])
    }

    @Test("ADR-0021: an auto-accepted reading was never shown, so it is odometer_updated without a draft event")
    func autoAcceptedReading() {
        let harness = Harness()
        let id = UUID()
        harness.stages([(.captureReceived, nil), (.interpretationStarted, nil)], id: id, source: .pitVoice)
        harness.clock.advance(by: .milliseconds(400))
        harness.stages([
            (.interpretationCompleted, .odometerReading), (.proposalValidated, .odometerReading),
            (.domainCommandCreated, .odometerReading), (.mutationCompleted, .odometerReading),
        ], id: id, source: .pitVoice)

        #expect(harness.spy.names == [.inputInterpretationCompleted, .odometerUpdated])
        #expect(harness.spy.last(.inputInterpretationCompleted) == [
            .intent: "odometer_reading", .availability: "available", .result: "draft",
            .latencyBucket: "lt_1s", .interpreterVersion: "rule_based_1",
        ])
        #expect(harness.spy.last(.odometerUpdated) == [.source: "natural", .anomalyConfirmation: "none"])
    }

    @Test("ADR-0021: an interpreter with no meaning is a fallback, and the wording is a created note")
    func fallbackSavesANote() {
        let harness = Harness()
        harness.stages([
            (.captureReceived, nil), (.interpretationStarted, nil), (.interpretationCompleted, nil),
            (.proposalValidated, .rawNote), (.domainCommandCreated, .rawNote), (.mutationCompleted, .rawNote),
            (.rawPreserved, .rawNote),
        ])

        #expect(harness.spy.names == [.inputInterpretationCompleted, .noteCreated])
        #expect(harness.spy.last(.inputInterpretationCompleted)?[.result] == "fallback")
        #expect(harness.spy.last(.inputInterpretationCompleted)?[.intent] == "none")
    }

    @Test("ADR-0021: closing a shown proposal is draft_cancelled at the preview stage")
    func cancelledPreview() {
        let harness = Harness()
        harness.stages([
            (.captureReceived, nil), (.interpretationStarted, nil), (.interpretationCompleted, .maintenanceCompletion),
            (.proposalValidated, .maintenanceCompletion), (.confirmationRequired, .maintenanceCompletion),
            (.captureDiscarded, .maintenanceCompletion),
        ])

        #expect(harness.spy.names == [.inputInterpretationCompleted, .draftCancelled])
        #expect(harness.spy.last(.draftCancelled) == [.intent: "maintenance_completion", .stage: "preview"])
    }

    @Test("ADR-0021: keeping only the words cancels the draft and creates a note")
    func declinedDraftKeepsWords() {
        let harness = Harness()
        let id = UUID()
        harness.stages([
            (.captureReceived, nil), (.interpretationStarted, nil), (.interpretationCompleted, .vehicleEvent),
            (.proposalValidated, .vehicleEvent), (.confirmationRequired, .vehicleEvent),
        ], id: id)
        harness.stages([
            (.proposalValidated, .rawNote), (.domainCommandCreated, .rawNote), (.mutationCompleted, .rawNote),
            (.rawPreserved, .rawNote),
        ], id: id)

        #expect(harness.spy.names == [.inputInterpretationCompleted, .draftCancelled, .noteCreated])
        #expect(harness.spy.last(.draftCancelled) == [.intent: "vehicle_event", .stage: "preview"])
    }

    @Test("ADR-0021: a draft completed through clarification is saved as edited")
    func clarifiedDraftIsEdited() {
        let harness = Harness()
        harness.stages([
            (.captureReceived, nil), (.interpretationStarted, nil), (.interpretationCompleted, .odometerReading),
            (.proposalValidated, .odometerReading), (.clarificationRequired, .odometerReading),
            (.proposalValidated, .odometerReading), (.domainCommandCreated, .odometerReading),
            (.mutationCompleted, .odometerReading),
        ])

        #expect(harness.spy.last(.draftSaved) == [.intent: "odometer_reading", .edited: "true"])
        #expect(harness.spy.last(.odometerUpdated)?[.anomalyConfirmation] == "none")
    }

    @Test("ADR-0021: a failed write keeps the capture, so the retried confirmation is still one saved draft")
    func retryAfterFailureSavesOnce() {
        let harness = Harness()
        let id = UUID()
        harness.stages([
            (.captureReceived, nil), (.interpretationStarted, nil), (.interpretationCompleted, .odometerReading),
            (.proposalValidated, .odometerReading), (.confirmationRequired, .odometerReading),
            (.domainCommandCreated, .odometerReading), (.pipelineFailed, .odometerReading),
        ], id: id)
        harness.stages([(.domainCommandCreated, .odometerReading), (.mutationCompleted, .odometerReading)], id: id)

        #expect(harness.spy.names == [.inputInterpretationCompleted, .draftSaved, .odometerUpdated])
        #expect(harness.spy.last(.odometerUpdated)?[.anomalyConfirmation] == "accepted")
    }

    @Test("ADR-0021: a confirmed captured reading is a saved draft with an accepted anomaly")
    func confirmedReading() {
        let harness = Harness()
        harness.stages([
            (.captureReceived, nil), (.interpretationStarted, nil), (.interpretationCompleted, .odometerReading),
            (.proposalValidated, .odometerReading), (.confirmationRequired, .odometerReading),
            (.domainCommandCreated, .odometerReading), (.mutationCompleted, .odometerReading),
        ], source: .siri)

        #expect(harness.spy.names == [.inputInterpretationCompleted, .draftSaved, .odometerUpdated])
        #expect(harness.spy.last(.draftSaved) == [.intent: "odometer_reading", .edited: "false"])
        #expect(harness.spy.last(.odometerUpdated) == [.source: "siri", .anomalyConfirmation: "accepted"])
    }

    @Test("ADR-0021: a contextual note has a canonical context and no guessed context count")
    func contextualNote() {
        let harness = Harness()
        harness.stages([
            (.captureReceived, nil), (.proposalValidated, .contextualNote), (.domainCommandCreated, .contextualNote),
            (.mutationCompleted, .contextualNote),
        ], source: .pitVoice)

        #expect(harness.spy.names == [.noteCreated])
        #expect(harness.spy.last(.noteCreated) == [.inputSource: "voice", .hasCanonicalContext: "true"])
    }

    @Test("ADR-0021: an evicted capture is not re-created by its later stages and reports no draft or latency")
    func journeysAreBounded() {
        let harness = Harness()
        let abandoned = UUID()
        harness.stages([(.captureReceived, nil), (.confirmationRequired, .expense)], id: abandoned)
        for _ in 0 ..< CaptureAnalyticsObserver.journeyLimit {
            harness.stages([(.captureReceived, nil)])
        }
        // Stages that used to re-create a journey outside the eviction order.
        harness.stages([(.interpretationStarted, nil), (.confirmationRequired, .expense)], id: abandoned)
        for _ in 0 ..< CaptureAnalyticsObserver.journeyLimit {
            harness.stages([(.captureReceived, nil)])
        }
        harness.stages([(.interpretationCompleted, .expense), (.captureDiscarded, .expense)], id: abandoned)

        #expect(harness.spy.names == [.inputInterpretationCompleted])
        #expect(harness.spy.last(.inputInterpretationCompleted)?[.latencyBucket] == nil)
    }

    @Test("ADR-0021: blank input reports nothing")
    func blankInputIsSilent() {
        let harness = Harness()
        harness.stages([(.captureReceived, nil), (.captureDiscarded, nil)])
        #expect(harness.spy.events.isEmpty)
    }
}

@MainActor
@Suite("Capture analytics end to end")
struct CaptureAnalyticsEndToEndTests {
    private let secret = "поменял масло на 85000, VIN WVWZZZ3HZKE012345"

    private func makeModel(_ harness: Harness, store: FakeCarMemoryStore) -> PitCaptureViewModel {
        PitCaptureViewModel(
            pipeline: RememberPipeline(
                store: store,
                interpreter: RuleBasedInterpreter(),
                observer: CaptureStageObservers([CaptureStageLogger(), harness.observer]),
                now: { now }
            ),
            now: { now }
        )
    }

    @Test("ADR-0021: a confirmed Pit capture reaches the spy as interpretation and a saved draft, with no raw content")
    func confirmedCapture() async {
        let harness = Harness()
        let store = FakeCarMemoryStore()
        let model = makeModel(harness, store: store)
        model.text = secret

        await model.submit(from: .service)
        await model.confirm()

        #expect(await store.completions.count == 1)
        #expect(harness.spy.names == [.inputInterpretationCompleted, .draftSaved])
        #expect(harness.spy.last(.inputInterpretationCompleted)?[.intent] == "maintenance_completion")
        #expect(harness.spy.last(.draftSaved) == [.intent: "maintenance_completion", .edited: "false"])
        let dump = String(reflecting: harness.spy.events)
        #expect(!dump.contains("WVWZZZ") && !dump.contains("масло") && !dump.contains("85000"))
    }

    @Test("ADR-0021: \"I don't know\" to a shown clarification ends the draft as cancelled and keeps the words")
    func clarificationToRawEndsTheDraft() async {
        let harness = Harness()
        let model = PitCaptureViewModel(
            pipeline: RememberPipeline(
                store: FakeCarMemoryStore(),
                interpreter: KindInterpreter(kind: .odometerReading),
                observer: harness.observer,
                now: { now }
            ),
            now: { now }
        )
        model.text = "записал показания"
        await model.submit(from: .carBoard)

        await model.answer(.unknown)

        #expect(model.phase == .saved(.notes, preservedRaw: true))
        #expect(harness.spy.names == [.inputInterpretationCompleted, .draftCancelled, .noteCreated])
        #expect(harness.spy.last(.draftCancelled) == [.intent: "odometer_reading", .stage: "edit"])
    }

    @Test("ADR-0021: with consent not asked, the same capture records nothing")
    func noConsentEndToEnd() async {
        let harness = Harness(consent: .notAsked)
        let store = FakeCarMemoryStore()
        let model = makeModel(harness, store: store)
        model.text = secret

        await model.submit(from: .service)
        await model.confirm()

        #expect(await store.completions.count == 1)
        #expect(harness.spy.events.isEmpty)
    }

    @Test("ADR-0021: a note written in Notes is note_created from the explicit source")
    func notesEditorNote() async {
        let harness = Harness(interpreter: .noInterpreter)
        let model = NotesViewModel(store: FakeCarMemoryStore(), captureObserver: harness.observer, now: { now })

        #expect(await model.add(text: "заменить дворники"))

        #expect(harness.spy.names == [.noteCreated])
        #expect(harness.spy.last(.noteCreated)?[.inputSource] == "explicit")
    }
}

/// Proposes the given kind with no extracted fields, so a reading stops for clarification.
private struct KindInterpreter: SemanticInterpreting {
    let kind: ProposalKind

    func interpret(_ input: CaptureInput) async throws -> MemoryProposal? {
        MemoryProposal(sourceInputID: input.id, kind: kind, rawText: input.payload.rawContent)
    }
}
