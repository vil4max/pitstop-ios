import Foundation
@testable import Pitstop
import Testing

/// A scheduler whose draws are fixed, so a schedule is reproducible.
private func scheduler(_ draws: [Double]) -> PitIdleScheduler {
    let box = DrawBox(draws)
    return PitIdleScheduler { box.next() }
}

private final class DrawBox: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Double]
    private var index = 0

    init(_ values: [Double]) {
        self.values = values
    }

    func next() -> Double {
        lock.withLock {
            defer { index += 1 }
            return values[index % values.count]
        }
    }
}

@Suite("Pit idle motion")
struct PitIdleSchedulerTests {
    @Test(
        "REQ-PIT-005: idle motion stops for every activity the model is told about",
        arguments: [PitActivity.scrolling, .editing, .capturing, .modalTask, .reduceMotion, .recentlyDismissed]
    )
    func activityStopsIdleMotion(activity: PitActivity) {
        let plan = scheduler([0.0]).nextPlan(activity: activity, sinceLastAction: 600)
        #expect(plan == nil)
    }

    @Test("REQ-PIT-004: an action never follows another before the cooldown has passed")
    func cooldownIsRespected() {
        let idle = scheduler([0.0])
        #expect(idle.nextPlan(activity: .idle, sinceLastAction: PitIdleScheduler.cooldown - 0.1) == nil)
        #expect(idle.nextPlan(activity: .idle, sinceLastAction: PitIdleScheduler.cooldown) != nil)
    }

    @Test("REQ-PIT-004: the delay is irregular, not a fixed interval")
    func delaysAreIrregular() {
        let delays = (0 ..< 4).map { index in
            scheduler([0.0, Double(index) / 4]).nextPlan(activity: .idle, sinceLastAction: 60)?.delay
        }
        #expect(Set(delays).count == delays.count)
        for delay in delays.compactMap(\.self) {
            #expect(delay >= PitIdleScheduler.minimumDelay && delay <= PitIdleScheduler.maximumDelay)
        }
    }

    @Test("REQ-PIT-004: a high draw is stillness, so a session can pass with no visible motion")
    func stillnessIsANormalOutcome() {
        #expect(scheduler([0.99]).nextPlan(activity: .idle, sinceLastAction: 600) == nil)
        #expect(scheduler([0.1]).nextPlan(activity: .idle, sinceLastAction: 600)?.action == .blink)
    }

    @Test("ADR-0012: every scheduled action is part of the semantic vocabulary and never a knock")
    func scheduledActionsAreIdleOnly() {
        let actions = stride(from: 0.0, to: 1.0, by: 0.01).compactMap {
            scheduler([$0, 0.5]).nextPlan(activity: .idle, sinceLastAction: 60)?.action
        }
        #expect(Set(actions) == Set(PitIdleAction.allCases))
        let states = Set(PitIdleAction.allCases.flatMap { $0.beats(returningTo: .resting).map(\.state) })
        #expect(states.isSubset(of: [.blink, .lookLeft, .lookRight, .lookUp, .resting]))
    }

    @Test("ADR-0028: a double blink is a rare variation of the baseline blink, drawn as two blinks")
    func doubleBlinkIsRare() {
        let counts = drawCounts(.idle)
        #expect(counts[.doubleBlink, default: 0] > 0)
        #expect(counts[.doubleBlink, default: 0] * 5 < counts[.blink, default: 0])
        #expect(PitIdleAction.doubleBlink.beats(returningTo: .resting).map(\.state) == [
            .blink,
            .resting,
            .blink,
            .resting,
        ])
    }

    @Test("ADR-0028: while listening Pit only blinks, and blinks less than when idle")
    func listeningBlinksLess() {
        let listening = drawCounts(.listening)
        let idle = drawCounts(.idle)
        #expect(Set(listening.keys) == [.blink])
        #expect(listening[.blink, default: 0] < idle[.blink, default: 0])
        let delays = stride(from: 0.0, to: 1.0, by: 0.1).compactMap {
            scheduler([0.0, $0]).nextPlan(.listening, activity: .capturing, sinceLastAction: 60)?.delay
        }
        #expect(delays.allSatisfy { $0 >= PitIdleScheduler.minimumDelay })
        #expect(delays.max() ?? 0 > PitIdleScheduler.maximumDelay)
    }

    @Test("ADR-0028: listening is the capture activity itself, but Reduce Motion and other activity still stop it")
    func listeningYieldsToEverythingElse() {
        let draws = scheduler([0.0])
        #expect(draws.nextPlan(.listening, activity: [.capturing, .editing], sinceLastAction: 60) != nil)
        #expect(draws.nextPlan(.idle, activity: .capturing, sinceLastAction: 60) == nil)
        for activity in [PitActivity.reduceMotion, .scrolling, .modalTask, .recentlyDismissed] {
            #expect(draws.nextPlan(.listening, activity: activity.union(.capturing), sinceLastAction: 60) == nil)
        }
    }

    /// How often each action is drawn over an even grid of 1,000 draws.
    private func drawCounts(_ mode: PitIdleScheduler.Mode) -> [PitIdleAction: Int] {
        var counts: [PitIdleAction: Int] = [:]
        for roll in stride(from: 0.0, to: 1.0, by: 0.001) {
            let activity: PitActivity = mode == .listening ? .capturing : .idle
            if let action = scheduler([roll, 0.5]).nextPlan(mode, activity: activity, sinceLastAction: 60)?.action {
                counts[action, default: 0] += 1
            }
        }
        return counts
    }
}

