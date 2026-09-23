import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate
private let day: TimeInterval = 86400

/// A capture over "Mark as done" keeps the duplicate rules: the editor rechecks what is stored before it saves
/// (pit-behavior-and-motion.md, "Availability"; REQ-PIT-026).
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
        #expect(await store.completions.count == 1)
    }

    @Test("REQ-PIT-026: a capture over Mark as done for the same operation leaves one completion when it saves")
    func sameWorkIsRecordedOnce() async throws {
        let store = FakeCarMemoryStore()
        let service = TestViewModels.service(store, now: now)
        try await captureOilChange(store)
        let captured = await store.completions

        // Success closes the sheet: the work is recorded, once.
        #expect(await service.confirmDone(.engineOilService, on: now, odometerText: "85000"))

        #expect(await store.completions == captured)
        #expect(await store.executed.count == 1, "the editor wrote nothing")
        #expect(service.state.failure == nil)
    }

    @Test("REQ-PIT-026: other work is still recorded: the same operation on another day, or another operation")
    func otherWorkIsStillRecorded() async throws {
        let store = FakeCarMemoryStore()
        let service = TestViewModels.service(store, now: now)
        try await captureOilChange(store)

        #expect(await service.confirmDone(.engineOilService, on: now - 30 * day, odometerText: ""))
        #expect(await service.confirmDone(.cabinFilter, on: now, odometerText: ""))

        let completions = await store.completions
        #expect(completions.count == 3)
        #expect(completions.count { $0.operationID == .engineOilService } == 2)
    }

    @Test("REQ-PIT-026: when the recheck cannot read the store, Mark as done reports not saved and writes nothing")
    func unreadableStoreIsNotSaved() async {
        let store = FakeCarMemoryStore()
        let service = TestViewModels.service(store, now: now)
        await store.failEverything()

        #expect(await !service.confirmDone(.engineOilService, on: now, odometerText: ""))

        #expect(service.state.failure == .notSaved)
        #expect(await store.executed.isEmpty)
    }
}
