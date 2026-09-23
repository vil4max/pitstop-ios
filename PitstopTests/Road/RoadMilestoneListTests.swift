@testable import Pitstop
import Testing

private typealias Fix = MaintenanceFixture

/// Two planned dates 10 days apart share a slot, one far date has its own, and engine oil with stale mileage
/// waits for mileage.
private func mixedRoad() -> RoadProjection {
    RoadProjector().project(RoadContext(
        now: Fix.date(200),
        maintenanceStates: Fix.states(
            [Fix.oil10k],
            [Fix.completion(.engineOilService, km: 50000)],
            currentKm: nil,
            day: 200
        ),
        plannedEvents: [
            PlannedVehicleEvent(kind: .other, date: Fix.date(320), label: "Winter tyres"),
            PlannedVehicleEvent(kind: .insuranceExpiry, date: Fix.date(240)),
            PlannedVehicleEvent(kind: .plannedVisit, date: Fix.date(250)),
        ]
    ))
}

@Suite("Road milestone list")
struct RoadMilestoneListTests {
    @Test("REQ-ROAD-027: the list shows the lane's milestones in lane order, clustered ones included")
    func listMirrorsTheLane() {
        let road = mixedRoad()
        #expect(road.slots.map(\.milestones.count) == [2, 1])

        let list = RoadMilestoneList(road)

        #expect(list.ahead == road.slots.flatMap(\.milestones))
        #expect(list.ahead.map(\.plannedLabel) == [nil, nil, "Winter tyres"])
        // Every sign on the lane leads its own run of rows, in the lane's order.
        let leads = road.slots.compactMap(\.sign?.milestone)
        #expect(leads.compactMap { list.ahead.firstIndex(of: $0) } == [0, 2])
    }

    @Test("REQ-ROAD-027: milestones waiting for mileage form the second group, after the lane's")
    func waitingIsTheSecondGroup() throws {
        let road = mixedRoad()
        let list = RoadMilestoneList(road)

        #expect(list.waiting == road.waitingForMileage)
        let waiting = try #require(list.waiting.first)
        #expect(waiting.subject == .maintenance(.engineOilService))
        #expect(!list.ahead.contains(waiting))
    }

    @Test("REQ-ROAD-004: the list adds, removes and repeats nothing the projection did not return")
    func listAddsNothing() {
        let road = mixedRoad()
        let list = RoadMilestoneList(road)
        let returned = road.slots.flatMap(\.milestones) + road.waitingForMileage
        let shown = list.ahead + list.waiting

        #expect(shown.count == returned.count)
        #expect(Set(shown.map(\.id)) == Set(returned.map(\.id)))
        #expect(Set(shown.map(\.id)).count == shown.count)
    }

    @Test("REQ-ROAD-009: an empty road lists nothing")
    func emptyRoadListsNothing() {
        let list = RoadMilestoneList(RoadProjector().project(RoadContext(now: Fix.date(0), maintenanceStates: [])))
        #expect(list.ahead.isEmpty && list.waiting.isEmpty)
    }
}
