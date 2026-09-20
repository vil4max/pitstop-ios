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
    private let now: @Sendable () -> Date

    public init(store: any CarMemoryStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.now = now
    }

    public func rememberRaw(_ input: CaptureInput) async throws(RememberError) -> RememberOutcome {
        let moment = now()
        let vehicle: Vehicle
        do {
            vehicle = try await store.currentVehicle()
        } catch {
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
            return .nothingToSave
        case .incomplete, .preserveRaw:
            // Unreachable for a raw note today. Failing loudly keeps a future interpreted path from
            // dropping input by falling into "nothing to save" (core P1, REQ-CAPTURE-006).
            throw .notSaved
        }
        guard let permit = ConfirmationPolicy().permit(for: validated, userConfirmed: false) else {
            // A raw note is always auto-accepted; reaching this means the policy table changed.
            throw .notSaved
        }

        do {
            let command = try DomainCommandMapper().command(for: permit, now: moment)
            let result = try await store.execute(command, now: moment)
            return .saved(result, preservedRaw: true)
        } catch {
            throw .notSaved
        }
    }
}
