import Foundation
@testable import Pitstop
import Testing

// Every car, mileage and date here is fictional (ADR 0035 worked example, scaled to the fixture clock).

private typealias Fixture = MaintenanceFixture

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
        #expect(
            await service.enterReport(
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
        #expect(
            await service.enterReport(
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
        #expect(
            await service.enterReport(
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
        #expect(
            await service.enterReport(
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
        #expect(
            await !service.enterReport(
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
        #expect(
            await ServiceViewModel(store: store, now: { morning }).enterReport(
                .engineOilService, distanceText: "-300", unit: .kilometers, daysText: "", odometerText: "40000"
            ))
        let later = ServiceViewModel(store: store, now: { afternoon })
        #expect(await later.confirmDone(.engineOilService, on: afternoon, odometerText: "40050"))
        #expect(later.state.operations.first?.isReportSuperseded == true)
        #expect(later.state.operations.first?.status != .due)

        #expect(
            await later.enterReport(
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
