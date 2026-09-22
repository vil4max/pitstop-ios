import Foundation
@testable import Pitstop
import Testing

// Every car, mileage and date here is fictional (ADR 0035 worked example, scaled to the fixture clock).

private typealias Fixture = MaintenanceFixture

/// A stable ID per fact, so two builds of the same reading compare equal.
func dashboardReport(
    _ operation: MaintenanceOperationID = .engineOilService,
    distance: Double? = nil,
    unit: DistanceUnit = .kilometers,
    days: Int? = nil,
    odometer: Int? = nil,
    day: Double,
    savedAfter completion: MaintenanceCompletion? = nil
) -> VehicleServiceReport {
    let seed = "\(operation.rawValue)-\(distance ?? -1)-\(days ?? -1)-\(odometer ?? -1)-\(Int(day))"
    let hash = seed.unicodeScalars.reduce(5381) { (($0 << 5) &+ $0) &+ Int($1.value) } & 0xFFFF_FFFF_FFFF
    return VehicleServiceReport(
        id: UUID(uuidString: "00000000-0000-4000-9000-" + String(format: "%012x", hash)) ?? UUID(),
        vehicleID: Fixture.vehicleID,
        operationID: operation,
        reportedAt: Fixture.date(day),
        odometerKm: odometer,
        remainingDistance: distance,
        distanceUnit: unit,
        remainingDays: days
    ).entered(after: completion)
}

func dashboardStates(
    _ policies: [MaintenancePolicy],
    _ completions: [MaintenanceCompletion] = [],
    reports: [VehicleServiceReport],
    currentKm: Double?,
    day: Double
) -> [MaintenanceOperationState] {
    let context = MaintenanceContext(
        now: Fixture.date(day),
        latestReading: currentKm.map { Fixture.reading($0, day: day) },
        completions: completions,
        reports: reports
    )
    return MaintenanceEngine().states(
        policies: policies, completions: completions, reports: reports, context: context, calendar: Fixture.utc
    )
}

private func oil(
    _ policies: [MaintenancePolicy],
    _ completions: [MaintenanceCompletion] = [],
    reports: [VehicleServiceReport],
    currentKm: Double?,
    day: Double
) throws -> MaintenanceOperationState {
    try #require(dashboardStates(policies, completions, reports: reports, currentKm: currentKm, day: day)
        .first { $0.id == .engineOilService })
}

@Suite("Dashboard reading as a maintenance anchor")
struct VehicleServiceReportEngineTests {
    @Test("REQ-MAINT-030: a reading alone yields anchors and a status with no completion and no policy")
    func readingAloneYieldsAnchors() throws {
        let dashboard = dashboardReport(distance: 3200, days: 45, odometer: 38800, day: 0)
        let state = try oil([], reports: [dashboard], currentKm: 38800, day: 0)

        #expect(state.policy == nil && state.lastCompletion == nil)
        #expect(state.anchorKm == 42000 && state.remainingKm == 3200)
        #expect(state.anchorDate == Fixture.date(45) && state.remainingDays == 45)
        #expect(state.status == .upToDate && state.isDecidedByReport)
    }

    @Test("REQ-MAINT-032: the car's earlier anchor wins per dimension over a longer owner interval")
    func earlierReportAnchorWins() throws {
        // Oil every 15,000 km / 12 months, done on day 0 at 30,000 km: owner anchors 45,000 km and day 365.
        let policy = Fixture.custom(.engineOilService, km: 15000, months: 12)
        let done = Fixture.completion(.engineOilService, km: 30000, day: 0)
        let dashboard = dashboardReport(distance: 3200, days: 45, odometer: 38800, day: 203)
        let state = try oil([policy], [done], reports: [dashboard], currentKm: 38800, day: 203)

        #expect(state.anchorKm == 42000 && state.remainingKm == 3200)
        #expect(state.anchorDate == Fixture.date(248) && state.remainingDays == 45)
        // 45 days of a 12-month interval is about 0.12: approaching, decided by the car's date.
        #expect(state.status == .approaching && state.decidedBy == .time && state.isDecidedByReport)
    }

