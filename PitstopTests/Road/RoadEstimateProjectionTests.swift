import Foundation
@testable import Pitstop
import Testing

/// The fictional car of ADR 0034 as Road sees it: readings, one completion, and the projection that
/// annotates its distance milestone.
private enum EstimatedRoad {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    static let vehicleID = DomainFixtures.Vehicles.defaultID

    static func day(_ text: String, hour: Int = 12) -> Date {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = hour
        return utc.date(from: components) ?? .distantPast
    }

    static let today = day("2026-09-22")

    static let oil = MaintenancePolicy(
        operationID: .engineOilService,
        distanceIntervalKm: 10000,
        timeIntervalMonths: 12,
        source: .userCustom
    )

    static let oilDone = MaintenanceCompletion(
        id: UUID(uuidString: "00000000-0000-4000-8000-00000000e571") ?? UUID(),
        vehicleID: vehicleID,
        operationID: .engineOilService,
        performedAt: day("2026-06-30"),
        odometerKm: 42500
    )

    static let readings: [OdometerReading] = [
        ("2026-05-01", 40000.0), ("2026-05-31", 41300), ("2026-07-15", 45100),
        ("2026-08-14", 46300), ("2026-09-13", 47560),
    ].map { entry in
        OdometerReading(vehicleID: vehicleID, value: entry.1, recordedAt: day(entry.0))
    }

    /// The projection of this car, with the reading history fed in or withheld. Everything else is
    /// identical, so any difference is the estimate's doing.
    static func projection(
        policies: [MaintenancePolicy] = [oil],
        completions: [MaintenanceCompletion] = [oilDone],
        planned: [PlannedVehicleEvent] = [],
        withReadings: Bool
    ) -> RoadProjection {
        let context = MaintenanceContext(now: today, latestReading: readings.latest, completions: completions)
        let states = MaintenanceEngine().states(
            policies: policies, completions: completions, context: context, calendar: utc
        )
        return RoadProjector().project(RoadContext(
            now: today,
            maintenanceStates: states,
            plannedEvents: planned,
            mileageObservations: withReadings
                ? MileageObservation.history(readings: readings, completions: completions)
                : [],
            calendar: utc
        ))
    }

    /// Everything Road decides: what is placed, in which order, in which slot, with which state,
    /// number and horizon. The estimate is deliberately not part of it.
    static func placement(_ projection: RoadProjection) -> String {
        let slots = projection.slots.map { slot in
            slot.milestones.map { milestone in
                "\(milestone.id)/\(milestone.state.rawValue)/\(milestone.remainingKm.map(String.init) ?? "-")"
                    + "/\(milestone.remainingDays.map(String.init) ?? "-")/\(milestone.dimension.rawValue)"
            }.joined(separator: "+")
        }.joined(separator: "|")
        let waiting = projection.waitingForMileage.map(\.id).joined(separator: ",")
        let summary = switch projection.semanticSummary {
        case let .noKnownMilestones(tracked): "none-\(tracked)"
        case let .nearest(milestone, ahead, waitingCount): "\(milestone.id)-\(ahead)-\(waitingCount)"
        }
        return "\(slots)#\(waiting)#\(projection.horizon)#\(projection.initialSlotCount)#\(summary)"
    }
}

@Suite("Road date estimate")
struct RoadEstimateProjectionTests {
    @Test("REQ-ROAD-022: a fictional car's distance milestone carries the estimated range end to end")
    func endToEndProjection() throws {
        let road = EstimatedRoad.projection(withReadings: true)
        let lead = try #require(road.slots.first?.lead)

        #expect(lead.subject == .maintenance(.engineOilService))
        #expect(lead.dimension == .distance && lead.remainingKm == 4940)
        let estimate = try #require(lead.estimate)
        #expect(estimate.earliest == EstimatedRoad.day("2026-12-10", hour: 0))
        #expect(estimate.latest == EstimatedRoad.day("2027-01-11", hour: 0))
    }

