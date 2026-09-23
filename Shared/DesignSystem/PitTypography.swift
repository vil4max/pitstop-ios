import SwiftUI

/// Typography roles mapped to Dynamic Type text styles (design-system-module.md). Feature code names a role;
/// the system font and Dynamic Type stay the only type source until a brand decision.
enum PitTypography {
    static let display = Font.largeTitle.bold()
    static let title = Font.title3.weight(.semibold)
    static let headline = Font.headline
    static let body = Font.body
    static let supporting = Font.subheadline
    static let supportingSmall = Font.footnote
    static let caption = Font.caption
    static let captionSmall = Font.caption2
}
