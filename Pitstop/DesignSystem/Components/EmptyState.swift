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

    /// Fixed at every text size (mockup `#empty`): the disc is decoration, and a disc that grew with the text would
    /// push the actions off screen at accessibility sizes.
    private let discSize = DesignTokens.emptyStateDiscSize

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

/// What a sparse state says (REQ-GRAMMAR-004), decided from the screen's state rather than in its view so the rule
/// is testable without snapshots. It has no slot for a value: a surface without records shows no placeholder
/// metric.
struct EmptyStateContent<Action: Hashable>: Equatable {
    /// One or two actions at most; the single entrance comes first (mockup `#empty`).
    static var actionLimit: Int {
        2
    }

    let systemImage: String
    let headline: LocalizedStringResource
    let sentence: LocalizedStringResource?
    let actions: [Action]

    init(
        systemImage: String,
        headline: LocalizedStringResource,
        sentence: LocalizedStringResource? = nil,
        actions: [Action] = []
    ) {
        assert(actions.count <= Self.actionLimit, "A sparse state offers at most two actions (REQ-GRAMMAR-004)")
        self.systemImage = systemImage
        self.headline = headline
        self.sentence = sentence
        self.actions = actions
    }
}

extension EmptyState {
    /// Draws `content`. The screen supplies each action's button; the first is the prominent one and a second
    /// stacks under it, bordered, so the single entrance always reads first.
    init<Action: Hashable, ActionButton: View>(
        _ content: EmptyStateContent<Action>,
        @ViewBuilder button: @escaping (Action) -> ActionButton
    ) where Actions == EmptyStateActions<Action, ActionButton> {
        self.init(
            Text(content.headline),
            systemImage: content.systemImage,
            message: content.sentence.map { Text($0) }
        ) {
            EmptyStateActions(actions: content.actions, button: button)
        }
    }
}

/// A sparse state's actions, stacked at every text size: two side by side would not fit an accessibility size.
struct EmptyStateActions<Action: Hashable, ActionButton: View>: View {
    let actions: [Action]
    let button: (Action) -> ActionButton

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(actions.enumerated()), id: \.element) { index, action in
                if index == 0, isEnabled {
                    // White on the pale dark-mode accent is unreadable; `contentOnAccent` stays legible in both.
                    button(action)
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(PitColor.contentOnAccent)
                } else if index == 0 {
                    // Disabled keeps the style's own dimmed label, since on-accent text would sit on its grey fill.
                    button(action).buttonStyle(.borderedProminent)
                } else {
                    button(action).buttonStyle(.bordered)
                }
            }
        }
        // The role, not `Color.accentColor`, which can resolve to the navy asset instead (ADR 0038).
        .tint(PitColor.accentPrimary)
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
