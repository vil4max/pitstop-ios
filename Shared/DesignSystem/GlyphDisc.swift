import SwiftUI

/// The stage-tier glyph disc (ADR 0038): an accent glyph on a `surfaceTint` circle. The empty state and the
/// "Remember" widget draw it, so it lives in `Shared/`, which both the app and the widget extension compile.
/// The size is fixed rather than scaled with the text: the disc is decoration, and one that grew would push the
/// text around it out of its container at accessibility sizes.
struct GlyphDisc: View {
    let systemImage: String
    var size: CGFloat = DesignTokens.emptyStateDiscSize

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundStyle(PitColor.accentPrimary)
            .frame(width: size, height: size)
            .background(PitColor.surfaceTint, in: .circle)
            .accessibilityHidden(true)
    }
}