    @Test("REQ-MAINT-032: a stricter owner interval keeps deciding when the car's anchors are later")
    func earlierOwnerAnchorWins() throws {
        let policy = Fixture.custom(.engineOilService, km: 3000, months: 1)
        let done = Fixture.completion(.engineOilService, km: 38000, day: 190)
        let dashboard = dashboardReport(distance: 3200, days: 45, odometer: 38800, day: 203)
        let state = try oil([policy], [done], reports: [dashboard], currentKm: 38800, day: 203)

        #expect(state.anchorKm == 41000 && state.remainingKm == 2200)
        #expect(!state.isDecidedByReport)
        #expect(state.report == dashboard && !state.isReportSuperseded)
    }

    @Test("REQ-MAINT-033: without an owner interval the reported value is the share denominator")
    func reportedValueIsTheDenominator() throws {
        let dashboard = dashboardReport(distance: 3200, odometer: 38800, day: 0)
        // 480 of 3,200 km left is exactly 15%: approaching. One kilometre more is still up to date.
        #expect(try oil([], reports: [dashboard], currentKm: 41520, day: 10).status == .approaching)
        #expect(try oil([], reports: [dashboard], currentKm: 41519, day: 10).status == .upToDate)
    }

    @Test("REQ-MAINT-033: with an owner interval the share is measured against that interval")
    func ownerIntervalIsTheDenominator() throws {
        let policy = Fixture.custom(.engineOilService, km: 15000)
        let dashboard = dashboardReport(distance: 3200, odometer: 38800, day: 0)
        let state = try oil([policy], reports: [dashboard], currentKm: 38800, day: 0)
        #expect(state.remainingFraction.map { abs($0 - 3200.0 / 15000.0) < 0.0001 } == true)
        #expect(state.status == .upToDate && state.isDecidedByReport)
    }

    @Test("REQ-MAINT-031: only the newest reading of an operation counts, in any input order")
    func newestReadingOnly() throws {
        let older = dashboardReport(distance: 1000, odometer: 40000, day: 20)
        let newer = dashboardReport(distance: 5000, odometer: 40500, day: 30)
        for order in [[older, newer], [newer, older]] {
            let state = try oil([], reports: order, currentKm: 40500, day: 30)
            #expect(state.report == newer && state.anchorKm == 45500)
        }
    }

    @Test("REQ-MAINT-031: a completion confirmed after the reading supersedes it; an older one does not")
    func completionSupersedesReading() throws {
        let dashboard = dashboardReport(distance: 3200, odometer: 38800, day: 10)
        let later = Fixture.completion(.engineOilService, km: 39000, day: 20)
        let state = try oil([Fixture.oil10k], [later], reports: [dashboard], currentKm: 39000, day: 20)
        #expect(state.isReportSuperseded && state.countingReport == nil)
        #expect(state.anchorKm == 49000 && !state.isDecidedByReport)

        let earlier = Fixture.completion(.engineOilService, km: 30000, day: 5)
        let kept = try oil([Fixture.oil10k], [earlier], reports: [dashboard], currentKm: 38800, day: 10)
        #expect(!kept.isReportSuperseded && kept.anchorKm == 40000 && !kept.isDecidedByReport)
        let shorter = try oil([Fixture.custom(.engineOilService, km: 15000)], [earlier], reports: [dashboard],
                              currentKm: 38800, day: 10)
        #expect(shorter.anchorKm == 42000 && shorter.isDecidedByReport)
    }

    @Test("REQ-MAINT-034: an owner distance rule with no completion is reported as not counted")
    func ownerDistanceWithoutCompletionIsPartial() throws {
        let policy = Fixture.custom(.engineOilService, km: 15000)
        let state = try oil([policy], reports: [dashboardReport(days: 300, day: 0)], currentKm: 38800, day: 0)
        #expect(state.distanceBlock == .completionMissing && state.remainingKm == nil)
        #expect(state.decidedBy == .time && state.status == .upToDate && state.isPartial)
    }

