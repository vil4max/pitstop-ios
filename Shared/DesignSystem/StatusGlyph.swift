import SwiftUI

/// One shape per state, shared by chips, Road markers and widgets, so state is never colour alone
/// (REQ-DESIGN-001). The word that goes with it carries the meaning for VoiceOver.
/// It and `StatusChip` live in `Shared/` because the next-service widget draws them; their previews stay in the app
/// (`StatusPreviews.swift`), which has `PreviewMatrix`.
enum StatusGlyph: CaseIterable, Hashable, Sendable {
    /// Ahead or up to date.
    case ring
    case half
    /// Due.
    case filled
    /// Past due: filled, with a halo ring.
    case filledRing
    /// Unknown or waiting for mileage.
    case dashed
}

/// Draws a `StatusGlyph` in the current foreground style.
struct StatusGlyphView: View {
    let glyph: StatusGlyph
    var size: CGFloat = DesignTokens.statusGlyphSize

    var body: some View {
        ZStack {
            switch glyph {
            case .ring:
                Circle().strokeBorder(lineWidth: strokeWidth)
            case .half:
                Circle().strokeBorder(lineWidth: strokeWidth)
                LeadingHalf().fill()
            case .filled:
                Circle().fill()
            case .filledRing:
                // The halo stays inside the box so a scaled glyph never overlaps the chip's word.
                Circle().strokeBorder(lineWidth: strokeWidth).opacity(0.35)
                Circle().fill().padding(strokeWidth * 1.25)
            case .dashed:
                Circle().strokeBorder(style: StrokeStyle(lineWidth: strokeWidth, dash: [size / 4, size / 6]))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var strokeWidth: CGFloat {
        max(1.5, size / 4.5)
    }

    private struct LeadingHalf: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radius: rect.width / 2,
                startAngle: .degrees(-90),
                endAngle: .degrees(90),
                clockwise: true
            )
            path.closeSubpath()
            return path
        }
    }
}
