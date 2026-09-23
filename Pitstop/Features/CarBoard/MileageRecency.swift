import SwiftUI

/// The age of the newest mileage observation on the hero's mileage line (REQ-BOARD-027). It is counted from
/// the observation's own date only — a reading, or a completion or dashboard reading saved with its mileage —
/// never from when the board last loaded. The unit coarsens with age so the line stays one short phrase:
/// today, 1–13 days, 2–8 weeks, then whole calendar months from two on.
enum MileageRecency: Equatable, Sendable {
    case today
    case days(Int)
    case weeks(Int)
    case months(Int)

    static let weeksFromDay = 14
    static let monthsFrom = 2

    init(observedAt: Date, now: Date, calendar: Calendar) {
        let observedDay = calendar.startOfDay(for: observedAt)
        let today = calendar.startOfDay(for: now)
        // An observation inside the future tolerance, or a clock set back, is still today, never a negative age.
        let days = calendar.dateComponents([.day], from: observedDay, to: today).day ?? 0
        let months = calendar.dateComponents([.month], from: observedDay, to: today).month ?? 0
        if months >= Self.monthsFrom {
            self = .months(months)
        } else if days >= Self.weeksFromDay {
            self = .weeks(days / 7)
        } else if days > 0 {
            self = .days(days)
        } else {
            self = .today
        }
    }

    var text: Text {
        switch self {
        case .today: Text("carBoard.mileage.updated.today")
        case let .days(days): Text("carBoard.mileage.updated.days \(days)")
        case let .weeks(weeks): Text("carBoard.mileage.updated.weeks \(weeks)")
        case let .months(months): Text("carBoard.mileage.updated.months \(months)")
        }
    }
}
