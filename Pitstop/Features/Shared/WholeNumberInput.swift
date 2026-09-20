import Foundation

/// A whole number typed by the user: mileage, an interval, a count of months.
enum WholeNumberInput: Equatable {
    /// Blank input means "not supplied"; it must never become zero.
    case absent
    case value(Int)
    case invalid

    var intValue: Int? {
        if case let .value(value) = self {
            value
        } else {
            nil
        }
    }

    /// Plain ASCII digits, optionally grouped in threes by one kind of separator. Any other separator
    /// may be a decimal point, and dropping it would record a value ten times too large.
    static func parse(_ text: String, upTo maximum: Int) -> WholeNumberInput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .absent }
        let grouped = /[0-9]{1,3}([ ,.\u{00A0}\u{202F}])[0-9]{3}(\1[0-9]{3})*|[0-9]+/
        guard trimmed.wholeMatch(of: grouped) != nil else { return .invalid }
        let digits = trimmed.filter { $0.isASCII && $0.isNumber }
        guard let value = Int(digits), value <= maximum else { return .invalid }
        return .value(value)
    }

    /// Same as `parse`, but zero is not a usable interval.
    static func parsePositive(_ text: String, upTo maximum: Int) -> WholeNumberInput {
        let parsed = parse(text, upTo: maximum)
        return parsed == .value(0) ? .invalid : parsed
    }
}
