import SwiftUI

/// A small offset and scale drawn on top of a state: a micro-saccade, a thinking drift, or a breath.
/// It never changes the state.
struct PitEyeLife: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        /// A jump: micro-saccades are fast, not drift.
        case saccade
        case drift
    }

    /// Extra gaze in -1...1 on each axis; the head moves the eyes 1.2 units across and 1 unit down per step.
    var gaze: CGPoint = .zero
    var breath: CGFloat = 1
    var kind: Kind = .saccade

    static let still = PitEyeLife()

    var animation: Animation {
        switch kind {
        case .saccade: .spring(duration: 0.12, bounce: 0)
        case .drift: .easeInOut(duration: 1.1)
        }
    }
}

/// One step of bounded life: wait `delay`, then show `life`.
struct PitEyeLifeStep: Hashable, Sendable {
    let delay: TimeInterval
    let life: PitEyeLife
}

/// Life after a state change is bounded and irregular (ADR 0028): a few steps at jittered intervals
/// inside a short window, then stillness until the next state change. Nothing runs on a fixed period
/// and nothing runs forever (REQ-PIT-004).
enum PitEyeLifePlan {
    static let window: TimeInterval = 5
    static let minimumInterval: TimeInterval = 0.5
    static let maximumInterval: TimeInterval = 1.6

    /// Steps for `state`, ending on `.still`. Empty when the state has no life, with Reduce Motion
    /// (REQ-PIT-017), or while the user edits text or scrolls (REQ-PIT-005).
    static func steps(
        for state: PitState,
        activity: PitActivity,
        random: () -> Double
    ) -> [PitEyeLifeStep] {
        guard activity.isDisjoint(with: [.reduceMotion, .editing, .scrolling]) else { return [] }
        let hasGaze = state == .fixedGaze || state == .sideGaze
        guard hasGaze || state == .resting else { return [] }
        let kind: PitEyeLife.Kind = state == .sideGaze ? .drift : .saccade
        let reach = state == .sideGaze ? CGPoint(x: 0.12, y: 0.08) : CGPoint(x: 0.1, y: 0.08)

        var steps: [PitEyeLifeStep] = []
        var elapsed: TimeInterval = 0
        var inhaled = false
        while true {
            let delay = minimumInterval + random() * (maximumInterval - minimumInterval)
            guard elapsed + delay <= window else { break }
            elapsed += delay
            inhaled.toggle()
            let gaze = hasGaze
                ? CGPoint(x: reach.x * (random() * 2 - 1), y: reach.y * (random() * 2 - 1))
                : .zero
            steps.append(PitEyeLifeStep(
                delay: delay,
                life: PitEyeLife(gaze: gaze, breath: inhaled ? 1.015 : 1, kind: kind)
            ))
        }
        let settle = minimumInterval + random() * (maximumInterval - minimumInterval)
        steps.append(PitEyeLifeStep(delay: settle, life: PitEyeLife(kind: kind)))
        return steps
    }
}

/// The animation for a change into `state`: blinks close fast and reopen with a little spring, gaze
/// changes overshoot slightly, a startle snaps.
enum PitEyeAnimation {
    static func into(_ state: PitState) -> Animation {
        switch state {
        case .blink: .easeIn(duration: 0.07)
        case .closedEyes: .easeInOut(duration: 0.3)
        case .startle: .spring(duration: 0.2, bounce: 0.4)
        case .lookLeft, .lookRight, .lookUp, .glance, .sideGaze: .spring(duration: 0.38, bounce: 0.3)
        default: .spring(duration: 0.26, bounce: 0.2)
        }
    }

    /// The trailing eye follows a moment later, so the pair never moves as one rigid piece.
    static let trailingEyeDelay: TimeInterval = 0.025
}
