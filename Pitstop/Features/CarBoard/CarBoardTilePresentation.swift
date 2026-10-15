import Foundation

/// One presentation table per surface: its Car Board tile, its own screen's title and its empty state read the
/// same title, glyph and empty words, so the entrance and the screen behind it never disagree.
extension CarBoardTileKind {
    var title: LocalizedStringResource {
        switch self {
        case .road: "tile.road.title"
        case .notes: "tile.notes.title"
        case .service: "tile.service.title"
        case .history: "tile.history.title"
        }
    }

    var systemImage: String {
        switch self {
        case .road: "road.lanes"
        case .notes: "note.text"
        case .service: PitSymbol.service
        case .history: "clock.arrow.circlepath"
        }
    }

    var emptyHeadline: LocalizedStringResource {
        switch self {
        case .road: "tile.road.empty.headline"
        case .notes: "tile.notes.empty.headline"
        case .service: "tile.service.empty.headline"
        case .history: "tile.history.empty.headline"
        }
    }

    /// The tile's empty sentence. Service's own screen says more ("service.empty.detail"): it offers two entrances.
    var emptyDetail: LocalizedStringResource {
        switch self {
        case .road: "tile.road.empty.detail"
        case .notes: "tile.notes.empty.detail"
        case .service: "tile.service.empty.detail"
        case .history: "tile.history.empty.detail"
        }
    }
}
