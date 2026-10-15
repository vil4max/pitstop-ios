import SwiftUI

extension View {
    /// A confirmation dialog for the candidate a view model holds. The dialog shows while `candidate` is set;
    /// its own dismissal calls `cancel`. The last candidate stays latched, so the title, actions and message
    /// stay readable while the dialog animates out after the view model has cleared it.
    func latchedConfirmation<Candidate: Equatable, Actions: View, Message: View>(
        candidate: Candidate?,
        title: @escaping (Candidate?) -> Text,
        cancel: @escaping @MainActor @Sendable () -> Void,
        @ViewBuilder actions: @escaping (Candidate) -> Actions,
        @ViewBuilder message: @escaping (Candidate) -> Message
    ) -> some View {
        modifier(
            LatchedConfirmation(candidate: candidate, title: title, cancel: cancel, actions: actions, message: message)
        )
    }
}

private struct LatchedConfirmation<Candidate: Equatable, Actions: View, Message: View>: ViewModifier {
    let candidate: Candidate?
    let title: (Candidate?) -> Text
    let cancel: @MainActor @Sendable () -> Void
    let actions: (Candidate) -> Actions
    let message: (Candidate) -> Message

    @State private var presented: Candidate?

    func body(content: Content) -> some View {
        let shown = candidate ?? presented
        let isShown = candidate != nil
        content.confirmationDialog(
            title(shown),
            isPresented: .presence {
                isShown
            } onDismiss: {
                cancel()
            },
            titleVisibility: .visible,
            presenting: shown,
            actions: actions,
            message: message
        )
        .onChange(of: candidate) { _, candidate in
            if let candidate {
                presented = candidate
            }
        }
    }
}
