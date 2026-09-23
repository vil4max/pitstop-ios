import SwiftUI

/// The stage tier (ADR 0038): the only tinted surface, behind the car and the Road lane (REQ-DESIGN-003).
struct StageSurface<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        content
            .padding(.horizontal, DesignTokens.tilePadding)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { background }
            .overlay {
                if reduceTransparency || contrast == .increased {
                    shape.strokeBorder(PitColor.separator, lineWidth: DesignTokens.hairline)
                }
            }
            .clipShape(shape)
    }

    private var background: some View {
        ZStack {
            // Over an opaque base the tint no longer lets the screen ground show through.
            if reduceTransparency {
                PitColor.surfaceSecondary
            }
            LinearGradient(
                colors: [PitColor.surfaceTintStrong, PitColor.surfaceTint],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DesignTokens.tileCornerRadius, style: .continuous)
    }
}

#if DEBUG
    #Preview("Stage") {
        PreviewMatrix {
            StageSurface {
                VStack(alignment: .leading, spacing: 4) {
                    AbstractCarView().frame(height: DesignTokens.heroCarMaxHeight)
                    Text(verbatim: "47 560 km")
                        .font(PitTypography.title)
                    Text(verbatim: "updated 9 days ago")
                        .font(PitTypography.supportingSmall)
                        .foregroundStyle(PitColor.contentSecondary)
                }
            }
        }
    }
#endif
