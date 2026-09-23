import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate
private let day: TimeInterval = 86400

/// A capture over "Mark as done" keeps the duplicate rules: the editor rechecks what is stored before it saves
/// (pit-behavior-and-motion.md, "Availability"; REQ-PIT-026; proposed as REQ-MAINT-040). Only a completion recorded
/// while the sheet is open can be the same one, as a dashboard reading tells completions apart by what existed at its
/// entry (ADR 0035).
@MainActor
@Suite("Mark as done after a capture")
struct MarkDoneAfterCaptureTests {
    /// Pit records "changed the oil at 85000" today while the Mark as done sheet is open underneath.
    private func captureOilChange(_ store: FakeCarMemoryStore) async throws {
        let entry = try PitInSheetTests.entry(store)
        let sheet = PitCaptureEntry.Host.sheet(UUID())
        #expect(entry.open(from: sheet))
        entry.capture.text = "поменял масло на 85000"
        await entry.capture.submit(from: .service)
        await entry.capture.confirm()
        #expect(entry.capture.phase == .saved(.service, preservedRaw: false))
        entry.close(from: sheet)
    }

    /// Opens Mark as done as Service does when no other sheet is open: the read becomes the sheet's snapshot.
    private func openMarkDone(_ service: ServiceViewModel, _ operation: MaintenanceOperationID) async {
        await service.openMarkDone(service.readMarkDoneOpening(operation))
    }

    private func openedService(_ store: FakeCarMemoryStore) async -> ServiceViewModel {
        let service = TestViewModels.service(store, now: now)
        await service.load()
        return service
    }

