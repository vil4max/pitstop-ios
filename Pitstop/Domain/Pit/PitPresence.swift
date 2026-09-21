import Foundation

/// The semantic motion vocabulary (pit-behavior-and-motion.md, "Motion language"). Each state means
/// something; none of them is decoration, and none is required to identify the control.
public enum PitState: String, Hashable, Sendable, CaseIterable {
    case hidden
    case resting
    case blink
    case lookLeft
    case lookRight
    case lookUp
    case fixedGaze
    case sideGaze
    case startle
    case knock
    case closedEyes
}

/// What the interface is doing right now. Idle motion yields to all of it (REQ-PIT-005).
public struct PitActivity: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let scrolling = PitActivity(rawValue: 1 << 0)
    public static let editing = PitActivity(rawValue: 1 << 1)
    public static let capturing = PitActivity(rawValue: 1 << 2)
    public static let modalTask = PitActivity(rawValue: 1 << 3)
    public static let reduceMotion = PitActivity(rawValue: 1 << 4)
    public static let recentlyDismissed = PitActivity(rawValue: 1 << 5)
    /// A question is on screen waiting for an answer; Pit holds still until it is resolved.
    public static let askingQuestion = PitActivity(rawValue: 1 << 6)

    public static let idle: PitActivity = []
}

/// Chooses idle actions by irregular weighted scheduling with cooldowns, never on a fixed repeating
/// timer, and a normal session may contain no visible idle motion at all (REQ-PIT-004).
///
/// It is a value type with an injected random source, so a schedule is reproducible in a test.
public struct PitIdleScheduler: Sendable {
    public struct Plan: Hashable, Sendable {
        public let state: PitState
        /// Seconds to wait before the action.
        public let delay: TimeInterval
    }

    /// Weighted vocabulary of idle actions. Blink is the baseline; looking around is rarer; the rest
    /// of the weight is stillness.
    static let weights: [(state: PitState, weight: Double)] = [
        (.blink, 0.45), (.lookLeft, 0.10), (.lookRight, 0.10), (.lookUp, 0.06),
    ]
    static let minimumDelay: TimeInterval = 4
    static let maximumDelay: TimeInterval = 19
    /// After an action Pit is still for at least this long, so motion cannot become constant.
    static let cooldown: TimeInterval = 6

    private let random: @Sendable () -> Double

    public init(random: @escaping @Sendable () -> Double = { Double.random(in: 0 ..< 1) }) {
        self.random = random
    }

    /// `nil` means "do nothing": either the interface is busy, or this turn simply draws stillness.
    public func nextPlan(activity: PitActivity, sinceLastAction: TimeInterval) -> Plan? {
        guard activity == .idle, sinceLastAction >= Self.cooldown else { return nil }

        let roll = random()
        var cumulative = 0.0
        for entry in Self.weights {
            cumulative += entry.weight
            guard roll < cumulative else { continue }
            let spread = Self.maximumDelay - Self.minimumDelay
            return Plan(state: entry.state, delay: Self.minimumDelay + random() * spread)
        }
        // The remaining weight is stillness, which is why a session can pass with no visible motion.
        return nil
    }
}

/// What answering a question would change. A question with nothing declared is not asked
/// (REQ-PIT-009): "Pit may interrupt only for measurable value".
public enum PitValueUnlock: String, Hashable, Sendable {
    case serviceStatus
    case roadHorizon
    case historyCompleteness
}

/// One thing Pit may ask about. Identity, priority, resolution, and the value its answer unlocks are
/// modelled so a deferred question is not asked again (pit-behavior-and-motion.md, "Interruption
/// budget").
public struct PitQuestion: Identifiable, Hashable, Sendable {
    public enum Resolution: String, Hashable, Sendable {
        case unresolved
        case answered
        case deferred
        case dismissed
    }

    public let id: String
    public let priority: Int
    /// The surface the question is about; it is asked only there (REQ-PIT-007).
    public let context: VisibleFeature
    /// `nil` means nothing was declared, so the question may not be asked at all.
    public let unlocks: PitValueUnlock?
    public var resolution: Resolution

    public init(
        id: String,
        priority: Int,
        context: VisibleFeature,
        unlocks: PitValueUnlock?,
        resolution: Resolution = .unresolved
    ) {
        self.id = id
        self.priority = priority
        self.context = context
        self.unlocks = unlocks
        self.resolution = resolution
    }
}

/// Decides whether Pit may interrupt: "Pit may look alive without permission. Pit may interrupt only
/// for measurable value." (core C3).
public struct PitAttentionPolicy: Sendable {
    /// No second question within this window, whatever its priority.
    public static let interruptionCooldown: TimeInterval = 12 * 60 * 60
    /// A dismissal silences questions for longer than an answer does.
    public static let dismissalCooldown: TimeInterval = 7 * 24 * 60 * 60

    public init() {}

    /// The interface is idle (REQ-PIT-006). Reduce Motion changes how Pit asks — the knock alone
    /// (REQ-PIT-018) — never whether it may.
    public func allowsInterruption(_ activity: PitActivity) -> Bool {
        activity.subtracting(.reduceMotion) == .idle
    }

    /// The one question Pit may ask now, or `nil`: highest priority first, then a stable ID order.
    public func question(
        from questions: some Sequence<PitQuestion>,
        activity: PitActivity,
        context: VisibleFeature,
        sinceLastInterruption: TimeInterval,
        sinceLastDismissal: TimeInterval
    ) -> PitQuestion? {
        guard allowsInterruption(activity) else { return nil }
        guard sinceLastInterruption >= Self.interruptionCooldown else { return nil }
        guard sinceLastDismissal >= Self.dismissalCooldown else { return nil }
        return questions
            .filter { $0.resolution == .unresolved && $0.context == context && $0.unlocks != nil }
            .max { ($0.priority, $1.id) < ($1.priority, $0.id) }
    }
}
