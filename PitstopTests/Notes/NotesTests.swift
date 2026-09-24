import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate

@Suite("Notes summary and commands")
struct NotesDomainTests {
    @Test("REQ-BOARD-012: the summary counts raw notes without any classification")
    func summaryCountsUnclassifiedNotes() {
        let summary = NotesSummary(notes: [
            DomainFixtures.Notes.rawThought,
            DomainFixtures.Notes.contextualWash,
            DomainFixtures.Notes.archivedNote,
        ])
        #expect(summary.activeCount == 2)
        #expect(summary.latest != nil)
        #expect(summary.latest?.status == .active)
    }

    @Test("REQ-BOARD-011: no notes is an empty summary, not an error")
    func emptySummary() {
        #expect(NotesSummary(notes: []) == .empty)
        #expect(NotesSummary.empty.activeCount == 0 && NotesSummary.empty.latest == nil)
        #expect(NotesSummary(notes: [DomainFixtures.Notes.archivedNote]).latest == nil)
    }

    @Test(
        "REQ-CAPTURE-021: a note update must change something and may not blank the text",
        arguments: [
            (UpdateNoteCommand(noteID: UUID()), DomainCommandError.emptyNoteUpdate),
            (UpdateNoteCommand(noteID: UUID(), rawText: "  "), .emptyNoteText)
        ]
    )
    func invalidUpdateIsRejected(command: UpdateNoteCommand, expected: DomainCommandError) {
        #expect(throws: expected) { try DomainCommand.updateNote(command).validate(now: now) }
    }
}

@Suite("Raw Remember pipeline")
struct RememberPipelineTests {
    @Test("REQ-CAPTURE-001: raw mode saves a note through the shared path without a model")
    func rawRememberSavesNote() async throws {
        let store = FakeCarMemoryStore()
        let pipeline = RememberPipeline(store: store, now: { now })
        let input = CaptureInput(
            payload: .text("Спросить про пятно на заднем сиденье"),
            source: .directApp,
            capturedAt: now
        )

        let outcome = try await pipeline.rememberRaw(input)

        let notes = await store.storedNotes
        #expect(notes.map(\.rawText) == ["Спросить про пятно на заднем сиденье"])
        #expect(outcome == .saved(.noteCreated(notes[0]), preservedRaw: true))
        #expect(await store.executed.count == 1)
    }

    @Test("ADR-0006: blank input performs no mutation")
    func blankInputSavesNothing() async throws {
        let store = FakeCarMemoryStore()
        let outcome = try await RememberPipeline(store: store, now: { now })
            .rememberRaw(CaptureInput(payload: .text("  \n"), source: .pitText, capturedAt: now))
        #expect(outcome == .nothingToSave)
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-CAPTURE-009: a persistence failure is an error, never a saved outcome")
    func persistenceFailureIsNotSuccess() async {
        let store = FakeCarMemoryStore()
        await store.failEverything()
        await #expect(throws: RememberError.notSaved) {
            try await RememberPipeline(store: store, now: { now })
                .rememberRaw(CaptureInput(payload: .text("мысль"), source: .widget, capturedAt: now))
        }
    }
}

@MainActor
@Suite("Notes view model")
struct NotesViewModelTests {
    @Test("REQ-CAPTURE-026, ADR-0030: a note typed in the editor carries the injected locale")
    func editorCaptureCarriesInjectedLocale() {
        let model = NotesViewModel(store: FakeCarMemoryStore(), now: { now }, locale: { Locale(identifier: "en_GB") })

        let input = model.captureInput(text: "check the tyre pressure")

        #expect(input.localeIdentifier == "en_GB")
        #expect(input.source == .directApp)
        #expect(input.visibleFeature == .notes)
        #expect(input.capturedAt == now)
    }

    @Test("REQ-CAPTURE-012: a saved note can be found, corrected, and keeps its identity")
    func noteCanBeCorrected() async throws {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.notes(store, now: now)
        #expect(await model.add(text: "заменить дворники"))
        let note = try #require(model.state.visibleNotes.first)

        #expect(await model.correct(note, text: "заменить задний дворник"))

        let corrected = try #require(model.state.visibleNotes.first)
        #expect(corrected.rawText == "заменить задний дворник")
        #expect(corrected.id == note.id && corrected.createdAt == note.createdAt)
    }

