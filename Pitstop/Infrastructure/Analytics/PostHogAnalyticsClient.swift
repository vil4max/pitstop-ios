import Foundation
import os
import Synchronization

/// The PostHog adapter over plain HTTP, without the SDK (ANL-001, ADR 0022).
///
/// `send` only appends to an in-memory queue under a lock and returns; requests run in detached tasks.
/// Nothing is written to disk: events that could not be delivered are lost when the process ends.
/// Every failure is logged and absorbed, so no analytics error ever reaches a caller.
final class PostHogAnalyticsClient: AnalyticsClient, AnalyticsPipelineControlling {
    struct Policy: Sendable {
        var batchSize = 20
        /// When full, the oldest event is dropped for the newest.
        var capacity = 200
        /// `nil` sends only when a batch is full or on an explicit flush.
        var flushInterval: Duration? = .seconds(30)
        var maxAttempts = 3
        var initialBackoff: Duration = .seconds(2)
        var maxBackoff: Duration = .seconds(60)

        /// Doubles after every failed attempt: 2 s, 4 s, 8 s … up to `maxBackoff`.
        func backoff(afterAttempt attempt: Int) -> Duration {
            let factor = 1 << min(max(attempt - 1, 0), 16)
            return min(initialBackoff * factor, maxBackoff)
        }
    }

    private struct Buffer {
        var events: [PostHogPendingEvent] = []
        var isFlushing = false
        var isTimerScheduled = false
        /// Set after a flush gave up; until then a full batch waits for the timer instead of flushing at once.
        var retryAfter: Date?
    }

    private enum Outcome {
        case delivered
        /// PostHog refused the batch; sending it again would not help.
        case rejected(status: Int)
        case transient
    }

    private let configuration: PostHogConfiguration
    private let transport: any AnalyticsHTTPTransport
    private let identity: any AnalyticsIdentityReading
    private let policy: Policy
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (Duration) async throws -> Void
    private let buffer = Mutex(Buffer())

    private static let logger = AppLog.logger(category: "analytics")

    init(
        configuration: PostHogConfiguration,
        transport: any AnalyticsHTTPTransport,
        identity: any AnalyticsIdentityReading,
        policy: Policy = Policy(),
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.configuration = configuration
        self.transport = transport
        self.identity = identity
        self.policy = policy
        self.now = now
        self.sleep = sleep
    }

    var pendingCount: Int {
        buffer.withLock { $0.events.count }
    }

    var retryAfter: Date? {
        buffer.withLock { $0.retryAfter }
    }

    func send(_ event: AnalyticsEvent) {
        guard let distinctID = identity.anonymousID else { return }
        let date = now()
        let pending = PostHogPendingEvent(event: event, distinctID: distinctID, timestamp: date)
        let policy = policy
        let (isFull, startsTimer) = buffer.withLock { buffer in
            buffer.events.append(pending)
            buffer.events.removeFirst(max(buffer.events.count - policy.capacity, 0))
            let isWaiting = buffer.retryAfter.map { date < $0 } ?? false
            let isFull = buffer.events.count >= policy.batchSize && !isWaiting
            let startsTimer = !isFull && !buffer.isTimerScheduled && policy.flushInterval != nil
            if startsTimer {
                buffer.isTimerScheduled = true
            }
            return (isFull, startsTimer)
        }
        if isFull {
            Task.detached(priority: .utility) { await self.flush() }
        } else if startsTimer, let interval = policy.flushInterval {
            Task.detached(priority: .utility) {
                try? await self.sleep(interval)
                self.buffer.withLock { $0.isTimerScheduled = false }
                await self.flush()
            }
        }
    }

    /// Sends every queued batch. A batch that still fails after its retries goes back to the queue for the
    /// next flush; a second concurrent call returns at once, because the running flush drains the queue.
    /// Explicit flushes (interval, background) ignore `retryAfter`; only size-triggered ones wait for it.
    func flush() async {
        let starts = buffer.withLock { buffer in
            guard !buffer.isFlushing else { return false }
            buffer.isFlushing = true
            return true
        }
        guard starts else { return }
        var gaveUp = false
        while let batch = takeBatch() {
            guard await deliver(batch) else {
                requeue(batch)
                gaveUp = true
                break
            }
        }
        let retryAfter = gaveUp ? now().addingTimeInterval(TimeInterval(policy.maxBackoff.components.seconds)) : nil
        buffer.withLock { buffer in
            buffer.isFlushing = false
            buffer.retryAfter = retryAfter
        }
    }

    func discardPending() {
        buffer.withLock { $0.events.removeAll() }
    }

    private func takeBatch() -> [PostHogPendingEvent]? {
        let current = identity.anonymousID
        return buffer.withLock { buffer in
            // An event queued under an earlier identity belongs to a withdrawn consent: never send it.
            buffer.events.removeAll { $0.distinctID != current }
            guard !buffer.events.isEmpty else { return nil }
            let count = min(policy.batchSize, buffer.events.count)
            let batch = Array(buffer.events.prefix(count))
            buffer.events.removeFirst(count)
            return batch
        }
    }

    private func requeue(_ batch: [PostHogPendingEvent]) {
        let current = identity.anonymousID
        let policy = policy
        buffer.withLock { buffer in
            buffer.events.insert(contentsOf: batch.filter { $0.distinctID == current }, at: 0)
            buffer.events.removeFirst(max(buffer.events.count - policy.capacity, 0))
        }
    }

    /// `true` when the batch is finished with (delivered, refused, or no longer consented); `false` keeps it.
    private func deliver(_ batch: [PostHogPendingEvent]) async -> Bool {
        let body: Data
        do {
            body = try PostHogPayload.batch(batch, apiKey: configuration.projectAPIKey)
        } catch {
            Self.logger.error("Analytics batch not encodable; dropped \(batch.count) events")
            return true
        }
        for attempt in 1 ... policy.maxAttempts {
            // Consent may have been withdrawn during a backoff.
            guard identity.anonymousID == batch.first?.distinctID else { return true }
            switch await post(body) {
            case .delivered:
                return true
            case let .rejected(status):
                Self.logger.error("Analytics batch rejected with status \(status); dropped \(batch.count) events")
                return true
            case .transient:
                guard attempt < policy.maxAttempts else { break }
                do {
                    try await sleep(policy.backoff(afterAttempt: attempt))
                } catch {
                    return false
                }
            }
        }
        Self.logger.info("Analytics batch not delivered; kept \(batch.count) events in memory")
        return false
    }

    private func post(_ body: Data) async -> Outcome {
        do {
            let status = try await transport.post(body, to: configuration.batchURL)
            switch status {
            case 200 ..< 300: return .delivered
            case 0, 408, 429, 500 ... 599: return .transient
            default: return .rejected(status: status)
            }
        } catch {
            return .transient
        }
    }
}
