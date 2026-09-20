import SwiftUI

/// Hosts navigation and the utility layer. The layer sits outside the navigation stack, so
/// Settings and Pit keep one position on Car Board and on every detail screen (REQ-UTILITY-003, 005).
struct RootView: View {
    let carBoard: CarBoardViewModel

    @State private var path: [CarBoardRoute] = []
    @State private var sheet: UtilitySheet?

    private enum UtilitySheet: String, Identifiable {
        case settings
        case pit

        var id: String {
            rawValue
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            CarBoardView(viewModel: carBoard)
                .navigationDestination(for: CarBoardRoute.self) { route in
                    destination(for: route)
                }
        }
        .tint(PitColor.accentPrimary)
        // A safe-area inset, not an overlay: scroll content is inset by the layer's height, so the
        // last tile always scrolls clear of the controls (REQ-UTILITY-008).
        .safeAreaInset(edge: .bottom, spacing: 0) {
            UtilityLayer(onSettings: { sheet = .settings }, onPit: { sheet = .pit })
        }
        // Text input lives in sheets, which cover the layer; it never rides up over a keyboard.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .settings: SettingsView(isStorageTemporary: carBoard.state.isStorageTemporary)
            case .pit: PitPendingView()
            }
        }
    }

    @ViewBuilder
    private func destination(for route: CarBoardRoute) -> some View {
        switch route {
        case let .tile(kind):
            FeatureScaffold(carName: carBoard.state.car.name, title: title(for: kind)) {
                PendingSurfaceView(kind: kind)
            }
        }
    }

    private func title(for kind: CarBoardTileKind) -> String {
        switch kind {
        case .road: String(localized: "tile.road.title")
        case .notes: String(localized: "tile.notes.title")
        case .service: String(localized: "tile.service.title")
        case .history: String(localized: "tile.history.title")
        }
    }
}
