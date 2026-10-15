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

    @Test("REQ-PIT-026: every sheet with a save reports it to Pit, and Pit in the sheet follows the report")
    func savingSheetsReportToPit() throws {
        /// Code lines only, so a comment naming the modifier does not satisfy the rule.
        func code(_ path: String) throws -> String {
            try PitInSheetTests.source(path).split(separator: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
        }
        let reporters = [
            "Pitstop/Features/Shared/SaveSheetScaffold.swift": ".pitDisabledWhileSaving(saving.isSaving)",
            "Pitstop/Features/Service/TrackSeveralView.swift": ".pitDisabledWhileSaving(model.isSaving)",
            "Pitstop/Features/Service/MarkDoneView.swift": ".pitDisabledWhileSaving(isSaving)",
        ]
        for (path, report) in reporters {
            #expect(try code(path).contains(report), "\(path) does not report its save to Pit")
        }
        // The planned date editor and the dashboard reading save through the scaffold.
        let scaffolded = [
            "Pitstop/Features/Road/PlannedEventEditorView.swift", "Pitstop/Features/Service/DashboardReadingView.swift",
        ]
        for path in scaffolded {
            #expect(try code(path).contains("SaveSheetScaffold("), "\(path) no longer saves through the scaffold")
        }
        let sheet = try code("Pitstop/Features/Pit/PitInSheet.swift")
        for wiring in [
            ".environment(\\.pitSheetSaving, saving)", "saving?.isSaving = isSaving",
            "open(from: host, isSaving: saving.isSaving)", ".disabled(saving.isSaving)",
        ] {
            #expect(sheet.contains(wiring), "PitInSheet.swift lost `\(wiring)`")
        }
    }

    /// Cancel during a save that then fails would leave its "not saved" alert for the next editor.
    @Test("ADR-0032: the History, Notes and Service editors lock Cancel and swipe-to-dismiss while a save runs")
    func editorsLockWhileSaving() {
        let history = HistoryEventEditorView(draft: HistoryEventDraft(date: now), isNew: true) { _ in true }
        let note = NoteEditorView(target: .new) { _ in true }
        let track = TrackOperationView(operations: [.engineOilService]) { _, _, _ in true }
        let reading = DashboardReadingView(
            operation: .engineOilService, defaultUnit: .kilometers, odometerPrefill: nil
        ) { _ in true }
        let bodies: [(String, Any)] = [
            ("history", history.body), ("note", note.body), ("track", track.body), ("dashboard reading", reading.body),
        ]
        for (name, body) in bodies {
            // Nil means the editor is no longer a SaveSheetScaffold.
            let locks = Mirror(reflecting: body).descendant("locksWhileSaving") as? Bool
            #expect(locks == true, "the \(name) editor does not lock while saving")
        }
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
