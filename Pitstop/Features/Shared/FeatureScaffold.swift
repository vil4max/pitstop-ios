import SwiftUI

/// Detail screens share the header grammar, padding, and the clearance for the utility layer.
struct FeatureScaffold<Content: View>: View {
    let carName: String
    let title: String
    @ViewBuilder let content: Content

    /// Road, Notes, History and Service show the car's avatar before the eyebrow (REQ-BOARD-034).
    @Environment(\.carAvatar) private var carAvatar

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                ScreenHeader(eyebrow: carName, title: title, avatar: carAvatar)
                content
            }
            .padding(.horizontal, DesignTokens.screenPadding)
            .padding(.bottom, DesignTokens.tileSpacing)
        }
        .pitReportsScrolling()
        .background(PitColor.surfacePrimary)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
    #Preview("Feature scaffold") {
        PreviewMatrix {
            FeatureScaffold(carName: "Kestrel", title: "Service") {
                Text(verbatim: "Engine oil service")
                    .font(PitTypography.body)
                    .foregroundStyle(PitColor.contentPrimary)
            }
            .frame(height: 220)
            .environment(\.carAvatar, CarAvatarSource(body: .suv, photo: nil))
        }
    }
#endif
