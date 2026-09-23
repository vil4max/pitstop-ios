@testable import Pitstop
import SwiftUI
import Testing
import UIKit

@Suite("Colour roles")
struct PitColorTests {
    private struct Components: Equatable {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        func sameColour(as other: Components) -> Bool {
            abs(red - other.red) < 0.001 && abs(green - other.green) < 0.001 && abs(blue - other.blue) < 0.001
        }
    }

    private func resolve(_ color: Color, dark: Bool, highContrast: Bool = false) -> Components {
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = dark ? .dark : .light
            traits.accessibilityContrast = highContrast ? .high : .normal
        }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return Components(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// WCAG 2 relative luminance of an opaque colour.
    private func luminance(_ color: Components) -> CGFloat {
        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.red) + 0.7152 * channel(color.green) + 0.0722 * channel(color.blue)
    }

    private func contrast(_ first: Components, _ second: Components) -> CGFloat {
        let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (lighter + 0.05) / (darker + 0.05)
    }

    @Test("REQ-DESIGN-003: the stage tint is the accent at the token opacity in light and dark")
    func stageTintIsTheAccent() {
        for dark in [false, true] {
            let accent = resolve(PitColor.accentPrimary, dark: dark)
            let tint = resolve(PitColor.surfaceTint, dark: dark)
            let strong = resolve(PitColor.surfaceTintStrong, dark: dark)
            #expect(tint.sameColour(as: accent))
            #expect(strong.sameColour(as: accent))
            #expect(abs(tint.alpha - DesignTokens.stageTint.value(dark: dark, highContrast: false)) < 0.001)
            #expect(abs(strong.alpha - DesignTokens.stageTintStrong.value(dark: dark, highContrast: false)) < 0.001)
        }
    }

    @Test("REQ-DESIGN-003: the tint stays inside the approved 10–22 % light and 14–28 % dark range")
    func stageTintStaysInRange() {
        let light = [DesignTokens.stageTint.light, DesignTokens.stageTintStrong.light]
        let dark = [DesignTokens.stageTint.dark, DesignTokens.stageTintStrong.dark]
        #expect(light.allSatisfy { (0.10 ... 0.22).contains($0) })
        #expect(dark.allSatisfy { (0.14 ... 0.28).contains($0) })
    }

    @Test("Increase Contrast raises the stage tint so the stage still reads as a surface")
    func increaseContrastRaisesTheTint() {
        for dark in [false, true] {
            let normal = resolve(PitColor.surfaceTint, dark: dark).alpha
            let high = resolve(PitColor.surfaceTint, dark: dark, highContrast: true).alpha
            #expect(high > normal)
        }
    }

    @Test("Content on the accent fill keeps at least 4.5:1 in light and dark")
    func contentOnAccentIsReadable() {
        for dark in [false, true] {
            let ratio = contrast(
                resolve(PitColor.contentOnAccent, dark: dark),
                resolve(PitColor.accentPrimary, dark: dark)
            )
            #expect(ratio >= 4.5, "contrast \(ratio) in \(dark ? "dark" : "light")")
        }
    }
}
