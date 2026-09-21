import Foundation
import Synchronization

/// How long the Remember pipeline waits for meaning before it keeps the wording instead (ADR 0015).
///
/// An interpreter that hangs is as unavailable as one that throws (REQ-CAPTURE-007). The race below
/// resumes the caller as soon as either side finishes and never awaits the loser, so an interpreter
/// that ignores cancellation cannot hold a capture hostage.
public struct InterpretationDeadline: Sendable {
    public enum Result<Value: Sendable>: Sendable {
        case finished(Value)
        case timedOut
    }

    /// The default is a hypothesis to revisit with on-device model latency (ADR 0015).
    public static let standard = InterpretationDeadline(limit: .seconds(6))

    public let limit: Duration
    private let sleep: @Sendable (Duration) async throws -> Void

    public init(
        limit: Duration,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.limit = limit
        self.sleep = sleep
    }

    /// Throws what `operation` throws, or `CancellationError` when the calling task is cancelled.
    public func run<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Result<Value> {
        let gate = RaceGate<Result<Value>>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard gate.install(continuation) else { return }
                gate.register(Task {
                    do {
                        let value = try await operation()
                        gate.finish(.success(.finished(value)))
                    } catch {
                        gate.finish(.failure(error))
                    }
                })
                gate.register(Task { [sleep, limit] in
                    // A cancelled timer means the operation already won; it must not resume anything.
                    guard await (try? sleep(limit)) != nil else { return }
                    gate.finish(.success(.timedOut))
                })
            }
        } onCancel: {
            gate.finish(.failure(CancellationError()))
        }
    }
}

/// Resumes one continuation exactly once and cancels every racer when it does.
private final class RaceGate<Value: Sendable>: Sendable {
    private enum Phase {
        case idle
        case waiting(CheckedContinuation<Value, any Error>)
        /// Finished before the continuation existed: only cancellation can do that.
        case finishedEarly(Swift.Result<Value, any Error>)
        case finished
    }

    /// One lock for both, so a racer registered while the race ends is still cancelled.
    private struct State {
        var phase = Phase.idle
        var racers: [Task<Void, Never>] = []
    }

    private let state = Mutex(State())

    /// Returns false when the race is already over, so no racer should start.
    func install(_ continuation: CheckedContinuation<Value, any Error>) -> Bool {
        let early: Swift.Result<Value, any Error>? = state.withLock { state in
            guard case let .finishedEarly(result) = state.phase else {
                state.phase = .waiting(continuation)
                return nil
            }
            state.phase = .finished
            return result
        }
        guard let early else { return true }
        continuation.resume(with: early)
        return false
    }

    func register(_ racer: Task<Void, Never>) {
        let isOver = state.withLock { state in
            if case .finished = state.phase {
                return true
            }
            state.racers.append(racer)
            return false
        }
        if isOver {
            racer.cancel()
        }
    }

    func finish(_ result: Swift.Result<Value, any Error>) {
        let (continuation, racers): (CheckedContinuation<Value, any Error>?, [Task<Void, Never>]) =
            state.withLock { state in
                switch state.phase {
                case let .waiting(continuation):
                    state.phase = .finished
                    defer { state.racers = [] }
                    return (continuation, state.racers)
                case .idle:
                    state.phase = .finishedEarly(result)
                    return (nil, [])
                case .finishedEarly, .finished:
                    return (nil, [])
                }
            }
        continuation?.resume(with: result)
        for racer in racers {
            racer.cancel()
        }
    }
}
