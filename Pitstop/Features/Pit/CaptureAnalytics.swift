import Foundation
import Synchronization

/// Remember funnel events from `docs/operations/analytics.md` (AQ-004). A draft is a proposal the user
/// was shown (confirmation or clarification); only such drafts produce `draft_saved` or
/// `draft_cancelled`, so the save and cancel rates share one denominator (ADR 0021).
enum CaptureAnalyticsEvent: AnalyticsEncodable, Hashable {
    case inputInterpretationCompleted(
        intent: CaptureIntent,
        availability: InterpreterAvailability,
        result: InterpretationResult,
        // `nil` when the start of interpretation was not observed (the capture was evicted).
        latency: LatencyBucket?,
        interpreter: InterpreterVersion
    )
    case draftSaved(intent: CaptureIntent, edited: Bool)
    case draftCancelled(intent: CaptureIntent, stage: DraftStage)

    var analyticsEvent: AnalyticsEvent {
        switch self {
        case let .inputInterpretationCompleted(intent, availability, result, latency, interpreter):
            var properties: [AnalyticsProperty: AnalyticsValue] = [
                .intent: AnalyticsValue(intent),
                .availability: AnalyticsValue(availability),
                .result: AnalyticsValue(result),
                .interpreterVersion: AnalyticsValue(interpreter),
            ]
            properties[.latencyBucket] = latency.map(AnalyticsValue.init)
            return AnalyticsEvent(name: .inputInterpretationCompleted, properties: properties)
        case let .draftSaved(intent, edited):
            return AnalyticsEvent(name: .draftSaved, properties: [
                .intent: AnalyticsValue(intent),
                .edited: AnalyticsValue(edited),
            ])
        case let .draftCancelled(intent, stage):
            return AnalyticsEvent(name: .draftCancelled, properties: [
                .intent: AnalyticsValue(intent),
                .stage: AnalyticsValue(stage),
            ])
        }
    }
}

/// Analytics spelling of `ProposalKind`; the switch is exhaustive, so a new kind must be named here.
enum CaptureIntent: String, AnalyticsCategory {
    case noMeaning = "none"
    case rawNote = "raw_note"
    case contextualNote = "contextual_note"
    case odometerReading = "odometer_reading"
    case vehicleFact = "vehicle_fact"
    case maintenanceCompletion = "maintenance_completion"
    case maintenancePolicyDraft = "maintenance_policy_draft"
    case vehicleEvent = "vehicle_event"
    case expense
    case reminderCandidate = "reminder_candidate"
    case unknown

    init(_ kind: ProposalKind?) {
        switch kind {
        case nil: self = .noMeaning
        case .rawNote: self = .rawNote
        case .contextualNote: self = .contextualNote
        case .odometerReading: self = .odometerReading
        case .vehicleFact: self = .vehicleFact
        case .maintenanceCompletion: self = .maintenanceCompletion
        case .maintenancePolicyDraft: self = .maintenancePolicyDraft
        case .vehicleEvent: self = .vehicleEvent
        case .expense: self = .expense
        case .reminderCandidate: self = .reminderCandidate
        case .unknown: self = .unknown
        }
    }
}

enum InterpreterAvailability: String, AnalyticsCategory {
    case available
    case unavailable
}

/// `error` is part of the taxonomy but not observable yet: the pipeline turns a throwing or late
/// interpreter into "no meaning" before any stage is reported (ADR 0021).
enum InterpretationResult: String, AnalyticsCategory {
    case draft
    case fallback
    case error
    case unsupported

    init(_ kind: ProposalKind?) {
        switch kind {
        case nil, .rawNote: self = .fallback
        case .unknown: self = .unsupported
        default: self = .draft
        }
    }
}

enum InterpreterVersion: String, AnalyticsCategory {
    case noInterpreter = "none"
    case ruleBasedV1 = "rule_based_1"

    var availability: InterpreterAvailability {
        self == .noInterpreter ? .unavailable : .available
    }
}

enum DraftStage: String, AnalyticsCategory {
    /// A proposal was shown for confirmation.
    case preview
    /// The user was asked for a missing field.
    case edit
}

/// Turns capture stages into product events. Stage events carry only IDs and closed enums
/// (ADR 0006), so nothing here can see what the user wrote. Stages of one capture are joined by
/// correlation ID; state is kept only for captures still in progress and is bounded.
final class CaptureAnalyticsObserver: CaptureStageObserving {
    private struct Journey {
        var interpretationStartedAt: ContinuousClock.Instant?
        var wasClarified = false
        /// The last draft the user was shown, and how; `nil` until a draft stops for the user.
        var shownDraft: (kind: ProposalKind, stage: DraftStage)?
    }

    private struct State {
        var journeys: [UUID: Journey] = [:]
        var order: [UUID] = []
    }

    /// A capture abandoned without a terminal stage (the surface closed mid-flow) is dropped oldest-first.
    static let journeyLimit = 16

    private let capture: any AnalyticsTracking<CaptureAnalyticsEvent>
    private let notes: any AnalyticsTracking<NotesAnalyticsEvent>
    private let odometer: any AnalyticsTracking<OdometerAnalyticsEvent>
    private let interpreter: InterpreterVersion
    private let now: @Sendable () -> ContinuousClock.Instant
    private let state = Mutex(State())

