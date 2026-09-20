import Foundation

/// What the Notes tile says before it is tapped. Counts every active note, classified or not:
/// a missing context never hides a note (REQ-BOARD-012).
public struct NotesSummary: Hashable, Sendable {
    public let activeCount: Int
    public let latest: Note?

    public init(notes: some Sequence<Note>) {
        let active = notes.filter { $0.status == .active }
        activeCount = active.count
        latest = active.max { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }

    public static let empty = NotesSummary(notes: [])
}
