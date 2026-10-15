import Foundation

/// The words `RuleBasedInterpreter` recognises as units, markers and currencies, and how it reads a number.
enum CaptureWords {
    static let units: Set<String> = ["км", "km", "килом", "kilometers", "kilometres"]
    static let mileageWords: Set<String> = ["mileage", "odometer"]
    static let mileUnits: Set<String> = ["mi", "mile", "miles", "миль", "милі"]
    static let dayWords = ["day", "дн", "ден", "сут", "дні", "днів"]
    static let aheadMarkers: Set<String> = [
        "in", "через", "осталось", "остаётся", "остается", "залишилось", "лишилось", "залишається",
    ]
    static let trailingAheadMarkers: Set<String> = ["left", "remaining", "осталось", "залишилось"]
    static let overdueMarkers: Set<String> = ["overdue", "просрочено", "прострочено"]
    static let conjunctions: Set<String> = ["and", "or", "и", "или", "і", "й", "та", "або"]
    static let looseMileageMarkers: Set<String> = ["на", "at"]
    static let yearMarkers: Set<String> = ["в", "с", "in", "since", "from", "года", "году"]
    static let currencies: Set<String> = ["руб", "рублей", "₽", "грн", "uah", "eur", "usd"]

    static func isUnitOrDayWord(_ word: String) -> Bool {
        units.contains(word) || mileUnits.contains(word) || dayWords.contains(where: word.hasPrefix)
    }

    static func isMileageWord(_ word: String) -> Bool {
        word.hasPrefix("пробег") || word.hasPrefix("пробіг") || word.hasPrefix("одометр") || mileageWords.contains(word)
    }

    /// A whole number only: a decimal separator marks money or litres, never a mileage.
    static func number(_ word: String) -> Double? {
        guard !word.isEmpty, word.allSatisfy(\.isNumber) else { return nil }
        return Double(word)
    }
}
