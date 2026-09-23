import SwiftUI

/// What a note row's archive control does. The visible glyph, the swipe and the VoiceOver action all read it and
/// call the same view-model path, so the three can never disagree about which way a note moves.
enum NoteArchiveToggle: Equatable {
    case archive
    case restore

    init(_ note: Note) {
        self = note.status == .active ? .archive : .restore
    }

    var targetStatus: NoteStatus {
        switch self {
        case .archive: .archived
        case .restore: .active
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .archive: "notes.archive"
        case .restore: "notes.restore"
        }
    }

    var systemImage: String {
        switch self {
        case .archive: "archivebox"
        case .restore: "arrow.uturn.backward"
        }
    }
}

extension NotesViewState {
    /// "All" (`nil`) first, then each context a note in this scope carries. Empty while nothing in the scope is
    /// classified, so no filter row shows; "All" is the main list and keeps unclassified notes (REQ-BOARD-012).
    var contextChips: [NoteContext?] {
        availableContexts.isEmpty ? [] : [nil] + availableContexts
    }
}

extension Note {
    /// The note's contexts in the catalog's order, so its meta line reads the same on every visit.
    var metaContexts: [NoteContext] {
        NoteContext.allCases.filter(canonicalContexts.contains)
    }

    /// "2 hours ago · Car wash": recency, then any contexts. A raw note shows recency alone.
    var metaText: Text {
        metaContexts.reduce(Text(createdAt, format: .relative(presentation: .named))) { line, context in
            Text("notes.meta \(line) \(Text(context.title))")
        }
    }
}

extension NoteContext {
    var title: LocalizedStringKey {
        switch self {
        case .carWash: "notes.context.carWash"
        case .service: "notes.context.service"
        case .shopping: "notes.context.shopping"
        }
    }
}
