import SwiftUI

/// The road the car stands on: one horizontal dashed line across the proposed width, centred in its own
/// height. The stage horizon, the Road lane and the Car Board tile draw it the same way, with one dash
/// pattern (`DesignTokens.roadDash`). Decorative: the words beside it carry the meaning.
struct DashedRoadLine: View {
    var lineWidth: CGFloat = DesignTokens.roadLineWidth

    var body: some View {
        Centreline()
            .stroke(
                PitColor.contentTertiary,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: DesignTokens.roadDash)
            )
            .frame(height: lineWidth)
            .accessibilityHidden(true)
    }

    private struct Centreline: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

#if DEBUG
    #Preview("Dashed road line") {
        PreviewMatrix {
            VStack(spacing: 16) {
                DashedRoadLine()
                DashedRoadLine(lineWidth: 1.5)
            }
        }
    }
#endif