    init(
        capture: any AnalyticsTracking<CaptureAnalyticsEvent>,
        notes: any AnalyticsTracking<NotesAnalyticsEvent>,
        odometer: any AnalyticsTracking<OdometerAnalyticsEvent>,
        interpreter: InterpreterVersion,
        now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        self.capture = capture
        self.notes = notes
        self.odometer = odometer
        self.interpreter = interpreter
        self.now = now
    }

    func record(_ event: CaptureStageEvent) {
        let moment = now()
        let outgoing = state.withLock { state in
            Self.advance(&state, with: event, at: moment, interpreter: interpreter)
        }
        for item in outgoing {
            switch item {
            case let .capture(event): capture.track(event)
            case let .notes(event): notes.track(event)
            case let .odometer(event): odometer.track(event)
            }
        }
    }

    private enum Outgoing {
        case capture(CaptureAnalyticsEvent)
        case notes(NotesAnalyticsEvent)
        case odometer(OdometerAnalyticsEvent)
    }

    private static func advance(
        _ state: inout State,
        with event: CaptureStageEvent,
        at moment: ContinuousClock.Instant,
        interpreter: InterpreterVersion
    ) -> [Outgoing] {
        let id = event.correlationID
        // Only `captureReceived` creates a journey, so every stored journey is also in `order` and an
        // evicted capture cannot come back unbounded; its later stages fall back to a blank journey.
        let tracked = state.journeys[id]
        let journey = tracked ?? Journey()
        switch event.stage {
        case .captureReceived:
            start(id, in: &state)
            return []
        case .interpretationStarted:
            state.journeys[id]?.interpretationStartedAt = moment
            return []
        case .interpretationCompleted:
            return [.capture(.inputInterpretationCompleted(
                intent: CaptureIntent(event.proposalKind),
                availability: interpreter.availability,
                result: InterpretationResult(event.proposalKind),
                latency: journey.interpretationStartedAt.map { LatencyBucket(moment - $0) },
                interpreter: interpreter
            ))]
        case .confirmationRequired, .clarificationRequired:
            guard tracked != nil, let kind = event.proposalKind else { return [] }
            let stage: DraftStage = event.stage == .confirmationRequired ? .preview : .edit
            state.journeys[id]?.shownDraft = (kind, stage)
            if stage == .edit {
                state.journeys[id]?.wasClarified = true
            }
            return []
        case .mutationCompleted:
            end(id, in: &state)
            guard let kind = event.proposalKind else { return [] }
            return saved(kind, source: event.source, journey: journey)
        case .captureDiscarded:
            end(id, in: &state)
            guard let shown = journey.shownDraft else { return [] }
            return [.capture(.draftCancelled(intent: CaptureIntent(shown.kind), stage: shown.stage))]
        case .proposalValidated, .domainCommandCreated, .rawPreserved, .pipelineFailed:
            // A failed write keeps the journey: the surface lets the user retry the same capture.
            return []
        }
    }

    private static func saved(_ kind: ProposalKind, source: CaptureSource, journey: Journey) -> [Outgoing] {
        var outgoing: [Outgoing] = []
        // An auto-accepted proposal was never shown, so it is not a draft event; its fact events below
        // still fire.
        if let shown = journey.shownDraft {
            if kind == .rawNote {
                // The user declined the proposed meaning, answered "I don't know", or the answered draft
                // could only be kept as wording: the draft was not saved, only the words.
                outgoing.append(.capture(.draftCancelled(intent: CaptureIntent(shown.kind), stage: shown.stage)))
            } else {
                outgoing.append(.capture(.draftSaved(intent: CaptureIntent(kind), edited: journey.wasClarified)))
            }
        }
        switch kind {
        case .rawNote:
            outgoing.append(.notes(.noteCreated(
                inputSource: NoteInputSource(source), contextCount: .zero, hasCanonicalContext: false
            )))
        case .contextualNote:
            outgoing.append(.notes(.noteCreated(
                inputSource: NoteInputSource(source), contextCount: nil, hasCanonicalContext: true
            )))
        case .odometerReading:
            // A reading stops for confirmation only on a conflict or low confidence (ADR 0006); the
            // stage does not say which, so any confirmed reading counts as an accepted anomaly.
            let confirmed = journey.shownDraft?.stage == .preview
            outgoing.append(.odometer(.odometerUpdated(
                source: OdometerSource(source),
                anomalyConfirmation: confirmed ? .accepted : .noAnomaly
            )))
        case .vehicleFact, .maintenanceCompletion, .maintenancePolicyDraft, .vehicleEvent, .expense,
             .reminderCandidate, .unknown:
            break
        }
        return outgoing
    }

    private static func start(_ id: UUID, in state: inout State) {
        state.journeys[id] = Journey()
        state.order.removeAll { $0 == id }
        state.order.append(id)
        while state.order.count > journeyLimit {
            state.journeys[state.order.removeFirst()] = nil
        }
    }

    private static func end(_ id: UUID, in state: inout State) {
        state.journeys[id] = nil
        state.order.removeAll { $0 == id }
    }
}
