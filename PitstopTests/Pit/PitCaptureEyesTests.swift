import Foundation
@testable import Pitstop
import Testing

@Suite("Pit capture choreography")
struct PitCaptureChoreographyTests {
    private func states(_ old: PitCaptureMoment?, _ new: PitCaptureMoment, reduceMotion: Bool = false) -> [PitState] {
        PitCaptureChoreography.beats(from: old, to: new, reduceMotion: reduceMotion).map(\.state)
    }

    @Test("ADR-0028: after input Pit blinks, then thinks with a side gaze")
    func inputBlinksThenThinks() {
        #expect(states(.listening, .working) == [.blink, .sideGaze])
        #expect(states(.asking, .working) == [.blink, .sideGaze])
        #expect(states(.working, .proposing) == [.knock])
    }

    @Test("ADR-0028: a save that skips the working phase still thinks first, then glances and closes the eyes")
    func directSaveKeepsTheTransition() {
        #expect(states(.listening, .saved) == [.blink, .sideGaze, .glance, .closedEyes, .resting])
        #expect(states(.proposing, .saved) == [.glance, .closedEyes, .resting])
        #expect(states(.proposing, .working) == [.sideGaze])
    }

    @Test("REQ-PIT-017: with Reduce Motion the transient blink and glance are dropped; the states remain")
    func reduceMotionKeepsOnlyStates() {
        #expect(states(.listening, .working, reduceMotion: true) == [.sideGaze])
        #expect(states(.working, .saved, reduceMotion: true) == [.closedEyes, .resting])
        #expect(states(.working, .proposing, reduceMotion: true) == [.knock])
    }

    @Test("ADR-0028: the thinking beat holds long enough to be seen before a fast proposal")
    func thinkingHolds() {
        let beats = PitCaptureChoreography.beats(from: .listening, to: .proposing, reduceMotion: false)
        #expect(beats.first { $0.state == .sideGaze }?.hold == PitCaptureChoreography.thinkingHold)
        #expect(beats.last == PitBeat(.knock))
    }

    @Test("ADR-0028: capture phases map to what Pit's eyes do")
    func phasesMapToMoments() {
        #expect(PitCaptureMoment(.composing, isAsking: false) == .listening)
        #expect(PitCaptureMoment(.composing, isAsking: true) == .asking)
        #expect(PitCaptureMoment(.working, isAsking: false) == .working)
        #expect(PitCaptureMoment(.saved(.notes, preservedRaw: true), isAsking: false) == .saved)
    }
}

@MainActor
@Suite("Pit capture eyes")
struct PitCaptureEyesTests {
    private func eyes(
        _ shown: CaptureShownStates,
        draw: Double = 0.99,
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) -> PitCaptureEyes {
        PitCaptureEyes(
            scheduler: PitIdleScheduler { draw },
            random: { 0.5 },
            sleep: { _ in await Task.yield() },
            now: now,
            onShow: shown.append,
            onLife: shown.appendLife
        )
    }

    private func settle() async {
        for _ in 0 ..< 60 {
            await Task.yield()
        }
    }

    @Test("ADR-0028: the capture flow shows fixed gaze → blink → side gaze → proposal")
    func captureFlowEmitsTheTransition() async {
        let shown = CaptureShownStates()
        let model = eyes(shown)

        model.update(to: .listening, reduceMotion: false)
        model.update(to: .working, reduceMotion: false)
        model.update(to: .proposing, reduceMotion: false)
        await model.finishBeats()
        model.stop()

        #expect(shown.states == [.fixedGaze, .blink, .sideGaze, .knock])
        #expect(model.state == .knock)
    }

    @Test("ADR-0028: a saved capture ends with closed eyes, then rest")
    func saveClosesTheEyes() async {
        let shown = CaptureShownStates()
        let model = eyes(shown)

        model.update(to: .listening, reduceMotion: false)
        model.update(to: .working, reduceMotion: false)
        model.update(to: .saved, reduceMotion: false)
        await model.finishBeats()
        model.stop()

        #expect(shown.states == [.fixedGaze, .blink, .sideGaze, .glance, .closedEyes, .resting])
    }

    @Test("REQ-PIT-017: with Reduce Motion the flow is state changes only, and listening never blinks")
    func reduceMotionFlow() async {
        let shown = CaptureShownStates()
        let model = eyes(shown, draw: 0.0)

        model.update(to: .listening, reduceMotion: true)
        await settle()
        model.update(to: .working, reduceMotion: true)
        model.update(to: .saved, reduceMotion: true)
        await model.finishBeats()
        model.stop()

        #expect(shown.states == [.fixedGaze, .sideGaze, .closedEyes, .resting])
    }

