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

    /// How far both eye tops lean toward each other, in degrees: half the angle between the two eyes, positive when
    /// they converge, negative when they splay. A roll of both eyes the same way leaves it unchanged, so this is the
    /// angle that could read as judgement, and it is capped at 6° (REQ-PIT-022).
    var inwardTilt: Double {
        (left.rotation - right.rotation) / 2
    }

    /// How far both eyes turn the same way, in degrees, clockwise positive.
    var roll: Double {
        (left.rotation + right.rotation) / 2
    }

    /// The Poses table of pit-behavior-and-motion.md, drawn without animation. Offsets are in head units; the
    /// head's own tilt and lift are separate.
    init(_ state: PitState) {
        switch state {
        case .resting, .hidden:
            self = .resting
            dimmed = state == .hidden
        case .blink:
            // The lenses flatten to 20 % of their height.
            self = PitPose.resting.eyes { $0.heightScale = 0.2 }
            showsHighlight = false
        case .lookLeft, .lookRight:
            // Both eyes shift toward the side and turn 3° toward it; the trailing eye follows 25 ms later
            // (`PitEyeAnimation.trailingEyeDelay`).
            let side: Double = state == .lookRight ? 1 : -1
            self = PitPose.resting.eyes { $0.rotation += 3 * side }
            eyeOffset = CGPoint(x: 2.2 * side, y: 0)
        case .lookUp:
            self = PitPose.resting.eyes { $0.heightScale = 1.04 }
            eyeOffset = CGPoint(x: 0, y: -1.6)
        case .glance:
            // Down toward the saved result below the sheet header: both eyes roll 8° toward it and converge 2°.
            self = PitPose(left: PitEyePose(rotation: 10), right: PitEyePose(rotation: 6))
            eyeOffset = CGPoint(x: 0.6, y: 1.4)
        case .fixedGaze:
            // Listening: upright and 6 % taller.
            let upright = PitEyePose(rotation: 0, heightScale: 1.06)
            self = PitPose(left: upright, right: upright)
        case .sideGaze:
            // Thinking: up and aside, both eyes rolled 10° the same way.
            self = PitPose(left: PitEyePose(rotation: 10), right: PitEyePose(rotation: 10))
            eyeOffset = CGPoint(x: 2, y: -1.3)
        case .startle:
            // The lenses round out.
            self = PitPose.resting.eyes {
                $0.widthScale = 1.16
                $0.heightScale = 1.06
            }
        case .knock:
            // Attention, never judgement: the tops lean inward by the 6° cap.
            self = PitPose(
                left: PitEyePose(rotation: PitHeadGeometry.restingOutwardTilt),
                right: PitEyePose(rotation: -PitHeadGeometry.restingOutwardTilt)
            )
        case .closedEyes:
            // Shallow upward arcs; the flattened, upright lenses fade into them.
            let closed = PitEyePose(outline: .arc, rotation: 0, heightScale: 0.2)
            self = PitPose(left: closed, right: closed)
            showsHighlight = false
        }
    }

    init(left: PitEyePose, right: PitEyePose) {
        self.left = left
        self.right = right
    }

    /// This pose with both eyes changed the same way.
    private func eyes(_ change: (inout PitEyePose) -> Void) -> PitPose {
        var pose = self
        change(&pose.left)
        change(&pose.right)
        return pose
    }
}
