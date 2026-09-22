import SwiftUI

/// Detail screens share the header grammar, padding, and the clearance for the utility layer.
struct FeatureScaffold<Content: View>: View {
    let carName: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                ScreenHeader(eyebrow: carName, title: title)
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
