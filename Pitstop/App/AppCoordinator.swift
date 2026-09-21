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
    private let analyticsSharing: AnalyticsSharing

    init(environment: AppEnvironment = .live()) {
        let client = environment.analytics
        analyticsSharing = environment.analyticsSharing
        let notesAnalytics = AnalyticsTracker<NotesAnalyticsEvent>(client: client)
        let odometerAnalytics = AnalyticsTracker<OdometerAnalyticsEvent>(client: client)
        func captureObserver(_ interpreter: InterpreterVersion) -> any CaptureStageObserving {
            CaptureStageObservers([
                CaptureStageLogger(),
                CaptureAnalyticsObserver(
                    capture: AnalyticsTracker<CaptureAnalyticsEvent>(client: client),
                    notes: notesAnalytics,
                    odometer: odometerAnalytics,
                    interpreter: interpreter
                ),
            ])
        }
        carBoard = CarBoardViewModel(
            store: environment.store,
            persistence: environment.persistence,
            analytics: odometerAnalytics
        )
        prepare = environment.prepare
        notes = NotesViewModel(
            store: environment.store,
            analytics: notesAnalytics,
            captureObserver: captureObserver(.noInterpreter)
        )
        history = HistoryViewModel(store: environment.store)
        service = ServiceViewModel(store: environment.store)
        road = RoadViewModel(store: environment.store)
        pitCapture = PitCaptureViewModel(pipeline: RememberPipeline(
            store: environment.store,
            interpreter: RuleBasedInterpreter(),
            observer: captureObserver(.ruleBasedV1)
        ))
        pitQuestion = PitQuestionViewModel(
            questions: environment.questions,
            store: environment.store,
            registry: environment.registry,
            analytics: odometerAnalytics
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
            analyticsSharing: analyticsSharing,
            prepare: prepare
        )
    }
}
