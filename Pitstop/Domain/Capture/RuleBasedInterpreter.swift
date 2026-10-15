import Foundation

/// A deterministic stand-in for the language model (CAP-002, ADR 0011). It recognises a few explicit
/// phrasings in Russian, Ukrainian and English and proposes nothing at all when it is not sure, so unsupported
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
        // Before the odometer rule, because "service in 3200 km" would otherwise read as a mileage of
        // 3,200 km, and after the completion rule, so "changed the oil at 84 200, next in 15 000" stays
        // the completion it reports. The operation is taken only when exactly one is named; a bare
        // "service" is asked, never guessed. "Overdue" next to a service word or a catalog operation names
        // the car's countdown too; "insurance overdue" does not.
        let isDashboardPhrase = reading.reportsDashboard || reading.mentionsServiceOverdue
        if isDashboardPhrase, let remaining = reading.dashboardRemaining {
            return MemoryProposal(
                sourceInputID: input.id,
                kind: .vehicleServiceReport,
                rawText: text,
                extractedOdometerKm: reading.statedOdometerBesideRemaining,
                extractedOperationID: reading.operation,
                extractedRemainingDistance: remaining.distance,
                extractedRemainingDistanceUnit: remaining.distance == nil ? nil : remaining.unit,
                extractedRemainingDays: remaining.days
            )
        }
        // A dashboard phrase whose number is marked overdue but could not be read as a countdown is kept as
        // words: that number is never a mileage. Anything else, including "odometer 91500 km, service
        // overdue", falls through to the rules below.
        if isDashboardPhrase, reading.hasOverdueMarkedValue {
            return nil
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
    private typealias Words = CaptureWords

    private let words: [String]
    /// Marks that survive word splitting: a question, and the English contracted negation.
    private let isQuestionOrNegated: Bool
    /// "ТО" (scheduled service) written as an uppercase word of its own. Lowercased, "то" is also the
    /// particle of "что-то" and "то есть", so only the uppercase spelling names a service.
    private let namesScheduledService: Bool

    init(_ raw: String) {
        // "Т.О." / "т.о." is the service "ТО"; split at the dots it would miss the marker "до ТО".
        // The iOS keyboard types U+2019 (and some layouts U+02BC) for an apostrophe; folded to ASCII so
        // "haven’t" is the same contracted negation as "haven't".
        let text = raw.replacing(/\b[Тт]\.\s?[Оо]\.?/, with: "ТО")
            .replacing("\u{2019}", with: "'")
            .replacing("\u{02BC}", with: "'")
        // Split keeping hyphens inside a token, so "что-ТО" is one token and never the service.
        namesScheduledService = text.split { !$0.isLetter && $0 != "-" }.contains("ТО")
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

    /// The car's own display is named: "dashboard says", "the car shows", "приборка показывает".
    var reportsDashboard: Bool {
        let namesCar = containsWord(["car", "машина", "авто"])
        let saysSomething = containsWord(["says", "shows", "показывает", "пишет", "показує", "пише"])
        return containsStem(["dashboard", "приборн", "приборк", "бортов", "панел"]) || (namesCar && saysSomething)
    }

    /// "Overdue", "просрочено", "прострочено" anywhere in the words.
    var mentionsOverdue: Bool {
        containsStem(["overdue", "просроч", "простроч"])
    }

    /// "Overdue" said of service work: next to a service word ("ТО", "service", "обслуживание") or a
    /// catalog operation. An overdue insurance, inspection or parking fine is not the car's countdown.
    var mentionsServiceOverdue: Bool {
        guard mentionsOverdue else { return false }
        let namesService =
            namesScheduledService || containsWord(["service", "servicing", "maintenance"])
            || containsStem(["сервис", "сервіс", "обслуж", "обслуг", "техобслуж"])
        return namesService || operation != nil
    }

    /// What the display says is left: a number after a countdown marker ("in", "через", "до ТО",
    /// "overdue by", "просрочено на") or before "left" / "overdue" after its unit, followed by a distance
    /// unit or a day word. A second value joined by "and" continues the countdown. A number after
    /// "пробег", "odometer" or a bare "на", or followed by "пробега" / "odometer", is never a remaining
    /// value, so a plain mileage next to the display is not mistaken for one. With no marked value,
    /// nothing was reported.
    var dashboardRemaining: (distance: Double?, unit: DistanceUnit, days: Int?)? {
        var distance: Double?
        var unit = DistanceUnit.kilometers
        var days: Int?
        var sign: Double?
        for index in words.indices {
            guard let value = joinedNumber(from: index), let next = nextWord(after: index, skippingDigits: true),
                !Words.isMileageWord(word(after: next, from: index) ?? ""),
                let marked = countdownSign(before: index, unitWord: next) ?? continuation(before: index, sign)
            else { continue }
            sign = marked
            if distance == nil, Words.units.contains(next) {
                distance = marked * value
            } else if distance == nil, Words.mileUnits.contains(next) {
                distance = marked * value
                unit = .miles
            } else if days == nil, Words.dayWords.contains(where: next.hasPrefix), value <= 10000 {
                days = Int(marked * value)
            }
        }
        guard distance != nil || days != nil else { return nil }
        return (distance, unit, days)
    }

    /// A number marked overdue and followed by a unit or a day word: an overdue countdown value, whether
    /// or not it could be read as one.
    var hasOverdueMarkedValue: Bool {
        words.indices.contains { index in
            guard joinedNumber(from: index) != nil, let next = nextWord(after: index, skippingDigits: true),
                Words.isUnitOrDayWord(next)
            else { return false }
            return countdownSign(before: index, unitWord: next) == -1
        }
    }

    /// +1 ahead, −1 overdue, nil when unmarked. Only the word right before the number counts, or "left" /
    /// "overdue" right after a unit or day word; never past any other word ("пробег 91500, ТО просрочено").
    private func countdownSign(before index: Int, unitWord: String) -> Double? {
        let previous = index > 0 ? words[index - 1] : nil
        let beforePrevious = index > 1 ? words[index - 2] : nil
        // "Odometer 92000 km overdue for oil": a number right after a mileage word is where the car is.
        guard previous.map(Words.isMileageWord) != true else { return nil }
        let afterUnit = Words.isUnitOrDayWord(unitWord) ? word(after: unitWord, from: index) : nil
        if let previous,
            Words.overdueMarkers.contains(previous) || (previous == "by" && beforePrevious == "overdue")
                || (previous == "на" && beforePrevious.map(Words.overdueMarkers.contains) == true)
        {
            return -1
        }
        if let afterUnit, Words.overdueMarkers.contains(afterUnit) {
            return -1
        }
        if let previous, Words.aheadMarkers.contains(previous) || (previous == "то" && beforePrevious == "до") {
            return 1
        }
        if let afterUnit, Words.trailingAheadMarkers.contains(afterUnit) {
            return 1
        }
        return nil
    }

    /// The word right after the unit that follows the number at `index`.
    private func word(after unitWord: String, from index: Int) -> String? {
        var cursor = index + 1
        while cursor < words.count, Words.number(words[cursor]) != nil {
            cursor += 1
        }
        guard cursor + 1 < words.count, words[cursor] == unitWord else { return nil }
        return words[cursor + 1]
    }

    /// "3200 km and 45 days": a value joined to a countdown value already read shares its sign.
    private func continuation(before index: Int, _ sign: Double?) -> Double? {
        guard let sign, index > 0 else { return nil }
        let previous = words[index - 1]
        let joined =
            Words.conjunctions.contains(previous) || Words.units.contains(previous)
            || Words.mileUnits.contains(previous)
        return joined ? sign : nil
    }

    /// A dashboard capture may also say where the car is: "пробег 38 800 км" or "38 800 км пробега". Only
    /// an explicit mileage word counts here; the remaining distance itself is never read as the odometer.
    var statedOdometerBesideRemaining: Double? {
        for index in words.indices {
            guard let value = joinedNumber(from: index) else { continue }
            let before = previousWord(before: index).map(Words.isMileageWord) ?? false
            let after =
                nextWord(after: index, skippingDigits: true)
                .flatMap { word(after: $0, from: index) }.map(Words.isMileageWord) ?? false
            if before || after, DomainCommandLimits.isPlausibleOdometer(value), value >= 100 {
                return value
            }
        }
        return nil
    }

    /// A price is written after "за" or "for", or next to a currency word.
    var amount: Decimal? {
        for (index, word) in words.enumerated() {
            let isPriceMarker = ["за", "for"].contains(word)
            let hasCurrencyNext = index + 1 < words.count && Words.currencies.contains(words[index + 1])
            guard isPriceMarker || (Words.number(word) != nil && hasCurrencyNext) else { continue }
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
        for index in words.indices {
            guard let value = joinedNumber(from: index) else { continue }
            let following = nextWord(after: index, skippingDigits: true)
            // "Просрочено на 300 км" is how far past something is, never where the car is.
            if let following, countdownSign(before: index, unitWord: following) == -1 {
                continue
            }
            let unitFollows = following.map(Words.units.contains) ?? false
            let previous = previousWord(before: index)
            let markerPrecedes =
                previous.map { word in
                    Words.isMileageWord(word)
                        || (allowingLooseMarkers && Words.looseMileageMarkers.contains(word))
                } ?? false
            guard unitFollows || markerPrecedes else { continue }
            // Plausibility first: nothing converts the value to an integer before it is in range.
            guard DomainCommandLimits.isPlausibleOdometer(value), value >= 100,
                Decimal(value) != amount
            else { continue }
            // A four-digit number after "в", "с", or "since" is a year, not a mileage.
            if !unitFollows, (1900...2100).contains(Int(value)), previous.map(Words.yearMarkers.contains) ?? false {
                continue
            }
            candidates.append(value)
        }
        return candidates.max()
    }

    // MARK: - Words and numbers

    private func containsWord(_ candidates: [String]) -> Bool {
        words.contains { candidates.contains($0) }
    }

    private func containsStem(_ stems: [String]) -> Bool {
        words.contains { word in stems.contains { word.contains($0) } }
    }

    private func previousWord(before index: Int) -> String? {
        var cursor = index - 1
        // Step back over the other halves of a grouped number such as "84 200".
        while cursor >= 0, Words.number(words[cursor]) != nil {
            cursor -= 1
        }
        return cursor >= 0 ? words[cursor] : nil
    }

    private func nextWord(after index: Int, skippingDigits: Bool) -> String? {
        var cursor = index + 1
        while skippingDigits, cursor < words.count, Words.number(words[cursor]) != nil {
            cursor += 1
        }
        return cursor < words.count ? words[cursor] : nil
    }

    /// Reads "84 200", written as separate words, as one number. It starts only at the first group,
    /// and a following group counts only when it is exactly three digits.
    private func joinedNumber(from index: Int) -> Double? {
        guard let first = Words.number(words[index]) else { return nil }
        if index > 0, Words.number(words[index - 1]) != nil {
            return nil
        }
        var digits = words[index]
        var cursor = index + 1
        while cursor < words.count, words[cursor].count == 3, Words.number(words[cursor]) != nil {
            digits += words[cursor]
            cursor += 1
        }
        return digits == words[index] ? first : Double(digits)
    }
}
