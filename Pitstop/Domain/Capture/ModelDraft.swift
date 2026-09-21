import Foundation

/// What a language model said about one capture, before any of it is trusted (ADR 0027). It is
/// model-agnostic: the Foundation Models adapter fills it, and tests fill it by hand, so the guards
/// below are tested without a model.
public struct ModelDraft: Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable, CaseIterable {
        case maintenanceCompletion
        case carWash
        case odometerReading
        /// Anything else: a thought, a plan, a question, a fact the validator cannot use.
        case other
    }

    public enum Operation: Hashable, Sendable {
        case named(MaintenanceOperationID)
        /// More than one operation: a visit with several jobs, which a proposal cannot express.
        case several
        case notNamed
    }

    public let kind: Kind
    public let operation: Operation
    /// The model's own reading of tense and mood. It can only suppress a proposal, never allow one.
    public let reportsCompletedAction: Bool
    public let odometerKm: Int?
    public let amount: Int?

    public init(
        kind: Kind,
        operation: Operation = .notNamed,
        reportsCompletedAction: Bool = true,
        odometerKm: Int? = nil,
        amount: Int? = nil
    ) {
        self.kind = kind
        self.operation = operation
        self.reportsCompletedAction = reportsCompletedAction
        self.odometerKm = odometerKm
        self.amount = amount
    }
}

/// Turns a model draft into a proposal under deterministic guards (ADR 0027). Every guard can only
/// remove meaning; none adds any. The validator and `ConfirmationPolicy` still decide what the
/// proposal may do (core P3).
public struct ModelDraftMapper: Sendable {
    /// A model has no calibrated confidence. This fixed value sits below
    /// `ConfirmationPolicy.autoAcceptConfidenceFloor`, so nothing a model proposes is saved without
    /// the user seeing it, including an odometer reading that a rule would auto-accept.
    public static let modelConfidence = 0.5

    public init() {}

    public func proposal(from draft: ModelDraft, input: CaptureInput) -> MemoryProposal? {
        let text = input.payload.rawContent
        // An intention stays a Note (REQ-CAPTURE-014), by a deterministic rule rather than the model.
        guard !text.isBlank, !Self.isHedged(text) else { return nil }
        let numbers = GroundedNumbers(text)
        // A number the user did not write is a hallucination, not an extraction.
        let kilometers = draft.odometerKm.map(Double.init).flatMap { value in
            numbers.contains(value) && value >= 100 && DomainCommandLimits.isPlausibleOdometer(value) ? value : nil
        }
        // Presence is not enough for a price: a number written as a mileage ("at 84200", "84200 km") is
        // never read as money, whatever the model says.
        let amount = draft.amount.flatMap { value in
            let number = Double(value)
            return value > 0 && numbers.contains(number) && !numbers.isMileage(number) && number != kilometers
                ? value : nil
        }

        switch draft.kind {
        case .maintenanceCompletion:
            guard draft.reportsCompletedAction, case let .named(operation) = draft.operation,
                  MaintenanceOperationID.catalog.contains(operation) else { return nil }
            return MemoryProposal(
                sourceInputID: input.id,
                kind: .maintenanceCompletion,
                rawText: text,
                confidence: Self.modelConfidence,
                extractedOdometerKm: kilometers,
                extractedOperationID: operation
            )
        case .carWash:
            guard draft.reportsCompletedAction else { return nil }
            return MemoryProposal(
                sourceInputID: input.id,
                kind: .vehicleEvent,
                rawText: text,
                confidence: Self.modelConfidence,
                extractedOdometerKm: kilometers,
                extractedEventKind: .carWash,
                extractedAmount: amount.map { Decimal($0) }
            )
        case .odometerReading:
            // A reading without a number the user wrote is no reading at all.
            guard let kilometers else { return nil }
            return MemoryProposal(
                sourceInputID: input.id,
                kind: .odometerReading,
                rawText: text,
                confidence: Self.modelConfidence,
                extractedOdometerKm: kilometers
            )
        case .other:
            return nil
        }
    }
}

