import SwiftUI

/// A sparse screen (REQ-GRAMMAR-004): a glyph disc, a headline, at most one sentence and one or two actions,
/// never a placeholder metric.
struct EmptyState<Actions: View>: View {
    let title: Text
    let systemImage: String
    let message: Text?
    @ViewBuilder let actions: Actions

    init(
        _ title: Text,
        systemImage: String,
        message: Text? = nil,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.actions = actions()
    }

    @ScaledMetric(relativeTo: .title3) private var discSize = DesignTokens.emptyStateDiscSize

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: discSize * 0.45, weight: .medium))
                .foregroundStyle(PitColor.accentPrimary)
                .frame(width: discSize, height: discSize)
                .background(PitColor.surfaceTint, in: .circle)
                .accessibilityHidden(true)
            title
                .font(PitTypography.title.bold())
                .foregroundStyle(PitColor.contentPrimary)
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)
            if let message {
                message
                    .font(PitTypography.supporting)
                    .foregroundStyle(PitColor.contentSecondary)
                    .frame(maxWidth: 280)
            }
            actions
                .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 40)
        .padding(.bottom, 20)
    }
}

#if DEBUG
    #Preview("Empty state") {
        PreviewMatrix {
            EmptyState(
                Text(verbatim: "Nothing on the road yet"),
                systemImage: "road.lanes",
                message: Text(verbatim: "Mark a service as done and it will show here.")
            ) {
                Button(action: {}, label: { Text(verbatim: "Mark as done") })
                    .buttonStyle(.borderedProminent)
            }
        }
    }
#endif
