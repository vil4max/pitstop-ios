import Foundation

/// A deterministic stand-in for the language model (CAP-002, ADR 0011). It recognises a few explicit
/// phrasings in Russian and English and proposes nothing at all when it is not sure, so unsupported
/// meaning degrades to raw preservation instead of a guess (REQ-CAPTURE-006).
///
/// It is not an attempt at understanding language. It exists so the proposal, confirmation, and
/// mutation path can be built and tested before any model, and so the app keeps a working
/// interpreted mode when a model is unavailable.
public struct RuleBasedInterpreter: SemanticInterpreting {
    public init() {}

    public func interpret(_ input: CaptureInput) async throws -> MemoryProposal? {
        let text = input.payload.rawContent
        let reading = Reading(text)
        guard !reading.isEmpty, !reading.isHedged else { return nil }

        if let operation = reading.operation, reading.reportsCompletedWork {
            return MemoryProposal(
                sourceInputID: input.id,
                kind: .maintenanceCompletion,
                rawText: text,
                extractedOdometerKm: reading.reportedMileageKm,
                extractedOperationID: operation
            )
        }
        if reading.reportsWashing {
            return MemoryProposal(
                sourceInputID: input.id,
                kind: .vehicleEvent,
                rawText: text,
                extractedOdometerKm: reading.statedMileageKm,
                extractedEventKind: .carWash,
                extractedAmount: reading.amount
            )
        }
        if let kilometers = reading.statedMileageKm {
            return MemoryProposal(
                sourceInputID: input.id,
                kind: .odometerReading,
                rawText: text,
                extractedOdometerKm: kilometers
            )
        }
        return nil
    }

    /// The hedge rule on its own, so a model-backed interpreter applies exactly the same words
    /// (REQ-CAPTURE-014) instead of trusting a model to recognise an intention.
    public static func isHedged(_ text: String) -> Bool {
        Reading(text).isHedged
    }
}

/// One pass over the words of a capture. Matching is by whole word or by a stem inside a word, never
/// by a bare substring of the sentence: "в машине" must not read as the negation "не", and
/// "поработал" must not read as "пора".
private struct Reading {
    private let words: [String]
    /// Marks that survive word splitting: a question, and the English contracted negation.
    private let isQuestionOrNegated: Bool

