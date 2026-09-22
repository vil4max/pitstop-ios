import SwiftUI

/// Empty state of a feature screen: the system empty-state layout, full width, below the screen header.
struct FeatureEmptyState<Description: View, Actions: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    /// Road's empty state sits flush in its content stack without the extra top inset; it passes 0.
    var topPadding: CGFloat = 24
    @ViewBuilder let description: Description
    @ViewBuilder let actions: Actions

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            description
        } actions: {
            actions
        }
        .frame(maxWidth: .infinity)
        .padding(.top, topPadding)
    }
}
