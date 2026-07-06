import SwiftUI

@MainActor
@Observable
final class AppCoordinator {
    private(set) var carContext: ProvisionalCarContext

    init(carContext: ProvisionalCarContext = .firstLaunch) {
        self.carContext = carContext
    }

    var rootView: some View {
        CarBoardView(carContext: carContext)
    }
}
