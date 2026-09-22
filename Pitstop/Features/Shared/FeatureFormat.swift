import SwiftUI

/// The one home for how feature screens write a day's recency, a mileage and a money amount, so the
/// Car Board, History and Pit never drift apart.
enum FeatureFormat {
    /// Amounts are stated as entered: up to two decimals, no padded zeros.
    static let amountStyle: Decimal.FormatStyle = .number.precision(.fractionLength(0 ... 2))

    static func amount(_ amount: Decimal) -> String {
        amount.formatted(amountStyle)
    }

    static func mileage(_ kilometers: Int) -> Text {
        Text("carBoard.mileage.km \(kilometers)")
    }

    /// Events carry a day, not a moment, so recency is counted in whole days ("today", "3 days ago").
    static func dayRecency(of date: Date, now: Date = Date(), calendar: Calendar = .current) -> Text {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return Text(verbatim: formatter.localizedString(for: day, relativeTo: today))
    }
}
