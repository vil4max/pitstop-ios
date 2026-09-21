import Foundation

/// An amount of money typed or spoken by the user.
enum AmountInput: Equatable {
    /// No amount given: the cost stays unknown rather than zero.
    case absent
    case value(Decimal)
    case invalid
}

/// Reads the numbers every capture surface accepts, so Car Board, History, Service, Pit and Siri
/// agree on what a mileage or an amount is. Pure and UI-free, so any isolation may call it.
enum InputParsing {
    static func kilometers(from text: String) -> WholeNumberInput {
        WholeNumberInput.parse(text, upTo: Int(DomainCommandLimits.maximumOdometerKm))
    }

    /// Digits with an optional fraction of one or two digits; comma or point as the decimal separator.
    /// Three digits after a separator are rejected: "1,200" is far more likely twelve hundred than 1.2.
    static func amount(from text: String) -> AmountInput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .absent }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".").filter { !$0.isWhitespace }
        guard normalized.wholeMatch(of: /[0-9]+(\.[0-9]{1,2})?/) != nil,
              let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              value > 0
        else { return .invalid }
        return .value(value)
    }
}
