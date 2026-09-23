import SwiftUI

/// A `GroupedSection` row led by a state glyph (ADR 0038): the glyph sits in a scaled leading column, centred on
/// the title's first line, and the hairline above the row starts where the text starts at every text size. An
/// optional trailing accessory (a more menu) sits beside the text, and under it at accessibility sizes so the text
/// keeps the row's width. Road milestones and Service's "Next visit" share it.
struct GlyphColumnRow<Content: View, Accessory: View>: View {
    let glyph: StatusGlyph
    let color: Color
    /// Every row but a section's first draws the hairline above it.
    var showsSeparator = false
    /// The text column. The glyph is hidden from VoiceOver, so accessibility modifiers belong on this content.
    @ViewBuilder let content: Content
    @ViewBuilder let accessory: Accessory

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var glyphSize: CGFloat = GlyphColumnMetrics.glyphSize
    /// Half the headline's cap height: it centres the glyph on the title's first line.
    @ScaledMetric(relativeTo: .headline) private var glyphLift: CGFloat = GlyphColumnMetrics.glyphLift

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        // Read on the main actor: the alignment closure below is Sendable.
        let lift = glyphLift
        layout {
            HStack(alignment: .firstTextBaseline, spacing: GlyphColumnMetrics.glyphSpacing) {
                StatusGlyphView(glyph: glyph, size: glyphSize)
                    .foregroundStyle(color)
                    .frame(width: glyphColumnWidth)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + lift }
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            accessory
        }
        .padding(.vertical, 12)
        .padding(.horizontal, DesignTokens.groupedRowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The inset comes from the same scaled glyph column the row lays out, so it holds at every text size.
        .groupedRowSeparator(
            showsSeparator,
            leadingInset: DesignTokens.groupedRowPadding + glyphColumnWidth + GlyphColumnMetrics.glyphSpacing
        )
    }

    /// The glyph column grows with the headline, so the text starts further in at larger sizes.
    private var glyphColumnWidth: CGFloat {
        max(GlyphColumnMetrics.glyphColumn, glyphSize)
    }
}

/// Outside the generic row: a generic type cannot hold static stored properties.
private enum GlyphColumnMetrics {
    static let glyphColumn: CGFloat = 20
    static let glyphSpacing: CGFloat = 12
    static let glyphSize: CGFloat = 13
    static let glyphLift: CGFloat = 6
}

extension GlyphColumnRow where Accessory == EmptyView {
    init(glyph: StatusGlyph, color: Color, showsSeparator: Bool = false, @ViewBuilder content: () -> Content) {
        self.init(glyph: glyph, color: color, showsSeparator: showsSeparator, content: content) { EmptyView() }
    }
}

/// The label of a row's more menu: the ellipsis glyph in the accent, with the 44 pt minimum target
/// (REQ-GRAMMAR-003). VoiceOver says "More".
struct MoreMenuLabel: View {
    var body: some View {
        Label("service.more", systemImage: "ellipsis.circle")
            .labelStyle(.iconOnly)
            .font(PitTypography.headline)
            .foregroundStyle(PitColor.accentPrimary)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
    }
}

#if DEBUG
    #Preview("Glyph column rows") {
        PreviewMatrix {
            GroupedSection(title: "service.nextVisit") {
                GlyphColumnRow(glyph: .half, color: PitColor.statusApproaching) {
                    Text(verbatim: "Brake fluid").font(PitTypography.headline)
                }
                GlyphColumnRow(glyph: .ring, color: PitColor.accentPrimary, showsSeparator: true) {
                    Text(verbatim: "Winter tyres").font(PitTypography.headline)
                } accessory: {
                    Menu {} label: { MoreMenuLabel() }
                }
            }
        }
    }
#endif
