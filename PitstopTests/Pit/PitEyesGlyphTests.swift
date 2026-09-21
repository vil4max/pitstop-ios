import CoreGraphics
@testable import Pitstop
import Testing

@Suite("Pit eye vocabulary")
struct PitEyeGeometryTests {
    @Test("ADR-0012: every semantic state is drawn differently from every other")
    func statesAreVisuallyDistinct() {
        let drawn = Set(PitState.allCases.map(PitEyeGeometry.init))
        #expect(drawn.count == PitState.allCases.count)
    }

    @Test("ADR-0012: a closed eye shows no highlight outside the lid")
    func closedEyesHideThePupil() {
        for state in [PitState.blink, .closedEyes] {
            let geometry = PitEyeGeometry(state)
            #expect(!geometry.showsHighlight)
            #expect(geometry.openness == 0)
        }
        #expect(PitEyeGeometry(.resting).showsHighlight)
    }

    @Test("ADR-0028: a closing eye keeps a visible lid line and stays inside its box when open")
    func eyeShapeStaysDrawable() {
        let box = CGRect(x: 0, y: 0, width: 9, height: 15)
        let closed = PitEyeShape(openness: 0).path(in: box).boundingRect
        #expect(closed.height >= 1 && closed.height < 3)
        let open = PitEyeShape(openness: 1).path(in: box).boundingRect
        #expect(open.minY >= -0.01 && open.maxY <= 15.01)
        #expect(PitEyeShape(openness: 1.15).path(in: box).boundingRect.height > open.height)
    }

    /// A random source that walks through fixed values, so a plan is reproducible.
    private func draws(_ values: [Double]) -> () -> Double {
        var index = 0
        return {
            defer { index += 1 }
            return values[index % values.count]
        }
    }

    @Test("REQ-PIT-004: life after a state change is bounded, irregular, and ends still")
    func lifeIsBoundedAndIrregular() {
        for state in [PitState.fixedGaze, .sideGaze, .resting] {
            let steps = PitEyeLifePlan.steps(for: state, activity: .capturing, random: draws([0.1, 0.9, 0.4, 0.7, 0.2]))
            #expect(steps.count >= 2)
            #expect(steps.last?.life.gaze == .zero && steps.last?.life.breath == 1)
            let moving = steps.dropLast().map(\.delay)
            #expect(moving.reduce(0, +) <= PitEyeLifePlan.window)
            #expect(Set(steps.map(\.delay)).count > 1)
            #expect(steps.allSatisfy {
                $0.delay >= PitEyeLifePlan.minimumInterval && $0.delay <= PitEyeLifePlan.maximumInterval
            })
        }
    }

    @Test("REQ-PIT-005, REQ-PIT-017: no life while editing or scrolling, with Reduce Motion, or in other states")
    func lifeYields() {
        let random = draws([0.5])
        #expect(PitEyeLifePlan.steps(for: .fixedGaze, activity: [.capturing, .editing], random: random).isEmpty)
        #expect(PitEyeLifePlan.steps(for: .fixedGaze, activity: [.capturing, .scrolling], random: random).isEmpty)
        #expect(PitEyeLifePlan.steps(for: .sideGaze, activity: .reduceMotion, random: random).isEmpty)
        for state in [PitState.blink, .knock, .closedEyes, .lookLeft, .startle, .glance] {
            #expect(PitEyeLifePlan.steps(for: state, activity: [], random: random).isEmpty)
        }
    }

    @Test("ADR-0028: listening makes small jumps, thinking drifts, resting only breathes")
    func lifeKinds() {
        let random = draws([0.1, 0.95, 0.3, 0.8])
        let saccades = PitEyeLifePlan.steps(for: .fixedGaze, activity: [], random: random).dropLast()
        #expect(saccades
            .allSatisfy { $0.life.kind == .saccade && abs($0.life.gaze.x) <= 0.1 && abs($0.life.gaze.y) <= 0.08 })
        #expect(saccades.contains { $0.life.gaze != .zero })
        #expect(PitEyeLifePlan.steps(for: .sideGaze, activity: [], random: random)
            .allSatisfy { $0.life.kind == .drift })
        let breaths = PitEyeLifePlan.steps(for: .resting, activity: [], random: random)
        #expect(breaths.allSatisfy { $0.life.gaze == .zero })
        #expect(breaths.contains { $0.life.breath > 1 })
    }
}
