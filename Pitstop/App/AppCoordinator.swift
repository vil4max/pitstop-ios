import SwiftUI

@MainActor
@Observable
final class AppCoordinator {
    private let carBoard: CarBoardViewModel
    private let prepare: (@Sendable () async -> Void)?
    private let notes: NotesViewModel
    private let history: HistoryViewModel
    private let service: ServiceViewModel
    private let road: RoadViewModel
    private let pitCapture: PitCaptureViewModel
    private let pitQuestion: PitQuestionViewModel

    init(environment: AppEnvironment = .live()) {
        carBoard = CarBoardViewModel(store: environment.store, persistence: environment.persistence)
        prepare = environment.prepare
        notes = NotesViewModel(store: environment.store)
        history = HistoryViewModel(store: environment.store)
        service = ServiceViewModel(store: environment.store)
        road = RoadViewModel(store: environment.store)
        pitCapture = PitCaptureViewModel(pipeline: RememberPipeline(
            store: environment.store,
            interpreter: RuleBasedInterpreter(),
            observer: CaptureStageLogger()
        ))
        pitQuestion = PitQuestionViewModel(
            questions: environment.questions,
            store: environment.store,
            registry: environment.registry
        )
    }

    var rootView: some View {
        RootView(
            carBoard: carBoard,
            notes: notes,
            history: history,
            service: service,
            road: road,
            pitCapture: pitCapture,
            pitQuestion: pitQuestion,
            prepare: prepare
        )
    }
}
