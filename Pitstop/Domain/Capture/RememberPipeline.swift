import Foundation

public enum RememberOutcome: Hashable, Sendable {
    /// Persistence succeeded. `preservedRaw` is true when no stronger interpretation was applied.
    case saved(CommandResult, preservedRaw: Bool)
    /// There was nothing to remember (blank input).
    case nothingToSave
}

public enum RememberError: Error, Hashable, Sendable {
    /// Nothing was saved; the caller keeps the input so the user can retry (REQ-CAPTURE-009).
    case notSaved
}

/// The one path from a `CaptureInput` to persisted memory (core C4). This slice implements
/// Raw Remember: no model, but the same validator, policy, mapper, and store as any
/// interpreted proposal will use (REQ-CAPTURE-001). Interpretation joins in CAP-002.
public struct RememberPipeline: Sendable {
    private let store: any CarMemoryStore
    private let observer: any CaptureStageObserving
    private let now: @Sendable () -> Date

    public init(
        store: any CarMemoryStore,
        observer: any CaptureStageObserving = NoCaptureStageObserver(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.observer = observer
        self.now = now
    }

    public func rememberRaw(_ input: CaptureInput) async throws(RememberError) -> RememberOutcome {
        let moment = now()
        report(.captureReceived, input)
        let vehicle: Vehicle
        do {
            vehicle = try await store.currentVehicle()
        } catch {
            report(.pipelineFailed, input)
            throw .notSaved
        }

        let proposal = RawProposalFactory().proposal(for: input)
        let context = ProposalValidationContext(vehicle: vehicle, now: moment)
        let validation = ProposalValidator().validate(proposal, input: input, context: context)
        let validated: ValidatedProposal
        switch validation {
        case let .valid(result):
            validated = result
        case .empty:
            report(.captureDiscarded, input, kind: proposal.kind)
            return .nothingToSave
        case .incomplete, .preserveRaw:
            // Unreachable for a raw note today. Failing loudly keeps a future interpreted path from
            // dropping input by falling into "nothing to save" (core P1, REQ-CAPTURE-006).
            report(.pipelineFailed, input, kind: proposal.kind)
            throw .notSaved
        }
        let outcome = ConfirmationPolicy().outcome(for: validated)
        report(.proposalValidated, input, kind: proposal.kind, outcome: outcome)
        guard let permit = ConfirmationPolicy().permit(for: validated, userConfirmed: false) else {
            // A raw note is always auto-accepted; reaching this means the policy table changed.
            report(.pipelineFailed, input, kind: proposal.kind, outcome: outcome)
            throw .notSaved
        }

        do {
            let command = try DomainCommandMapper().command(for: permit, now: moment)
            report(.domainCommandCreated, input, kind: proposal.kind, outcome: outcome)
            let result = try await store.execute(command, now: moment)
            // `raw_preserved` is reserved for degradation (CAP-002/006); a note the user chose to save
            // raw is an ordinary completed mutation.
            report(.mutationCompleted, input, kind: proposal.kind, outcome: outcome)
            return .saved(result, preservedRaw: true)
        } catch {
            report(.pipelineFailed, input, kind: proposal.kind, outcome: outcome)
            throw .notSaved
        }
    }

    private func report(
        _ stage: CaptureStage,
        _ input: CaptureInput,
        kind: ProposalKind? = nil,
        outcome: ConfirmationOutcome? = nil
    ) {
        observer.record(CaptureStageEvent(
            correlationID: input.id,
            stage: stage,
            source: input.source,
            proposalKind: kind,
            outcome: outcome
        ))
    }
}
