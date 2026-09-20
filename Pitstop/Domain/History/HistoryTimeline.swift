import Foundation

/// One thing that actually happened. History shows recorded events and confirmed completions;
/// notes, plans, and proposals never appear here (REQ-BOARD-016).
public enum HistoryEntry: Hashable, Identifiable, Sendable {
    case event(HistoryEvent)
    case completion(MaintenanceCompletion)

    public var id: UUID {
        switch self {
        case let .event(event): event.id
        case let .completion(completion): completion.id
        }
    }

    public var date: Date {
        switch self {
        case let .event(event): event.date
        case let .completion(completion): completion.performedAt
        }
    }

    /// `nil` means the mileage was not recorded; it is shown as unknown, never estimated.
    public var odometerKm: Int? {
        switch self {
        case let .event(event): event.odometerKm
        case let .completion(completion): completion.odometerKm
        }
    }
}

public struct HistoryTimeline: Hashable, Sendable {
    /// Newest first; ties broken by ID so equal input always gives equal output.
    public let entries: [HistoryEntry]

    public init(events: some Sequence<HistoryEvent>, completions: some Sequence<MaintenanceCompletion>) {
        let events = Array(events)
        let eventIDs = Set(events.map(\.id))
        // A completion that came from a recorded visit is already represented by that event. If the
        // visit is not in this timeline, the completion is shown itself rather than lost.
        let standalone = completions.filter { completion in
            completion.sourceEventID.map { !eventIDs.contains($0) } ?? true
        }
        entries = (events.map(HistoryEntry.event) + standalone.map(HistoryEntry.completion))
            .sorted { ($0.date, $0.id.uuidString) > ($1.date, $1.id.uuidString) }
    }

    public var latest: HistoryEntry? {
        entries.first
    }

    public static let empty = HistoryTimeline(events: [], completions: [])
}
