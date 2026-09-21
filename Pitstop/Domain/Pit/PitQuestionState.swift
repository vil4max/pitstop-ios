import Foundation

/// The persisted part of a question: what the user did with it and when (pit-behavior-and-motion.md,
/// "Interruption budget"). The declaration lives in `PitQuestionRegistry`.
public struct PitQuestionState: Hashable, Sendable {
    public let questionID: String
    public var resolution: PitQuestion.Resolution
    /// When Pit last interrupted with this question.
    public var lastAskedAt: Date?
    /// Kept apart from `resolvedAt`: a later answer must not erase the dismissal cooldown.
    public var lastDismissedAt: Date?
    /// When the current resolution was reached; a deferral path is measured from it.
    public var resolvedAt: Date?

    public init(
        questionID: String,
        resolution: PitQuestion.Resolution = .unresolved,
        lastAskedAt: Date? = nil,
        lastDismissedAt: Date? = nil,
        resolvedAt: Date? = nil
    ) {
        self.questionID = questionID
        self.resolution = resolution
        self.lastAskedAt = lastAskedAt
        self.lastDismissedAt = lastDismissedAt
        self.resolvedAt = resolvedAt
    }
}

/// The only way question state changes. Each case names a registered question.
public enum PitQuestionCommand: Hashable, Sendable {
    /// Pit interrupted with the question; this starts the interruption cooldown.
    case asked(questionID: String)
    case answered(questionID: String)
    case deferred(questionID: String)
    case dismissed(questionID: String)

    public var questionID: String {
        switch self {
        case let .asked(id), let .answered(id), let .deferred(id), let .dismissed(id):
            id
        }
    }

    /// Applies the command to the current state; `nil` means the question has no stored row yet.
    public func applied(to state: PitQuestionState?, now: Date) throws(PitQuestionStoreError) -> PitQuestionState {
        var next = state ?? PitQuestionState(questionID: questionID)
        switch self {
        case .asked:
            next.lastAskedAt = now
        case .answered:
            next.resolution = .answered
            next.resolvedAt = now
        case .deferred:
            try next.decline(as: .deferred, now: now)
        case .dismissed:
            try next.decline(as: .dismissed, now: now)
            next.lastDismissedAt = now
        }
        // A resolution implies the question was shown; without this, a caller that skipped `.asked`
        // would leave the interruption cooldown unstarted (REQ-PIT-010).
        if next.lastAskedAt == nil {
            next.lastAskedAt = now
        }
        return next
    }
}

private extension PitQuestionState {
    mutating func decline(as resolution: PitQuestion.Resolution, now: Date) throws(PitQuestionStoreError) {
        // An answer is a fact the user gave; a later "not now" cannot turn it back into a question.
        guard self.resolution != .answered else { throw .alreadyAnswered }
        self.resolution = resolution
        resolvedAt = now
    }
}

public enum PitQuestionStoreError: Error, Hashable, Sendable {
    /// The command names a question the registry does not declare.
    case unknownQuestion
    case alreadyAnswered
    case storageFailure
}

/// Persisted question state. Separate from `CarMemoryStore` because question state is Pit's
/// interaction record, not a car fact, and no capture proposal may change it (ADR 0016).
public protocol PitQuestionStateStore: Sendable {
    func questionStates() async throws(PitQuestionStoreError) -> [PitQuestionState]

    /// Validates the command against the registry, then persists it. A thrown error means nothing was saved.
    @discardableResult
    func execute(_ command: PitQuestionCommand, now: Date) async throws(PitQuestionStoreError) -> PitQuestionState
}

/// The global interruption budget derived from every question's state: the attention policy's
/// cooldowns apply across questions, not per question.
public struct PitAttentionBudget: Hashable, Sendable {
    public let lastInterruption: Date?
    public let lastDismissal: Date?

    public init(_ states: some Sequence<PitQuestionState>) {
        lastInterruption = states.compactMap(\.lastAskedAt).max()
        lastDismissal = states.compactMap(\.lastDismissedAt).max()
    }

    /// Never interrupted reads as an unbounded elapsed time, so the cooldown is satisfied.
    public func sinceLastInterruption(now: Date) -> TimeInterval {
        lastInterruption.map { now.timeIntervalSince($0) } ?? .infinity
    }

    public func sinceLastDismissal(now: Date) -> TimeInterval {
        lastDismissal.map { now.timeIntervalSince($0) } ?? .infinity
    }
}
