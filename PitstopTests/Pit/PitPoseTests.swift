import CoreGraphics
@testable import Pitstop
import Testing

/// The Poses table of pit-behavior-and-motion.md, checked on the values the head draws.
@Suite("Pit poses")
struct PitPoseTests {
    /// Every state of the motion language; "hidden" is not used (Pit is always on screen).
    static let motionStates = PitState.allCases.filter { $0 != .hidden }

    /// What a pose looks like, ignoring the dimming that only "hidden" uses.
    private struct Drawn: Hashable {
        let left: PitEyePose
        let right: PitEyePose
        let eyeOffset: CGPoint
    }

    @Test("REQ-PIT-022: every state of the motion language has its own static pose")
    func posesAreDistinct() {
        let drawn = Self.motionStates.map { state in
            let pose = PitPose(state)
            return Drawn(left: pose.left, right: pose.right, eyeOffset: pose.eyeOffset)
        }
        #expect(Set(drawn).count == Self.motionStates.count)
    }

    @Test("REQ-PIT-022: the inward eye tilt never exceeds 6°, and only the knock leans both eyes inward")
    func inwardTiltIsCapped() {
        for state in PitState.allCases {
            let pose = PitPose(state)
            #expect(pose.inwardTilt <= 6, "\(state) leans inward \(pose.inwardTilt)°")
            // Each eye turns at most 10° (proposal §3.6b); a same-way roll is not an inward angle.
            #expect(abs(pose.left.rotation) <= 10 && abs(pose.right.rotation) <= 10, "\(state)")
            if state != .knock {
                #expect(pose.inwardTilt < 6, "\(state) takes the knock's inward pose")
            }
        }
        #expect(PitPose(.knock).inwardTilt == 6)
    }

    @Test("REQ-PIT-022: the poses follow the table: resting, blink, looks, listening, thinking, startle, closed")
    func posesFollowTheTable() {
        let resting = PitPose(.resting)
        #expect(resting.left.rotation == -6 && resting.right.rotation == 6)
        #expect(resting.eyeOffset == .zero && resting.showsHighlight)

        let blink = PitPose(.blink)
        #expect(blink.left.heightScale == 0.2 && blink.right.heightScale == 0.2 && !blink.showsHighlight)

        // Looking aside shifts the eyes and turns both 3° toward the side.
        let right = PitPose(.lookRight), left = PitPose(.lookLeft)
        #expect(right.eyeOffset.x > 0 && left.eyeOffset.x == -right.eyeOffset.x)
        #expect(right.left.rotation == -3 && right.right.rotation == 9)
        #expect(left.left.rotation == -9 && left.right.rotation == 3)

        let up = PitPose(.lookUp)
        #expect(up.eyeOffset.y < 0 && up.left.heightScale > 1)

        let glance = PitPose(.glance)
        #expect(glance.eyeOffset.y > 0)
        #expect(glance.roll == 8 && glance.inwardTilt == 2)

        let listening = PitPose(.fixedGaze)
        #expect(listening.left.rotation == 0 && listening.right.rotation == 0)
        #expect(abs(listening.left.heightScale - 1.06) < 0.0001)

        let thinking = PitPose(.sideGaze)
        #expect(thinking.eyeOffset.y < 0 && thinking.eyeOffset.x != 0)
        #expect(thinking.left.rotation == 10 && thinking.right.rotation == 10)

        let startle = PitPose(.startle)
        #expect(startle.left.widthScale > 1 && startle.left.heightScale > 1)

        let knock = PitPose(.knock)
        #expect(knock.left.rotation == 6 && knock.right.rotation == -6)

        let closed = PitPose(.closedEyes)
        #expect(closed.left.outline == .arc && closed.right.outline == .arc && !closed.showsHighlight)
    }

    @Test("REQ-PIT-022: in every pose both lenses stay on the face screen")
    func eyesStayOnTheScreen() {
        let screen = PitHeadGeometry.visor.insetBy(dx: 1, dy: 1)
        for state in PitState.allCases {
            let pose = PitPose(state)
            for (eye, center) in [
                (pose.left, PitHeadGeometry.leftEyeCenter),
                (pose.right, PitHeadGeometry.rightEyeCenter),
            ] {
                let bounds = Self.lensBounds(eye, center: CGPoint(
                    x: center.x + pose.eyeOffset.x,
                    y: center.y + pose.eyeOffset.y
                ))
                #expect(screen.contains(bounds), "\(state): \(bounds)")
            }
        }
    }

    /// The axis-aligned bounds of a scaled, then tilted lens.
    static func lensBounds(_ eye: PitEyePose, center: CGPoint) -> CGRect {
        let radians = eye.rotation * .pi / 180
        let rx = PitHeadGeometry.lensRadii.width * eye.widthScale
        let ry = PitHeadGeometry.lensRadii.height * eye.heightScale
        let halfWidth = (pow(rx * cos(radians), 2) + pow(ry * sin(radians), 2)).squareRoot()
        let halfHeight = (pow(rx * sin(radians), 2) + pow(ry * cos(radians), 2)).squareRoot()
        return CGRect(x: center.x - halfWidth, y: center.y - halfHeight, width: 2 * halfWidth, height: 2 * halfHeight)
    }
}
