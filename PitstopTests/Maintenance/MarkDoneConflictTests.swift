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

            #expect(service.state.markDoneConflict == MarkDoneConflict(pitEntries: [pits]))
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
        let measured = MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService, performedAt: now, odometerKm: 85000
        )
        let unmeasured = MaintenanceCompletion(vehicleID: vehicleID, operationID: .engineOilService, performedAt: now)
        let withOdometer = MarkDoneConflict(pitEntries: [measured])
        let withoutOdometer = MarkDoneConflict(pitEntries: [unmeasured])

        #expect(withOdometer.message.contains(date))
        #expect(Self.namesOdometer(withOdometer.message))
        #expect(withoutOdometer.message.contains(date))
        #expect(withOdometer.message != withoutOdometer.message)
    }

    /// 85,000 km as any locale may write it.
    private static func namesOdometer(_ message: String) -> Bool {
        ["85000", "85,000", "85 000", "85\u{a0}000", "85\u{202f}000"].contains { message.contains($0) }
    }

    @Test("REQ-MAINT-040: with two Pit entries within a day, the prompt names both, and Replace revokes exactly those")
    func twoEntriesAreNamedAndReplaced() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        let yesterday = try await pitRecords(store, on: now - day, odometerKm: 85000)
        let today = try await pitRecords(store, on: now, odometerKm: nil)

        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000"))

        let conflict = try #require(service.state.markDoneConflict)
        #expect(Set(conflict.pitEntries.map(\.id)) == [yesterday.id, today.id])
        #expect(conflict.message.contains(yesterday.performedAt.formatted(date: .long, time: .omitted)))
        #expect(conflict.message.contains(today.performedAt.formatted(date: .long, time: .omitted)))
        #expect(Self.namesOdometer(conflict.message))
        #expect(conflict.keepTitle == "service.done.keepPits.many")
        #expect(MarkDoneConflict(pitEntries: [today]).keepTitle == "service.done.keepPits")
        let commands = await store.executed.count

        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "86000", replacingPits: true))

        let written = await Array(store.executed.dropFirst(commands))
        guard case let .replaceMaintenanceCompletion(replace) = written.first, written.count == 1 else {
            Issue.record("expected one replace command, got \(written)")
            return
        }
        #expect(replace.replacedIDs == [yesterday.id, today.id])
        #expect(await oil(store).map(\.odometerKm) == [86000])
    }

    @Test("REQ-NEW-12: a Pit entry recorded after the prompt is not replaced unseen: it asks again, writing nothing")
    func newEntryAfterThePromptAsksAgain() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        let first = try await pitRecords(store, on: now, odometerKm: 85000)
        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000"))
        let second = try await pitRecords(store, on: now - day, odometerKm: nil)
        let commands = await store.executed.count

        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000", replacingPits: true))

        #expect(await store.executed.count == commands, "nothing written")
        #expect(Set(service.state.markDoneConflict?.pitEntries.map(\.id) ?? []) == [first.id, second.id])
        #expect(service.state.markDoneConflictNotices == 2, "the new prompt is announced")
        // Replace again, now for what the prompt shows.
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "86000", replacingPits: true))
        #expect(await oil(store).map(\.odometerKm) == [86000])
    }

    @Test("REQ-NEW-12: an entry that vanished after the prompt changes the choice, so it asks again for what is left")
    func vanishedEntryAsksAgain() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        let kept = try await pitRecords(store, on: now, odometerKm: 85000)
        let gone = try await pitRecords(store, on: now - day, odometerKm: nil)
        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000"))
        _ = try await store.execute(.revokeMaintenanceCompletion(.init(completionID: gone.id)), now: now)
        let commands = await store.executed.count

        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000", replacingPits: true))

        #expect(await store.executed.count == commands, "nothing written")
        #expect(service.state.markDoneConflict?.pitEntries.map(\.id) == [kept.id])
    }

    @Test("REQ-NEW-12: Pit recording the owner's own entry after the prompt does not skip the chosen Replace")
    func identicalEntryDoesNotSkipReplace() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        let prompted = try await pitRecords(store, on: now - day, odometerKm: 85000)
        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000"))
        // Pit now records exactly what the owner typed.
        let identical = try await pitRecords(store, on: now, odometerKm: 86000)

        #expect(
            await !service.confirmDone(.engineOilService, on: now, odometerText: "86000", replacingPits: true),
            "not closed as already recorded while the prompted entry is still stored"
        )
        #expect(Set(service.state.markDoneConflict?.pitEntries.map(\.id) ?? []) == [prompted.id, identical.id])

        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "86000", replacingPits: true))
        #expect(await oil(store).map(\.odometerKm) == [86000], "one completion of the work")
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

    @Test("REQ-NEW-15: a replace that cannot be stored keeps Pit's entry, stores nothing of the owner's and says so")
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

    @Test("REQ-NEW-13: undo after Replace removes only the owner's entry and does not bring Pit's back")
    func undoAfterReplaceDoesNotRestorePits() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        try await pitRecords(store, on: now, odometerKm: 85000)
        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000"))
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "86000", replacingPits: true))
        let replaced = try #require(service.state.operations.first { $0.id == .engineOilService })

        #expect(await service.undoLastCompletion(of: replaced))

        #expect(await oil(store).isEmpty, "Pit's replaced entry stays revoked (ADR 0010 undo)")
        #expect(service.state.operations.first { $0.id == .engineOilService }?.lastCompletion == nil)
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
        #expect(code.contains("Button(conflict.keepTitle)"))
        #expect(code.contains("Button(\"service.done.replaceWithMine\")"))
        #expect(!code.contains("saveAnyway"))
        #expect(!code.contains("anyway"))
        let service = try PitInSheetTests.source("Pitstop/Features/Service/ServiceView.swift")
        #expect(service.contains("onKeepPits: viewModel.keepPitsEntry"))
        #expect(!service.contains("anyway"))
    }

    @Test("REQ-NEW-9: the list only states that Pit's entry was kept and the owner's was not saved, in en, ru and uk")
    func listStatesPitsEntryKept() throws {
        let code = try PitInSheetTests.source("Pitstop/Features/Service/ServiceView.swift")
        #expect(code.contains("case .pitAlreadyRecorded: \"service.failure.pitEntryKept\""))
        let catalog = try PitInSheetTests.source("Pitstop/Resources/Localizations/Localizable.xcstrings")
        let root = try #require(JSONSerialization.jsonObject(with: Data(catalog.utf8)) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])
        let entry = try #require(strings["service.failure.pitEntryKept"] as? [String: Any])
        let localizations = try #require(entry["localizations"] as? [String: [String: [String: String]]])
        #expect(Set(localizations.keys) == ["en", "ru", "uk"])
        // A fact, not advice: "undo the last done" can point at another completion (REQ-NEW-9).
        let english = try #require(localizations["en"]?["stringUnit"]?["value"])
        #expect(!english.localizedCaseInsensitiveContains("undo"))
    }
}