    init(_ text: String) {
        let lowered = text.lowercased()
        isQuestionOrNegated = lowered.contains("?") || lowered.contains("n't")
        words = lowered.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    var isEmpty: Bool {
        words.isEmpty
    }

    /// Wishes, plans, negations, and questions are not reports of work. An intention stays a Note
    /// (REQ-CAPTURE-014), so anything hedged is left to the raw path.
    var isHedged: Bool {
        if isQuestionOrNegated {
            return true
        }
        let exact: Set = [
            "надо", "нужно", "хочу", "хочется", "пора", "если", "бы", "не", "нет", "должен", "должна",
            "should", "need", "needs", "want", "wants", "must", "maybe", "if", "not",
        ]
        let stems = ["планир", "собира", "буду", "будет"]
        return words.contains { word in
            exact.contains(word) || stems.contains { word.hasPrefix($0) }
        }
    }

    /// Past-tense reports only. Ambiguous verbs such as "залил" (a top-up, not a service) are left out
    /// on purpose: confirming one would reset a maintenance cycle.
    var reportsCompletedWork: Bool {
        containsStem(["менял", "менил", "сделал", "прошёл", "прошел", "поставил"])
            || containsWord(["changed", "replaced", "swapped", "serviced", "did", "done"])
    }

    /// The verb only, spelled out: "мылом", "смыл", and the noun "мойка" report nothing about
    /// washing this car.
    var reportsWashing: Bool {
        containsWord(["помыл", "помыла", "помыли", "мыл", "мыла", "мыли", "washed"])
    }

    /// Only one operation may be named. Two candidates mean a visit with several jobs, which this
    /// interpreter cannot express; the capture stays raw rather than confirming half of it.
    var operation: MaintenanceOperationID? {
        let operations: [(stem: String, id: MaintenanceOperationID)] = [
            ("масл", .engineOilService), ("oil", .engineOilService),
            ("дсг", .dsgService), ("dsg", .dsgService), ("коробк", .dsgService),
            ("халдекс", .awdCouplingService), ("haldex", .awdCouplingService), ("муфт", .awdCouplingService),
            ("тормозн", .brakeFluid), ("brake", .brakeFluid),
            ("салонн", .cabinFilter), ("cabin", .cabinFilter),
            ("воздушн", .airFilter),
            ("свеч", .sparkPlugs), ("spark", .sparkPlugs),
        ]
        let found = Set(operations.filter { pair in words.contains { $0.contains(pair.stem) } }.map(\.id))
        return found.count == 1 ? found.first : nil
    }

    /// A price is written after "за" or "for", or next to a currency word.
    var amount: Decimal? {
        for (index, word) in words.enumerated() {
            let isPriceMarker = ["за", "for"].contains(word)
            let hasCurrencyNext = index + 1 < words.count && Self.currencies.contains(words[index + 1])
            guard isPriceMarker || (Self.number(word) != nil && hasCurrencyNext) else { continue }
            let numberIndex = isPriceMarker ? index + 1 : index
            guard words.indices.contains(numberIndex) else { continue }
            let candidate = joinedNumber(from: numberIndex)
            if let candidate, candidate > 0 {
                return Decimal(candidate)
            }
        }
        return nil
    }

    /// A mileage on its own needs an explicit mileage word or unit: "пробег 84 200", "92000 km".
    /// "потратил на 1500" is money, so "на" alone is not enough here.
    var statedMileageKm: Double? {
        mileage(allowingLooseMarkers: false)
    }

    /// Inside a report of work or washing, "на 85000" is unambiguous and counts as the mileage.
    var reportedMileageKm: Double? {
        mileage(allowingLooseMarkers: true)
    }

    private func mileage(allowingLooseMarkers: Bool) -> Double? {
        var candidates: [Double] = []
        for (index, _) in words.enumerated() {
            guard let value = joinedNumber(from: index) else { continue }
            let unitFollows = nextWord(after: index, skippingDigits: true).map(Self.units.contains) ?? false
            let previous = previousWord(before: index)
            let markerPrecedes = previous.map { word in
                word.hasPrefix("пробег") || word.hasPrefix("одометр") || Self.mileageWords.contains(word)
                    || (allowingLooseMarkers && Self.looseMileageMarkers.contains(word))
            } ?? false
            guard unitFollows || markerPrecedes else { continue }
            // Plausibility first: nothing converts the value to an integer before it is in range.
            guard DomainCommandLimits.isPlausibleOdometer(value), value >= 100,
                  Decimal(value) != amount else { continue }
            // A four-digit number after "в", "с", or "since" is a year, not a mileage.
            if !unitFollows, (1900 ... 2100).contains(Int(value)), previous.map(Self.yearMarkers.contains) ?? false {
                continue
            }
            candidates.append(value)
        }
        return candidates.max()
    }

    // MARK: - Words and numbers

    private static let units: Set<String> = ["км", "km", "килом", "kilometers", "kilometres"]
    private static let mileageWords: Set<String> = ["mileage", "odometer"]
    private static let looseMileageMarkers: Set<String> = ["на", "at"]
    private static let yearMarkers: Set<String> = ["в", "с", "in", "since", "from", "года", "году"]
    private static let currencies: Set<String> = ["руб", "рублей", "₽", "грн", "uah", "eur", "usd"]

    private func containsWord(_ candidates: [String]) -> Bool {
        words.contains { candidates.contains($0) }
    }

    private func containsStem(_ stems: [String]) -> Bool {
        words.contains { word in stems.contains { word.contains($0) } }
    }

    private func previousWord(before index: Int) -> String? {
        var cursor = index - 1
        // Step back over the other halves of a grouped number such as "84 200".
        while cursor >= 0, Self.number(words[cursor]) != nil {
            cursor -= 1
        }
        return cursor >= 0 ? words[cursor] : nil
    }

    private func nextWord(after index: Int, skippingDigits: Bool) -> String? {
        var cursor = index + 1
        while skippingDigits, cursor < words.count, Self.number(words[cursor]) != nil {
            cursor += 1
        }
        return cursor < words.count ? words[cursor] : nil
    }

    /// Reads "84 200", written as separate words, as one number. It starts only at the first group,
    /// and a following group counts only when it is exactly three digits.
    private func joinedNumber(from index: Int) -> Double? {
        guard let first = Self.number(words[index]) else { return nil }
        if index > 0, Self.number(words[index - 1]) != nil {
            return nil
        }
        var digits = words[index]
        var cursor = index + 1
        while cursor < words.count, words[cursor].count == 3, Self.number(words[cursor]) != nil {
            digits += words[cursor]
            cursor += 1
        }
        return digits == words[index] ? first : Double(digits)
    }

    /// A whole number only: a decimal separator marks money or litres, never a mileage.
    private static func number(_ word: String) -> Double? {
        guard !word.isEmpty, word.allSatisfy(\.isNumber) else { return nil }
        return Double(word)
    }
}
