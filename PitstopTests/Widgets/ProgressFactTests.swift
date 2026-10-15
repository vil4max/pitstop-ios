import Foundation
@testable import Pitstop
import Testing

private let vehicleID = MaintenanceFixture.vehicleID
private let calendar = MaintenanceFixture.utc

/// One operation's state as Service and the widget get it from the engine.
private func state(
    _ policy: MaintenancePolicy?,
    completion: MaintenanceCompletion?,
    reading: OdometerReading? = nil,
    reports: [VehicleServiceReport] = [],
    now: Date
) throws -> MaintenanceOperationState {
    let completions = completion.map { [$0] } ?? []
    let context = MaintenanceContext(now: now, latestReading: reading, completions: completions, reports: reports)
    return try #require(
        MaintenanceEngine().states(
            policies: policy.map { [$0] } ?? [],
            completions: completions,
            reports: reports,
            context: context,
            calendar: calendar
        ).first)
}

/// The status word and the progress fact Service and the widget both say (ADR 0036), branch by branch.
@Suite("Progress fact and status word")
struct ProgressFactTests {
    private static let oil = MaintenanceFixture.custom(.engineOilService, km: 10000)
    private static let brakeFluid = MaintenanceFixture.custom(.brakeFluid, months: 12)
    private static let oilByBoth = MaintenanceFixture.custom(.engineOilService, km: 15000, months: 12)

    @Test("REQ-WIDGET-004: due by distance counts the kilometres past the anchor")
    func dueByDistanceCountsKilometresPast() throws {
        let overdue = try state(
            Self.oil,
            completion: MaintenanceFixture.completion(.engineOilService, km: 30000),
            reading: MaintenanceFixture.reading(41000, day: 10),
            now: MaintenanceFixture.date(10)
        )
        #expect(overdue.statusWord == .due)
        #expect(overdue.progressFact == .progress(.kilometersPast(1000), block: nil))
    }

    @Test("REQ-WIDGET-004: due exactly at the distance anchor says it is reached, not zero past")
    func dueAtTheAnchorIsReached() throws {
        let atAnchor = try state(
            Self.oil,
            completion: MaintenanceFixture.completion(.engineOilService, km: 30000),
            reading: MaintenanceFixture.reading(40000, day: 10),
            now: MaintenanceFixture.date(10)
        )
        #expect(atAnchor.statusWord == .due)
        #expect(atAnchor.progressFact == .progress(.reached, block: nil))
    }

    @Test("REQ-WIDGET-004: due by time counts the days past the anchor")
    func dueByTimeCountsDaysPast() throws {
        let overdue = try state(
            Self.brakeFluid,
            completion: MaintenanceFixture.completion(.brakeFluid, km: nil),
            now: MaintenanceFixture.date(400)
        )
        #expect(overdue.statusWord == .due)
        guard case let .progress(.daysPast(days)?, block: nil) = overdue.progressFact else {
            Issue.record("expected days past, got \(overdue.progressFact)")
            return
        }
        #expect(days > 0)
    }

    @Test("REQ-WIDGET-004: approaching with nothing left to count down says almost")
    func approachingWithNothingLeftIsAlmost() throws {
        let done = MaintenanceFixture.date(0)
        let anchor = try #require(calendar.date(byAdding: .month, value: 12, to: done))
        let almost = try state(
            Self.brakeFluid,
            completion: MaintenanceFixture.completion(.brakeFluid, km: nil),
            now: anchor - 43200
        )
        #expect(almost.statusWord == .approaching)
        #expect(almost.progressFact == .progress(.almost, block: nil))
    }

    @Test("REQ-WIDGET-005: a status resting on the date alone says so in its word, beside the missing distance")
    func partialStatusSaysByDate() throws {
        let completion = MaintenanceFixture.completion(.engineOilService, km: nil)
        let calm = try state(
            Self.oilByBoth,
            completion: completion,
            reading: MaintenanceFixture.reading(38800, day: 30),
            now: MaintenanceFixture.date(30)
        )
        #expect(calm.statusWord == .upToDateByDate)
        guard case .progress(.daysLeft?, block: .completionMileageMissing) = calm.progressFact else {
            Issue.record("expected days left beside the missing mileage, got \(calm.progressFact)")
            return
        }

        let near = try state(
            Self.oilByBoth,
            completion: completion,
            reading: MaintenanceFixture.reading(52000, day: 340),
            now: MaintenanceFixture.date(340)
        )
        #expect(near.statusWord == .approachingByDate)
    }

    @Test("REQ-MAINT-031: a reading that newer work superseded, with no rule of the owner's, has nothing to count by")
    func supersededReadingWithoutPolicy() throws {
        let report = VehicleServiceReport(
            vehicleID: vehicleID, operationID: .cabinFilter, reportedAt: MaintenanceFixture.date(0),
            odometerKm: 30000, remainingDistance: 5000
        )
        let superseded = try state(
            nil,
            completion: MaintenanceFixture.completion(.cabinFilter, km: nil, day: 5),
            reports: [report],
            now: MaintenanceFixture.date(10)
        )
        #expect(superseded.countingReport == nil)
        #expect(superseded.statusWord == .unknown)
        #expect(superseded.progressFact == .readingSuperseded)
    }

    @Test("Core C2: a decided status with nothing to measure and no stated reason says the mileage is unknown")
    func decidedWithoutMeasureOrBlockSaysMileageUnknown() {
        let decided = MaintenanceOperationState(
            operationID: .engineOilService,
            policy: Self.oil,
            lastCompletion: MaintenanceFixture.completion(.engineOilService, km: 30000),
            status: .upToDate,
            anchorKm: nil,
            anchorDate: nil,
            remainingKm: nil,
            remainingDays: nil,
            remainingFraction: 0.5,
            decidedBy: .distance,
            distanceBlock: nil
        )
        #expect(decided.progressFact == .progress(nil, block: .mileageUnknown))
    }
}
