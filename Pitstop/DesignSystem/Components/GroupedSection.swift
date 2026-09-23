import SwiftUI

/// One inset-grouped container per section (ADR 0038, REQ-GRAMMAR-001): a heading, then rows separated by
/// hairlines on one calm surface, not a card per row, and an optional footer under the container. It lives in a
/// `ScrollView`, so screens that also draw a stage or a banner keep one scroll surface instead of a `List`.
struct GroupedSection<Rows: View>: View {
    let title: LocalizedStringKey
    var footer: LocalizedStringKey?
    @ViewBuilder let rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(PitTypography.title)
                .foregroundStyle(PitColor.contentPrimary)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) {
                rows
            }
            .background(PitColor.surfaceSecondary, in: shape)
            .overlay(shape.strokeBorder(PitColor.separator.opacity(0.35), lineWidth: DesignTokens.hairline))
            if let footer {
                Text(footer)
                    .font(PitTypography.supportingSmall)
                    .foregroundStyle(PitColor.contentSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DesignTokens.groupedRowPadding)
            }
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DesignTokens.groupedCornerRadius, style: .continuous)
    }
}

extension View {
    /// The hairline above a grouped row. It starts where the row's text starts, as a native inset list separator
    /// does; a row with a scaled leading column passes the scaled inset so it holds at every text size.
    func groupedRowSeparator(_ isShown: Bool, leadingInset: CGFloat = DesignTokens.groupedRowPadding) -> some View {
        overlay(alignment: .top) {
            if isShown {
                Rectangle()
                    .fill(PitColor.separator)
                    .frame(height: DesignTokens.hairline)
                    .padding(.leading, leadingInset)
                    .accessibilityHidden(true)
            }
        }
    }
}

#if DEBUG
    #Preview("Grouped section") {
        PreviewMatrix {
            GroupedSection(title: "service.tracked", footer: "service.nextVisit.footer") {
                ForEach(0 ..< 3, id: \.self) { index in
                    Text(verbatim: "Row \(index + 1)")
                        .font(PitTypography.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, DesignTokens.groupedRowPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .groupedRowSeparator(index > 0)
                }
            }
        }
    }
#endif