    @Test("REQ-ROAD-023: the same car without a reading history keeps its milestone and carries no estimate")
    func noHistoryNoEstimate() throws {
        let road = EstimatedRoad.projection(withReadings: false)
        let lead = try #require(road.slots.first?.lead)
        #expect(lead.remainingKm == 4940 && lead.estimate == nil)
    }

    @Test("REQ-ROAD-007, REQ-ROAD-022: the estimate changes no placement, order, cluster, or state")
    func placementIsUnchanged() {
        let planned = PlannedVehicleEvent(
            id: UUID(uuidString: "00000000-0000-4000-8000-0000000000e0") ?? UUID(),
            kind: .insuranceExpiry,
            date: EstimatedRoad.day("2026-11-20")
        )
        // Distance, date, a milestone in the same cluster, and one waiting for mileage, at once.
        let policies = [
            EstimatedRoad.oil,
            MaintenancePolicy(operationID: .brakeFluid, timeIntervalMonths: 24, source: .userCustom),
            MaintenancePolicy(operationID: .airFilter, distanceIntervalKm: 15000, source: .userCustom),
            MaintenancePolicy(operationID: .cabinFilter, distanceIntervalKm: 20000, source: .userCustom),
        ]
        let completions = [
            EstimatedRoad.oilDone,
            MaintenanceCompletion(
                vehicleID: EstimatedRoad.vehicleID, operationID: .brakeFluid,
                performedAt: EstimatedRoad.day("2025-02-10")
            ),
            MaintenanceCompletion(
                vehicleID: EstimatedRoad.vehicleID, operationID: .airFilter,
                performedAt: EstimatedRoad.day("2026-01-20"), odometerKm: 37000
            ),
            // Saved without mileage: this one waits for mileage in both projections.
            MaintenanceCompletion(
                vehicleID: EstimatedRoad.vehicleID, operationID: .cabinFilter,
                performedAt: EstimatedRoad.day("2026-02-15")
            ),
        ]

        let withEstimates = EstimatedRoad.projection(
            policies: policies, completions: completions, planned: [planned], withReadings: true
        )
        let without = EstimatedRoad.projection(
            policies: policies, completions: completions, planned: [planned], withReadings: false
        )

        #expect(EstimatedRoad.placement(withEstimates) == EstimatedRoad.placement(without))
        #expect(withEstimates.slots.flatMap(\.milestones).contains { $0.estimate != nil })
        #expect(without.slots.flatMap(\.milestones).allSatisfy { $0.estimate == nil })
    }

    @Test("REQ-ROAD-022: only a distance milestone with kilometres left is annotated")
    func onlyDistanceMilestonesAreAnnotated() {
        let planned = PlannedVehicleEvent(kind: .insuranceExpiry, date: EstimatedRoad.day("2026-11-20"))
        let road = EstimatedRoad.projection(
            policies: [
                EstimatedRoad.oil,
                MaintenancePolicy(operationID: .brakeFluid, timeIntervalMonths: 24, source: .userCustom),
            ],
            completions: [
                EstimatedRoad.oilDone,
                MaintenanceCompletion(
                    vehicleID: EstimatedRoad.vehicleID, operationID: .brakeFluid,
                    performedAt: EstimatedRoad.day("2025-02-10")
                ),
            ],
            planned: [planned],
            withReadings: true
        )
        let annotated = road.slots.flatMap(\.milestones).filter { $0.estimate != nil }
        #expect(annotated.map(\.subject) == [.maintenance(.engineOilService)])
        #expect(road.slots.flatMap(\.milestones).allSatisfy { $0.dimension == .time ? $0.estimate == nil : true })
    }