    /// What Pit writes while the sheet is open: its own completion of the work, as the store holds a confirmed capture.
    private func pitRecords(_ store: FakeCarMemoryStore, on date: Date, odometerKm: Int?) async throws {
        let vehicleID = await store.vehicle.id
        try await store.execute(.confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService, performedAt: date, odometerKm: odometerKm
        ))), now: now)
    }

    @Test(
        "REQ-MAINT-040: the same work, date and odometer captured over Mark as done is recorded once and nothing is lost"
    )
    func sameEntryIsRecordedOnce() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        await openMarkDone(service, .engineOilService)
        try await captureOilChange(store)
        let captured = await store.completions
        #expect(captured.count == 1 && captured.first?.odometerKm == 85000)

        // The sheet holds what Pit already stored, so success closes it with nothing dropped.
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "85 000"))

        #expect(await store.completions == captured)
        #expect(await store.executed.count == 1, "the editor wrote nothing")
        #expect(service.state.failure == nil && !service.state.isMarkDoneAlreadyRecorded)
    }

    @Test("REQ-MAINT-040: with no odometer typed, the same work and date captured over Mark as done is recorded once")
    func emptyOdometerIsRecordedOnce() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        await openMarkDone(service, .engineOilService)
        try await captureOilChange(store)

        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: ""))

        #expect(await store.completions.count == 1)
    }

    @Test("REQ-MAINT-040: a different odometer for the same work and date keeps the sheet open until the owner decides")
    func differentOdometerAsksTheOwner() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        await openMarkDone(service, .engineOilService)
        try await captureOilChange(store)

        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000"))
        #expect(service.state.isMarkDoneAlreadyRecorded)
        #expect(service.state.failure == nil)
        #expect(await store.completions.count == 1, "nothing written before the owner decides")

        // "Save anyway": the owner's entry is recorded as well.
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "86000", anyway: true))
        #expect(await store.completions.map(\.odometerKm).sorted { ($0 ?? 0) < ($1 ?? 0) } == [85000, 86000])
        #expect(!service.state.isMarkDoneAlreadyRecorded)
    }

    @Test("REQ-MAINT-040: every time the sheet has to say Pit already saved the work, it is announced to VoiceOver")
    func alreadyRecordedIsAnnounced() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        await openMarkDone(service, .engineOilService)
        try await captureOilChange(store)
        #expect(service.state.markDoneAlreadyRecordedNotices == 0)

        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000"))
        #expect(service.state.markDoneAlreadyRecordedNotices == 1)
        // Confirming again with another odometer says it again, although the message is already shown.
        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "87000"))
        #expect(service.state.markDoneAlreadyRecordedNotices == 2)

        // The sheet speaks each notice, and its view reads the count Service passes in.
        let code = try PitInSheetTests.source("Pitstop/Features/Service/MarkDoneView.swift").split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        let change = try #require(code.range(of: ".onChange(of: alreadyRecordedNotices)"))
        #expect(code[change.upperBound...].prefix(200).contains(
            "AccessibilityNotification.Announcement(String(localized: \"service.done.alreadyRecorded\")).post()"
        ))
        #expect(try PitInSheetTests.source("Pitstop/Features/Service/ServiceView.swift")
            .contains("alreadyRecordedNotices: viewModel.state.markDoneAlreadyRecordedNotices"))
    }

    @Test("REQ-MAINT-040: after the message, an entry edited to match Pit's is not recorded twice, even on Save anyway")
    func editedEntryIsRechecked() async throws {
        for edited in ["85000", ""] {
            let store = FakeCarMemoryStore()
            let service = await openedService(store)
            await openMarkDone(service, .engineOilService)
            try await captureOilChange(store)
            #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000"))
            #expect(service.state.isMarkDoneAlreadyRecorded)

            // The owner corrects the field: the message spoke of 86000, so it goes.
            service.markDoneInputChanged()
            #expect(!service.state.isMarkDoneAlreadyRecorded)
            #expect(await service.confirmDone(.engineOilService, on: now, odometerText: edited, anyway: true))

            #expect(await store.completions.count == 1, "\(edited.isEmpty ? "cleared" : edited) matches Pit's record")
            #expect(!service.state.isMarkDoneAlreadyRecorded)
        }
    }

    @Test("REQ-MAINT-040: the sheet reports every edit of the date or the odometer, so a stale message goes")
    func editsClearTheMessage() throws {
        let code = try PitInSheetTests.source("Pitstop/Features/Service/MarkDoneView.swift").split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(code.contains(".onChange(of: date) { onEdit() }"))
        #expect(code.contains(".onChange(of: odometer) { onEdit() }"))
        #expect(try PitInSheetTests.source("Pitstop/Features/Service/ServiceView.swift")
            .contains("onEdit: viewModel.markDoneInputChanged"))
    }

    @Test("REQ-MAINT-040: a sheet opened while the store cannot be read saves as before, with no recheck")
    func unreadableAtOpeningSavesWithoutRecheck() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        // Siri saves while Service stays on screen, so Service's last load does not have it.
        try await pitRecords(store, on: now, odometerKm: 84000)
        await store.failEverything()
        await openMarkDone(service, .engineOilService)
        await store.recover()

        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: ""))

        // Without a trustworthy snapshot nothing is taken for Pit's: the owner's completion is recorded.
        #expect(await store.completions.count == 2)
        #expect(!service.state.isMarkDoneAlreadyRecorded)
    }

    @Test(
        "REQ-MAINT-040: a Mark as done read that loses to an open sheet leaves that sheet's snapshot and message alone"
    )
    func losingReadLeavesTheOpenSheetAlone() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        // Mark as done is tapped on oil, then on the cabin filter, before the first read returns. Oil's read opens
        // its sheet; the cabin filter's read lands next, finds a sheet open and is dropped.
        let oil = await service.readMarkDoneOpening(.engineOilService)
        _ = await service.readMarkDoneOpening(.cabinFilter)
        service.openMarkDone(oil)
        try await captureOilChange(store)

        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "86000"))
        #expect(service.state.isMarkDoneAlreadyRecorded)
        // Another late read, after the message appeared, changes nothing either.
        _ = await service.readMarkDoneOpening(.cabinFilter)
        #expect(service.state.isMarkDoneAlreadyRecorded)
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: ""))
        #expect(await store.completions.count == 1, "the oil sheet kept its snapshot: Pit's work is not recorded twice")

        // Service commits a read only when it opens the sheet, and has nothing that could clear another sheet's state.
        let code = try PitInSheetTests.source("Pitstop/Features/Service/ServiceView.swift").split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        let read = try #require(code.range(of: "let opening = await viewModel.readMarkDoneOpening(operation.id)"))
        let after = code[read.upperBound...].prefix(200)
        let guardRange = try #require(after.range(of: "guard sheet == nil else { return }"))
        let open = try #require(after.range(of: "viewModel.openMarkDone(opening)"))
        #expect(guardRange.upperBound <= open.lowerBound)
        #expect(!code.contains("cancelMarkDone"))
    }

    @Test("REQ-MAINT-040: an odometer typed where Pit recorded none for the same date is never dropped silently")
    func odometerPitLackedAsksTheOwner() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        await openMarkDone(service, .engineOilService)
        try await pitRecords(store, on: now, odometerKm: nil)

        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: "85000"))

        #expect(service.state.isMarkDoneAlreadyRecorded)
        #expect(await store.completions.count == 1)
    }

    @Test("REQ-MAINT-040: work Pit recorded for another date while Mark as done is open does not replace the owner's")
    func captureOnAnotherDayIsNotTheSameWork() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        await openMarkDone(service, .engineOilService)
        // "Changed the oil in March", told to Pit over the sheet.
        try await pitRecords(store, on: now - 60 * day, odometerKm: nil)

        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "85000"))

        let completions = await store.completions
        #expect(completions.count == 2)
        #expect(completions.contains { $0.odometerKm == 85000 && Calendar.current.isDate(
            $0.performedAt,
            inSameDayAs: now
        ) })
    }

    @Test("REQ-MAINT-040: a completion stored after Service last loaded but before the sheet opened is not Pit's")
    func completionBeforeOpeningIsNotPits() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        // Siri saves while the app stays on Service, so Service is not reloaded.
        try await pitRecords(store, on: now, odometerKm: 84000)

        await openMarkDone(service, .engineOilService)
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "85000"))

        #expect(await store.completions.count == 2)
        #expect(!service.state.isMarkDoneAlreadyRecorded)
    }

    @Test("REQ-MAINT-040: without a capture, a second Mark as done on the same day is recorded as the owner asked")
    func deliberateRepeatIsRecorded() async {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        await openMarkDone(service, .engineOilService)
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: ""))

        // The owner opens it again the same day to add the odometer.
        await openMarkDone(service, .engineOilService)
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "85000"))

        let completions = await store.completions
        #expect(completions.count == 2)
        #expect(completions.contains { $0.odometerKm == 85000 })
    }

    @Test("REQ-MAINT-031: Mark as done opened after a same-day reading still records the work and supersedes it")
    func sameDayMarkDoneSupersedesAReading() async {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        await openMarkDone(service, .engineOilService)
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "84000"))
        let later = now + 0.02 * day
        let afterReading = TestViewModels.service(store, now: later)
        #expect(await afterReading.enterReport(
            .engineOilService, distanceText: "-300", unit: .kilometers, daysText: "", odometerText: "84000"
        ))
        #expect(afterReading.state.operations.first?.countingReport != nil)

        await openMarkDone(afterReading, .engineOilService)
        #expect(await afterReading.confirmDone(.engineOilService, on: later, odometerText: "84050"))

        #expect(await store.completions.count == 2)
        #expect(afterReading.state.operations.first?.isReportSuperseded == true)
    }

    @Test("REQ-MAINT-040: other work is still recorded: the same operation on another day, or another operation")
    func otherWorkIsStillRecorded() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        await openMarkDone(service, .cabinFilter)
        try await captureOilChange(store)

        #expect(await service.confirmDone(.cabinFilter, on: now, odometerText: ""))
        await openMarkDone(service, .engineOilService)
        #expect(await service.confirmDone(.engineOilService, on: now - 30 * day, odometerText: ""))

        let completions = await store.completions
        #expect(completions.count == 3)
        #expect(completions.count { $0.operationID == .engineOilService } == 2)
    }

    @Test("REQ-MAINT-040: when the recheck cannot read the store, Mark as done reports not saved and writes nothing")
    func unreadableStoreIsNotSaved() async {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        await openMarkDone(service, .engineOilService)
        await store.failEverything()

        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: ""))

        #expect(service.state.failure == .notSaved)
        #expect(await store.executed.isEmpty)
    }
}
