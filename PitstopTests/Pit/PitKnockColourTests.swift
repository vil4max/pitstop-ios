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
        // Below the highlight, inside the left lens.
        let point = CGPoint(x: 22 * unit, y: 32 * unit)
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
            #expect(Self.close(PitHeadTests.rgb(of: resting, at: point), lit), "resting in \(scheme)")
        }
    }

    @Test("REQ-PIT-023: the accent eyes read on the face screen in every appearance")
    func accentReadsOnTheScreen() {
        for highContrast in [false, true] {
            let visor = PitHeadTests.resolve(PitColor.headVisorTop, dark: true, highContrast: highContrast)
            let accent = PitHeadTests.resolve(PitColor.accentPrimary, dark: true, highContrast: highContrast)
            #expect(PitHeadTests.contrast(accent, visor) >= 4.5)
        }
    }

    private static func close(_ first: PitHeadTests.Components, _ second: PitHeadTests.Components) -> Bool {
        abs(first.red - second.red) < 0.04 && abs(first.green - second.green) < 0.04
            && abs(first.blue - second.blue) < 0.04
    }
}
