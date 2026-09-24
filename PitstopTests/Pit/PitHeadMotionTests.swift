import CoreGraphics
@testable import Pitstop
import Testing

/// The head adds only a tilt and a lift, and only in motion-table states (REQ-PIT-024).
@MainActor
@Suite("Pit head motion")
struct PitHeadMotionTests {
    /// The states whose row in the Poses table moves the head.
    static let movingStates: Set<PitState> = [.sideGaze, .startle, .knock]

    @Test("REQ-PIT-024: the head tilts or lifts only when thinking, startled or knocking")
    func onlyMotionTableStatesMoveTheHead() {
        for state in PitState.allCases {
            let pose = PitPose(state)
            let moves = pose.headTilt != 0 || pose.headLift != 0
            #expect(moves == Self.movingStates.contains(state), "\(state)")
        }
        #expect(PitPose(.sideGaze).headTilt != 0 && PitPose(.sideGaze).headLift == 0)
        #expect(PitPose(.startle).headLift == 2 && PitPose(.startle).headTilt == 0)
        #expect(PitPose(.knock).headLift == 3 && PitPose(.knock).headTilt != 0)
    }

    @Test("REQ-PIT-024: the head tilts at most 6° and lifts at most 3 pt, bumps included")
    func headMovesStayInBounds() {
        for state in PitState.allCases {
            let pose = PitPose(state)
            #expect(abs(pose.headTilt) <= 6 && (0 ... 3).contains(pose.headLift), "\(state)")
        }
        #expect(abs(PitPose(.knock).headTilt) <= 4)
        // The knock's two bumps dip from the lifted pose and never lift the head past it or below rest.
        let lift = PitPose(.knock).headLift
        // These are the keyframes the head plays, then a spring back to the lifted pose.
        #expect(PitHeadMotion.knockBumps.filter { $0.dip > 0 }.count == 2)
        for bump in PitHeadMotion.knockBumps {
            #expect(bump.dip >= 0 && lift - bump.dip >= 0 && bump.duration > 0)
        }
    }

    @Test("REQ-PIT-024: resting and every idle action keep the head still")
    func idleKeepsTheHeadStill() {
        #expect(PitPose(.resting).headTilt == 0 && PitPose(.resting).headLift == 0)
        for action in PitIdleAction.allCases {
            for base in [PitState.resting, .fixedGaze] {
                for beat in action.beats(returningTo: base) {
                    let pose = PitPose(beat.state)
                    #expect(pose.headTilt == 0 && pose.headLift == 0, "\(action) shows \(beat.state)")
                }
            }
        }
    }

    @Test("REQ-PIT-024: with Reduce Motion every pose is shown as it is, without animation or bumps")
    func reduceMotionShowsPosesWithoutAnimation() {
        for state in PitState.allCases {
            #expect(PitHeadMotion.animation(into: state, reduceMotion: true) == nil, "\(state)")
            #expect(PitHeadMotion.animation(into: state, reduceMotion: false) != nil, "\(state)")
            #expect(!PitHeadMotion.playsBumps(entering: state, reduceMotion: true))
        }
        #expect(PitHeadMotion.playsBumps(entering: .knock, reduceMotion: false))
        #expect(!PitHeadMotion.playsBumps(entering: .startle, reduceMotion: false))
    }

    @Test("REQ-PIT-024: with Reduce Motion the utility layer's Pit is still at rest and lifted, lit only on a knock")
    func reduceMotionInTheLayer() async {
        let presence = PitPresenceModel(sleep: { _ in })
        presence.setReduceMotion(true)
        #expect(presence.state == .resting)
        #expect(PitPose(presence.state).headLift == 0 && PitPose(presence.state).headTilt == 0)
        await presence.askPermissionToInterrupt()
        // No startle first: the knock alone, lifted and lit (REQ-PIT-018, REQ-PIT-023).
        #expect(presence.state == .knock && PitPose(presence.state).headLift == 3)
        presence.endQuestion()
        #expect(PitPose(presence.state).headLift == 0)
        presence.stop()
    }
}
