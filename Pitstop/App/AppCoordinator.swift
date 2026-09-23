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
    private let pitEntry: PitCaptureEntry
    private let analyticsSharing: AnalyticsSharing
    private let captureRequests: CaptureSurfaceRequests
    private let serviceRequests: ServiceLinkRequests

    init(
        environment: AppEnvironment = .live(),
        captureRequests: CaptureSurfaceRequests = CaptureSurfaceRequests(),
        serviceRequests: ServiceLinkRequests = ServiceLinkRequests()
    ) {
        self.captureRequests = captureRequests
        self.serviceRequests = serviceRequests
        let client = environment.analytics
        analyticsSharing = environment.analyticsSharing
        let notesAnalytics = AnalyticsTracker<NotesAnalyticsEvent>(client: client)
        let odometerAnalytics = AnalyticsTracker<OdometerAnalyticsEvent>(client: client)
        carBoard = CarBoardViewModel(
            store: environment.store,
            persistence: environment.persistence,
            analytics: odometerAnalytics
        )
        prepare = environment.prepare
        notes = NotesViewModel(
            store: environment.store,
            analytics: notesAnalytics,
            captureObserver: Self.captureObserver(client: client, interpreter: .noInterpreter),
            locale: environment.locale
        )
        history = HistoryViewModel(store: environment.store)
        service = ServiceViewModel(store: environment.store)
        road = RoadViewModel(store: environment.store)
        pitCapture = PitCaptureViewModel(pipeline: Self.interpretedPipeline(environment), locale: environment.locale)
        pitQuestion = PitQuestionViewModel(
            questions: environment.questions,
            store: environment.store,
            registry: environment.registry,
            analytics: odometerAnalytics
        )
        pitEntry = PitCaptureEntry(capture: pitCapture, question: pitQuestion)
    }

    /// The one interpreted capture path, shared by Pit and `RememberInPitStopIntent` (core C4).
    static func interpretedPipeline(_ environment: AppEnvironment) -> RememberPipeline {
        RememberPipeline(
            store: environment.store,
            interpreter: environment.interpretation.interpreter,
            observer: captureObserver(client: environment.analytics, interpreter: environment.interpretation.version)
        )
    }

    private static func captureObserver(
        client: any AnalyticsClient,
        interpreter: InterpreterVersion
    ) -> any CaptureStageObserving {
        CaptureStageObservers([
            CaptureStageLogger(),
            CaptureAnalyticsObserver(
                capture: AnalyticsTracker<CaptureAnalyticsEvent>(client: client),
                notes: AnalyticsTracker<NotesAnalyticsEvent>(client: client),
                odometer: AnalyticsTracker<OdometerAnalyticsEvent>(client: client),
                interpreter: interpreter
            ),
        ])
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
            pitEntry: pitEntry,
            analyticsSharing: analyticsSharing,
            captureRequests: captureRequests,
            serviceRequests: serviceRequests,
            prepare: prepare
        )
    }
}
