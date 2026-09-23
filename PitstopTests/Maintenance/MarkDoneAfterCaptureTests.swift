import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate
private let day: TimeInterval = 86400

/// A capture over "Mark as done" keeps the duplicate rules: the editor rechecks what is stored before it saves
/// (pit-behavior-and-motion.md, "Availability"; REQ-PIT-026). Only a completion recorded while the sheet is open is
/// the same one, as a dashboard reading tells completions apart by what existed at its entry (ADR 0035).
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

    private func openedService(_ store: FakeCarMemoryStore) async -> ServiceViewModel {
        let service = TestViewModels.service(store, now: now)
        await service.load()
        return service
    }

    @Test("REQ-PIT-026: a capture over Mark as done for the same operation leaves one completion when it saves")
    func sameWorkIsRecordedOnce() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        service.beginMarkDone(.engineOilService)
        try await captureOilChange(store)
        let captured = await store.completions
        #expect(captured.count == 1)

        // Success closes the sheet: the work is recorded, once.
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "85000"))

        #expect(await store.completions == captured)
        #expect(await store.executed.count == 1, "the editor wrote nothing")
        #expect(service.state.failure == nil)
    }

    @Test("REQ-PIT-026: a capture dated another day while Mark as done is open is still the same completion")
    func captureOnAnotherDayIsRecordedOnce() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        service.beginMarkDone(.engineOilService)
        // What Pit writes for "changed the oil yesterday": the capture's own completion, dated the day before.
        let vehicleID = await store.vehicle.id
        try await store.execute(.confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService, performedAt: now - day
        ))), now: now)

        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: ""))

        #expect(await store.completions.count == 1)
    }

    @Test("REQ-PIT-026: without a capture, a second Mark as done on the same day is recorded as the owner asked")
    func deliberateRepeatIsRecorded() async {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        service.beginMarkDone(.engineOilService)
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: ""))

        // The owner opens it again the same day to add the odometer.
        service.beginMarkDone(.engineOilService)
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "85000"))

        let completions = await store.completions
        #expect(completions.count == 2)
        #expect(completions.contains { $0.odometerKm == 85000 })
    }

    @Test("REQ-MAINT-031: Mark as done opened after a same-day reading still records the work and supersedes it")
    func sameDayMarkDoneSupersedesAReading() async {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        service.beginMarkDone(.engineOilService)
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "84000"))
        let later = now + 0.02 * day
        let afterReading = TestViewModels.service(store, now: later)
        #expect(await afterReading.enterReport(
            .engineOilService, distanceText: "-300", unit: .kilometers, daysText: "", odometerText: "84000"
        ))
        #expect(afterReading.state.operations.first?.countingReport != nil)

        afterReading.beginMarkDone(.engineOilService)
        #expect(await afterReading.confirmDone(.engineOilService, on: later, odometerText: "84050"))

        #expect(await store.completions.count == 2)
        #expect(afterReading.state.operations.first?.isReportSuperseded == true)
    }

    @Test("REQ-PIT-026: other work is still recorded: the same operation on another day, or another operation")
    func otherWorkIsStillRecorded() async throws {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        service.beginMarkDone(.cabinFilter)
        try await captureOilChange(store)

        #expect(await service.confirmDone(.cabinFilter, on: now, odometerText: ""))
        service.beginMarkDone(.engineOilService)
        #expect(await service.confirmDone(.engineOilService, on: now - 30 * day, odometerText: ""))

        let completions = await store.completions
        #expect(completions.count == 3)
        #expect(completions.count { $0.operationID == .engineOilService } == 2)
    }

    @Test("REQ-PIT-026: when the recheck cannot read the store, Mark as done reports not saved and writes nothing")
    func unreadableStoreIsNotSaved() async {
        let store = FakeCarMemoryStore()
        let service = await openedService(store)
        service.beginMarkDone(.engineOilService)
        await store.failEverything()

        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: ""))

        #expect(service.state.failure == .notSaved)
        #expect(await store.executed.isEmpty)
    }
}