extension ModelDraftMapper {
    /// The rules' hedge words plus English future and planning wording. The extra words apply only
    /// before and after the model: the shipped rules keep their narrower list (ADR 0011), where
    /// "did the scheduled brake fluid change" must still read as done.
    public static func isHedged(_ text: String) -> Bool {
        RuleBasedInterpreter.isHedged(text) || mentionsFutureOrPlan(text)
    }

    private static let futureWords: Set<String> = [
        "will", "ll", "shall", "gonna", "wanna", "gotta", "tomorrow", "later", "soon", "plan", "plans",
        "planned", "planning", "book", "booking", "schedule", "scheduled", "remind", "reminder", "todo",
    ]

    private static let futurePhrases: [[String]] = [
        ["going", "to"], ["have", "to"], ["has", "to"], ["next", "week"], ["next", "month"], ["next", "time"],
    ]

    /// "ll" is what "I'll" splits into.
    private static func mentionsFutureOrPlan(_ text: String) -> Bool {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let hasPhrase = zip(words, words.dropFirst()).contains { futurePhrases.contains([$0.0, $0.1]) }
        return hasPhrase || words.contains { futureWords.contains($0) }
    }
}

/// Whole numbers written in a capture, so a model's number can be checked against the wording.
/// "84 200" counts as 84200 and as its leading group 84 (not 200), and "85k" or 85 followed by a word
/// for "thousand" as 85000. A number after a mileage marker or before a distance unit is also
/// remembered as a mileage.
struct GroundedNumbers {
    private var values: Set<Double> = []
    private var mileages: Set<Double> = []

    init(_ text: String) {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        var index = 0
        while index < words.count {
            let word = words[index]
            if let value = Self.thousands(word) {
                values.insert(value)
                let unitFollows = index + 1 < words.count && Self.isDistanceUnit(words[index + 1])
                if (index > 0 && Self.isMileageMarker(words[index - 1])) || unitFollows {
                    mileages.insert(value)
                }
            }
            guard let value = Self.number(word) else {
                index += 1
                continue
            }
            values.insert(value)
            var digits = word
            var cursor = index + 1
            while cursor < words.count, words[cursor].count == 3, Self.number(words[cursor]) != nil {
                digits += words[cursor]
                values.insert(Double(digits) ?? value)
                cursor += 1
            }
            var whole = Double(digits) ?? value
            var unitIndex = cursor
            if cursor < words.count, Self.thousandWords.contains(words[cursor]) {
                whole *= 1000
                values.insert(whole)
                unitIndex += 1
            }
            let markerPrecedes = index > 0 && Self.isMileageMarker(words[index - 1])
            let unitFollows = unitIndex < words.count && Self.isDistanceUnit(words[unitIndex])
            if markerPrecedes || unitFollows {
                mileages.insert(whole)
            }
            index = cursor
        }
    }

    func contains(_ value: Double) -> Bool {
        values.contains(value)
    }

    func isMileage(_ value: Double) -> Bool {
        mileages.contains(value)
    }

    private static func isMileageMarker(_ word: String) -> Bool {
        ["at", "на", "mileage", "odometer"].contains(word)
            || ["пробег", "пробіг", "одометр"].contains { word.hasPrefix($0) }
    }

    private static func isDistanceUnit(_ word: String) -> Bool {
        ["km", "км", "kilometers", "kilometres", "miles"].contains(word)
            || ["килом", "кілом"].contains { word.hasPrefix($0) }
    }

    private static let thousandWords: Set<String> = ["тыс", "тысяч", "тысячи", "тысяча", "k", "тис", "тисяч", "тисячі"]

    private static func number(_ word: String) -> Double? {
        guard !word.isEmpty, word.allSatisfy(\.isNumber) else { return nil }
        return Double(word)
    }

    private static func thousands(_ word: String) -> Double? {
        guard let suffix = word.last, ["k", "к"].contains(suffix) else { return nil }
        return number(String(word.dropLast())).map { $0 * 1000 }
    }
}
