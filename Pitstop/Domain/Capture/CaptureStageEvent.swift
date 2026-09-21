import Foundation

/// Pipeline stages named by the capture contract ("Observability").
public enum CaptureStage: String, Hashable, Sendable, CaseIterable {
    case captureReceived = "capture_received"
    case interpretationStarted = "interpretation_started"
    case interpretationCompleted = "interpretation_completed"
    case proposalValidated = "proposal_validated"
    case confirmationRequired = "confirmation_required"
    case clarificationRequired = "clarification_required"
    case domainCommandCreated = "domain_command_created"
    case mutationCompleted = "mutation_completed"
    case rawPreserved = "raw_preserved"
    case pipelineFailed = "pipeline_failed"
    /// Not in the contract's list yet (proposed in ADR 0006): blank input ends here, so an abandoned
    /// capture can be told apart from a pipeline that stopped without a terminal stage.
    case captureDiscarded = "capture_discarded"
}

/// One observed stage. The type has no field that can hold what the user wrote or said, so raw
/// content cannot reach a log or an analytics event through it (REQ-CAPTURE-025).
public struct CaptureStageEvent: Hashable, Sendable {
    /// The `CaptureInput.id`; every stage of one capture carries the same value (REQ-CAPTURE-024).
    public let correlationID: UUID
    public let stage: CaptureStage
    public let source: CaptureSource
    public let proposalKind: ProposalKind?
    public let outcome: ConfirmationOutcome?

    public init(
        correlationID: UUID,
        stage: CaptureStage,
        source: CaptureSource,
        proposalKind: ProposalKind? = nil,
        outcome: ConfirmationOutcome? = nil
    ) {
        self.correlationID = correlationID
        self.stage = stage
        self.source = source
        self.proposalKind = proposalKind
        self.outcome = outcome
    }
}

public protocol CaptureStageObserving: Sendable {
    func record(_ event: CaptureStageEvent)
}

public struct NoCaptureStageObserver: CaptureStageObserving {
    public init() {}

    public func record(_: CaptureStageEvent) {}
}

/// Passes every stage to each observer in order, so DEBUG logging and product analytics can watch
/// the same pipeline without knowing about each other.
public struct CaptureStageObservers: CaptureStageObserving {
    private let observers: [any CaptureStageObserving]

    public init(_ observers: [any CaptureStageObserving]) {
        self.observers = observers
    }

    public func record(_ event: CaptureStageEvent) {
        for observer in observers {
            observer.record(event)
        }
    }
}
