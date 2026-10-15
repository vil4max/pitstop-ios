import Foundation
@testable import Pitstop
import Testing

private typealias Fix = MaintenanceFixture

/// Milestone states, labels and the projection's determinism.
extension RoadProjectorTests {
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
        "ADR-0032: days left to a planned date are calendar days, also across a daylight saving change",
        arguments: [
            // Fall back on 2026-10-25: the 48 hours span a 25-hour day.
            ([2026, 10, 24, 0, 30], [2026, 10, 26, 0, 0]),
            // Spring forward on 2027-03-28: the span holds a 23-hour day.
            ([2027, 3, 27, 23, 30], [2027, 3, 29, 0, 0]),
        ]
    )
    func plannedDaysFollowTheCalendarAcrossDaylightSaving(now: [Int], event: [Int]) throws {
        var kyiv = Calendar(identifier: .gregorian)
        kyiv.timeZone = try #require(TimeZone(identifier: "Europe/Kyiv"))
        func date(_ parts: [Int]) throws -> Date {
            try #require(
                kyiv.date(
                    from: DateComponents(
                        year: parts[0], month: parts[1], day: parts[2], hour: parts[3], minute: parts[4]
                    )))
        }
        let road = RoadProjector().project(
            RoadContext(
                now: try date(now),
                maintenanceStates: [],
                plannedEvents: [PlannedVehicleEvent(kind: .insuranceExpiry, date: try date(event))],
                calendar: kyiv
            ))
        let lead = try #require(road.slots.first?.lead)
        #expect(lead.remainingDays == 2)
        #expect(lead.state == .approaching)
    }

    @Test(
        "REQ-ROAD-011: approaching, due, and overdue are distinct states decided by the projection",
        arguments: [
            (58500.0, RoadMilestoneState.approaching),
            (60000, .due),
            (60999, .due),
            (61000, .overdue),
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
        arguments: [
            (59999.6, RoadDistanceLabel.almost), (60000, .reached), (59000, .inKm(1000)), (60700, .pastKm(700)),
        ]
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
