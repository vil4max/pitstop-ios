import Foundation
@testable import Pitstop
import Synchronization
import Testing

/// Set once from any task; read by the test.
private final class Flag: Sendable {
    private let state = Mutex(false)

    var isSet: Bool {
        state.withLock { $0 }
    }

    func set() {
        state.withLock { $0 = true }
    }

    /// Waits, bounded, for another task to set the flag: a cancelled racer reports asynchronously.
    func waitUntilSet() async throws {
        for _ in 0..<500 where !isSet {
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

/// The race between an interpreter and its deadline (ADR 0015): one side wins, the loser is cancelled, and a
/// capture already cancelled never starts interpreting.
@Suite("Interpretation deadline", .timeLimit(.minutes(1)))
struct InterpretationDeadlineTests {
    @Test("REQ-CAPTURE-005: a run inside an already-cancelled task throws CancellationError and never starts")
    func alreadyCancelledNeverStarts() async {
        let started = Flag()
        let deadline = InterpretationDeadline(limit: .seconds(3600))
        let task = Task {
            while !Task.isCancelled {
                await Task.yield()
            }
            return try await deadline.run {
                started.set()
                return 1
            }
        }
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(!started.isSet)
    }

    @Test("ADR-0015: an operation that finishes first wins, and the deadline's timer is cancelled")
    func operationWinsCancelsTimer() async throws {
        let timerCancelled = Flag()
        let deadline = InterpretationDeadline(limit: .seconds(3600)) { limit in
            do {
                try await Task.sleep(for: limit)
            } catch {
                timerCancelled.set()
                throw error
            }
        }

        let result = try await deadline.run { 42 }

        guard case .finished(42) = result else {
            Issue.record("expected the operation's value, got \(result)")
            return
        }
        try await timerCancelled.waitUntilSet()
        #expect(timerCancelled.isSet)
    }

    @Test("REQ-CAPTURE-007: a timer that fires first wins, and the hanging operation is cancelled")
    func timerWinsCancelsOperation() async throws {
        let operationCancelled = Flag()
        let deadline = InterpretationDeadline(limit: .seconds(1)) { _ in }

        let result = try await deadline.run { () async throws -> Int in
            do {
                try await Task.sleep(for: .seconds(3600))
            } catch {
                operationCancelled.set()
                throw error
            }
            return 1
        }

        guard case .timedOut = result else {
            Issue.record("expected the deadline to win, got \(result)")
            return
        }
        try await operationCancelled.waitUntilSet()
        #expect(operationCancelled.isSet)
    }
}
