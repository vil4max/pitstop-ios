import Foundation

/// Proof that a specific validated proposal may mutate state. Only `ConfirmationPolicy` can
/// create one, and it carries the exact content it authorizes, so `DomainCommandMapper`
/// cannot be reached around the policy or handed different content (REQ-CAPTURE-016).
public struct MutationPermit: Hashable, Sendable {
    public enum Basis: String, Hashable, Sendable {
        case autoAccepted
        case userConfirmed
    }

    public let validated: ValidatedProposal
    public let basis: Basis

    fileprivate init(validated: ValidatedProposal, basis: Basis) {
        self.validated = validated
        self.basis = basis
    }
}

/// Rationale and the full decision table: docs/decisions/0006-capture-confirmation-policy.md.
public struct ConfirmationPolicy: Sendable {
    /// Below this an interpreted reading is shown for confirmation instead of saved silently.
    /// Confidence never makes a proposal valid; it can only demand more confirmation.
    public static let autoAcceptConfidenceFloor = 0.8

    public init() {}

    public func outcome(for validation: ProposalValidation) -> ConfirmationOutcome {
        switch validation {
        case let .valid(validated):
            outcome(for: validated)
        case .incomplete:
            .clarify
        case .preserveRaw:
            .preserveRaw
        case .empty:
            .rejectUnsupported
        }
    }

    public func outcome(for validated: ValidatedProposal) -> ConfirmationOutcome {
        guard validated.conflicts.isEmpty else { return .confirmCompact }
        switch validated.content {
        case .note:
            return .autoAcceptSafe
        case .odometerReading:
            return isConfident(validated.proposal) ? .autoAcceptSafe : .confirmCompact
        case let .vehicleFact(fact):
            let lowRisk = !fact.field.affectsRecommendationApplicability && isConfident(validated.proposal)
            return lowRisk ? .autoAcceptSafe : .confirmCompact
        case .maintenanceCompletion, .maintenancePolicy, .vehicleEvent, .expense:
            return .confirmCompact
        }
    }

    /// The single question to ask next; clarification is never a form (REQ-CAPTURE-020).
    public func nextClarification(for validation: ProposalValidation) -> ProposalField? {
        guard case let .incomplete(_, missing) = validation else { return nil }
        return missing.first
    }

    public func permit(for validated: ValidatedProposal, userConfirmed: Bool) -> MutationPermit? {
        switch outcome(for: validated) {
        case .autoAcceptSafe:
            MutationPermit(validated: validated, basis: .autoAccepted)
        case .confirmCompact where userConfirmed:
            MutationPermit(validated: validated, basis: .userConfirmed)
        case .confirmCompact, .clarify, .preserveRaw, .rejectUnsupported:
            nil
        }
    }

    private func isConfident(_ proposal: MemoryProposal) -> Bool {
        // No confidence means a deterministic producer, not an uncertain model.
        (proposal.confidence ?? 1) >= Self.autoAcceptConfidenceFloor
    }
}
