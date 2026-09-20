import SwiftUI

@MainActor
@Observable
final class AppCoordinator {
    private let carBoard: CarBoardViewModel

    init(environment: AppEnvironment = .live()) {
        carBoard = CarBoardViewModel(store: environment.store, persistence: environment.persistence)
    }

    var rootView: some View {
        CarBoardView(viewModel: carBoard)
    }
}
