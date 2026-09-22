import AppIntents
import SwiftUI

@main
struct PitstopApp: App {
    @State private var coordinator: AppCoordinator
    private let captureRequests: CaptureSurfaceRequests
    private let serviceRequests: ServiceLinkRequests

    /// One environment per process: the UI and `RememberInPitStopIntent` share one store, so a save
    /// from Siri is the same data Pit sees. The system may run an intent right after launch, so the
    /// handler is registered here, before any scene exists.
    init() {
        let log = AppLog.logger(category: "app.lifecycle")
        log.info("PitStop launched")
        let environment = AppEnvironment.live()
        let captureRequests = CaptureSurfaceRequests()
        let serviceRequests = ServiceLinkRequests()
        self.captureRequests = captureRequests
        self.serviceRequests = serviceRequests
        _coordinator = State(initialValue: AppCoordinator(
            environment: environment,
            captureRequests: captureRequests,
            serviceRequests: serviceRequests
        ))
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
                // The widgets' `pitstop://pit` and `pitstop://service` links (ADR 0025, ADR 0036). Handled at the
                // scene root, which exists from launch, while `RootView` may still be preparing; the request
                // waits until `RootView` takes it.
                .onOpenURL { url in
                    if !AppLinkRouter.route(url, capture: captureRequests, service: serviceRequests) {
                        AppLog.logger(category: "app.url").info("Ignored an unsupported URL")
                    }
                }
        }
    }
}
