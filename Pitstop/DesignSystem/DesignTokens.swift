import SwiftUI

enum DesignTokens {
    static let screenPadding: CGFloat = 20
    static let tileSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 24
    static let tileCornerRadius: CGFloat = 26
    static let tilePadding: CGFloat = 18
    static let fullTileMinHeight: CGFloat = 148
    static let halfTileMinHeight: CGFloat = 120
    static let utilityButtonSize: CGFloat = 56
    static let heroCarMaxHeight: CGFloat = 88
    /// The road line under the car: the Road lane, the Car Board tile and the stage horizon (`DashedRoadLine`).
    static let roadLineWidth: CGFloat = 2
    static let roadDash: [CGFloat] = [2, 8]

    /// Stage tint: accent 10–22 % in light and 14–28 % in dark (redesign proposal §1).
    static let stageTint = TintOpacity(light: 0.10, dark: 0.14, highContrastLight: 0.16, highContrastDark: 0.22)
    static let stageTintStrong = TintOpacity(light: 0.22, dark: 0.28, highContrastLight: 0.30, highContrastDark: 0.36)

    static let chipCornerRadius: CGFloat = 20
    static let statusGlyphSize: CGFloat = 9
    static let shareTrackHeight: CGFloat = 5
    static let emptyStateDiscSize: CGFloat = 64
    static let hairline: CGFloat = 0.5

    struct TintOpacity: Equatable {
        let light: CGFloat
        let dark: CGFloat
        let highContrastLight: CGFloat
        let highContrastDark: CGFloat

        func value(dark isDark: Bool, highContrast: Bool) -> CGFloat {
            switch (isDark, highContrast) {
            case (false, false): light
            case (true, false): dark
            case (false, true): highContrastLight
            case (true, true): highContrastDark
            }
        }
    }
}
