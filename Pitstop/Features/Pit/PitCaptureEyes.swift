import Foundation
import Observation

/// What the capture sheet is doing, as far as Pit's eyes are concerned.
enum PitCaptureMoment: Equatable {
    /// The user is writing: Pit holds a fixed gaze.
    case listening
    /// Pit's own question waits above the composer.
    case asking
    /// The capture is being interpreted or saved.
    case working
    /// A confirmation or a clarification waits for the user.
    case proposing
    case saved

    init(_ phase: PitCapturePhase, isAsking: Bool) {
        switch phase {
        case .composing: self = isAsking ? .asking : .listening
        case .working: self = .working
        case .confirming, .clarifying: self = .proposing
        case .saved: self = .saved
        }
    }
}

/// The beats between two capture moments (ADR 0028). After the user's input the contract's candidate
/// transition is "fixed gaze → blink → side gaze → proposal"; after a save Pit glances at what it
/// saved, then closes its eyes ("completion").
enum PitCaptureChoreography {
    /// The shortest time side gaze stays, so a fast interpretation still reads as thinking.
    static let thinkingHold: TimeInterval = 0.6
    static let glanceHold: TimeInterval = 0.6

    static func beats(from old: PitCaptureMoment?, to new: PitCaptureMoment, reduceMotion: Bool) -> [PitBeat] {
        switch new {
        case .listening: return [PitBeat(.fixedGaze)]
        case .asking: return [PitBeat(.knock)]
        case .working, .proposing, .saved: break
        }
        // A save may arrive without a working phase ever being drawn; the thinking beat still comes first.
        var beats: [PitBeat] = []
        if old == nil || old == .listening || old == .asking {
            // With Reduce Motion the blink is dropped; the side gaze is a state, not wandering.
            if !reduceMotion {
                beats.append(PitBeat(.blink, hold: PitIdleAction.blinkHold))
            }
            beats.append(PitBeat(.sideGaze, hold: thinkingHold))
        } else if new == .working {
            beats.append(PitBeat(.sideGaze, hold: thinkingHold))
        }
        switch new {
        case .proposing:
            beats.append(PitBeat(.knock))
        case .saved:
            if !reduceMotion {
                beats.append(PitBeat(.glance, hold: glanceHold))
            }
            beats += [PitBeat(.closedEyes, hold: PitBeat.closedEyesHold), PitBeat(.resting)]
        case .listening, .asking, .working:
            break
        }
        return beats
    }
}

/// Plays Pit's eyes in the capture sheet: the transition beats between moments, the occasional blink
/// while listening, and bounded life after each state change. The view only renders `state` and `life`.
@MainActor
@Observable
final class PitCaptureEyes {
    private(set) var state: PitState = .fixedGaze
    private(set) var life: PitEyeLife = .still

    private let scheduler: PitIdleScheduler
    private let random: () -> Double
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    /// Seconds on a monotonic clock.
    private let now: () -> TimeInterval
    private let onShow: (PitState) -> Void
    private let onLife: (PitEyeLife) -> Void
    private var moment: PitCaptureMoment?
    private var reduceMotion = false
    /// What the sheet reports: editing the composer, scrolling. Capturing is implied.
    private var activity: PitActivity = []
    /// Beats not shown yet. Each beat keeps its hold even when the next moment arrives early.
    private var queue: [PitBeat] = []
    private var player: Task<Void, Never>?
    private var listening: Task<Void, Never>?
    private var living: Task<Void, Never>?
    /// When the last listening blink ended. Kept on the model, so restarting the loop for a new activity
    /// never shortens the cooldown.
    private var lastListeningAction: TimeInterval?

