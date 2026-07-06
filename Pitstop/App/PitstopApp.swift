import SwiftUI

@main
struct PitstopApp: App {
    @State private var coordinator = AppCoordinator()

    init() {
        let log = AppLog.logger(category: "app.lifecycle")
        log.info("PitStop launched")
    }

    var body: some Scene {
        WindowGroup {
            coordinator.rootView
        }
    }
}
