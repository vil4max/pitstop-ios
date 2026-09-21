import Foundation
@testable import Pitstop

final class StageSpy: CaptureStageObserving, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [CaptureStageEvent] = []

    var events: [CaptureStageEvent] {
        lock.withLock { recorded }
    }

    func record(_ event: CaptureStageEvent) {
        lock.withLock { recorded.append(event) }
    }
}
