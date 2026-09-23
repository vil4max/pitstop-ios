import Foundation

/// One calendar month of History: the section the screen draws as one grouped list (REQ-GRAMMAR-001).
struct HistoryMonth: Hashable, Identifiable {
    /// The month's first instant in the calendar and time zone it was grouped in; the header formats it with the
    /// same ones, so a header never names a different month than its rows.
    let start: Date
    /// In the timeline's order: newest first, ties broken by ID.
    let entries: [HistoryEntry]

    var id: Date {
        start
    }
}

extension HistoryTimeline {
    /// The timeline cut into calendar months, newest month first, without reordering or dropping an entry. The
    /// calendar and time zone are passed in rather than read from the device, so the same records and settings
    /// always give the same months; the time zone decides on which side of a month boundary an entry falls.
    func months(calendar: Calendar, timeZone: TimeZone) -> [HistoryMonth] {
        var calendar = calendar
        calendar.timeZone = timeZone
        var months: [HistoryMonth] = []
        var start: Date?
        var entries: [HistoryEntry] = []
        // Entries are newest first, so each month is one run of consecutive entries.
        for entry in self.entries {
            let entryMonth = calendar.dateInterval(of: .month, for: entry.date)?.start ?? entry.date
            if let start, start != entryMonth {
                months.append(HistoryMonth(start: start, entries: entries))
                entries = []
            }
            start = entryMonth
            entries.append(entry)
        }
        if let start {
            months.append(HistoryMonth(start: start, entries: entries))
        }
        return months
    }
}

extension HistoryEntry {
    /// The event History can correct (ADR 0007). A completion has no editor here: it is corrected where it was
    /// confirmed, on Service.
    var editableEvent: HistoryEvent? {
        if case let .event(event) = self {
            event
        } else {
            nil
        }
    }
}
