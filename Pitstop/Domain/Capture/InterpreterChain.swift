import Foundation

/// Asks interpreters in order and returns the first proposal (ADR 0027). A later interpreter is
/// asked only when every earlier one found no meaning, so it can widen recall but can never
/// override an earlier answer.
///
/// An error from any member is rethrown: to the pipeline that is the same as "no meaning", and the
/// wording is kept raw (REQ-CAPTURE-007). Cancellation propagates the same way.
public struct InterpreterChain: SemanticInterpreting {
    private let members: [any SemanticInterpreting]

    public init(_ members: [any SemanticInterpreting]) {
        self.members = members
    }

    public func interpret(_ input: CaptureInput) async throws -> MemoryProposal? {
        for member in members {
            try Task.checkCancellation()
            if let proposal = try await member.interpret(input) {
                return proposal
            }
        }
        return nil
    }
}
