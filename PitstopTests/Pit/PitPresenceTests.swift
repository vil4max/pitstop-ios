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
        #expect(scheduler([0.1]).nextPlan(activity: .idle, sinceLastAction: 600)?.state == .blink)
    }

    @Test("ADR-0012: every scheduled action is part of the semantic vocabulary and never a knock")
    func scheduledActionsAreIdleOnly() {
        let states = stride(from: 0.0, to: 1.0, by: 0.02).compactMap {
            scheduler([$0, 0.5]).nextPlan(activity: .idle, sinceLastAction: 60)?.state
        }
        #expect(!states.isEmpty)
        #expect(Set(states).isSubset(of: [.blink, .lookLeft, .lookRight, .lookUp]))
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

@Suite("Pit eye vocabulary")
struct PitEyeGeometryTests {
    @Test("ADR-0012: every semantic state is drawn differently from every other")
    func statesAreVisuallyDistinct() {
        let drawn = PitState.allCases.map { state in
            let geometry = PitEyeGeometry(state)
            return "\(geometry.height)|\(geometry.pupil.x),\(geometry.pupil.y)|\(geometry.showsPupil)|\(geometry.dimmed)|\(geometry.lift)"
        }
        #expect(Set(drawn).count == PitState.allCases.count)
    }

    @Test("ADR-0012: a closed eye shows no highlight outside the lid")
    func closedEyesHideThePupil() {
        for state in [PitState.blink, .closedEyes] {
            let geometry = PitEyeGeometry(state)
            #expect(!geometry.showsPupil)
            #expect(geometry.height < 4)
        }
        #expect(PitEyeGeometry(.resting).showsPupil)
    }
}

@MainActor
@Suite("Pit presence")
struct PitPresenceModelTests {
    @Test("REQ-PIT-005: becoming busy stops motion and returns Pit to rest")
    func busyStopsMotion() {
        let model = PitPresenceModel(scheduler: scheduler([0.0]), sleep: { _ in })
        model.show(.lookLeft)

        model.setInterface(.scrolling)

        #expect(model.state == .resting && model.activity == .scrolling)
    }

    @Test("REQ-PIT-017: a sheet that opens and closes does not clear Reduce Motion")
    func reduceMotionSurvivesASheet() {
        let model = PitPresenceModel(scheduler: scheduler([0.0]), sleep: { _ in })
        model.setReduceMotion(true)

        model.setInterface(.modalTask)
        model.setInterface([])

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

        model.setInterface(.modalTask)
        model.setInterface([])
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
        model.setInterface([])

        await model.askPermissionToInterrupt()
        for _ in 0 ..< 50 {
            await Task.yield()
        }

        #expect(model.state == .knock)
        #expect(model.activity == .askingQuestion)

        model.endQuestion()
        #expect(model.state == .resting && model.activity == .idle)
    }
}

@MainActor
private final class ShownStates {
    private(set) var states: [PitState] = []

    func append(_ state: PitState) {
        states.append(state)
    }
}
