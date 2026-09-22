import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(30 * 86400)

@MainActor
@Suite("Service view model")
struct ServiceViewModelTests {
    private func makeModel(_ store: FakeCarMemoryStore) -> ServiceViewModel {
        ServiceViewModel(store: store, now: { now })
    }

    @Test("REQ-BOARD-014: with nothing tracked there are no operations, no scope, and no urgency")
    func nothingTrackedIsCalm() async {
        let model = makeModel(FakeCarMemoryStore())
        await model.load()
        #expect(model.state.operations.isEmpty && model.state.scope.isEmpty)
        #expect(model.state.untrackedOperations == MaintenanceOperationID.catalog)
    }

    @Test("REQ-MAINT-017: tracking an operation needs no baseline and starts as unknown")
    func trackingStartsUnknown() async throws {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)

        #expect(await model.track(.engineOilService, kilometersText: "10 000", monthsText: ""))

        let operation = try #require(model.state.operations.first)
        #expect(operation.status == .unknown && operation.policy?.source == .userCustom)
        #expect(operation.policy?.distanceIntervalKm == 10000 && operation.policy?.timeIntervalMonths == nil)
        #expect(!model.state.untrackedOperations.contains(.engineOilService))
    }

    @Test(
        "ADR-0010: an interval must be a positive whole number in at least one dimension",
        arguments: [("", ""), ("0", ""), ("", "0"), ("abc", "12"), ("10000", "1.5"), ("-5", "")]
    )
    func invalidIntervalIsRejected(kilometers: String, months: String) async {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        #expect(await !model.track(.brakeFluid, kilometersText: kilometers, monthsText: months))
        #expect(model.state.failure == .invalidInterval)
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-DOMAIN-007: confirming work starts the cycle from that completion and records nothing else")
    func confirmingWorkStartsCycle() async throws {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        let vehicleID = await store.vehicle.id
        _ = try await store.execute(
            .recordOdometerReading(.init(reading: OdometerReading(
                vehicleID: vehicleID,
                value: 84500,
                recordedAt: now
            ))),
            now: now
        )
        #expect(await model.track(.engineOilService, kilometersText: "10000", monthsText: "12"))
        #expect(await model.track(.dsgService, kilometersText: "60000", monthsText: ""))

        #expect(await model.confirmDone(.engineOilService, on: now.addingTimeInterval(-86400), odometerText: "84 200"))

        let oil = try #require(model.state.operations.first { $0.id == .engineOilService })
        #expect(oil.status == .upToDate && oil.anchorKm == 94200 && oil.remainingKm == 9700)
        #expect(model.state.operations.first { $0.id == .dsgService }?.status == .unknown)
        #expect(await store.completions.count == 1)
        #expect(await store.events.isEmpty)
    }

    @Test("ADR-0006: work dated in the future cannot be confirmed as done")
    func futureWorkIsNotConfirmed() async {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        #expect(await !model.confirmDone(.brakeFluid, on: now.addingTimeInterval(3 * 86400), odometerText: ""))
        #expect(model.state.failure == .futureDate)
        #expect(await store.completions.isEmpty)
    }

    @Test("REQ-CAPTURE-009: a failed save is reported and changes no state")
    func failedSaveIsReported() async {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        await store.failEverything()
        #expect(await !model.track(.airFilter, kilometersText: "30000", monthsText: ""))
        #expect(model.state.failure == .notSaved && model.state.operations.isEmpty)
    }

    @Test("REQ-BOARD-015: the Service tile state comes from recorded facts and never invents a baseline")
    func tileStateNeverInventsBaseline() async throws {
        let store = FakeCarMemoryStore()
        let board = CarBoardViewModel(store: store, now: { now })
        #expect(await makeModel(store).track(.engineOilService, kilometersText: "10000", monthsText: ""))

        await board.load()

        let tile = try #require(board.state.service.first)
        #expect(tile.status == .unknown && tile.lastCompletion == nil && tile.remainingKm == nil)
    }

    @Test("ADR-0010: a confirmation made by mistake can be undone and the cycle returns to what was known")
    func mistakenConfirmationCanBeUndone() async throws {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        #expect(await model.track(.engineOilService, kilometersText: "10000", monthsText: ""))
        #expect(await model.confirmDone(.engineOilService, on: now, odometerText: "845000"))
        let wrong = try #require(model.state.operations.first)
        #expect(wrong.anchorKm == 855_000)

        #expect(await model.undoLastCompletion(of: wrong))

        #expect(model.state.operations.first?.status == .unknown)
        #expect(await store.completions.isEmpty)
    }

    @Test("REQ-DOMAIN-006: changing the interval of a tracked operation replaces the owner's own policy only")
    func intervalCanBeChanged() async {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        #expect(await model.track(.engineOilService, kilometersText: "10000", monthsText: ""))
        #expect(await model.track(.engineOilService, kilometersText: "7500", monthsText: "6"))

        let policies = await store.policies
        #expect(policies.count == 1)
        #expect(policies.first?.distanceIntervalKm == 7500 && policies.first?.timeIntervalMonths == 6)
    }

    @Test("ADR-0010: marking work done at a mileage above the last reading does not inflate what remains")
    func completionAboveReadingIsNotInflated() async throws {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        let vehicleID = await store.vehicle.id
        let old = OdometerReading(vehicleID: vehicleID, value: 68500, recordedAt: now.addingTimeInterval(-60 * 86400))
        _ = try await store.execute(.recordOdometerReading(.init(reading: old)), now: now)
        #expect(await model.track(.engineOilService, kilometersText: "10000", monthsText: ""))

        #expect(await model.confirmDone(.engineOilService, on: now, odometerText: "70000"))

        let oil = try #require(model.state.operations.first)
        #expect(oil.remainingKm == 10000 && oil.status == .upToDate)
    }

    @Test("REQ-CAPTURE-009: a failed undo is reported on the list and never leaks into the next sheet")
    func failedUndoIsReportedOnTheList() async throws {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        #expect(await model.track(.brakeFluid, kilometersText: "", monthsText: "24"))
        #expect(await model.confirmDone(.brakeFluid, on: now, odometerText: ""))
        let operation = try #require(model.state.operations.first)
        await store.failEverything()

        #expect(await !model.undoLastCompletion(of: operation))

        #expect(model.state.listFailure == .notSaved && model.state.failure == nil)
    }
}
