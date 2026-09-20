import Foundation
import Observation

struct NotesViewState: Equatable {
    var notes: [Note] = []
    var scope: NoteStatus = .active
    /// `nil` is the main list: every note, classified or not.
    var contextFilter: NoteContext?
    var isLoadFailed = false
    /// Shown inside the editor sheet, where the unsaved text still is.
    var editorFailure: NotesFailure?
    /// Shown on the list: archive and restore happen with no sheet open.
    var listFailure: NotesFailure?

    /// A context filter narrows the list only while it is selected; the main list always
    /// contains unclassified notes (car-board-screen.md, Notes).
    var visibleNotes: [Note] {
        notes.filter { note in
            note.status == scope && (contextFilter.map(note.canonicalContexts.contains) ?? true)
        }
    }

    var availableContexts: [NoteContext] {
        NoteContext.allCases.filter { context in
            notes.contains { $0.status == scope && $0.canonicalContexts.contains(context) }
        }
    }
}

enum NotesFailure: Equatable {
    case notSaved
    case emptyText
}

@MainActor
@Observable
final class NotesViewModel {
    private(set) var state = NotesViewState()

    private let store: any CarMemoryStore
    private let pipeline: RememberPipeline
    private let now: @Sendable () -> Date

    init(store: any CarMemoryStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.now = now
        pipeline = RememberPipeline(store: store, now: now)
    }

    func load() async {
        do {
            state.notes = try await store.notes()
            state.isLoadFailed = false
            // A filter whose last note was archived would otherwise show an empty list with no way out.
            if let filter = state.contextFilter, !state.availableContexts.contains(filter) {
                state.contextFilter = nil
            }
        } catch {
            state.isLoadFailed = true
        }
    }

    /// The model outlives the screen, so each visit starts from the main list.
    func prepareForDisplay() async {
        state.scope = .active
        state.contextFilter = nil
        state.editorFailure = nil
        await load()
    }

    func select(scope: NoteStatus) {
        state.scope = scope
        state.contextFilter = nil
    }

    func select(context: NoteContext?) {
        state.contextFilter = context
    }

    /// Direct app capture is a capture source like any other, so it goes through the pipeline
    /// rather than building a note itself (core C4). Returns `true` only after persistence.
    func add(text: String) async -> Bool {
        let input = CaptureInput(payload: .text(text), source: .directApp, capturedAt: now(), visibleFeature: .notes)
        do {
            guard case .saved = try await pipeline.rememberRaw(input) else { return failEditor(.emptyText) }
        } catch {
            return failEditor(.notSaved)
        }
        return await finish()
    }

    func correct(_ note: Note, text: String) async -> Bool {
        guard !text.isBlank else { return failEditor(.emptyText) }
        guard text != note.rawText else { return true }
        guard await update(UpdateNoteCommand(noteID: note.id, rawText: text)) else { return failEditor(.notSaved) }
        return await finish()
    }

    func setStatus(_ status: NoteStatus, for note: Note) async -> Bool {
        guard await update(UpdateNoteCommand(noteID: note.id, status: status)) else {
            state.listFailure = .notSaved
            return false
        }
        return await finish()
    }

    func dismissFailure() {
        state.editorFailure = nil
        state.listFailure = nil
    }

    private func update(_ command: UpdateNoteCommand) async -> Bool {
        do {
            try await store.execute(.updateNote(command), now: now())
            return true
        } catch {
            return false
        }
    }

    private func finish() async -> Bool {
        await load()
        dismissFailure()
        return true
    }

    private func failEditor(_ failure: NotesFailure) -> Bool {
        state.editorFailure = failure
        return false
    }
}
