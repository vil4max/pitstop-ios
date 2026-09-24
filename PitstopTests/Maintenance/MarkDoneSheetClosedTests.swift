import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate

/// The sheet locks Cancel and swipe-to-dismiss while its save runs (ADR 0032), but the app itself can still close it,
/// and Mark as done may then open for other work before the first save returns. That save belongs to a sheet that is
/// gone, so it must leave the open sheet's snapshot and message alone, and still record the owner's work or say on the
/// list that it did not (REQ-MAINT-040, proposed). The tests close the sheet by opening the next one or directly.
@MainActor
@Suite("Mark as done after its sheet closed")
struct MarkDoneSheetClosedTests {
    private func openedService(_ store: HeldStore) async -> ServiceViewModel {
        let service = ServiceViewModel(store: store, now: { now })
        await service.load()
        return service
    }

    /// Opens Mark as done as Service does: the read becomes the sheet's snapshot.
    private func openMarkDone(_ service: ServiceViewModel, _ operation: MaintenanceOperationID) async {
        #expect(await service.openMarkDone(service.readMarkDoneOpening(operation)))
    }

    /// Pit records this work today over the open sheet, as a confirmed capture is stored.
    private func pitRecords(
        _ operation: MaintenanceOperationID,
        odometerKm: Int?,
        in store: HeldStore
    ) async throws {
        let vehicleID = await store.base.vehicle.id
        try await store.base.execute(.confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
            vehicleID: vehicleID, operationID: operation, performedAt: now, odometerKm: odometerKm
        ))), now: now)
    }

    /// The owner confirms oil and the save stops at the store, as a slow write does. Returns the running save.
    private func confirmOilAndHold(
        _ service: ServiceViewModel,
        _ store: HeldStore,
        at call: HeldStore.Call,
        odometerText: String
    ) async -> Task<Bool, Never> {
        await store.hold(call)
        let save = Task { await service.confirmDone(.engineOilService, on: now, odometerText: odometerText) }
        await store.waitUntilHeld()
        return save
    }

    @Test(
        "REQ-MAINT-040: an oil save that returns after the cabin filter sheet opened keeps that sheet's snapshot and message"
    )
    func lateSaveKeepsTheNextSheetsState() async throws {
        let store = HeldStore()
        let service = await openedService(store)
        await openMarkDone(service, .engineOilService)
        let oilSave = await confirmOilAndHold(service, store, at: .write, odometerText: "")

        // The oil sheet closes while it saves, and the owner opens Mark as done for the cabin filter. Pit records
        // today's cabin filter change over it, and the owner's odometer differs, so the sheet says Pit saved it.
        await openMarkDone(service, .cabinFilter)
        try await pitRecords(.cabinFilter, odometerKm: nil, in: store)
        #expect(await !service.confirmDone(.cabinFilter, on: now, odometerText: "30000"))
        #expect(service.state.isMarkDoneAlreadyRecorded)

        await store.release()
        _ = await oilSave.value

        #expect(service.state.isMarkDoneAlreadyRecorded, "the cabin filter sheet still says Pit saved this")
        #expect(service.state.failure == nil)
        // The cabin filter sheet kept its snapshot: with the odometer cleared, Pit's record is not repeated.
        service.markDoneInputChanged()
        #expect(await service.confirmDone(.cabinFilter, on: now, odometerText: ""))
        #expect(await store.base.completions.count { $0.operationID == .cabinFilter } == 1)
    }

    @Test("REQ-MAINT-040: a late \"Pit already saved this\" from a closed sheet shows nothing in the sheet open now")
    func lateAlreadyRecordedStaysOutOfTheNextSheet() async throws {
        let store = HeldStore()
        let service = await openedService(store)
        await openMarkDone(service, .engineOilService)
        try await pitRecords(.engineOilService, odometerKm: nil, in: store)
        // The owner's odometer differs from Pit's record; the recheck read is slow.
        let oilSave = await confirmOilAndHold(service, store, at: .completionsRead, odometerText: "86000")

        await openMarkDone(service, .cabinFilter)
        let notices = service.state.markDoneAlreadyRecordedNotices
        await store.release()

        #expect(await !oilSave.value)
        #expect(!service.state.isMarkDoneAlreadyRecorded, "the cabin filter sheet shows no message about oil")
        #expect(service.state.markDoneAlreadyRecordedNotices == notices, "and announces none")
        #expect(service.state.failure == nil)
        // The owner's entry was not recorded, and the list says Pit's record is why.
        #expect(service.state.listFailure == .pitAlreadyRecorded)
        #expect(await store.base.completions.count { $0.operationID == .engineOilService } == 1, "only Pit's")
    }

    @Test("REQ-MAINT-040: the owner's work from a sheet that closed while saving is recorded once, even if saved again")
    func closedSheetsSaveIsRecordedOnce() async {
        let store = HeldStore()
        let service = await openedService(store)
        #expect(await service.track(.engineOilService, kilometersText: "10000", monthsText: "12"))
        await openMarkDone(service, .engineOilService)
        let oilSave = await confirmOilAndHold(service, store, at: .write, odometerText: "85000")

        // The sheet closes while it saves; unsure the save went through, the owner marks the oil change again.
        await openMarkDone(service, .engineOilService)
        await store.release()
        #expect(await !oilSave.value, "the closed sheet's save cannot close the sheet open now")

        #expect(service.state.operations.first { $0.id == .engineOilService }?.lastCompletion?.odometerKm == 85000)
        #expect(service.state.listFailure == nil && service.state.failure == nil)
        // The open sheet's snapshot predates the first save, so that save counts as already recorded.
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "85000"))
        let oil = await store.base.completions.filter { $0.operationID == .engineOilService }
        #expect(oil.map(\.odometerKm) == [85000])
    }

    @Test("REQ-MAINT-040: a save that fails after its sheet closed says so on the list, not in a later sheet")
    func closedSheetsFailureIsOnTheList() async {
        let store = HeldStore()
        let service = await openedService(store)
        await openMarkDone(service, .engineOilService)
        let oilSave = await confirmOilAndHold(service, store, at: .write, odometerText: "85000")

        // The sheet closes and nothing else opens; the write then fails.
        service.markDoneClosed()
        await store.base.failCommands()
        await store.release()

        #expect(await !oilSave.value)
        #expect(service.state.listFailure == .notSaved)
        #expect(service.state.failure == nil, "no sheet is open to show it, and the next one is about other work")
        #expect(await store.base.completions.isEmpty)
    }

    @Test(
        "REQ-MAINT-040: an entry a closed sheet could not ask about is reported as Pit's record, with the list reloaded"
    )
    func closedSheetsConflictNamesPitsRecord() async throws {
        let store = HeldStore()
        let service = await openedService(store)
        #expect(await service.track(.engineOilService, kilometersText: "10000", monthsText: "12"))
        await openMarkDone(service, .engineOilService)
        // Siri saves Pit's record without reloading Service; the owner's odometer differs and the recheck is slow.
        try await pitRecords(.engineOilService, odometerKm: nil, in: store)
        let oilSave = await confirmOilAndHold(service, store, at: .completionsRead, odometerText: "86000")

        service.markDoneClosed()
        await store.release()

        #expect(await !oilSave.value)
        // Not "try again": a retry would record Pit's work a second time without asking.
        #expect(service.state.listFailure == .pitAlreadyRecorded)
        #expect(service.state.operations.first { $0.id == .engineOilService }?.lastCompletion != nil,
                "the list shows Pit's record before the owner decides whether to mark it again")
        #expect(await store.base.completions.count == 1, "only Pit's")
    }

    @Test("REQ-MAINT-040: Service tells the view model when a Mark as done sheet closes, however it closes")
    func serviceReportsTheSheetClosing() throws {
        let code = try PitInSheetTests.source("Pitstop/Features/Service/ServiceView.swift").split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(code.contains(".pitSheet(item: sheetBinding)"))
        #expect(!code.contains(".pitSheet(item: $sheet)"), "a close that skips the binding would go unreported")
        let setter = try #require(code.range(of: "private var sheetBinding: Binding<ServiceSheet?>"))
        let body = code[setter.upperBound...].prefix(300)
        #expect(body.contains("if case .done = sheet, newValue != sheet {"))
        #expect(body.contains("viewModel.markDoneClosed()"))
    }

    @Test("REQ-MAINT-040, ADR-0032: the owner cannot close Mark as done while its save runs, by Cancel or a swipe")
    func sheetLocksWhileSaving() throws {
        let code = try PitInSheetTests.source("Pitstop/Features/Service/MarkDoneView.swift").split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(code.contains(".interactiveDismissDisabled(isSaving)"))
        let cancel = try #require(code.range(of: "Button(\"common.cancel\", role: .cancel) { dismiss() }"))
        #expect(code[cancel.upperBound...].prefix(80).contains(".disabled(isSaving)"))
    }
}

