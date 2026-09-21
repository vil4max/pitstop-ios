import AppIntents
import SwiftUI

@main
struct PitstopApp: App {
    @State private var coordinator: AppCoordinator
    private let captureRequests: CaptureSurfaceRequests

    /// One environment per process: the UI and `RememberInPitStopIntent` share one store, so a save
    /// from Siri is the same data Pit sees. The system may run an intent right after launch, so the
    /// handler is registered here, before any scene exists.
    init() {
        let log = AppLog.logger(category: "app.lifecycle")
        log.info("PitStop launched")
        let environment = AppEnvironment.live()
        let captureRequests = CaptureSurfaceRequests()
        self.captureRequests = captureRequests
        _coordinator = State(initialValue: AppCoordinator(environment: environment, captureRequests: captureRequests))
        let handler = RememberIntentHandler(
            pipeline: AppCoordinator.interpretedPipeline(environment),
            persistence: environment.persistence,
            analytics: environment.analyticsSharing.pipeline
        )
        AppDependencyManager.shared.add(dependency: handler)
        AppDependencyManager.shared.add(dependency: captureRequests)
    }

    var body: some Scene {
        WindowGroup {
            coordinator.rootView
                // The widget's `pitstop://pit` link (ADR 0025). Handled at the scene root, which exists from
                // launch, while `RootView` may still be preparing; the request waits until `RootView` takes it.
                .onOpenURL { url in
                    if !captureRequests.request(opening: url) {
                        AppLog.logger(category: "app.url").info("Ignored an unsupported URL")
                    }
                }
        }
    }
}
