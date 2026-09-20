import SwiftUI

/// Static Pit Eyes mark. Pit is identified without animation (bottom-utility-layer.md);
/// motion arrives with CAP-003 / DISC-004.
struct PitEyesGlyph: View {
    var body: some View {
        HStack(spacing: 5) {
            eye
            eye
        }
        .accessibilityHidden(true)
    }

    private var eye: some View {
        Capsule()
            .fill(PitColor.contentPrimary)
            .frame(width: 9, height: 15)
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(PitColor.surfaceSecondary)
                    .frame(width: 3.5, height: 3.5)
                    .padding(2)
            }
    }
}
