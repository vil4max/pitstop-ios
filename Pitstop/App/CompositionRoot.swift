import Foundation

struct CompositionRoot {
    @MainActor
    func makeCoordinator() -> AppCoordinator {
        AppCoordinator()
    }
}