@Suite("Pit attention policy")
struct PitAttentionPolicyTests {
    private let policy = PitAttentionPolicy()
    private let never = TimeInterval.greatestFiniteMagnitude

    private func question(
        _ id: String,
        priority: Int = 1,
        context: VisibleFeature = .carBoard,
        unlocks: PitValueUnlock? = .serviceStatus,
        resolution: PitQuestion.Resolution = .unresolved
    ) -> PitQuestion {
        PitQuestion(id: id, priority: priority, context: context, unlocks: unlocks, resolution: resolution)
    }

    @Test("REQ-PIT-006: Pit does not interrupt while the user is doing something")
    func busyUiIsNotInterrupted() {
        let asked = policy.question(
            from: [question("oilInterval")],
            activity: .editing,
            context: .carBoard,
            sinceLastInterruption: never,
            sinceLastDismissal: never
        )
        #expect(asked == nil)
    }

    @Test("REQ-PIT-007: a question is asked only where it is relevant")
    func contextMustMatch() {
        let questions = [question("oilInterval", context: .service)]
        #expect(policy.question(
            from: questions,
            activity: .idle,
            context: .notes,
            sinceLastInterruption: never,
            sinceLastDismissal: never
        ) == nil)
        #expect(policy.question(
            from: questions,
            activity: .idle,
            context: .service,
            sinceLastInterruption: never,
            sinceLastDismissal: never
        ) != nil)
    }

    @Test(
        "REQ-PIT-008: an answered, deferred, or dismissed question is not asked again",
        arguments: [PitQuestion.Resolution.answered, .deferred, .dismissed]
    )
    func resolvedQuestionsAreNotRepeated(resolution: PitQuestion.Resolution) {
        let asked = policy.question(
            from: [question("oilInterval", resolution: resolution)],
            activity: .idle,
            context: .carBoard,
            sinceLastInterruption: never,
            sinceLastDismissal: never
        )
        #expect(asked == nil)
    }

    @Test("core C3: one interruption at a time, and a dismissal silences Pit for longer than an answer")
    func cooldownsAreRespected() {
        let questions = [question("oilInterval")]
        #expect(policy.question(
            from: questions,
            activity: .idle,
            context: .carBoard,
            sinceLastInterruption: 60,
            sinceLastDismissal: never
        ) == nil)
        #expect(policy.question(
            from: questions,
            activity: .idle,
            context: .carBoard,
            sinceLastInterruption: never,
            sinceLastDismissal: 60
        ) == nil)
        #expect(PitAttentionPolicy.dismissalCooldown > PitAttentionPolicy.interruptionCooldown)
    }

    @Test("REQ-PIT-009: a question that unlocks nothing declared is never asked")
    func valueUnlockIsRequired() {
        let asked = policy.question(
            from: [question("idle curiosity", unlocks: nil)],
            activity: .idle,
            context: .carBoard,
            sinceLastInterruption: never,
            sinceLastDismissal: never
        )
        #expect(asked == nil)
    }

    @Test("REQ-PIT-003: exactly one question is offered, the most valuable one")
    func onlyOneQuestionIsOffered() {
        let questions = [question("low", priority: 1), question("high", priority: 9), question("mid", priority: 5)]
        let asked = policy.question(
            from: questions,
            activity: .idle,
            context: .carBoard,
            sinceLastInterruption: never,
            sinceLastDismissal: never
        )
        #expect(asked?.id == "high")
    }
}

