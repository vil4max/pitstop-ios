import Foundation
@testable import Pitstop
import Testing

@MainActor
@Suite("Pit leaving")
struct PitLeavingTests {
    @Test("ADR-0028: an earlier leave waking late never opens the eyes of a later leave")
    func staleLeaveDoesNotCutALaterOneShort() async {
        let shown = LeaveShownStates()
        let gate = SleepGate()
        let model = PitPresenceModel(
            scheduler: PitIdleScheduler { 0.99 },
            sleep: { _ in await gate.wait() },
            onShow: shown.append
        )

        let first = Task { await model.leave() }
        await gate.waitForSleepers(1)
        let second = Task { await model.leave() }
        await gate.waitForSleepers(2)

        gate.resume(0)
        await first.value
        #expect(model.state == .closedEyes)

        gate.resume(1)
        await second.value
        #expect(shown.states == [.closedEyes, .closedEyes, .resting])
    }
}

@MainActor
private final class LeaveShownStates {
    private(set) var states: [PitState] = []

    func append(_ state: PitState) {
        states.append(state)
    }
}

/// Holds each sleep until the test resumes it.
@MainActor
private final class SleepGate {
    private var sleepers: [CheckedContinuation<Void, Never>?] = []

    nonisolated func wait() async {
        await park()
    }

    private func park() async {
        await withCheckedContinuation { sleepers.append($0) }
    }

    func waitForSleepers(_ count: Int) async {
        while sleepers.count < count {
            await Task.yield()
        }
    }

    func resume(_ index: Int) {
        sleepers[index]?.resume()
        sleepers[index] = nil
    }
}
