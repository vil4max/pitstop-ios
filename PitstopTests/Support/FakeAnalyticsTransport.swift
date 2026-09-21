import Foundation
@testable import Pitstop
import Synchronization

/// Answers each request with the next scripted reply (then with the fallback) and records every body.
final class FakeAnalyticsTransport: AnalyticsHTTPTransport {
    enum Reply: Sendable {
        case status(Int)
        case failure
    }

    private struct State {
        var replies: [Reply]
        var bodies: [Data] = []
        var urls: [URL] = []
    }

    private let state: Mutex<State>
    private let fallback: Reply
    private let continuation: AsyncStream<Data>.Continuation
    /// Every request body in the order it was posted, for tests that wait for a background flush.
    let requests: AsyncStream<Data>

    init(replies: [Reply] = [], fallback: Reply = .status(200)) {
        state = Mutex(State(replies: replies))
        self.fallback = fallback
        (requests, continuation) = AsyncStream.makeStream(of: Data.self)
    }

    var bodies: [Data] {
        state.withLock { $0.bodies }
    }

    var urls: [URL] {
        state.withLock { $0.urls }
    }

    func post(_ body: Data, to url: URL) async throws -> Int {
        let reply = state.withLock { state in
            state.bodies.append(body)
            state.urls.append(url)
            return state.replies.isEmpty ? fallback : state.replies.removeFirst()
        }
        continuation.yield(body)
        switch reply {
        case let .status(code): return code
        case .failure: throw URLError(.notConnectedToInternet)
        }
    }
}

/// Records every requested sleep and returns at once, so backoff is observable without waiting.
final class RecordingSleeper: Sendable {
    private let recorded = Mutex<[Duration]>([])

    var durations: [Duration] {
        recorded.withLock { $0 }
    }

    func sleep(_ duration: Duration) async throws {
        recorded.withLock { $0.append(duration) }
    }
}

/// A PostHog batch body decoded back into plain values.
struct DecodedBatch {
    let root: [String: Any]
    let events: [[String: Any]]

    init(_ data: Data) throws {
        let object = try JSONSerialization.jsonObject(with: data)
        root = object as? [String: Any] ?? [:]
        events = root["batch"] as? [[String: Any]] ?? []
    }

    var eventNames: [String] {
        events.compactMap { $0["event"] as? String }
    }

    var distinctIDs: Set<String> {
        Set(events.compactMap { $0["distinct_id"] as? String })
    }
}