    @Test("REQ-DOMAIN-013: archiving moves the note to the archived list and keeps its wording")
    func archivingChangesOnlyStatus() async throws {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.notes(store, now: now)
        #expect(await model.add(text: "поменял масло, надо записать"))
        let note = try #require(model.state.visibleNotes.first)

        #expect(await model.setStatus(.archived, for: note))

        #expect(model.state.visibleNotes.isEmpty)
        model.select(scope: .archived)
        #expect(model.state.visibleNotes.map(\.rawText) == ["поменял масло, надо записать"])
    }

    @Test("REQ-BOARD-012: the main list keeps unclassified notes; a context filter only narrows while selected")
    func contextFilterNeverHidesFromMainList() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.notes(store, now: now)
        let vehicleID = await store.vehicle.id
        for (text, contexts) in [("без контекста", Set<NoteContext>()), ("мойка", [.carWash])] {
            _ = try? await store.execute(
                .createNote(CreateNoteCommand(vehicleID: vehicleID, rawText: text, canonicalContexts: contexts)),
                now: now
            )
        }
        await model.load()

        #expect(Set(model.state.visibleNotes.map(\.rawText)) == ["без контекста", "мойка"])
        #expect(model.state.availableContexts == [.carWash])
        model.select(context: .carWash)
        #expect(model.state.visibleNotes.map(\.rawText) == ["мойка"])
        model.select(context: nil)
        #expect(model.state.visibleNotes.count == 2)
    }

    @Test("REQ-CAPTURE-009: a failed save reports failure so the editor keeps the text")
    func failedSaveKeepsEditorOpen() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.notes(store, now: now)
        await store.failEverything()

        #expect(await !model.add(text: "мысль"))
        #expect(model.state.editorFailure == .notSaved)
        #expect(model.state.listFailure == nil)
    }

    @Test("ADR-0006: blank text saves nothing")
    func blankTextSavesNothing() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.notes(store, now: now)
        #expect(await !model.add(text: "   "))
        #expect(model.state.editorFailure == .emptyText)
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-CAPTURE-009: a failed archive is reported on the list and never leaks into the editor")
    func failedArchiveIsVisibleOnTheList() async throws {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.notes(store, now: now)
        #expect(await model.add(text: "мысль"))
        let note = try #require(model.state.visibleNotes.first)
        await store.failEverything()

        #expect(await !model.setStatus(.archived, for: note))

        #expect(model.state.listFailure == .notSaved)
        #expect(model.state.editorFailure == nil)
        #expect(model.state.visibleNotes.map(\.id) == [note.id])
    }

    @Test("REQ-BOARD-012: a filter whose last note was archived falls back to the main list")
    func orphanedFilterIsCleared() async throws {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.notes(store, now: now)
        let vehicleID = await store.vehicle.id
        for (text, contexts) in [("без контекста", Set<NoteContext>()), ("мойка", [.carWash])] {
            _ = try await store.execute(
                .createNote(CreateNoteCommand(vehicleID: vehicleID, rawText: text, canonicalContexts: contexts)),
                now: now
            )
        }
        await model.load()
        model.select(context: .carWash)
        let wash = try #require(model.state.visibleNotes.first)

        #expect(await model.setStatus(.archived, for: wash))

        #expect(model.state.contextFilter == nil)
        #expect(model.state.visibleNotes.map(\.rawText) == ["без контекста"])
    }

    @Test("ADR-0006: each visit to Notes starts from the active main list")
    func visitStartsFromMainList() async {
        let model = TestViewModels.notes(FakeCarMemoryStore(), now: now)
        model.select(scope: .archived)
        await model.prepareForDisplay()
        #expect(model.state.scope == .active && model.state.contextFilter == nil)
    }
}

@MainActor
@Suite("Car Board notes summary")
struct CarBoardNotesSummaryTests {
    @Test("REQ-BOARD-012: the Notes tile state accounts for a saved raw note after a reload")
    func tileStateIncludesRawNote() async throws {
        let store = FakeCarMemoryStore()
        let board = CarBoardViewModel(store: store, now: { now })
        await board.load()
        #expect(board.state.notes == .empty)

        _ = try await store.execute(.createNote(CreateNoteCommand(rawText: "проверить давление")), now: now)
        await board.load()

        #expect(board.state.notes.activeCount == 1)
        #expect(board.state.notes.latest?.rawText == "проверить давление")
    }
}