    @Test("REQ-ROAD-022: the estimate reads as an approximate range, by day or by month")
    func labelReadsAsAnEstimate() {
        let english = Locale(identifier: "en_US")
        let short = RoadEstimateLabel(
            range: EstimatedDateRange(
                earliest: EstimatedRoad.day("2026-12-10", hour: 0),
                latest: EstimatedRoad.day("2027-01-11", hour: 0)
            ),
            now: EstimatedRoad.today,
            calendar: EstimatedRoad.utc,
            locale: english
        )
        #expect(short.granularity == .day)
        #expect(short.text == "Dec 10, 2026 \u{2013} Jan 11, 2027")
        #expect(short.spokenEarliest.contains("December") && short.spokenLatest.contains("January"))

        let wide = RoadEstimateLabel(
            range: EstimatedDateRange(
                earliest: EstimatedRoad.day("2026-12-10", hour: 0),
                latest: EstimatedRoad.day("2027-03-20", hour: 0)
            ),
            now: EstimatedRoad.today,
            calendar: EstimatedRoad.utc,
            locale: english
        )
        #expect(wide.granularity == .month)
        #expect(wide.text == "December 2026 \u{2013} March 2027")
        // No day: a range this wide is a season, not a date.
        #expect(!wide.text.contains("10") && !wide.text.contains("20 "))
    }

    @Test("REQ-ROAD-022: a range inside one year needs no year, and two different days keep both bounds")
    func labelYearAndCollapseRules() {
        let english = Locale(identifier: "en_US")
        let sameYear = RoadEstimateLabel(
            range: EstimatedDateRange(
                earliest: EstimatedRoad.day("2027-03-02", hour: 0),
                latest: EstimatedRoad.day("2027-03-28", hour: 0)
            ),
            now: EstimatedRoad.today,
            calendar: EstimatedRoad.utc,
            locale: english
        )
        // 2027 is not the fixture's year, so both bounds say so.
        #expect(sameYear.text == "Mar 2, 2027 \u{2013} Mar 28, 2027")

        // A year apart in the same month: without the year this read as one month (review finding).
        let yearApart = RoadEstimateLabel(
            range: EstimatedDateRange(
                earliest: EstimatedRoad.day("2027-11-30", hour: 0),
                latest: EstimatedRoad.day("2028-11-21", hour: 0)
            ),
            now: EstimatedRoad.today,
            calendar: EstimatedRoad.utc,
            locale: english
        )
        #expect(yearApart.granularity == .month)
        #expect(yearApart.text == "November 2027 \u{2013} November 2028")

        // One day only: one label, and nothing else collapses.
        let oneDay = EstimatedRoad.day("2027-03-02", hour: 0)
        let single = RoadEstimateLabel(
            range: EstimatedDateRange(earliest: oneDay, latest: oneDay),
            now: EstimatedRoad.today,
            calendar: EstimatedRoad.utc,
            locale: english
        )
        #expect(single.text == "Mar 2, 2027")
        #expect(single.isSingleDay && single.spokenEarliest == single.spokenLatest)
    }

    @Test("REQ-ROAD-022: a bound outside the current year carries its year, inside it does not")
    func labelYearFollowsToday() {
        let english = Locale(identifier: "en_US")
        func label(_ earliest: String, _ latest: String) -> RoadEstimateLabel {
            RoadEstimateLabel(
                range: EstimatedDateRange(
                    earliest: EstimatedRoad.day(earliest, hour: 0),
                    latest: EstimatedRoad.day(latest, hour: 0)
                ),
                now: EstimatedRoad.today,
                calendar: EstimatedRoad.utc,
                locale: english
            )
        }
        // Inside the fixture's own year (2026): the months just ahead need no year.
        #expect(label("2026-11-02", "2026-11-28").text == "Nov 2 \u{2013} Nov 28")
        // Next year, and two years out: both would otherwise read as the coming March.
        #expect(label("2027-03-08", "2027-03-09").text == "Mar 8, 2027 \u{2013} Mar 9, 2027")
        #expect(label("2028-03-08", "2028-03-09").text == "Mar 8, 2028 \u{2013} Mar 9, 2028")
        #expect(label("2028-03-08", "2028-03-08").text == "Mar 8, 2028")
    }
}
