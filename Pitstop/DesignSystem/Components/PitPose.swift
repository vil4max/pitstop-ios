import CoreGraphics

/// One eye of a pose, relative to the resting lens of `PitHeadGeometry`.
struct PitEyePose: Hashable {
    enum Outline: Hashable {
        /// The lit lens, scaled by the pose.
        case lens
        /// A shallow upward arc: the eye is closed and content.
        case arc
    }

    var outline: Outline = .lens
    /// Degrees, clockwise positive, as in the mockup's SVG: the left eye leans outward below zero, the right eye
    /// above zero.
    var rotation: Double
    var widthScale: CGFloat = 1
    var heightScale: CGFloat = 1
}

/// Pit drawn in one state, without animation. The view draws a pose; the vocabulary is checked on these values, so
/// two states that look alike, or a pose outside the motion table's limits, fail a test instead of a review.
struct PitPose: Hashable {
    var left: PitEyePose
    var right: PitEyePose
    /// Offset of both eyes from their resting centres, in head units; negative y is up.
    var eyeOffset: CGPoint = .zero
    var showsHighlight = true
    var dimmed = false

    /// The lenses at rest: tops leaning outward (ADR 0037).
    static let resting = PitPose(
        left: PitEyePose(rotation: -PitHeadGeometry.restingOutwardTilt),
        right: PitEyePose(rotation: PitHeadGeometry.restingOutwardTilt)
    )

    /// The eye vocabulary of ADR 0028 on the head's lenses: the lid's openness becomes the lens height, the gaze an
    /// offset, the lift a vertical offset.
    init(_ state: PitState) {
        let openness: CGFloat = switch state {
        case .blink, .closedEyes: 0.2
        case .startle: 1.06
        case .sideGaze: 0.87
        case .glance: 0.92
        case .resting, .hidden, .lookLeft, .lookRight: 1
        case .lookUp, .fixedGaze, .knock: 1.04
        }
        let gaze: CGPoint = switch state {
        case .lookLeft: CGPoint(x: -1, y: 0.1)
        case .lookRight: CGPoint(x: 1, y: 0.1)
        case .lookUp: CGPoint(x: 0.15, y: -1)
        case .glance: CGPoint(x: 0.5, y: 0.9)
        case .fixedGaze: CGPoint(x: 0, y: 0.15)
        case .sideGaze: CGPoint(x: -0.9, y: -0.6)
        case .startle: CGPoint(x: 0, y: -0.25)
        case .knock: CGPoint(x: 0, y: -0.1)
        case .hidden: CGPoint(x: 0, y: 0.1)
        case .resting, .blink, .closedEyes: .zero
        }
        let lift: CGFloat = switch state {
        case .knock: -3
        case .startle: -2
        case .closedEyes: 1
        default: 0
        }
        let eye = PitEyePose(
            outline: state == .closedEyes ? .arc : .lens,
            rotation: 0,
            widthScale: state == .startle ? 1.16 : 1,
            heightScale: openness
        )
        var left = eye
        left.rotation = -PitHeadGeometry.restingOutwardTilt
        var right = eye
        right.rotation = PitHeadGeometry.restingOutwardTilt
        self.left = left
        self.right = right
        eyeOffset = CGPoint(x: gaze.x * 2.2, y: gaze.y * 1.6 + lift)
        showsHighlight = openness > 0.35
        dimmed = state == .hidden
    }

    init(left: PitEyePose, right: PitEyePose) {
        self.left = left
        self.right = right
    }
}
