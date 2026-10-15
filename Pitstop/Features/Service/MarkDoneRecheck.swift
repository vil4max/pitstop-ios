import Foundation

/// What the open Mark as done sheet asks about: every entry Pit recorded within a day of the owner's date, nearest
/// first. "Replace with mine" revokes exactly these (REQ-MAINT-040, REQ-MAINT-043).
struct MarkDoneConflict: Equatable {
    let pitEntries: [MaintenanceCompletion]
}

/// An open Mark as done sheet: its operation and the completions stored for it when it opened.
struct MarkDoneOpening: Equatable {
    let operation: MaintenanceOperationID
    let completionIDs: Set<UUID>
}

/// What Mark as done does when completions of its operation were recorded while the sheet was open (REQ-PIT-026).
enum MarkDoneRecheck: Equatable {
    /// Nothing recorded within a day of this date: the owner's completion is other work and is written (REQ-MAINT-045).
    case write
    /// The same work on the same day, and the typed odometer is empty or the one recorded: writing would duplicate
    /// (REQ-MAINT-041).
    case alreadyRecorded
    /// The same work within a day of this date, differing from the owner's entry: writing would record it twice, so
    /// the owner keeps Pit's entries or replaces them (REQ-MAINT-040). Nearest to the owner's date first.
    case conflict([MaintenanceCompletion])
    /// The owner chose "Replace with mine", and Pit's entries within a day are exactly the ones the prompt showed.
    case replace(Set<UUID>)

    /// `prompted` is the set the owner chose to replace. The choice covers only what the prompt showed: when Pit's
    /// entries within a day changed since, the owner is asked again, and the same-day skip does not apply, since the
    /// owner chose to remove the prompted entries (REQ-MAINT-052).
    init(
        recorded: [MaintenanceCompletion],
        date: Date,
        odometerKm: Int?,
        replacing prompted: Set<UUID>? = nil,
        calendar: Calendar = .current
    ) {
        let nearby = Self.nearby(recorded, date: date, calendar: calendar)
        if let prompted, !nearby.isEmpty {
            self = Set(nearby.map(\.id)) == prompted ? .replace(prompted) : .conflict(nearby)
            return
        }
        let sameDay = recorded.filter { calendar.isDate($0.performedAt, inSameDayAs: date) }
        if !sameDay.isEmpty, odometerKm == nil || sameDay.contains(where: { $0.odometerKm == odometerKm }) {
            self = .alreadyRecorded
            return
        }
        self = nearby.isEmpty ? .write : .conflict(nearby)
    }

    /// Completions dated on `date`'s day, the day before or the day after, nearest first, then newest. Whole calendar
    /// days apart: "yesterday" is one day away at any hour.
    private static func nearby(
        _ recorded: [MaintenanceCompletion],
        date: Date,
        calendar: Calendar
    ) -> [MaintenanceCompletion] {
        let day = calendar.startOfDay(for: date)
        let daysAway = { (completion: MaintenanceCompletion) in
            abs(
                calendar.dateComponents([.day], from: day, to: calendar.startOfDay(for: completion.performedAt))
                    .day ?? .max)
        }
        return recorded.filter { daysAway($0) <= 1 }
            .sorted { (daysAway($0), $1.performedAt) < (daysAway($1), $0.performedAt) }
    }
}