    @Test("REQ-MAINT-031: on the same day a completion saved after the reading supersedes it")
    func sameDayCompletionSavedLaterSupersedes() throws {
        // "300 km overdue" in the morning, "Mark done" in the afternoon.
        let morning = dashboardReport(distance: -300, odometer: 40000, day: 0)
        let afternoon = Fixture.completion(.engineOilService, km: 40050, day: 0.02)
        let state = try oil([Fixture.oil10k], [afternoon], reports: [morning], currentKm: 40050, day: 0.03)
        #expect(state.isReportSuperseded && state.countingReport == nil)
        #expect(state.status == .upToDate && state.anchorKm == 50050)
    }

    @Test("REQ-MAINT-031: on the same day a reading saved after the completion keeps counting")
    func sameDayReadingSavedLaterCounts() throws {
        // The completion carries the later time of day, as "Mark done" keeps the time its sheet opened;
        // the order of saving decides, not that time.
        let done = Fixture.completion(.engineOilService, km: 40000, day: 0.02)
        let postService = dashboardReport(distance: 15000, odometer: 40000, day: 0, savedAfter: done)
        let state = try oil([], [done], reports: [postService], currentKm: 40000, day: 0.03)
        #expect(!state.isReportSuperseded && state.countingReport == postService)
        #expect(state.anchorKm == 55000 && state.isDecidedByReport)
    }

    @Test("REQ-MAINT-031: on different days the calendar day decides, whatever was saved first")
    func differentDaysUseTheCalendarDay() throws {
        let earlier = Fixture.completion(.engineOilService, km: 39000, day: -3)
        let dashboard = dashboardReport(days: 300, day: 0)
        #expect(try !oil([], [earlier], reports: [dashboard], currentKm: nil, day: 1).isReportSuperseded)
        let nextDay = Fixture.completion(.engineOilService, km: nil, day: 1)
        let known = dashboardReport(days: 300, day: 0, savedAfter: nextDay)
        #expect(try oil([], [nextDay], reports: [known], currentKm: nil, day: 2).isReportSuperseded)
    }

    @Test("REQ-MAINT-034: stale mileage blocks only the distance part; the days still decide")
    func staleMileageBlocksOnlyDistance() throws {
        // The reading's odometer is the newest mileage fact; 100 days later it is stale.
        let dashboard = dashboardReport(distance: 3200, days: 400, odometer: 38800, day: 0)
        let state = try oil([], reports: [dashboard], currentKm: nil, day: 100)
        #expect(state.distanceBlock == .mileageStale && state.remainingKm == nil)
        #expect(state.decidedBy == .time && state.remainingDays == 300 && state.status == .upToDate)
        #expect(state.isPartial)
    }

    @Test("REQ-MAINT-034: a fresh reading is itself a current mileage observation")
    func readingRefreshesMileage() {
        let dashboard = dashboardReport(distance: 3200, odometer: 38800, day: 50)
        let context = MaintenanceContext(
            now: Fixture.date(60), latestReading: Fixture.reading(30000, day: 0), reports: [dashboard]
        )
        #expect(context.mileage == .known && context.observedKm == 38800)
    }

    @Test("REQ-MAINT-034: every stored reading's odometer is a mileage observation, not only the newest")
    func olderReadingsAreObservations() {
        let older = dashboardReport(distance: 3200, odometer: 38800, day: 0)
        let newer = dashboardReport(days: 40, day: 5)
        let context = MaintenanceContext(now: Fixture.date(10), latestReading: nil, reports: [newer, older])
        #expect(context.mileage == .known && context.observedKm == 38800)
        let history = MileageObservation.history(readings: [], completions: [], reports: [newer, older])
        #expect(history.map(\.km) == [38800])
    }

    @Test("REQ-MAINT-035: a reading is called old after 180 days and still counts; it never expires")
    func oldReadingStillCounts() throws {
        let dashboard = dashboardReport(days: 1000, day: 0)
        #expect(!dashboard.isOld(now: Fixture.date(180)))
        #expect(dashboard.isOld(now: Fixture.date(181)))
        let state = try oil([], reports: [dashboard], currentKm: nil, day: 900)
        #expect(state.countingReport == dashboard && state.remainingDays == 100 && state.status == .approaching)
    }

