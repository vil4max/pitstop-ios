import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate

/// Pit is disabled inside a sheet while it saves, so a capture never interleaves with a partial save (REQ-PIT-026).
@MainActor
@Suite("Pit while a sheet saves")
struct PitSavingGuardTests {
    @Test("REQ-PIT-026: Pit in Track several opens no capture while its intervals are saving")
    func trackSeveral() async throws {
        let store = FakeCarMemoryStore()
        let entry = try PitInSheetTests.entry(store)
        let sheet = PitCaptureEntry.Host.sheet(UUID())
        let observed = SavingObservation()
        // `onSaved` runs inside the save, after the writes and before it ends.
        let trackSeveral = TrackSeveralViewModel(store: store, operations: [.brakeFluid], now: { now }) {
            guard let model = observed.model else { return }
            observed.record(isSaving: model.isSaving, opened: entry.open(from: sheet, isSaving: model.isSaving))
        }
        observed.model = trackSeveral
        trackSeveral.toggle(.brakeFluid)
        trackSeveral.continueToIntervals()
        trackSeveral.setMonths("24", for: .brakeFluid)
        #expect(trackSeveral.continueToReview())

        await trackSeveral.apply()

        #expect(observed.samples == [.init(isSaving: true, opened: false)])
        #expect(entry.host == nil)
        #expect(entry.open(from: sheet, isSaving: trackSeveral.isSaving))
    }

    @Test("REQ-PIT-026: Pit in the planned date editor opens no capture while the date is saving")
    func plannedDateEditor() async throws {
        let store = FakeCarMemoryStore()
        let road = RoadViewModel(store: store, now: { now })
        await road.load()
        let draft = PlannedEventDraft(kind: .insuranceExpiry, date: now.addingTimeInterval(40 * 86400))

        try await expectPitWaits(store) { await road.save(draft) }
        #expect(await store.planned.count == 1)
    }

    @Test("REQ-PIT-026: Pit in the dashboard reading sheet opens no capture while the reading is saving")
    func dashboardReading() async throws {
        let store = FakeCarMemoryStore()
        let service = TestViewModels.service(store, now: now)

        try await expectPitWaits(store) {
            await service.enterReport(
                .cabinFilter, distanceText: "", unit: .kilometers, daysText: "45", odometerText: ""
            )
        }
        #expect(await store.reports.count == 1)
    }

    @Test("REQ-PIT-026: a sheet's save runs once at a time and reports saving only while it runs")
    func sheetSaveRunsOnce() async {
        let saving = SheetSave()
        var inner: Bool?
        let saved = await saving.run {
            inner = await saving.run { true }
            return true
        }
        #expect(saved && inner == false)
        #expect(!saving.isSaving)
    }

    /// Runs `save` through the editor scaffold's `SheetSave`, as the Save button does, and tries Pit mid-save.
    private func expectPitWaits(
        _ store: FakeCarMemoryStore,
        _ save: @escaping @MainActor () async -> Bool
    ) async throws {
        let entry = try PitInSheetTests.entry(store)
        let sheet = PitCaptureEntry.Host.sheet(UUID())
        let saving = SheetSave()
        var openedMidSave: Bool?

        let saved = await saving.run {
            #expect(saving.isSaving)
            openedMidSave = entry.open(from: sheet, isSaving: saving.isSaving)
            return await save()
        }

        #expect(saved)
        #expect(openedMidSave == false)
        #expect(entry.host == nil)
        #expect(entry.open(from: sheet, isSaving: saving.isSaving))
    }
}

@MainActor
private final class SavingObservation {
    struct Sample: Equatable {
        let isSaving: Bool
        let opened: Bool
    }

    weak var model: TrackSeveralViewModel?
    private(set) var samples: [Sample] = []

    func record(isSaving: Bool, opened: Bool) {
        samples.append(Sample(isSaving: isSaving, opened: opened))
    }
}
