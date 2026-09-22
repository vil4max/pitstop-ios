import SwiftUI

/// Inline notice that a screen could not load, with a retry that reloads it in place.
struct LoadFailureBanner: View {
    let message: LocalizedStringKey
    let retry: @MainActor () async -> Void

    var body: some View {
        HStack {
            Label(message, systemImage: "exclamationmark.arrow.circlepath")
                .font(.footnote)
                .foregroundStyle(PitColor.contentSecondary)
            Spacer()
            Button("carBoard.load.retry") {
                Task { await retry() }
            }
            .font(.footnote.weight(.semibold))
        }
    }
}