@Suite("Notes presentation")
struct NotesPresentationTests {
    @Test("REQ-BOARD-012: the chip row leads with All and shows only while a note in the scope has a context")
    func chipRowLeadsWithAll() {
        let notes = [
            DomainFixtures.Notes.rawThought,
            DomainFixtures.Notes.contextualWash,
            DomainFixtures.Notes.archivedNote,
        ]
        var state = NotesViewState(notes: notes)

        #expect(state.contextChips == [nil, .carWash])
        #expect(state.visibleNotes.contains(DomainFixtures.Notes.rawThought))

        state.scope = .archived
        #expect(state.contextChips == [nil, .shopping])

        #expect(NotesViewState(notes: [DomainFixtures.Notes.rawThought]).contextChips.isEmpty)
    }

    @Test("REQ-DOMAIN-013: the row's archive toggle archives an active note and restores an archived one")
    func archiveToggleTargetsTheOtherScope() {
        #expect(NoteArchiveToggle(DomainFixtures.Notes.rawThought) == .archive)
        #expect(NoteArchiveToggle.archive.targetStatus == .archived)
        #expect(NoteArchiveToggle(DomainFixtures.Notes.archivedNote) == .restore)
        #expect(NoteArchiveToggle.restore.targetStatus == .active)
    }

    @Test("REQ-CAPTURE-012: the meta line names a note's contexts in one fixed order, and none for a raw note")
    func metaContextsKeepOneOrder() {
        let note = Note(rawText: "wiper blades before the wash", canonicalContexts: [.shopping, .carWash])

        #expect(note.metaContexts == [.carWash, .shopping])
        #expect(DomainFixtures.Notes.rawThought.metaContexts.isEmpty)
    }
}

/// Notes' empty states (active and archived) state a fact: no notes in that scope. They may appear only once a
/// load has read the store and found none (core C2); an unread or unreadable store says nothing about the car.
@MainActor
@Suite("Notes load states")
struct NotesLoadStateTests {
    @Test("REQ-GRAMMAR-004, core C2: Notes show no empty state in either scope before the first load finishes")
    func noEmptyStateBeforeLoad() {
        let model = TestViewModels.notes(FakeCarMemoryStore(), now: now)

        #expect(model.state.sparseState == nil)
        model.select(scope: .archived)
        #expect(model.state.sparseState == nil)
    }

    @Test("REQ-GRAMMAR-004, core C2: a failed first load shows only the failure banner in either scope")
    func noEmptyStateBesideFailedFirstLoad() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.notes(store, now: now)
        await store.failEverything()

        await model.load()

        #expect(model.state.isLoadFailed)
        #expect(model.state.sparseState == nil)
        model.select(scope: .archived)
        #expect(model.state.sparseState == nil)
    }

    @Test("REQ-GRAMMAR-004, core C2: a failed reload after an empty load drops the empty state for the banner")
    func noEmptyStateBesideFailedReload() async throws {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.notes(store, now: now)
        await model.load()
        _ = try #require(model.state.sparseState)
        await store.failEverything()

        await model.load()

        #expect(model.state.isLoadFailed)
        #expect(model.state.sparseState == nil)
    }

    @Test("REQ-GRAMMAR-004, core C2: a successful load that finds no notes shows the empty state in both scopes")
    func emptyStateAfterSuccessfulEmptyLoad() async {
        let model = TestViewModels.notes(FakeCarMemoryStore(), now: now)

        await model.load()

        #expect(!model.state.isLoadFailed)
        #expect(model.state.sparseState != nil)
        model.select(scope: .archived)
        #expect(model.state.sparseState != nil)
    }

    @Test("REQ-GRAMMAR-004, core C2: a known note shows no empty state, even after a failed reload")
    func recordsShowNoEmptyState() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.notes(store, now: now)
        #expect(await model.add(text: "Check the wiper blades"))
        #expect(model.state.sparseState == nil)
        await store.failEverything()

        await model.load()

        #expect(model.state.isLoadFailed)
        #expect(model.state.visibleNotes.count == 1)
        #expect(model.state.sparseState == nil)
    }
}
