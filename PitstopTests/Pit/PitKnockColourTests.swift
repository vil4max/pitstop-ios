import CoreGraphics
@testable import Pitstop
import SwiftUI
import Testing

/// A knock is also a colour change (REQ-PIT-023).
@MainActor
@Suite("Pit knock colour")
struct PitKnockColourTests {
    @Test("REQ-PIT-023: only the knock draws the eyes in the accent, with a stronger glow")
    func onlyTheKnockUsesTheAccent() {
        for state in PitState.allCases {
            let pose = PitPose(state)
            #expect(pose.eyeTint == (state == .knock ? .accent : .lit), "\(state)")
            #expect((pose.glow > PitPose.restingGlow) == (state == .knock), "\(state)")
        }
    }

    @Test("REQ-PIT-023: the knock takes the accent with or without Reduce Motion, and the eyes return to rest after it")
    func knockWithAndWithoutReduceMotion() async {
        // In the capture sheet a proposal and Pit's question are knocks, with or without Reduce Motion.
        for reduceMotion in [false, true] {
            for moment in [PitCaptureMoment.proposing, .asking] {
                let beats = PitCaptureChoreography.beats(from: .listening, to: moment, reduceMotion: reduceMotion)
                #expect(beats.last?.state == .knock)
            }
        }
        // In the utility layer the knock stays a knock under Reduce Motion, and ends at rest.
        for reduceMotion in [false, true] {
            let presence = PitPresenceModel(sleep: { _ in })
            presence.setReduceMotion(reduceMotion)
            await presence.askPermissionToInterrupt()
            #expect(PitPose(presence.state).eyeTint == .accent)
            presence.endQuestion()
            #expect(PitPose(presence.state).eyeTint == .lit)
            presence.stop()
        }
    }

    @Test("REQ-PIT-023: the knocking eyes are drawn in accentPrimary as it reads on the dark screen")
    func renderedKnockUsesTheAccent() throws {
        let size: CGFloat = 56
        let unit = size / PitHeadGeometry.viewBox
        // Below the highlight, inside the left lens, where the knocking head carries it.
        let point = Self.posed(CGPoint(x: 22, y: 32), in: PitPose(.knock), unit: unit)
        let accent = PitHeadTests.resolve(PitColor.accentPrimary, dark: true)
        let lit = PitHeadTests.resolve(PitColor.headEye, dark: false)
        for scheme in [ColorScheme.light, .dark] {
            let knock = try #require(PitHeadTests.render(
                PitHead(state: .knock, size: size, finish: .standard).environment(\.colorScheme, scheme), size: size
            ))
            let resting = try #require(PitHeadTests.render(
                PitHead(state: .resting, size: size, finish: .standard).environment(\.colorScheme, scheme), size: size
            ))
            #expect(Self.close(PitHeadTests.rgb(of: knock, at: point), accent), "knock in \(scheme)")
            let restingPoint = Self.posed(CGPoint(x: 22, y: 32), in: PitPose(.resting), unit: unit)
            #expect(Self.close(PitHeadTests.rgb(of: resting, at: restingPoint), lit), "resting in \(scheme)")
        }
    }

    /// Against the bare screen, as Increase Contrast draws the knock (it removes the glow). With the glow the knock's
    /// eye contrast is lower; ADR 0039 records the measured values.
    @Test("REQ-PIT-023: the accent eyes read on the bare face screen in every appearance")
    func accentReadsOnTheScreen() {
        for highContrast in [false, true] {
            let visor = PitHeadTests.resolve(PitColor.headVisorTop, dark: true, highContrast: highContrast)
            let accent = PitHeadTests.resolve(PitColor.accentPrimary, dark: true, highContrast: highContrast)
            #expect(PitHeadTests.contrast(accent, visor) >= 4.5)
        }
    }

    /// A point of the head's view box where the pose's head tilt and lift carry it, in points.
    static func posed(_ point: CGPoint, in pose: PitPose, unit: CGFloat) -> CGPoint {
        let anchor = CGPoint(x: 28, y: 30)
        let radians = pose.headTilt * .pi / 180
        let (dx, dy) = (point.x - anchor.x, point.y - anchor.y)
        let turned = CGPoint(
            x: anchor.x + dx * cos(radians) - dy * sin(radians),
            y: anchor.y + dx * sin(radians) + dy * cos(radians) - pose.headLift
        )
        return CGPoint(x: turned.x * unit, y: turned.y * unit)
    }

    /// Within 0.08 per channel: the renderer shades a dark-scheme image a few percent darker, while the light accent
    /// and the resting eye each differ from the pale accent by more than 0.25 in red.
    private static func close(_ first: PitHeadTests.Components, _ second: PitHeadTests.Components) -> Bool {
        abs(first.red - second.red) < 0.08 && abs(first.green - second.green) < 0.08
            && abs(first.blue - second.blue) < 0.08
    }
}
