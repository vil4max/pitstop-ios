import Foundation

/// Optional producer of a typed proposal. It only suggests meaning; the validator, the confirmation
/// policy, and the domain commands decide what happens next (core P3, REQ-DOMAIN-018).
///
/// `nil` means "no supported meaning found", which is an ordinary answer, not a failure: the capture
/// then continues as Raw Remember. Throwing means the interpreter itself is unavailable, and the
/// input is preserved raw all the same (REQ-CAPTURE-007).
public protocol SemanticInterpreting: Sendable {
    func interpret(_ input: CaptureInput) async throws -> MemoryProposal?
}

/// The interpreter used while no model is wired: it never proposes anything, so every capture is
/// Raw Remember.
public struct NoSemanticInterpreter: SemanticInterpreting {
    public init() {}

    public func interpret(_: CaptureInput) async throws -> MemoryProposal? {
        nil
    }
}