    @Test("REQ-MAINT-037: a distance in miles converts only for arithmetic and stays in miles on the record")
    func milesConvertOnlyForArithmetic() throws {
        let dashboard = dashboardReport(distance: 2000, unit: .miles, odometer: 38800, day: 0)
        #expect(dashboard.remainingDistance == 2000 && dashboard.distanceUnit == .miles)
        let state = try oil([], reports: [dashboard], currentKm: 38800, day: 0)
        #expect(state.anchorKm == 38800 + 3219)
    }

    @Test("REQ-MAINT-038: an overdue reading is accepted and reads as due, in both dimensions")
    func overdueReadingIsDue() throws {
        let distance = try oil(
            [],
            reports: [dashboardReport(distance: -300, odometer: 40000, day: 0)],
            currentKm: 40000,
            day: 0
        )
        #expect(distance.status == .due && distance.remainingKm == -300)
        let days = try oil([], reports: [dashboardReport(days: -10, day: 0)], currentKm: nil, day: 0)
        #expect(days.status == .due && days.remainingDays == -10)
        try DomainCommand.recordVehicleServiceReport(.init(report: dashboardReport(
            distance: -300,
            days: -10,
            odometer: 40000,
            day: 0
        )))
        .validate(now: Fixture.date(0))
    }

    @Test(
        "REQ-MAINT-030: a reading the command cannot anchor is rejected",
        arguments: [
            (dashboardReport(day: 0), DomainCommandError.reportWithoutRemainingValue),
            (dashboardReport(distance: 3200, day: 0), .reportOdometerMissing),
            (dashboardReport(distance: 150_000, odometer: 1000, day: 0), .reportRemainingDistanceOutOfRange),
            (dashboardReport(distance: -60000, odometer: 1000, day: 0), .reportRemainingDistanceOutOfRange),
            (dashboardReport(days: 2000, day: 0), .reportRemainingDaysOutOfRange),
            (dashboardReport(days: 10, day: 5), .dateInFuture),
            (dashboardReport("", days: 10, day: 0), .emptyOperationID),
        ]
    )
    func invalidReadingIsRejected(reading: VehicleServiceReport, error: DomainCommandError) {
        #expect(throws: error) {
            try DomainCommand.recordVehicleServiceReport(.init(report: reading)).validate(now: Fixture.date(0))
        }
    }
}

@Suite("Dashboard reading on Service")
@MainActor
struct VehicleServiceReportServiceTests {
    private let now = Fixture.date(10)

    private func model(_ store: FakeCarMemoryStore) -> ServiceViewModel {
        let moment = now
        return ServiceViewModel(store: store, now: { moment })
    }

