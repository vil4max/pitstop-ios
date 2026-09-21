import SwiftUI

/// How one eye is drawn in a given state. Extracted from the view so the vocabulary can be checked:
/// two semantic states that look identical would make the motion meaningless.
struct PitEyeGeometry: Hashable {
    /// Eyelid: 0 is shut, 1 is open, above 1 is widened. The lid comes down from the top.
    let openness: CGFloat
    /// Where the eye looks, in -1...1 on each axis; negative y is up.
    let gaze: CGPoint
    let dimmed: Bool
    /// Vertical offset of both eyes in points: a startle and a knock lift them, closing settles them.
    let lift: CGFloat

    /// The highlight fades out as the lid comes down, so nothing is drawn outside a closing eye.
    var showsHighlight: Bool {
        openness > PitEyeShape.highlightFadeStart
    }

    init(_ state: PitState) {
        dimmed = state == .hidden
        lift = switch state {
        case .knock: -3
        case .startle: -2
        case .closedEyes: 1
        default: 0
        }
        openness = switch state {
        case .blink, .closedEyes: 0
        case .startle: 1.15
        case .sideGaze: 0.8
        case .glance: 0.85
        case .resting, .hidden, .lookLeft, .lookRight: 0.92
        case .lookUp, .fixedGaze, .knock: 1
        }
        gaze = switch state {
        case .lookLeft: CGPoint(x: -1, y: 0.1)
        case .lookRight: CGPoint(x: 1, y: 0.1)
        case .lookUp: CGPoint(x: 0.15, y: -1)
        // Down and toward the content below the header, where the saved result is shown.
        case .glance: CGPoint(x: 0.5, y: 0.9)
        case .fixedGaze: CGPoint(x: 0, y: 0.15)
        // Up and aside, the direction people look when they think.
        case .sideGaze: CGPoint(x: -0.9, y: -0.6)
        case .startle: CGPoint(x: 0, y: -0.25)
        case .knock: CGPoint(x: 0, y: -0.1)
        case .hidden: CGPoint(x: 0, y: 0.1)
        case .resting, .blink, .closedEyes: .zero
        }
    }
}

/// A small offset and scale drawn on top of a state: a micro-saccade, a thinking drift, or a breath.
/// It never changes the state.
struct PitEyeLife: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        /// A jump: micro-saccades are fast, not drift.
        case saccade
        case drift
    }

    /// Extra gaze, in the units of `PitEyeGeometry.gaze`.
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

/// One eye: a capsule whose upper lid comes down with a slight curve and whose lower lid rises a
/// little, so the lids meet below the middle. The eye squashes wider as it closes and widens when
/// opened past 1.
struct PitEyeShape: Shape {
    var openness: CGFloat

    static let highlightFadeStart: CGFloat = 0.35
    private static let closedLine: CGFloat = 1.5
    /// Where the lids meet, as a fraction of the height.
    private static let meeting: CGFloat = 0.72

    var animatableData: CGFloat {
        get { openness }
        set { openness = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let open = min(max(openness, 0), 1)
        let widened = max(openness - 1, 0)
        let squash = 1 + 0.14 * (1 - open) + 0.4 * widened
        let width = rect.width * squash
        let minX = rect.midX - width / 2
        let maxX = minX + width

        let meetY = rect.minY + rect.height * Self.meeting
        var top = meetY - (meetY - rect.minY) * open - rect.height * widened * 0.5
        var bottom = meetY + (rect.maxY - meetY) * open
        if bottom - top < Self.closedLine {
            top = meetY - Self.closedLine / 2
            bottom = meetY + Self.closedLine / 2
        }
        let radius = min(width / 2, (bottom - top) / 2)
        // A partly closed lid is flatter than the open eye's round top.
        let lid = radius * (0.55 + 0.45 * open)
        // Cubic control distance that makes a quarter ellipse.
        let kappa: CGFloat = 0.5523
        let half = width / 2

        var path = Path()
        path.move(to: CGPoint(x: minX, y: top + lid))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: top),
            control1: CGPoint(x: minX, y: top + lid - kappa * lid),
            control2: CGPoint(x: rect.midX - kappa * half, y: top)
        )
        path.addCurve(
            to: CGPoint(x: maxX, y: top + lid),
            control1: CGPoint(x: rect.midX + kappa * half, y: top),
            control2: CGPoint(x: maxX, y: top + lid - kappa * lid)
        )
        path.addLine(to: CGPoint(x: maxX, y: bottom - radius))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: bottom),
            control1: CGPoint(x: maxX, y: bottom - radius + kappa * radius),
            control2: CGPoint(x: rect.midX + kappa * half, y: bottom)
        )
        path.addCurve(
            to: CGPoint(x: minX, y: bottom - radius),
            control1: CGPoint(x: rect.midX - kappa * half, y: bottom),
            control2: CGPoint(x: minX, y: bottom - radius + kappa * radius)
        )
        path.closeSubpath()
        return path
    }
}