/// The in-memory store, with one chosen call held until the test releases it, as a slow disk would.
actor HeldStore: CarMemoryStore {
    enum Call {
        case write
        case completionsRead
    }

    let base = FakeCarMemoryStore()
    private var heldCall: Call?
    private var held: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?

    /// The next such call waits for `release()`.
    func hold(_ call: Call) {
        heldCall = call
    }

    func waitUntilHeld() async {
        guard held == nil else { return }
        await withCheckedContinuation { arrival = $0 }
    }

    func release() {
        held?.resume()
        held = nil
    }

    private func pass(_ call: Call) async {
        guard heldCall == call else { return }
        heldCall = nil
        await withCheckedContinuation { continuation in
            held = continuation
            arrival?.resume()
            arrival = nil
        }
    }

    func currentVehicle() async throws(CarMemoryStoreError) -> Vehicle {
        try await base.currentVehicle()
    }

    func odometerReadings() async throws(CarMemoryStoreError) -> [OdometerReading] {
        try await base.odometerReadings()
    }

    func notes() async throws(CarMemoryStoreError) -> [Note] {
        try await base.notes()
    }

    func historyEvents() async throws(CarMemoryStoreError) -> [HistoryEvent] {
        try await base.historyEvents()
    }

    func maintenancePolicies() async throws(CarMemoryStoreError) -> [MaintenancePolicy] {
        try await base.maintenancePolicies()
    }

    func maintenanceCompletions() async throws(CarMemoryStoreError) -> [MaintenanceCompletion] {
        await pass(.completionsRead)
        return try await base.maintenanceCompletions()
    }

    func plannedEvents() async throws(CarMemoryStoreError) -> [PlannedDatedEvent] {
        try await base.plannedEvents()
    }

    func vehicleServiceReports() async throws(CarMemoryStoreError) -> [VehicleServiceReport] {
        try await base.vehicleServiceReports()
    }

    @discardableResult
    func execute(_ command: DomainCommand, now: Date) async throws(CarMemoryStoreError) -> CommandResult {
        await pass(.write)
        return try await base.execute(command, now: now)
    }
}