    @Test("REQ-MAINT-036: a reading keeps an untracked operation on Service until the reading is deleted")
    func untrackedOperationStaysUntilDeleted() async {
        let store = FakeCarMemoryStore(vehicle: Vehicle.provisional(id: Fixture.vehicleID))
        let service = model(store)
        #expect(await service.enterReport(
            .cabinFilter, distanceText: "", unit: .kilometers, daysText: "45", odometerText: ""
        ))
        #expect(service.state.operations.map(\.id) == [.cabinFilter])
        #expect(service.state.operations.first?.policy == nil)
        // Not tracked by a rule, so the owner can still track it with an interval of their own.
        #expect(service.state.untrackedOperations.contains(.cabinFilter))

        let operation = service.state.operations[0]
        service.requestDeleteReport(operation)
        #expect(service.state.deleteReportCandidate == .cabinFilter)
        #expect(await store.reports.count == 1)
        service.cancelDeleteReport()
        #expect(await store.reports.count == 1)
        #expect(service.state.operations.count == 1)

        service.requestDeleteReport(operation)
        #expect(await service.confirmDeleteReport(.cabinFilter))
        #expect(await store.reports.isEmpty)
        #expect(service.state.operations.isEmpty)
    }

    @Test("REQ-MAINT-036: stopping tracking keeps the operation visible while its reading remains")
    func stopTrackingKeepsReportedOperation() async {
        let store = FakeCarMemoryStore(vehicle: Vehicle.provisional(id: Fixture.vehicleID))
        let service = model(store)
        #expect(await service.track(.engineOilService, kilometersText: "15000", monthsText: ""))
        #expect(await service.enterReport(
            .engineOilService, distanceText: "3 200", unit: .kilometers, daysText: "", odometerText: "38800"
        ))
        #expect(await service.confirmStopTracking(.engineOilService))
        let operation = service.state.operations.first
        #expect(operation?.id == .engineOilService && operation?.policy == nil && operation?.report != nil)
        #expect(operation?.status == .upToDate)
    }

    @Test("REQ-MAINT-037: the sheet stores miles as entered and defaults to the newest reading's unit")
    func milesEnteredStayMiles() async {
        let store = FakeCarMemoryStore(vehicle: Vehicle.provisional(id: Fixture.vehicleID))
        let service = model(store)
        #expect(service.state.defaultReportUnit == .kilometers)
        #expect(await service.enterReport(
            .engineOilService, distanceText: "2000", unit: .miles, daysText: "", odometerText: "38800"
        ))
        let stored = await store.reports.first
        #expect(stored?.remainingDistance == 2000 && stored?.distanceUnit == .miles && stored?.odometerKm == 38800)
        #expect(service.state.defaultReportUnit == .miles)
    }

    @Test("REQ-MAINT-038: an overdue value typed with a minus sign is stored as overdue")
    func overdueTypedWithMinus() async {
        let store = FakeCarMemoryStore(vehicle: Vehicle.provisional(id: Fixture.vehicleID))
        let service = model(store)
        #expect(await service.enterReport(
            .engineOilService, distanceText: "-300", unit: .kilometers, daysText: "-5", odometerText: "40000"
        ))
        let stored = await store.reports.first
        #expect(stored?.remainingDistance == -300 && stored?.remainingDays == -5)
        #expect(service.state.operations.first?.status == .due)
    }

    @Test(
        "REQ-MAINT-030: an unusable sheet entry names the problem and writes nothing",
        arguments: [
            ("", "", "", ServiceFailure.invalidReport),
            ("3200", "", "", .reportOdometerMissing),
            ("abc", "", "38800", .invalidReport),
            ("", "5000", "", .invalidReport),
            ("3200", "", "12,5", .invalidOdometer),
        ]
    )
    func invalidEntryWritesNothing(distance: String, days: String, odometer: String, failure: ServiceFailure) async {
        let store = FakeCarMemoryStore(vehicle: Vehicle.provisional(id: Fixture.vehicleID))
        let service = model(store)
        #expect(await !service.enterReport(
            .engineOilService, distanceText: distance, unit: .kilometers, daysText: days, odometerText: odometer
        ))
        #expect(service.state.failure == failure)
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-MAINT-031: Mark done after a same-day reading supersedes it; a reading after Mark done counts")
    func sameDayOrderOnService() async {
        let store = FakeCarMemoryStore(vehicle: Vehicle.provisional(id: Fixture.vehicleID))
        let morning = Fixture.date(10)
        let afternoon = Fixture.date(10.02)
        #expect(await ServiceViewModel(store: store, now: { morning }).enterReport(
            .engineOilService, distanceText: "-300", unit: .kilometers, daysText: "", odometerText: "40000"
        ))
        let later = ServiceViewModel(store: store, now: { afternoon })
        #expect(await later.confirmDone(.engineOilService, on: afternoon, odometerText: "40050"))
        #expect(later.state.operations.first?.isReportSuperseded == true)
        #expect(later.state.operations.first?.status != .due)

        #expect(await later.enterReport(
            .engineOilService, distanceText: "15000", unit: .kilometers, daysText: "", odometerText: "40050"
        ))
        #expect(later.state.operations.first?.countingReport?.remainingDistance == 15000)
    }

    @Test("REQ-MAINT-031: marking the work done supersedes the reading on Service")
    func markDoneSupersedes() async {
        let store = FakeCarMemoryStore(vehicle: Vehicle.provisional(id: Fixture.vehicleID))
        let later = Fixture.date(11)
        let service = ServiceViewModel(store: store, now: { later })
        await store.seed(dashboardReport(distance: 3200, odometer: 38800, day: 10))
        #expect(await service.confirmDone(.engineOilService, on: later, odometerText: "39000"))
        let operation = service.state.operations.first
        #expect(operation?.isReportSuperseded == true && operation?.countingReport == nil)
        // Still listed, so the owner can delete the superseded reading.
        #expect(operation?.report != nil)
    }
}
