import SwiftUI

@MainActor
@Observable
final class AppCoordinator {
    private let carBoard: CarBoardViewModel
    private let notes: NotesViewModel
    private let history: HistoryViewModel

    init(environment: AppEnvironment = .live()) {
        carBoard = CarBoardViewModel(store: environment.store, persistence: environment.persistence)
        notes = NotesViewModel(store: environment.store)
        history = HistoryViewModel(store: environment.store)
    }

    var rootView: some View {
        RootView(carBoard: carBoard, notes: notes, history: history)
    }
}