@MainActor
@Suite("Pit presence")
struct PitPresenceModelTests {
    @Test("REQ-PIT-005: becoming busy stops motion and returns Pit to rest")
    func busyStopsMotion() {
        let model = PitPresenceModel(scheduler: scheduler([0.0]), sleep: { _ in })
        model.show(.lookLeft)

        model.report(.scrolling, from: .unique())

        #expect(model.state == .resting && model.activity == .scrolling)
    }

    @Test("REQ-PIT-017: a sheet that opens and closes does not clear Reduce Motion")
    func reduceMotionSurvivesASheet() {
        let model = PitPresenceModel(scheduler: scheduler([0.0]), sleep: { _ in })
        model.setReduceMotion(true)

        model.report(.modalTask, from: .utilitySheet)
        model.report([], from: .utilitySheet)

        #expect(model.activity == .reduceMotion)
    }

    @Test("REQ-PIT-018: with Reduce Motion, asking permission is the knock alone")
    func reduceMotionSkipsTheStartle() async {
        let shown = ShownStates()
        let model = PitPresenceModel(scheduler: scheduler([0.0]), sleep: { _ in }, onShow: shown.append)
        model.setReduceMotion(true)

        await model.askPermissionToInterrupt()

        #expect(shown.states == [.knock])
    }

    @Test("ADR-0012: with motion allowed, Pit reacts before it asks")
    func startlePrecedesTheKnock() async {
        let shown = ShownStates()
        let model = PitPresenceModel(scheduler: scheduler([0.0]), sleep: { _ in }, onShow: shown.append)

        await model.askPermissionToInterrupt()

        #expect(shown.states == [.startle, .knock])
        #expect(model.state == .knock)
    }

    @Test("ADR-0012: a sheet opening and closing does not cancel a pending question")
    func sheetDoesNotCancelTheQuestion() async {
        let model = PitPresenceModel(scheduler: scheduler([0.0]), sleep: { _ in })
        await model.askPermissionToInterrupt()

        model.report(.modalTask, from: .utilitySheet)
        model.report([], from: .utilitySheet)
        for _ in 0 ..< 50 {
            await Task.yield()
        }

        #expect(model.state == .knock)
        #expect(model.activity == .askingQuestion)
    }

    @Test("ADR-0012: idle motion cannot erase a question that is waiting for an answer")
    func idleMotionDoesNotEraseTheKnock() async {
        // Sleeps return immediately, so the idle loop runs as fast as it can while the knock stands.
        let model = PitPresenceModel(scheduler: scheduler([0.0]), sleep: { _ in })
        model.report([], from: .utilitySheet)

        await model.askPermissionToInterrupt()
        for _ in 0 ..< 50 {
            await Task.yield()
        }

        #expect(model.state == .knock)
        #expect(model.activity == .askingQuestion)

        model.endQuestion()
        #expect(model.state == .resting && model.activity == .idle)
    }

    @Test("ADR-0028: leaving the sheet closes Pit's eyes for a moment, then Pit rests")
    func leavingClosesTheEyes() async {
        let shown = ShownStates()
        let model = PitPresenceModel(scheduler: scheduler([0.99]), sleep: { _ in }, onShow: shown.append)

        await model.leave()

        #expect(shown.states == [.closedEyes, .resting])
    }

    @Test("ADR-0028: leaving never erases a knock that waits for an answer")
    func leavingKeepsTheKnock() async {
        let shown = ShownStates()
        let model = PitPresenceModel(scheduler: scheduler([0.99]), sleep: { _ in }, onShow: shown.append)
        await model.askPermissionToInterrupt()

        await model.leave()

        #expect(shown.states == [.startle, .knock])
        #expect(model.state == .knock)
    }

    @Test("ADR-0028: the idle loop plays a double blink as two blinks and returns to rest")
    func idleLoopPlaysADoubleBlink() async {
        let shown = ShownStates()
        // 0.43 falls in the double-blink band of the idle weights.
        let model = PitPresenceModel(
            scheduler: scheduler([0.43]),
            sleep: { _ in await Task.yield() },
            onShow: shown.append
        )

        model.report([], from: .utilitySheet)
        for _ in 0 ..< 40 {
            await Task.yield()
        }
        model.stop()

        #expect(Array(shown.states.prefix(4)) == [.blink, .resting, .blink, .resting])
    }
}

@MainActor
private final class ShownStates {
    private(set) var states: [PitState] = []

    func append(_ state: PitState) {
        states.append(state)
    }
}