/// Pit's face is two eyes; there is no body, mouth, or mascot (ADR 0009). The shape alone identifies
/// the control, so the affordance survives Reduce Motion and VoiceOver unchanged.
struct PitEyesGlyph: View {
    var state: PitState = .resting
    /// Bounded life from a model; the utility-layer mark never gets any, so it is still between drawn
    /// idle actions (REQ-PIT-004).
    var life: PitEyeLife = .still

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Counts entries into the knock, which replays its two bumps.
    @State private var knocks = 0

    private static let eyeSize = CGSize(width: 9, height: 15)
    private static let spacing: CGFloat = 5

    private var geometry: PitEyeGeometry {
        PitEyeGeometry(state)
    }

    /// Reduce Motion draws no life even if a model sent some.
    private var shownLife: PitEyeLife {
        reduceMotion ? .still : life
    }

    var body: some View {
        HStack(spacing: Self.spacing) {
            eye(delay: 0)
            eye(delay: PitEyeAnimation.trailingEyeDelay)
        }
        .scaleEffect(shownLife.breath)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.2), value: shownLife.breath)
        .opacity(geometry.dimmed ? 0.35 : 1)
        .offset(y: geometry.lift)
        .animation(reduceMotion ? nil : PitEyeAnimation.into(state), value: state)
        .keyframeAnimator(initialValue: CGFloat.zero, trigger: knocks) { content, bump in
            content.offset(y: bump)
        } keyframes: { _ in
            // Two small bumps: a knock, not a bounce.
            KeyframeTrack {
                CubicKeyframe(-2.5, duration: 0.09)
                CubicKeyframe(0, duration: 0.1)
                CubicKeyframe(-2.5, duration: 0.09)
                SpringKeyframe(0, duration: 0.2)
            }
        }
        .onChange(of: state) { _, newState in
            // With Reduce Motion the knock is the lifted pose alone (REQ-PIT-018).
            if newState == .knock, !reduceMotion {
                knocks += 1
            }
        }
        .accessibilityHidden(true)
    }

    private func eye(delay: TimeInterval) -> some View {
        let gaze = geometry.gaze
        let life = shownLife.gaze
        let size = Self.eyeSize
        return PitEyeShape(openness: geometry.openness)
            .fill(PitColor.contentPrimary)
            .overlay {
                highlight(gaze: gaze, life: life)
                    .opacity(geometry.showsHighlight ? 1 : 0)
            }
            .clipShape(PitEyeShape(openness: geometry.openness))
            .frame(width: size.width, height: size.height)
            // The eye moves a little with its gaze; the highlight moves more (see `highlight`).
            .offset(x: gaze.x * 1.2, y: gaze.y * 1.0)
            .animation(reduceMotion ? nil : PitEyeAnimation.into(state).delay(delay), value: state)
            // Life is a separate offset so its steps never interrupt a state's spring.
            .offset(x: life.x * 1.2, y: life.y * 1.0)
            .animation(reduceMotion ? nil : shownLife.animation.delay(delay), value: shownLife.gaze)
    }

    /// A specular highlight in the upper trailing part of the eye, plus a faint lower one for depth.
    private func highlight(gaze: CGPoint, life: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(PitColor.surfaceSecondary)
                .frame(width: 3.4, height: 3.4)
                .offset(x: 1.4, y: -2.6)
            Circle()
                .fill(PitColor.surfaceSecondary.opacity(0.55))
                .frame(width: 1.4, height: 1.4)
                .offset(x: -1.6, y: 3.4)
        }
        .offset(x: gaze.x * 1.4, y: gaze.y * 2.4)
        .offset(x: life.x * 1.4, y: life.y * 2.4)
    }
}
