import Foundation
@testable import Pitstop
import Testing

private typealias Fix = MaintenanceFixture

private func project(
    _ policies: [MaintenancePolicy],
    _ done: [MaintenanceCompletion],
    currentKm: Double?,
    day: Double,
    planned: [PlannedVehicleEvent] = [],
    history: HistoryTimeline = .empty
) -> RoadProjection {
    RoadProjector().project(RoadContext(
        now: Fix.date(day),
        maintenanceStates: Fix.states(policies, done, currentKm: currentKm, day: day),
        plannedEvents: planned,
        history: history
    ))
}

private func subjects(_ slots: some Sequence<RoadSlot>) -> [[RoadMilestone.Subject]] {
    slots.map { $0.milestones.map(\.subject) }
}

@Suite("Road projection")
struct RoadProjectorTests {
    @Test("REQ-ROAD-009: with no eligible milestones the road is honestly empty and invents nothing")
    func noKnownMilestones() {
        let road = project([Fix.oil10k], [], currentKm: 50000, day: 10)
        #expect(road.slots.isEmpty && road.waitingForMileage.isEmpty && road.initialSlotCount == 0)
        #expect(road.horizon == .noKnownMilestones)
        #expect(road.semanticSummary == .noKnownMilestones(trackedWithoutBaseline: 1))
    }

