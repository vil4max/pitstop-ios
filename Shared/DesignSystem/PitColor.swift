import SwiftUI
import UIKit

/// Semantic colour roles (screen-grammar.md). Feature code names a role, never a literal colour.
/// Character: cloud blue accent, soft gray surfaces, warm amber for maintenance attention.
enum PitColor {
    static let surfacePrimary = Color(uiColor: .systemGroupedBackground)
    static let surfaceSecondary = Color(uiColor: .secondarySystemGroupedBackground)
    static let surfaceElevated = Color(uiColor: .tertiarySystemGroupedBackground)

    static let contentPrimary = Color(uiColor: .label)
    static let contentSecondary = Color(uiColor: .secondaryLabel)
    static let contentTertiary = Color(uiColor: .tertiaryLabel)
    static let separator = Color(uiColor: .separator)

    /// Light value chosen for at least 4.5:1 on `surfacePrimary`; it is used for small text.
    static let accentPrimary = dynamic(light: accentLight, dark: accentDark)

    static let statusUpToDate = dynamic(light: RGB(0.16, 0.55, 0.47), dark: RGB(0.42, 0.80, 0.70))
    static let statusApproaching = dynamic(light: RGB(0.80, 0.55, 0.10), dark: RGB(0.98, 0.78, 0.36))
    /// Due is attention, not danger: a deeper amber, never red (product-design.md).
    static let statusDue = dynamic(light: RGB(0.78, 0.38, 0.08), dark: RGB(0.99, 0.62, 0.30))
    static let statusDanger = Color(uiColor: .systemRed)

    /// The stage tier's only tint (REQ-DESIGN-003): `accentPrimary` at a token opacity. The strong step is the
    /// top of the stage gradient. Increase Contrast raises both so the stage still reads as a surface.
    static let surfaceTint = tint(DesignTokens.stageTint)
    static let surfaceTintStrong = tint(DesignTokens.stageTintStrong)

    /// Text and glyphs on an `accentPrimary` fill. White on the light accent; a deep navy on the pale dark-mode
    /// accent, where white would fall below 3:1.
    static let contentOnAccent = dynamic(light: RGB(1, 1, 1), dark: RGB(0.04, 0.13, 0.27))

    // Pit's head (product-design.md "Pit visual identity", ADR 0037). The head is an object, not a surface: it stays
    // pearl with a navy face screen in dark mode, so most pairs repeat the light value. Increase Contrast darkens the
    // edges that separate shell, bezel and screen. The values follow the mockup's `pitHead()` and the icon layers.

    /// The lit top-left of the pearl shell, where the light falls.
    static let headShellLight = fixed(RGB(1, 1, 1))
    static let headShell = fixed(RGB(0.933, 0.945, 0.961))
    /// The shell's lower-right edge; darker with Increase Contrast so the round edge reads on white content.
    static let headShellShade = pair(RGB(0.804, 0.827, 0.863), highContrast: RGB(0.690, 0.718, 0.765))
    /// The hairline around the shell. Its dark-mode value is lighter than the light one: on black content the pearl
    /// edge already separates, and a navy line would read as a gap.
    static let headHairline = dynamic(
        light: RGB(0.078, 0.125, 0.204, alpha: 0.16),
        dark: RGB(0.078, 0.125, 0.204, alpha: 0.10),
        highContrastLight: RGB(0.078, 0.125, 0.204, alpha: 0.55),
        highContrastDark: RGB(0.078, 0.125, 0.204, alpha: 0.40)
    )
    /// The gloss arcs on the shell and on the face screen; not drawn with Reduce Transparency or Increase Contrast.
    static let headGloss = fixed(RGB(1, 1, 1, alpha: 0.85))
    static let headVisorGloss = fixed(RGB(1, 1, 1, alpha: 0.22))
    /// The thin grey rim that sets the face screen into the shell (the icon's opaque `2-bezel`).
    static let headBezel = pair(RGB(0.788, 0.812, 0.847), highContrast: RGB(0.541, 0.576, 0.635))
    /// The face screen: the app icon's dark navy, lighter at the top.
    static let headVisorTop = pair(RGB(0.102, 0.165, 0.259), highContrast: RGB(0.043, 0.086, 0.149))
    static let headVisorBottom = fixed(RGB(0.043, 0.086, 0.149))
    /// The faint glow behind the eyes; the pose sets its strength.
    static let headGlow = fixed(RGB(0.435, 0.698, 1))
    /// The lit lens eyes: soft blue-white, white with Increase Contrast.
    static let headEye = pair(RGB(0.851, 0.914, 1), highContrast: RGB(1, 1, 1))
    static let headEyeHighlight = fixed(RGB(1, 1, 1, alpha: 0.9))
    /// Lifts the head off light content, where the pearl shell and a white screen are close in lightness.
    static let headShadow = dynamic(
        light: RGB(0.039, 0.078, 0.157, alpha: 0.22),
        dark: RGB(0, 0, 0, alpha: 0.45),
        highContrastLight: RGB(0.039, 0.078, 0.157, alpha: 0.34),
        highContrastDark: RGB(0, 0, 0, alpha: 0.6)
    )
    /// Laid over the head while it is pressed, as a pressed button darkens.
    static let headPressed = fixed(RGB(0.043, 0.086, 0.149, alpha: 0.14))

    private struct RGB {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, alpha: CGFloat = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        var uiColor: UIColor {
            UIColor(red: red, green: green, blue: blue, alpha: alpha)
        }
    }

    private static let accentLight = RGB(0.10, 0.37, 0.70)
    private static let accentDark = RGB(0.49, 0.73, 0.98)

    private static func dynamic(light: RGB, dark: RGB) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        })
    }

    /// The same value in every appearance: part of an object, not a surface.
    private static func fixed(_ rgb: RGB) -> Color {
        dynamic(light: rgb, dark: rgb, highContrastLight: rgb, highContrastDark: rgb)
    }

    /// Light and dark alike, with a stronger value under Increase Contrast.
    private static func pair(_ rgb: RGB, highContrast: RGB) -> Color {
        dynamic(light: rgb, dark: rgb, highContrastLight: highContrast, highContrastDark: highContrast)
    }

    private static func dynamic(light: RGB, dark: RGB, highContrastLight: RGB, highContrastDark: RGB) -> Color {
        Color(uiColor: UIColor { traits in
            let isHigh = traits.accessibilityContrast == .high
            let rgb = switch (traits.userInterfaceStyle == .dark, isHigh) {
            case (false, false): light
            case (true, false): dark
            case (false, true): highContrastLight
            case (true, true): highContrastDark
            }
            return rgb.uiColor
        })
    }

    private static func tint(_ opacity: DesignTokens.TintOpacity) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let rgb = isDark ? accentDark : accentLight
            let alpha = opacity.value(dark: isDark, highContrast: traits.accessibilityContrast == .high)
            return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: alpha)
        })
    }
}
