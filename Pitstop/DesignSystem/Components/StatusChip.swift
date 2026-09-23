import SwiftUI

/// A state said as a word, a glyph and a colour (REQ-DESIGN-001). The chip reads as its word alone.
struct StatusChip: View {
    let title: Text
    let glyph: StatusGlyph
    let color: Color

    init(_ title: Text, glyph: StatusGlyph, color: Color) {
        self.title = title
        self.glyph = glyph
        self.color = color
    }

    init(_ titleKey: LocalizedStringKey, glyph: StatusGlyph, color: Color) {
        self.init(Text(titleKey), glyph: glyph, color: color)
    }

    @ScaledMetric(relativeTo: .footnote) private var glyphSize = DesignTokens.statusGlyphSize

    var body: some View {
        HStack(spacing: 5) {
            StatusGlyphView(glyph: glyph, size: glyphSize)
            title
                .font(PitTypography.supportingSmall.weight(.semibold))
                // A chip wraps rather than truncates at accessibility sizes (REQ-GRAMMAR-003).
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(color)
        .padding(.vertical, 3)
        .padding(.leading, 7)
        .padding(.trailing, 9)
        .background(color.opacity(0.14), in: .rect(cornerRadius: DesignTokens.chipCornerRadius))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
    #Preview("Status chips") {
        PreviewMatrix {
            VStack(alignment: .leading, spacing: 8) {
                StatusChip(Text(verbatim: "Ahead"), glyph: .ring, color: PitColor.accentPrimary)
                StatusChip(Text(verbatim: "Up to date"), glyph: .ring, color: PitColor.statusUpToDate)
                StatusChip(Text(verbatim: "Approaching"), glyph: .half, color: PitColor.statusApproaching)
                StatusChip(Text(verbatim: "Due"), glyph: .filled, color: PitColor.statusDue)
                StatusChip(Text(verbatim: "Past due"), glyph: .filledRing, color: PitColor.statusDue)
                StatusChip(Text(verbatim: "Not enough facts"), glyph: .dashed, color: PitColor.contentSecondary)
            }
        }
    }
#endif
