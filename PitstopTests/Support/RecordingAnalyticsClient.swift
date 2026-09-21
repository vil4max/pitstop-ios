import Foundation
@testable import Pitstop
import Synchronization

/// Records every encoded event it receives, in order (ADR 0002 "RecordingAnalytics").
final class RecordingAnalyticsClient: AnalyticsClient {
    private let recorded = Mutex<[AnalyticsEvent]>([])

    var events: [AnalyticsEvent] {
        recorded.withLock { $0 }
    }

    var names: [AnalyticsEventName] {
        events.map(\.name)
    }

    func send(_ event: AnalyticsEvent) {
        recorded.withLock { $0.append(event) }
    }

    func last(_ name: AnalyticsEventName) -> [AnalyticsProperty: String]? {
        events.last { $0.name == name }?.properties.mapValues(\.encoded)
    }
}

/// A clock the test moves by hand.
final class ManualClock: Sendable {
    private let current = Mutex(ContinuousClock.now)

    var now: ContinuousClock.Instant {
        current.withLock { $0 }
    }

    func advance(by duration: Duration) {
        current.withLock { $0 += duration }
    }
}