    @Test("REQ-ROAD-001: an approaching or due maintenance anchor and a planned event each become a milestone")
    func eligibleMilestonesAppear() {
        let insurance = PlannedVehicleEvent(kind: .insuranceExpiry, date: Fix.date(40))
        let road = project(
            [Fix.oil10k, Fix.custom(.brakeFluid, months: 12)],
            [Fix.completion(.engineOilService, km: 50000), Fix.completion(.brakeFluid, km: nil, day: -370)],
            currentKm: 59000,
            day: 10,
            planned: [insurance]
        )
        let all = Set(road.slots.flatMap(\.milestones).map(\.subject))
        #expect(all == [
            .maintenance(.engineOilService),
            .maintenance(.brakeFluid),
            .planned(.insuranceExpiry, id: insurance.id),
        ])
        #expect(road.slots.first?.lead?.subject == .maintenance(.brakeFluid))
        #expect(road.slots.first?.lead?.state == .due)
    }

    @Test("REQ-ROAD-002: notes, history events, and a planned date long passed never become milestones")
    func nonMilestonesStayOffRoad() {
        let history = HistoryTimeline(
            events: [DomainFixtures.History.carWashEvent, DomainFixtures.History.serviceVisit],
            completions: []
        )
        let road = project(
            [],
            [],
            currentKm: 50000,
            day: 400,
            planned: [PlannedVehicleEvent(kind: .plannedVisit, date: Fix.date(300))],
            history: history
        )
        #expect(road.slots.isEmpty)
        #expect(road.horizon == .noKnownMilestones)
    }

    @Test("REQ-ROAD-010: a large past is one compact marker with a count and the latest date")
    func pastIsCompressed() {
        let events = (0 ..< 40).map { index in
            HistoryEvent(vehicleID: Fix.vehicleID, kind: .carWash, date: Fix.date(Double(index)))
        }
        let road = project([], [], currentKm: nil, day: 100, history: HistoryTimeline(events: events, completions: []))
        #expect(road.past == RoadPastSummary(count: 40, latestDate: Fix.date(39)))
        #expect(road.slots.isEmpty)
    }

    @Test("REQ-ROAD-005: a date milestone keeps its place when mileage is unknown")
    func dateMilestoneSurvivesUnknownMileage() throws {
        let road = project(
            [Fix.custom(.brakeFluid, months: 12)],
            [Fix.completion(.brakeFluid, km: nil)],
            currentKm: nil,
            day: 300
        )
        let milestone = try #require(road.slots.first?.lead)
        #expect(milestone.dimension == .time && milestone.remainingDays == 66 && milestone.mileageDependency == nil)
    }

    @Test("REQ-ROAD-006: a mileage-only milestone with stale mileage is kept, flagged, and not placed")
    func staleMileageMilestoneWaits() throws {
        let road = project([Fix.oil10k], [Fix.completion(.engineOilService, km: 50000)], currentKm: nil, day: 200)
        #expect(road.slots.isEmpty)
        let waiting = try #require(road.waitingForMileage.first)
        #expect(waiting.subject == .maintenance(.engineOilService))
        #expect(waiting.mileageDependency == .mileageStale)
        #expect(waiting.remainingKm == nil && waiting.anchorKm == 60000)
        #expect(road.semanticSummary == .nearest(waiting, alsoAhead: 0, waitingForMileage: 0))
        #expect(road.horizon == .waitingForMileage)
    }

    @Test("REQ-ROAD-007: a distance-or-time milestone is labelled by its deciding dimension and never converted")
    func noConversionBetweenDimensions() throws {
        let policy = DomainFixtures.Maintenance.standardOilPolicy
        let byTime = try #require(project(
            [policy], [Fix.completion(.engineOilService, km: 50000)], currentKm: 51000, day: 350
        ).slots.first?.lead)
        #expect(byTime.dimension == .time && byTime.remainingKm == nil && byTime.remainingDays == 16)

        let stale = try #require(project(
            [policy], [Fix.completion(.engineOilService, km: 50000)], currentKm: nil, day: 200
        ).slots.first?.lead)
        #expect(stale.dimension == .time && stale.remainingKm == nil && stale.mileageDependency == .mileageStale)
    }

    @Test("REQ-ROAD-008: when nothing is within the horizon the viewport still shows the nearest milestone")
    func horizonExtendsToNearest() {
        let road = project(
            [Fix.custom(.dsgService, km: 60000), Fix.custom(.sparkPlugs, km: 90000)],
            [Fix.completion(.dsgService, km: 50000), Fix.completion(.sparkPlugs, km: 50000)],
            currentKm: 52000,
            day: 10
        )
        #expect(road.horizon == .extendedToNearest)
        #expect(road.initialSlotCount == 1)
        #expect(subjects(road.initialSlots) == [[.maintenance(.dsgService)]])
        #expect(road.slots.count == 2)
    }

    @Test("ADR-0008: the default viewport holds at most four slots; later ones are reached by scrolling")
    func initialViewportIsCapped() {
        // Six dated events 25 days apart: all inside six months, none close enough to cluster.
        let planned = (0 ..< 6).map { index in
            PlannedVehicleEvent(
                id: UUID(uuidString: "BBBBBBBB-0000-4000-8000-00000000000\(index)") ?? UUID(),
                kind: .other,
                date: Fix.date(30 + Double(index) * 25)
            )
        }
        let road = project([], [], currentKm: nil, day: 10, planned: planned)
        #expect(road.slots.count == 6)
        #expect(road.horizon == .standard && road.initialSlotCount == 4)
        #expect(road.initialSlots.compactMap(\.lead?.remainingDays) == [20, 45, 70, 95])
    }

    @Test("REQ-ROAD-008: a near milestone is never hidden behind a far one with a smaller share of its interval")
    func nearBeatsSmallerShare() {
        // DSG: 12,000 km left of 60,000 (share 0.20). Oil: 3,000 km left of 10,000 (share 0.30).
        let road = project(
            [Fix.custom(.dsgService, km: 60000), Fix.custom(.engineOilService, km: 10000)],
            [Fix.completion(.dsgService, km: 2000), Fix.completion(.engineOilService, km: 43000)],
            currentKm: 50000,
            day: 10
        )
        #expect(road.horizon == .standard && road.initialSlotCount == 1)
        #expect(subjects(road.slots) == [[.maintenance(.engineOilService)], [.maintenance(.dsgService)]])
        guard case let .nearest(nearest, _, _) = road.semanticSummary else {
            Issue.record("expected a nearest milestone")
            return
        }
        #expect(nearest.subject == .maintenance(.engineOilService))
    }

    @Test("ADR-0008: the lane is ordered by nearness even when a farther milestone is already approaching")
    func nearnessBeatsApproachingState() {
        // DSG: 8,000 km left of 60,000 (approaching, 1.6 units). Oil: 5,500 km left of 10,000 (upcoming, 1.1 units).
        let road = project(
            [Fix.custom(.dsgService, km: 60000), Fix.custom(.engineOilService, km: 10000)],
            [Fix.completion(.dsgService, km: 0), Fix.completion(.engineOilService, km: 47500)],
            currentKm: 52000,
            day: 10
        )
        #expect(subjects(road.slots) == [[.maintenance(.engineOilService)], [.maintenance(.dsgService)]])
        #expect(road.slots.last?.lead?.state == .approaching)
        #expect(road.horizon == .extendedToNearest)
    }

    @Test("ADR-0008: work that is due now never shares a slot with a milestone that is still ahead")
    func dueIsNotMergedWithUpcoming() {
        let road = project(
            [Fix.custom(.engineOilService, km: 10000), Fix.custom(.airFilter, km: 10000)],
            [Fix.completion(.engineOilService, km: 50000), Fix.completion(.airFilter, km: 51400)],
            currentKm: 60500,
            day: 10
        )
        #expect(subjects(road.slots) == [[.maintenance(.engineOilService)], [.maintenance(.airFilter)]])
    }

    @Test("ADR-0008: due work leads the road even when a planned event is only days away")
    func dueLeadsPlannedEvent() {
        let insurance = PlannedVehicleEvent(kind: .insuranceExpiry, date: Fix.date(12))
        let road = project(
            [Fix.oil10k],
            [Fix.completion(.engineOilService, km: 50000)],
            currentKm: 60200,
            day: 10,
            planned: [insurance]
        )
        #expect(subjects(road.slots) == [
            [.maintenance(.engineOilService)],
            [.planned(.insuranceExpiry, id: insurance.id)],
        ])
    }

    @Test(
        "ADR-0008: milestones of one dimension within the window share a slot; the boundary is inclusive",
        arguments: [(1500, 1), (1501, 2)]
    )
    func clusteringBoundary(gapKm: Int, expectedSlots: Int) {
        let road = project(
            [Fix.custom(.engineOilService, km: 10000), Fix.custom(.airFilter, km: 10000)],
            [Fix.completion(.engineOilService, km: 50000), Fix.completion(.airFilter, km: 50000 + gapKm)],
            currentKm: 59000,
            day: 10
        )
        #expect(road.slots.count == expectedSlots)
        #expect(road.slots.first?.lead?.subject == .maintenance(.engineOilService))
    }

    @Test(
        "ADR-0008: a milestone decided by date never clusters with a mileage milestone, however close its own mileage anchor"
    )
    func mixedDimensionsNeverCluster() throws {
        // Oil is decided by its date rule (20 days left) while its mileage anchor, 60,000, is only
        // 500 km from the air filter's anchor of 60,500.
        let road = project(
            [Fix.custom(.engineOilService, km: 10000, months: 12), Fix.custom(.airFilter, km: 10000)],
            [Fix.completion(.engineOilService, km: 50000), Fix.completion(.airFilter, km: 50500, day: 340)],
            currentKm: 51000,
            day: 346
        )
        let oil = try #require(road.slots.flatMap(\.milestones).first { $0.subject == .maintenance(.engineOilService) })
        #expect(oil.dimension == .time && oil.anchorKm == 60000)
        #expect(road.slots.allSatisfy { $0.milestones.count == 1 })
    }

    @Test("ADR-0008: two close mileage milestones share a slot even when a date milestone sorts between them")
    func clusteringIgnoresOtherDimensionInBetween() {
        let road = project(
            [
                Fix.custom(.engineOilService, km: 10000),
                Fix.custom(.airFilter, km: 10000),
                Fix.custom(.brakeFluid, months: 12),
            ],
            [
                Fix.completion(.engineOilService, km: 50000),
                Fix.completion(.airFilter, km: 50800),
                Fix.completion(.brakeFluid, km: nil, day: -325),
            ],
            currentKm: 59500,
            day: 10
        )
        // Oil 500 km (0.10 units), brake fluid 30 days (0.16), air filter 1,300 km (0.26): the date
        // milestone sorts between the two mileage ones and still does not split their cluster.
        #expect(subjects(road.slots) == [
            [.maintenance(.engineOilService), .maintenance(.airFilter)],
            [.maintenance(.brakeFluid)],
        ])
        #expect(road.slots.last?.lead?.remainingDays == 30)
    }

    @Test("ADR-0008: dated milestones cluster within 21 days, inclusive", arguments: [(21, 1), (22, 2)])
    func timeClusteringBoundary(gapDays: Int, expectedSlots: Int) {
        let planned = [
            PlannedVehicleEvent(kind: .insuranceExpiry, date: Fix.date(40)),
            PlannedVehicleEvent(kind: .plannedVisit, date: Fix.date(40 + Double(gapDays))),
        ]
        #expect(project([], [], currentKm: nil, day: 10, planned: planned).slots.count == expectedSlots)
    }

    @Test("REQ-ROAD-006: an operation whose completion has no mileage is kept and flagged, not dropped")
    func completionWithoutMileageWaits() throws {
        let road = project([Fix.oil10k], [Fix.completion(.engineOilService, km: nil)], currentKm: 90000, day: 10)
        let waiting = try #require(road.waitingForMileage.first)
        #expect(waiting.mileageDependency == .completionMileageMissing && waiting.anchorKm == nil)
        #expect(road.horizon == .waitingForMileage)
    }

    @Test(
        "ADR-0008: a planned date that passed stays due for 14 days and then leaves the road",
        arguments: [(1.0, 1), (14, 1), (15, 0)]
    )
    func passedPlannedDateGracePeriod(daysAgo: Double, expectedSlots: Int) {
        let road = project(
            [],
            [],
            currentKm: nil,
            day: 100,
            planned: [PlannedVehicleEvent(kind: .insuranceExpiry, date: Fix.date(100 - daysAgo))]
        )
        #expect(road.slots.count == expectedSlots)
        #expect(road.slots.first?.lead.map { $0.state == .due } ?? true)
    }

    @Test(
        "REQ-ROAD-011: approaching, due, and overdue are distinct states decided by the projection",
        arguments: [
            (58500.0, RoadMilestoneState.approaching),
            (60000, .due),
            (60999, .due),
            (61000, .overdue)
        ]
    )
    func milestoneStates(currentKm: Double, expected: RoadMilestoneState) throws {
        let road = project([Fix.oil10k], [Fix.completion(.engineOilService, km: 50000)], currentKm: currentKm, day: 10)
        #expect(try #require(road.slots.first?.lead).state == expected)
    }

    @Test("REQ-ROAD-003: the same context gives the same projection whatever order the facts arrive in")
    func projectionIsDeterministic() {
        let policies = [Fix.oil10k, Fix.custom(.dsgService, km: 60000), Fix.custom(.brakeFluid, months: 24)]
        let done = [
            Fix.completion(.engineOilService, km: 50000),
            Fix.completion(.dsgService, km: 1000),
            Fix.completion(.brakeFluid, km: nil),
        ]
        let planned = [
            PlannedVehicleEvent(
                id: UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000001") ?? UUID(),
                kind: .insuranceExpiry,
                date: Fix.date(90)
            ),
            PlannedVehicleEvent(
                id: UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000002") ?? UUID(),
                kind: .plannedVisit,
                date: Fix.date(90)
            ),
        ]
        let forward = project(policies, done, currentKm: 59000, day: 10, planned: planned)
        let backward = project(
            policies.reversed(),
            done.reversed(),
            currentKm: 59000,
            day: 10,
            planned: planned.reversed()
        )
        #expect(forward == backward)
    }

    @Test("REQ-ROAD-015: the semantic summary names the nearest milestone and counts the rest")
    func semanticSummary() throws {
        let road = project(
            [Fix.oil10k, Fix.custom(.dsgService, km: 60000)],
            [Fix.completion(.engineOilService, km: 50000), Fix.completion(.dsgService, km: 40000)],
            currentKm: 59000,
            day: 10
        )
        let nearest = try #require(road.slots.first?.lead)
        #expect(road.semanticSummary == .nearest(nearest, alsoAhead: 1, waitingForMileage: 0))
        #expect(nearest.remainingKm == 1000)
    }

    @Test(
        "ADR-0008: at zero the distance wording follows the state, so approaching never reads as reached",
        arguments: [(59999.6, RoadDistanceLabel.almost), (60000, .reached), (59000, .inKm(1000)), (60700, .pastKm(700))]
    )
    func distanceLabelFollowsState(currentKm: Double, expected: RoadDistanceLabel) throws {
        let road = project([Fix.oil10k], [Fix.completion(.engineOilService, km: 50000)], currentKm: currentKm, day: 10)
        #expect(try #require(road.slots.first?.lead).distanceLabel == expected)
    }

    @Test("REQ-ROAD-006: a blocked milestone is labelled with its reason instead of a number")
    func blockedLabel() throws {
        let road = project([Fix.oil10k], [Fix.completion(.engineOilService, km: nil)], currentKm: 90000, day: 10)
        #expect(try #require(road.waitingForMileage.first).distanceLabel == .blocked(.completionMileageMissing))
        #expect(!road.isCompletelyEmpty)
    }

    @Test("REQ-ROAD-009: only a road with nothing tracked is completely empty")
    func completelyEmpty() {
        #expect(project([], [], currentKm: nil, day: 1).isCompletelyEmpty)
        #expect(!project([Fix.oil10k], [], currentKm: nil, day: 1).isCompletelyEmpty)
    }
}
