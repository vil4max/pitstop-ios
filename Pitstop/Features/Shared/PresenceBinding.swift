import SwiftUI

extension Binding where Value == Bool {
    /// An alert's or dialog's presentation for something the view model holds, such as a failure or a candidate.
    /// The presentation's own dismissal clears it through `onDismiss`; only the view model ever raises one, so
    /// setting `true` does nothing.
    @MainActor
    static func presence(
        _ isShown: @escaping @MainActor @Sendable () -> Bool,
        onDismiss: @escaping @MainActor @Sendable () -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { isShown() },
            set: { isPresented in
                if !isPresented {
                    onDismiss()
                }
            }
        )
    }
}
