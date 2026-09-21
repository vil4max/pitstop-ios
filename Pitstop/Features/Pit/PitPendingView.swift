import SwiftUI

/// Pit is reachable from every screen now; its capture surface lands with CAP-003 / CAP-004.
struct PitPendingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label {
                    Text("pit.pending.title")
                } icon: {
                    PitEyesGlyph(state: .fixedGaze).scaleEffect(2.2).padding(.bottom, 12)
                }
            } description: {
                Text("pit.pending.detail")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
