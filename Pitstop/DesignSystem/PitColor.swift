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
    static let accentPrimary = dynamic(light: RGB(0.10, 0.37, 0.70), dark: RGB(0.49, 0.73, 0.98))

    static let statusUpToDate = dynamic(light: RGB(0.16, 0.55, 0.47), dark: RGB(0.42, 0.80, 0.70))
    static let statusApproaching = dynamic(light: RGB(0.80, 0.55, 0.10), dark: RGB(0.98, 0.78, 0.36))
    /// Due is attention, not danger: a deeper amber, never red (product-design.md).
    static let statusDue = dynamic(light: RGB(0.78, 0.38, 0.08), dark: RGB(0.99, 0.62, 0.30))
    static let statusDanger = Color(uiColor: .systemRed)

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

    private static func dynamic(light: RGB, dark: RGB) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        })
    }
}
