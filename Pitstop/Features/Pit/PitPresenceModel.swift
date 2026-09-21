import Foundation
import Observation

/// Drives Pit's semantic motion. It owns no product data and decides nothing about capture: it only
/// says what Pit is doing, and stops entirely when the interface is busy or motion is reduced.
@MainActor
@Observable
final class PitPresenceModel {
    private(set) var state: PitState = .resting

    /// Reduce Motion and what the interface is doing are tracked apart, because a sheet that opens
    /// and closes must not clear the accessibility setting underneath it.
    private var accessibility: PitActivity = []
    private var interface: PitActivity = []
    /// Kept apart from `interface` too: opening and closing a sheet must not cancel a pending question.
    private var isAsking = false

    var activity: PitActivity {
        accessibility.union(interface).union(isAsking ? .askingQuestion : [])
    }

    private let scheduler: PitIdleScheduler
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    /// Sees every state as it is shown, so a sequence such as startle-then-knock is observable.
    private let onShow: (PitState) -> Void
    private var loop: Task<Void, Never>?

    init(
        scheduler: PitIdleScheduler = PitIdleScheduler(),
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(for: .seconds(seconds))
        },
        onShow: @escaping (PitState) -> Void = { _ in }
    ) {
        self.scheduler = scheduler
        self.sleep = sleep
        self.onShow = onShow
    }

    func setReduceMotion(_ isEnabled: Bool) {
        accessibility = isEnabled ? .reduceMotion : []
        refresh()
    }

    /// What the interface is doing right now. Replaces the previous interface state, never the
    /// accessibility one.
    func setInterface(_ activity: PitActivity) {
        interface = activity
        refresh()
    }

    /// Pit reacts before it explains: a startle, then the knock that asks for permission. Idle motion
    /// stops first, so nothing can erase the request until `endQuestion()`.
    func askPermissionToInterrupt() async {
        isAsking = true
        refresh()
        guard !activity.contains(.reduceMotion) else {
            show(.knock)
            return
        }
        show(.startle)
        try? await sleep(0.35)
        show(.knock)
    }

    /// The question was answered, deferred, or dismissed: Pit goes back to waiting.
    func endQuestion() {
        isAsking = false
        show(.resting)
        refresh()
    }

    func show(_ state: PitState) {
        self.state = state
        onShow(state)
    }

    func stop() {
        loop?.cancel()
        loop = nil
        // A pending question outlives the view: Pit keeps knocking until `endQuestion()`.
        state = isAsking ? .knock : .resting
    }

    private func refresh() {
        guard activity == .idle else {
            // Yielding means stopping, not pausing mid-blink (REQ-PIT-005). A knock keeps its state.
            loop?.cancel()
            loop = nil
            if state != .knock, state != .startle {
                state = .resting
            }
            return
        }
        guard loop == nil else { return }
        startIdleLoop()
    }

    private func startIdleLoop() {
        loop = Task { [weak self] in
            // Elapsed time as this loop accounts for it. After an action the counter restarts, so the
            // next turn is a full cooldown of stillness and only then a drawn delay (ADR 0012).
            var sinceLastAction = PitIdleScheduler.cooldown
            while !Task.isCancelled {
                guard let self else { return }
                guard let plan = scheduler.nextPlan(activity: activity, sinceLastAction: sinceLastAction) else {
                    // Stillness is a normal outcome; wait out the cooldown and draw again.
                    try? await sleep(PitIdleScheduler.cooldown)
                    sinceLastAction += PitIdleScheduler.cooldown
                    continue
                }
                try? await sleep(plan.delay)
                sinceLastAction += plan.delay
                // The interface may have become busy during the wait.
                guard !Task.isCancelled, activity == .idle else { continue }
                show(plan.state)
                try? await sleep(0.28)
                guard !Task.isCancelled, activity == .idle else { return }
                show(.resting)
                sinceLastAction = 0
            }
        }
    }
}
