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

    private struct RGB {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) {
            self.red = red
            self.green = green
            self.blue = blue
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

    private static func tint(_ opacity: DesignTokens.TintOpacity) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let rgb = isDark ? accentDark : accentLight
            let alpha = opacity.value(dark: isDark, highContrast: traits.accessibilityContrast == .high)
            return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: alpha)
        })
    }
}