    init(
        scheduler: PitIdleScheduler = PitIdleScheduler(),
        random: @escaping () -> Double = { Double.random(in: 0 ..< 1) },
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(for: .seconds(seconds))
        },
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        onShow: @escaping (PitState) -> Void = { _ in },
        onLife: @escaping (PitEyeLife) -> Void = { _ in }
    ) {
        self.scheduler = scheduler
        self.random = random
        self.sleep = sleep
        self.now = now
        self.onShow = onShow
        self.onLife = onLife
    }

    /// The whole activity the listening blinks and life yield to.
    private var fullActivity: PitActivity {
        activity.union(.capturing).union(reduceMotion ? .reduceMotion : [])
    }

    /// What the sheet is doing. Editing or scrolling stops life at once (REQ-PIT-005); anything the listening mode
    /// does not accept, such as scrolling, also stops the listening blinks until it ends.
    func setActivity(_ activity: PitActivity) {
        guard activity != self.activity else { return }
        self.activity = activity
        if !activity.isDisjoint(with: [.editing, .scrolling]) {
            stopLife()
        }
        if moment == .listening {
            stopListening()
            startListening()
        }
    }

    func update(to new: PitCaptureMoment, reduceMotion: Bool) {
        let old = moment
        let changedMotion = reduceMotion != self.reduceMotion
        self.reduceMotion = reduceMotion
        guard new != old || changedMotion else { return }
        if changedMotion, reduceMotion {
            // Transient beats still queued are motion, not states (REQ-PIT-017).
            queue.removeAll { $0.state == .blink || $0.state == .glance }
            stopLife()
        }
        moment = new
        stopListening()
        let beats = PitCaptureChoreography.beats(from: old, to: new, reduceMotion: reduceMotion)
        if new == .listening || new == .asking {
            // The user is back at the composer: nothing still queued from the last capture matters.
            player?.cancel()
            player = nil
            queue = []
            if let beat = beats.last, beat.state != state || new != old {
                show(beat.state)
            }
            if new == .listening {
                startListening()
            }
            return
        }
        guard new != old else { return }
        queue += beats
        guard player == nil else { return }
        player = Task { [weak self] in
            await self?.play()
        }
    }

    func stop() {
        player?.cancel()
        player = nil
        queue = []
        stopListening()
        stopLife()
    }

    /// Waits until every queued beat has been shown; tests use it to read a finished sequence.
    func finishBeats() async {
        await player?.value
    }

    /// Waits until the current bounded life has ended; tests use it.
    func finishLife() async {
        await living?.value
    }

    private func play() async {
        while !Task.isCancelled, !queue.isEmpty {
            let beat = queue.removeFirst()
            show(beat.state)
            if beat.hold > 0 {
                try? await sleep(beat.hold)
            }
        }
        // A cancelled player was already replaced; clearing the reference would drop its successor.
        if !Task.isCancelled {
            player = nil
        }
    }

    private func show(_ state: PitState) {
        stopLife()
        self.state = state
        onShow(state)
        startLife()
    }

    /// A few jittered steps after a state change, then stillness until the next one (ADR 0028).
    private func startLife() {
        let steps = PitEyeLifePlan.steps(for: state, activity: fullActivity, random: random)
        guard !steps.isEmpty else { return }
        living = Task { [weak self] in
            for step in steps {
                guard let self else { return }
                try? await sleep(step.delay)
                guard !Task.isCancelled else { return }
                setLife(step.life)
            }
        }
    }

    private func stopLife() {
        living?.cancel()
        living = nil
        if life != .still {
            setLife(.still)
        }
    }

    private func setLife(_ life: PitEyeLife) {
        self.life = life
        onLife(life)
    }

    /// While listening Pit only blinks, and less than when idle (`PitIdleScheduler.Mode.listening`).
    private func startListening() {
        guard !reduceMotion else { return }
        listening = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let sinceLastAction = lastListeningAction.map { now() - $0 } ?? PitIdleScheduler.cooldown
                guard let plan = scheduler.nextPlan(
                    .listening,
                    activity: fullActivity,
                    sinceLastAction: sinceLastAction
                ) else {
                    // Still cooling down, busy, or a turn of stillness: wait and draw again.
                    let remaining = PitIdleScheduler.cooldown - sinceLastAction
                    try? await sleep(remaining > 0 ? remaining : PitIdleScheduler.cooldown)
                    continue
                }
                try? await sleep(plan.delay)
                for beat in plan.action.beats(returningTo: .fixedGaze) {
                    guard !Task.isCancelled, moment == .listening else { return }
                    show(beat.state)
                    if beat.hold > 0 {
                        try? await sleep(beat.hold)
                    }
                }
                lastListeningAction = now()
            }
        }
    }

    private func stopListening() {
        listening?.cancel()
        listening = nil
    }
}
