import SwiftUI

/// Card geometry shared by every Car Board tile: summary content on a calm secondary surface.
struct TileCard<Content: View>: View {
    let minHeight: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(DesignTokens.tilePadding)
            // Fills the row height so two half tiles side by side always match.
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
            .background(PitColor.surfaceSecondary, in: shape)
            .overlay(shape.strokeBorder(PitColor.separator.opacity(0.35), lineWidth: 0.5))
            .contentShape(shape)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DesignTokens.tileCornerRadius, style: .continuous)
    }
}

/// Title row used inside a tile: a small symbol and the surface name.
struct TileTitle: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PitColor.contentSecondary)
            .labelStyle(.titleAndIcon)
    }
}
