import SwiftUI

/// How a surface tells Pit what the user is doing without holding Pit itself (ADR 0019). The root view
/// injects one that forwards to its `PitPresenceModel`; outside it, reports go nowhere.
///
/// Equal by the model it forwards to, not a closure: the root view re-renders on every blink, and a new
/// closure each time would invalidate every reporting view in the app.
struct PitActivityReporter: Equatable, Sendable {
    private weak var pit: PitPresenceModel?

    static let none = PitActivityReporter(pit: nil)

    static func forwarding(to pit: PitPresenceModel) -> PitActivityReporter {
        PitActivityReporter(pit: pit)
    }

    @MainActor
    func callAsFunction(_ activity: PitActivity, from source: PitActivitySource) {
        pit?.report(activity, from: source)
    }

    static func == (lhs: PitActivityReporter, rhs: PitActivityReporter) -> Bool {
        lhs.pit === rhs.pit
    }
}

extension EnvironmentValues {
    @Entry var pitActivityReporter: PitActivityReporter = .none
}

extension View {
    /// Reports `activity` while `isActive` holds, and withdraws it when the view goes away, so a sheet
    /// closed by a swipe or a screen popped mid-scroll never leaves Pit stuck at rest.
    func pitActivity(_ activity: PitActivity, while isActive: Bool) -> some View {
        modifier(PitActivityReport(activity: activity, isActive: isActive))
    }

    /// Apply to the scroll view itself: the scroll phase belongs to the first scroll view in the hierarchy.
    func pitReportsScrolling() -> some View {
        modifier(PitScrollReport())
    }

    /// For a text field without focus handling of its own. A view that already binds focus reports with
    /// `pitActivity(.editing, while:)` instead, because two focus bindings on one field would compete.
    func pitReportsEditing() -> some View {
        modifier(PitEditingReport())
    }
}

private struct PitActivityReport: ViewModifier {
    let activity: PitActivity
    let isActive: Bool

    @Environment(\.pitActivityReporter) private var reporter
    @State private var source = PitActivitySource.unique()

    func body(content: Content) -> some View {
        content
            // `onAppear` as well as `onChange`: a screen that comes back from a pushed one reports again.
            .onAppear { reporter(isActive ? activity : [], from: source) }
            .onChange(of: isActive) { _, isActive in reporter(isActive ? activity : [], from: source) }
            .onDisappear { reporter([], from: source) }
    }
}

private struct PitScrollReport: ViewModifier {
    @State private var isScrolling = false

    func body(content: Content) -> some View {
        content
            // Any movement counts, not only fast scrolling: a moving list is not idle UI (REQ-PIT-006).
            .onScrollPhaseChange { _, phase in isScrolling = phase.isScrolling }
            // A screen left mid-scroll gets no final phase change; it must not report scrolling on return.
            .onDisappear { isScrolling = false }
            .pitActivity(.scrolling, while: isScrolling)
    }
}

private struct PitEditingReport: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .pitActivity(.editing, while: isFocused)
    }
}