    @Test("ADR-0028: while listening Pit blinks now and then and holds its fixed gaze in between")
    func listeningBlinks() async {
        let shown = CaptureShownStates()
        let model = eyes(shown, draw: 0.0)

        model.update(to: .listening, reduceMotion: false)
        await settle()
        model.stop()

        #expect(shown.states.contains(.blink))
        #expect(Set(shown.states).isSubset(of: [.fixedGaze, .blink]))
    }

    @Test("ADR-0028: returning to the composer drops what was still queued from the last capture")
    func composerFlushesTheQueue() async {
        let shown = CaptureShownStates()
        let model = eyes(shown)

        model.update(to: .listening, reduceMotion: false)
        model.update(to: .saved, reduceMotion: false)
        model.update(to: .listening, reduceMotion: false)
        await settle()
        model.stop()

        #expect(model.state == .fixedGaze)
        #expect(!shown.states.contains(.closedEyes))
    }

    @Test("REQ-PIT-004: life after a state change ends still and stays still")
    func lifeEndsStill() async {
        let shown = CaptureShownStates()
        let model = eyes(shown)

        model.update(to: .listening, reduceMotion: false)
        await model.finishLife()

        #expect(!shown.lives.isEmpty)
        #expect(model.life == .still && shown.lives.last == .still)
        shown.clearLives()
        await settle()
        #expect(shown.lives.isEmpty)
        model.stop()
    }

    @Test("REQ-PIT-005: while the user types, no life is played and running life stops at once")
    func editingStopsLife() async {
        let shown = CaptureShownStates()
        let model = eyes(shown)

        model.update(to: .listening, reduceMotion: false)
        await Task.yield()
        model.setActivity(.editing)
        #expect(model.life == .still)
        shown.clearLives()
        model.update(to: .working, reduceMotion: false)
        await model.finishBeats()
        await settle()
        model.stop()

        #expect(shown.lives.allSatisfy { $0 == .still })
    }

    @Test("ADR-0028: scrolling the sheet stops the listening blinks")
    func scrollingStopsListeningBlinks() async {
        let shown = CaptureShownStates()
        let model = eyes(shown, draw: 0.0)

        model.setActivity(.scrolling)
        model.update(to: .listening, reduceMotion: false)
        await settle()
        model.stop()

        #expect(shown.states == [.fixedGaze])
    }

    @Test("REQ-PIT-017: turning on Reduce Motion mid-sequence drops the queued blink and glance")
    func reduceMotionMidSequence() async {
        let shown = CaptureShownStates()
        let model = eyes(shown)

        model.update(to: .listening, reduceMotion: false)
        model.update(to: .saved, reduceMotion: false)
        model.update(to: .saved, reduceMotion: true)
        await model.finishBeats()
        model.stop()

        #expect(shown.states == [.fixedGaze, .sideGaze, .closedEyes, .resting])
    }

    @Test("ADR-0028: restarting the listening loop for a new activity keeps the blink cooldown")
    func restartKeepsTheCooldown() async {
        let shown = CaptureShownStates()
        // The clock never moves, so after one blink the cooldown can never pass.
        let model = eyes(shown, draw: 0.0, now: { 100 })

        model.update(to: .listening, reduceMotion: false)
        await settle()
        #expect(shown.states.filter { $0 == .blink }.count == 1)

        model.setActivity(.scrolling)
        model.setActivity([])
        await settle()
        model.stop()

        #expect(shown.states.filter { $0 == .blink }.count == 1)
    }

    @Test("REQ-PIT-005: scrolling the sheet stops a running life burst at once")
    func scrollingStopsLife() async {
        let shown = CaptureShownStates()
        let model = eyes(shown)

        model.update(to: .listening, reduceMotion: false)
        await Task.yield()
        await Task.yield()
        model.setActivity(.scrolling)
        #expect(model.life == .still)
        shown.clearLives()
        model.update(to: .working, reduceMotion: false)
        await model.finishBeats()
        await settle()
        model.stop()

        #expect(shown.lives.allSatisfy { $0 == .still })
    }
}

@MainActor
private final class CaptureShownStates {
    private(set) var states: [PitState] = []
    private(set) var lives: [PitEyeLife] = []

    func append(_ state: PitState) {
        states.append(state)
    }

    func appendLife(_ life: PitEyeLife) {
        lives.append(life)
    }

    func clearLives() {
        lives = []
    }
}
