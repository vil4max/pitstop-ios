import Foundation
@testable import Pitstop
import Testing

/// When a Service row draws the remaining-share track and how full it is (ADR 0038; redesign proposal §4
/// decision 2 and §6): only with a known interval, a last completion and a mileage observation newer than
/// 90 days, and then as the used share of the dimension that decided the status.
@Suite("Service remaining-share track")
struct ServiceShareTrackTests {
    private typealias Fixture = MaintenanceFixture

    private static func state(
        _ policy: MaintenancePolicy,
        completions: [MaintenanceCompletion],
        reports: [VehicleServiceReport] = [],
        reading: OdometerReading?,
        day: Double
    ) throws -> (MaintenanceOperationState, MileageKnowledge) {
        let context = MaintenanceContext(
            now: Fixture.date(day), latestReading: reading, completions: completions, reports: reports
        )
        let states = MaintenanceEngine().states(
            policies: [policy], completions: completions, reports: reports, context: context, calendar: Fixture.utc
        )
        return try (#require(states.first), context.mileage)
    }

    private static func report(
        _ operation: MaintenanceOperationID,
        day: Double,
        odometerKm: Int,
        remainingKm: Double,
        after completions: [MaintenanceCompletion]
    ) -> VehicleServiceReport {
        VehicleServiceReport(
            vehicleID: Fixture.vehicleID, operationID: operation, reportedAt: Fixture.date(day),
            odometerKm: odometerKm, remainingDistance: remainingKm
        )
        .entered(after: completions)
    }

    @Test("ADR-0038: with an interval, a last completion and fresh mileage the track draws the used share")
    func drawsTheUsedShare() throws {
        let done = Fixture.completion(.engineOilService, km: 50000)
        let (operation, mileage) = try Self.state(
            Fixture.oil10k, completions: [done], reading: Fixture.reading(55000, day: 30), day: 30
        )

        #expect(operation.drawnUsedShare(mileage: mileage) == 0.5)
    }

    @Test("ADR-0038: a tracked operation without a last completion draws no track")
    func noCompletionDrawsNoTrack() throws {
        let (operation, mileage) = try Self.state(
            Fixture.oil10k, completions: [], reading: Fixture.reading(55000, day: 30), day: 30
        )

        #expect(operation.status == .unknown)
        #expect(operation.drawnUsedShare(mileage: mileage) == nil)
    }

    @Test("ADR-0038: unknown status draws no track, as when the completion has no mileage")
    func unknownStatusDrawsNoTrack() throws {
        let done = Fixture.completion(.engineOilService, km: nil)
        let (operation, mileage) = try Self.state(
            Fixture.oil10k, completions: [done], reading: Fixture.reading(55000, day: 30), day: 30
        )

        #expect(mileage == .known && operation.lastCompletion != nil)
        #expect(operation.status == .unknown)
        #expect(operation.drawnUsedShare(mileage: mileage) == nil)
    }

    @Test("ADR-0038: stale mileage draws no track even when the time rule decided the status")
    func staleMileageDrawsNoTrack() throws {
        let policy = Fixture.custom(.engineOilService, km: 10000, months: 12)
        let done = Fixture.completion(.engineOilService, km: 50000)
        let (operation, mileage) = try Self.state(
            policy, completions: [done], reading: Fixture.reading(55000, day: 60), day: 200
        )

        #expect(mileage == .stale)
        #expect(operation.status != .unknown && operation.decidedBy == .time)
        #expect(operation.drawnUsedShare(mileage: mileage) == nil)
    }

    @Test("ADR-0038: a mileage observation 89 days old still counts; 91 days old does not", arguments: [
        (89.0, true), (91.0, false),
    ])
    func ninetyDayBoundary(age: Double, draws: Bool) throws {
        let policy = Fixture.custom(.engineOilService, km: 10000, months: 12)
        let done = Fixture.completion(.engineOilService, km: 50000)
        let (operation, mileage) = try Self.state(
            policy, completions: [done], reading: Fixture.reading(52000, day: 10), day: 10 + age
        )

        #expect((operation.drawnUsedShare(mileage: mileage) != nil) == draws)
    }

    @Test("ADR-0038: past 100 % the bar is full; the status word carries the overdue meaning")
    func overdueFillsTheBar() throws {
        let done = Fixture.completion(.engineOilService, km: 50000)
        let (operation, mileage) = try Self.state(
            Fixture.oil10k, completions: [done], reading: Fixture.reading(62000, day: 30), day: 30
        )

        #expect(operation.status == .due)
        #expect(operation.drawnUsedShare(mileage: mileage) == 1)
    }

    @Test("ADR-0038: a time-only interval draws the time share")
    func timeOnlyIntervalDrawsTheTimeShare() throws {
        let policy = Fixture.custom(.brakeFluid, months: 12)
        let done = Fixture.completion(.brakeFluid, km: nil)
        let day = 120.0
        let (operation, mileage) = try Self.state(
            policy, completions: [done], reading: Fixture.reading(55000, day: day), day: day
        )
        let anchor = try #require(Fixture.utc.date(byAdding: .month, value: 12, to: Fixture.date(0)))
        let expected = Fixture.date(day).timeIntervalSince(Fixture.date(0)) / anchor.timeIntervalSince(Fixture.date(0))

        let share = try #require(operation.drawnUsedShare(mileage: mileage))
        #expect(operation.decidedBy == .time)
        #expect(abs(share - expected) < 0.000_001)
    }

    @Test("ADR-0038: with both dimensions the bar draws the one that decided the status")
    func bothDimensionsDrawTheDecidingOne() throws {
        let policy = Fixture.custom(.engineOilService, km: 10000, months: 12)
        let done = Fixture.completion(.engineOilService, km: 50000)
        let (operation, mileage) = try Self.state(
            policy, completions: [done], reading: Fixture.reading(59000, day: 30), day: 30
        )

        let share = try #require(operation.drawnUsedShare(mileage: mileage))
        #expect(operation.decidedBy == .distance)
        #expect(abs(share - 0.9) < 0.000_001)
    }

    @Test("ADR-0038: a dashboard reading that decided draws its share of the owner's interval")
    func dashboardReadingDrawsTheOwnersShare() throws {
        let done = Fixture.completion(.engineOilService, km: 40000)
        // The car said 2,000 km at 45,000: its anchor (47,000) comes before the owner's (50,000).
        let reading = Self.report(.engineOilService, day: 10, odometerKm: 45000, remainingKm: 2000, after: [done])
        let (operation, mileage) = try Self.state(
            Fixture.oil10k, completions: [done], reports: [reading],
            reading: Fixture.reading(46000, day: 20), day: 20
        )

        let share = try #require(operation.drawnUsedShare(mileage: mileage))
        #expect(operation.isDecidedByReport && operation.decidedBy == .distance)
        #expect(abs(share - 0.9) < 0.000_001)
    }

    @Test("ADR-0038: a reading that decided a dimension the owner set no interval for draws no track")
    func readingWithoutOwnerIntervalDrawsNoTrack() throws {
        let policy = Fixture.custom(.engineOilService, months: 12)
        let done = Fixture.completion(.engineOilService, km: 40000)
        let reading = Self.report(.engineOilService, day: 10, odometerKm: 45000, remainingKm: 1000, after: [done])
        let (operation, mileage) = try Self.state(
            policy, completions: [done], reports: [reading],
            reading: Fixture.reading(45500, day: 20), day: 20
        )

        #expect(operation.isDecidedByReport && operation.decidedBy == .distance)
        #expect(operation.drawnUsedShare(mileage: mileage) == nil)
    }

    @Test("ADR-0038: a reading without a last completion draws no track")
    func readingWithoutCompletionDrawsNoTrack() throws {
        let reading = Self.report(.engineOilService, day: 0, odometerKm: 50000, remainingKm: 5000, after: [])
        let (operation, mileage) = try Self.state(
            Fixture.oil10k, completions: [], reports: [reading],
            reading: Fixture.reading(52000, day: 10), day: 10
        )

        #expect(operation.status != .unknown && operation.lastCompletion == nil)
        #expect(operation.drawnUsedShare(mileage: mileage) == nil)
    }
}
