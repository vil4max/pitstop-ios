import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate
private let day: TimeInterval = 86400

/// Pit recording the same work while Mark as done is open is a merge conflict with one resolution: the owner keeps
/// Pit's entry or replaces it with their own. Nothing ever stores both (REQ-MAINT-040, proposed).
@MainActor
@Suite("Mark as done conflict with Pit's entry")
struct MarkDoneConflictTests {
    private func openedService(_ store: FakeCarMemoryStore) async -> ServiceViewModel {
        let service = TestViewModels.service(store, now: now)
        #expect(await service.track(.engineOilService, kilometersText: "10000", monthsText: "12"))
        #expect(await service.openMarkDone(service.readMarkDoneOpening(.engineOilService)))
        return service
    }

    /// Pit's own completion of the oil change, stored while the sheet is open, as a confirmed capture is.
    @discardableResult
    private func pitRecords(_ store: FakeCarMemoryStore, on date: Date, odometerKm: Int?) async throws
        -> MaintenanceCompletion
    {
        let completion = await MaintenanceCompletion(
            vehicleID: store.vehicle.id, operationID: .engineOilService, performedAt: date, odometerKm: odometerKm
        )
        _ = try await store.execute(.confirmMaintenanceCompletion(.init(completion: completion)), now: now)
        return completion
    }

    private func oil(_ store: FakeCarMemoryStore) async -> [MaintenanceCompletion] {
        await store.completions.filter { $0.operationID == .engineOilService }
    }

    @Test("REQ-MAINT-040: Pit's entry a day away from the owner's date is the same work, so the owner is asked")
    func entryWithinADayAsks() async throws {
        for (pitsDate, ownersDate) in [(now, now - day), (now - day, now)] {
            let store = FakeCarMemoryStore()
            let service = await openedService(store)
            let pits = try await pitRecords(store, on: pitsDate, odometerKm: nil)
            let commands = await store.executed.count

            #expect(await !service.confirmDone(.engineOilService, on: ownersDate, odometerText: ""))

            #expect(service.state.markDoneConflict == MarkDoneConflict(pitEntry: pits))
            #expect(service.state.markDoneConflictNotices == 1)
            #expect(service.state.failure == nil)
            #expect(await store.executed.count == commands, "nothing written before the owner decides")
        }
    }

    @Test("REQ-NEW-5: Pit's entry two days away from the owner's date is other work, and both are recorded")
    func entryTwoDaysAwayIsOtherWork() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        try await pitRecords(store, on: now - 2 * day, odometerKm: nil)

        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: ""))

        #expect(await oil(store).count == 2)
        #expect(service.state.markDoneConflict == nil)
    }

    @Test("REQ-MAINT-040: the prompt names the date of Pit's entry and its odometer when it has one")
    func promptNamesPitsEntry() {
        let vehicleID = VehicleID()
        let date = now.formatted(date: .long, time: .omitted)
        let withOdometer = MarkDoneConflict(pitEntry: MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService, performedAt: now, odometerKm: 85000
        ))
        let withoutOdometer = MarkDoneConflict(pitEntry: MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService, performedAt: now
        ))

        #expect(withOdometer.message.contains(date))
        #expect(withOdometer.message.contains("85000") || withOdometer.message.contains("85,000")
            || withOdometer.message.contains("85 000") || withOdometer.message.contains("85\u{a0}000"))
        #expect(withoutOdometer.message.contains(date))
        #expect(withOdometer.message != withoutOdometer.message)
    }

    @Test("REQ-NEW-2: keeping Pit's entry records nothing from the sheet, closes it and shows Pit's entry")
    func keepPitsEntry() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        let pits = try await pitRecords(store, on: now, odometerKm: 85000)
        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000"))
        let commands = await store.executed.count

        #expect(await service.keepPitsEntry(), "the sheet closes as saved")

        #expect(await oil(store) == [pits])
        #expect(await store.executed.count == commands, "the owner's entry is not written")
        #expect(service.state.markDoneConflict == nil && service.state.failure == nil)
        #expect(service.state.operations.first { $0.id == .engineOilService }?.lastCompletion == pits)
    }

    @Test("REQ-NEW-3: replacing Pit's entry leaves only the owner's, written as one replace command")
    func replaceWithMine() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        let pits = try await pitRecords(store, on: now, odometerKm: 85000)
        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000"))
        let commands = await store.executed.count

        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "86000", replacingPits: true))

        let written = await Array(store.executed.dropFirst(commands))
        #expect(written.count == 1, "one command, so one store transaction")
        guard case let .replaceMaintenanceCompletion(replace) = written.first else {
            Issue.record("expected a replace command, got \(written)")
            return
        }
        #expect(replace.replacedIDs == [pits.id])
        #expect(await oil(store).map(\.odometerKm) == [86000])
        #expect(service.state.markDoneConflict == nil && service.state.failure == nil)
        #expect(service.state.operations.first { $0.id == .engineOilService }?.lastCompletion?.odometerKm == 86000)
    }

    @Test("REQ-NEW-3: a replace that cannot be stored keeps Pit's entry, stores nothing of the owner's and says so")
    func failedReplaceKeepsPitsEntry() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        let pits = try await pitRecords(store, on: now, odometerKm: 85000)
        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000"))
        await store.failCommands()

        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000", replacingPits: true))

        #expect(await oil(store) == [pits])
        #expect(service.state.failure == .notSaved, "the open sheet says nothing was saved")
    }

    @Test("REQ-NEW-3: Replace rechecks what is stored: with Pit's entry gone, the owner's is recorded alone")
    func replaceRechecksTheStore() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        let pits = try await pitRecords(store, on: now, odometerKm: 85000)
        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000"))
        _ = try await store.execute(.revokeMaintenanceCompletion(.init(completionID: pits.id)), now: now)

        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "86000", replacingPits: true))

        #expect(await oil(store).map(\.odometerKm) == [86000])
    }

    @Test("REQ-NEW-8: when Replace cannot read the store, nothing is written and the sheet says it was not saved")
    func replaceOverUnreadableStore() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        try await pitRecords(store, on: now, odometerKm: 85000)
        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000"))
        let commands = await store.executed.count
        await store.failEverything()

        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000", replacingPits: true))

        await store.recover()
        #expect(await store.executed.count == commands)
        #expect(service.state.failure == .notSaved)
    }

    @Test("REQ-MAINT-040: the sheet offers only Keep Pit's entry and Replace with mine, never Save anyway")
    func sheetOffersTheTwoChoices() throws {
        let code = try PitInSheetTests.source("Pitstop/Features/Service/MarkDoneView.swift").split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(code.contains("Button(\"service.done.keepPits\")"))
        #expect(code.contains("Button(\"service.done.replaceWithMine\")"))
        #expect(!code.contains("saveAnyway"))
        #expect(!code.contains("anyway"))
        let service = try PitInSheetTests.source("Pitstop/Features/Service/ServiceView.swift")
        #expect(service.contains("onKeepPits: viewModel.keepPitsEntry"))
        #expect(!service.contains("anyway"))
    }

    @Test("REQ-NEW-9: the list names Pit's kept record in words that do not invite recording both")
    func listNamesPitsKeptRecord() throws {
        let code = try PitInSheetTests.source("Pitstop/Features/Service/ServiceView.swift")
        #expect(code.contains("case .pitAlreadyRecorded: \"service.failure.pitRecordKept\""))
    }
}
