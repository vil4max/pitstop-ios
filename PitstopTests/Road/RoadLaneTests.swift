@testable import Pitstop
import SwiftUI
import Testing
import UIKit

private typealias Fix = MaintenanceFixture

/// Planned dates alone are enough to build a road: 40 and 50 days out share a slot, 120 days is its own.
private func plannedRoad(days: [Double]) -> RoadProjection {
    RoadProjector().project(RoadContext(
        now: Fix.date(0),
        maintenanceStates: [],
        plannedEvents: days.map { PlannedVehicleEvent(kind: .other, date: Fix.date($0)) }
    ))
}

private func resolved(_ color: Color, dark: Bool) -> UIColor {
    UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
}

@Suite("Road lane")
struct RoadLaneTests {
    @Test("REQ-ROAD-028: Back to now is absent while the car leads the lane and shown once it has left")
    func backToNowFollowsThePosition() throws {
        let road = plannedRoad(days: [40, 120])
        let slot = try #require(road.slots.last)

        #expect(!RoadBackToNow.isShown(scrollPosition: RoadLaneView.carID))
        #expect(RoadBackToNow.isShown(scrollPosition: slot.id))
    }

    @Test("REQ-ROAD-014: with Reduce Motion the lane returns to the car without animation")
    func reduceMotionReturnsWithoutAnimation() {
        #expect(RoadBackToNow.animation(reduceMotion: true) == nil)
        #expect(RoadBackToNow.animation(reduceMotion: false) != nil)
    }

    @Test("REQ-ROAD-029: posts stand on the road line and the car's wheels touch it, with plates capped")
    func carAndPostsShareTheRoadLine() {
        // Stated independently of the geometry: a 12 pt post under the plate, plates capped at 36 pt, and a
        // 56 pt car whose frame has the SUV placeholder's proportions, 960 × 334. A plate shorter than the car
        // lowers the plate, not the road.
        let carHeight: CGFloat = 56 * 334 / 960
        let cases: [(scaled: CGFloat, plate: CGFloat, roadY: CGFloat)] = [
            (5, 5, carHeight),
            (18, 18, 30),
            (26, 26, 38),
            (36, 36, 48),
            (90, 36, 48),
        ]
        for expected in cases {
            let lane = RoadLaneGeometry(plateSize: expected.scaled)
            #expect(lane.plateSize == expected.plate)
            #expect(abs(lane.roadY - expected.roadY) < 0.001)
            #expect(lane.plateTop >= 0 && lane.carTop >= 0)

            // What RoadSignView stacks: top padding, the plate, then the post. Its foot is on the road line.
            let postFoot = lane.plateTop + lane.plateSize + RoadLaneGeometry.postHeight
            #expect(abs(postFoot - expected.roadY) < 0.001)

            // What the car column draws: top padding, then CarVisual, whose wheels stand on its frame's bottom
            // edge (CarBoardCarPictureTests). Their bottom touches the 2 pt road line.
            let wheelBottom = lane.carTop + carHeight
            #expect(abs(wheelBottom - expected.roadY) <= DesignTokens.roadLineWidth / 2)
        }
    }

    @Test("REQ-ROAD-013: the lane draws one sign per slot, the lead with a count of the others there")
    func oneSignPerSlot() {
        let road = plannedRoad(days: [40, 50, 120])
        #expect(road.slots.map(\.milestones.count) == [2, 1])

        let signs = road.slots.compactMap(\.sign)
        #expect(signs.map(\.milestone) == road.slots.compactMap(\.lead))
        #expect(signs.map(\.alsoHere) == [1, 0])
    }

    @Test("REQ-ROAD-029: no sign or row colour is the danger colour, in light or dark")
    func noDangerColour() throws {
        let waiting = try #require(RoadProjector().project(RoadContext(
            now: Fix.date(200),
            maintenanceStates: Fix.states(
                [Fix.oil10k],
                [Fix.completion(.engineOilService, km: 50000)],
                currentKm: nil,
                day: 200
            )
        )).waitingForMileage.first)
        let placed = plannedRoad(days: [-3, 5, 40]).slots.flatMap(\.milestones)
        let states: [RoadMilestoneState] = [.upcoming, .approaching, .due, .overdue]
        let colours = states.map(\.color) + (placed + [waiting]).map(\.color)

        for dark in [false, true] {
            let danger = resolved(PitColor.statusDanger, dark: dark)
            #expect(colours.allSatisfy { !resolved($0, dark: dark).isEqual(danger) })
        }
    }

    @Test("REQ-DESIGN-001: a sign waiting for mileage is dashed and secondary, never the ahead accent")
    func waitingSignIsSecondary() throws {
        let waiting = try #require(RoadProjector().project(RoadContext(
            now: Fix.date(200),
            maintenanceStates: Fix.states(
                [Fix.oil10k],
                [Fix.completion(.engineOilService, km: 50000)],
                currentKm: nil,
                day: 200
            )
        )).waitingForMileage.first)

        #expect(waiting.glyph == .dashed)
        for dark in [false, true] {
            #expect(resolved(waiting.color, dark: dark).isEqual(resolved(PitColor.contentSecondary, dark: dark)))
        }
    }
}
