import SwiftUI

/// A labelled floating glass control, such as Road's "Back to now". Glass is reserved for what floats
/// (REQ-DESIGN-002).
struct GlassPill: View {
    let title: Text
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label { title } icon: { Image(systemName: systemImage) }
                .font(PitTypography.supportingSmall.weight(.semibold))
                .foregroundStyle(PitColor.accentPrimary)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .pitGlass(in: .capsule)
                // The pill looks 34 pt tall; the target keeps the 44 pt minimum (REQ-GRAMMAR-003).
                .padding(.vertical, 5)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
    #Preview("Glass pill") {
        PreviewMatrix {
            GlassPill(title: Text(verbatim: "Back to now"), systemImage: "arrow.uturn.backward", action: {})
        }
    }
#endif
