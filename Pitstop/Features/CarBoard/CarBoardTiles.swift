import Foundation

enum CarBoardTileKind: String, CaseIterable, Sendable {
    case road
    case notes
    case service
    case history
}

enum CarBoardTileSize: Sendable {
    case full
    case half
}

/// Product-defined tile list. It exists to keep order and size out of the view, not to
/// become a layout engine: V1 has no resizing, reordering, or visibility rules.
struct CarBoardTileDescriptor: Identifiable, Equatable, Sendable {
    let kind: CarBoardTileKind
    let size: CarBoardTileSize
    let defaultOrder: Int

    var id: CarBoardTileKind {
        kind
    }

    static let v1: [CarBoardTileDescriptor] = [
        CarBoardTileDescriptor(kind: .road, size: .full, defaultOrder: 0),
        CarBoardTileDescriptor(kind: .notes, size: .half, defaultOrder: 1),
        CarBoardTileDescriptor(kind: .service, size: .half, defaultOrder: 2),
        CarBoardTileDescriptor(kind: .history, size: .half, defaultOrder: 3),
    ]

    /// Rows in visual order, which is also the accessibility reading order (REQ-BOARD-022).
    /// A trailing single half tile keeps its half width; the future slot stays empty.
    static func rows(_ tiles: [CarBoardTileDescriptor] = v1) -> [[CarBoardTileDescriptor]] {
        var rows: [[CarBoardTileDescriptor]] = []
        var pendingHalf: CarBoardTileDescriptor?
        for tile in tiles.sorted(by: { $0.defaultOrder < $1.defaultOrder }) {
            switch tile.size {
            case .full:
                if let half = pendingHalf {
                    rows.append([half])
                    pendingHalf = nil
                }
                rows.append([tile])
            case .half:
                if let half = pendingHalf {
                    rows.append([half, tile])
                    pendingHalf = nil
                } else {
                    pendingHalf = tile
                }
            }
        }
        if let half = pendingHalf {
            rows.append([half])
        }
        return rows
    }
}

enum CarBoardRoute: Hashable, Sendable {
    case tile(CarBoardTileKind)
}
