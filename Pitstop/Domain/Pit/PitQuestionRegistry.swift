import Foundation

/// The value a question's answer unlocks (core C3). It is non-optional in a definition, so a question
/// that unlocks nothing cannot be written down, let alone registered (REQ-PIT-009).
public struct PitQuestionValue: Hashable, Sendable {
    public let unlocks: PitValueUnlock
    /// The observable change an answer makes, stated so beta evidence can confirm or refute it.
    public let claim: String

    public init(unlocks: PitValueUnlock, claim: String) {
        self.unlocks = unlocks
        self.claim = claim
    }
}

/// When a resolved question may return, and what the app does without the answer in the meantime
/// (ADR 0018).
public struct PitDeferralPath: Hashable, Sendable {
    public enum Return: Hashable, Sendable {
        case never
        /// Measured from the moment the question was resolved (`PitQuestionState.resolvedAt`).
        case notBefore(TimeInterval)
    }

    /// How long an answer holds. Relevance still gates the return: an answer that still unlocks its
    /// value keeps the question quiet after this interval too.
    public let afterAnswer: Return
    public let afterDeferral: Return
    public let afterDismissal: Return
    /// The app's behaviour while the answer is missing; the fact itself stays unknown (core C2).
    public let withoutAnswer: String

    public init(afterAnswer: Return, afterDeferral: Return, afterDismissal: Return, withoutAnswer: String) {
        self.afterAnswer = afterAnswer
        self.afterDeferral = afterDeferral
        self.afterDismissal = afterDismissal
        self.withoutAnswer = withoutAnswer
    }

    public func returnRule(after resolution: PitQuestion.Resolution) -> Return? {
        switch resolution {
        case .unresolved, .closed: nil
        case .answered: afterAnswer
        case .deferred: afterDeferral
        case .dismissed: afterDismissal
        }
    }

    /// A resolved question is open again once its declared interval has passed since the resolution.
    /// Without a resolution time nothing can be measured, so the question stays closed: silence is the
    /// safe default (core C3).
    public func hasReturned(_ state: PitQuestionState, now: Date) -> Bool {
        guard case let .notBefore(interval) = returnRule(after: state.resolution),
              let resolvedAt = state.resolvedAt
        else { return false }
        return now.timeIntervalSince(resolvedAt) >= interval
    }
}

/// A question Pit may ask, as declared in code. Its persisted state is `PitQuestionState`.
public struct PitQuestionDefinition: Identifiable, Hashable, Sendable {
    /// Stable across releases: persisted state is keyed by it.
    public let id: String
    public let context: VisibleFeature
    public let priority: Int
    public let value: PitQuestionValue
    public let deferral: PitDeferralPath

    public init(id: String, context: VisibleFeature, priority: Int, value: PitQuestionValue,
                deferral: PitDeferralPath)
    {
        self.id = id
        self.context = context
        self.priority = priority
        self.value = value
        self.deferral = deferral
    }
}

/// The only source of questions Pit may ask (ADR 0016).
public struct PitQuestionRegistry: Sendable {
    public enum RegistrationError: Error, Hashable, Sendable {
        case blankID
        case duplicateID(String)
        case blankValueClaim(String)
        case blankFallback(String)
        case nonPositiveReturn(String)
    }

    /// Product questions (ADR 0017). A test builds the registry from this list, so an invalid entry
    /// fails the gate rather than a launch.
    static let productDefinitions: [PitQuestionDefinition] = [CurrentMileageQuestion.definition]

    /// No questions at all: the fallback when the product list cannot be registered, so Pit stays silent.
    public static let empty = PitQuestionRegistry(validated: [])

    public let definitions: [PitQuestionDefinition]

    public init(_ definitions: [PitQuestionDefinition]) throws(RegistrationError) {
        var seen = Set<String>()
        for definition in definitions {
            try Self.validate(definition)
            guard seen.insert(definition.id).inserted else { throw .duplicateID(definition.id) }
        }
        self.definitions = definitions
    }

    private init(validated definitions: [PitQuestionDefinition]) {
        self.definitions = definitions
    }

    public static func product() throws(RegistrationError) -> PitQuestionRegistry {
        try PitQuestionRegistry(productDefinitions)
    }

    public func definition(for id: String) -> PitQuestionDefinition? {
        definitions.first { $0.id == id }
    }

    /// Joins the declarations with persisted state as of `now`. A question without a stored row is
    /// unresolved, and so is one whose declared return interval has passed (ADR 0018); a stored row whose
    /// question is no longer registered is ignored.
    public func questions(with states: some Sequence<PitQuestionState>, now: Date) -> [PitQuestion] {
        let stored = Dictionary(states.map { ($0.questionID, $0) }) { first, _ in first }
        return definitions.map { definition in
            let state = stored[definition.id]
            let hasReturned = state.map { definition.deferral.hasReturned($0, now: now) } ?? false
            return PitQuestion(
                id: definition.id,
                priority: definition.priority,
                context: definition.context,
                unlocks: definition.value.unlocks,
                resolution: hasReturned ? .unresolved : state?.resolution ?? .unresolved
            )
        }
    }

    private static func validate(_ definition: PitQuestionDefinition) throws(RegistrationError) {
        guard !definition.id.isBlank else { throw .blankID }
        guard !definition.value.claim.isBlank else { throw .blankValueClaim(definition.id) }
        guard !definition.deferral.withoutAnswer.isBlank else { throw .blankFallback(definition.id) }
        let deferral = definition.deferral
        for rule in [deferral.afterAnswer, deferral.afterDeferral, deferral.afterDismissal] {
            if case let .notBefore(interval) = rule, !(interval > 0) {
                throw .nonPositiveReturn(definition.id)
            }
        }
    }
}

public extension PitAttentionPolicy {
    /// Feeds the policy from the registry and persisted state instead of hand-built elapsed times.
    func question(
        registry: PitQuestionRegistry,
        states: [PitQuestionState],
        activity: PitActivity,
        context: VisibleFeature,
        now: Date
    ) -> PitQuestion? {
        let budget = PitAttentionBudget(states)
        return question(
            from: registry.questions(with: states, now: now),
            activity: activity,
            context: context,
            sinceLastInterruption: budget.sinceLastInterruption(now: now),
            sinceLastDismissal: budget.sinceLastDismissal(now: now)
        )
    }
}
