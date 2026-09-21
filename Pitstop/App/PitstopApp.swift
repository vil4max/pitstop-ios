import AppIntents
import SwiftUI

@main
struct PitstopApp: App {
    @State private var coordinator: AppCoordinator

    /// One environment per process: the UI and `RememberInPitStopIntent` share one store, so a save
    /// from Siri is the same data Pit sees. The system may run an intent right after launch, so the
    /// handler is registered here, before any scene exists.
    init() {
        let log = AppLog.logger(category: "app.lifecycle")
        log.info("PitStop launched")
        let environment = AppEnvironment.live()
        _coordinator = State(initialValue: AppCoordinator(environment: environment))
        let handler = RememberIntentHandler(
            pipeline: AppCoordinator.interpretedPipeline(environment),
            persistence: environment.persistence,
            analytics: environment.analyticsSharing.pipeline
        )
        AppDependencyManager.shared.add(dependency: handler)
    }

    var body: some Scene {
        WindowGroup {
            coordinator.rootView
        }
    }
}
