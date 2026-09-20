import Foundation

/// Raw Remember: builds a proposal deterministically, with no model call. The result
/// enters the same validator, policy, and mapper as an interpreted proposal.
public struct RawProposalFactory: Sendable {
    public init() {}

    public func proposal(for input: CaptureInput, id: UUID = UUID()) -> MemoryProposal {
        MemoryProposal(id: id, sourceInputID: input.id, kind: .rawNote, rawText: input.payload.rawContent)
    }
}
