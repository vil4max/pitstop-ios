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
        .background(PitColor.surfacePrimary)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Honest destination for a surface whose owning task has not landed yet.
struct PendingSurfaceView: View {
    let kind: CarBoardTileKind

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "hourglass")
        } description: {
            Text("surface.pending.detail")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var title: LocalizedStringKey {
        switch kind {
        case .road: "tile.road.empty.headline"
        case .notes: "tile.notes.empty.headline"
        case .service: "tile.service.empty.headline"
        case .history: "tile.history.empty.headline"
        }
    }
}
