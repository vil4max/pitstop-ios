import Foundation
import FoundationModels
import NaturalLanguage

/// Why the model cannot interpret a capture. Every case is "interpreter unavailable" to the
/// pipeline (ADR 0011): the wording is kept raw.
public enum FoundationModelsInterpreterError: Error, Hashable, Sendable {
    case modelUnavailable(ModelUnavailability)
    /// The capture's language is not supported by Apple Intelligence (Russian and Ukrainian on iOS 27)
    /// or not covered by the deterministic hedge rule (ADR 0027).
    case unsupportedLanguage
    case generationFailed(GenerationFailure)

    public enum ModelUnavailability: String, Hashable, Sendable {
        case deviceNotEligible
        case appleIntelligenceNotEnabled
        case modelNotReady
        case unknown
    }

    public enum GenerationFailure: String, Hashable, Sendable {
        case guardrailViolation
        case refusal
        case exceededContextWindow
        case decodingFailure
        case unsupportedLanguage
        case rateLimited
        case other
    }
}

public enum ModelReadiness: Hashable, Sendable {
    case ready
    case unavailable(FoundationModelsInterpreterError.ModelUnavailability)
    case unsupportedLanguage
}

/// The seam over the language model, so the interpreter's rules are tested without one.
public protocol CaptureDrafting: Sendable {
    func readiness(for language: Locale.Language) -> ModelReadiness
    /// Throws `FoundationModelsInterpreterError` or `CancellationError`.
    func draft(_ text: String, localeIdentifier: String) async throws -> ModelDraft
}

/// Foundation Models behind `SemanticInterpreting` (CAP-005, ADR 0027). It only suggests: the
/// draft passes `ModelDraftMapper`'s guards, then the validator and `ConfirmationPolicy` decide.
/// It never writes anything.
public struct FoundationModelsInterpreter: SemanticInterpreting {
    /// A capture is a short thought. Longer text (a recognised document) is not this interpreter's
    /// job and would spend the 4,096-token context and the 6-second deadline (ADR 0015).
    public static let maximumInputLength = 400
    /// Languages whose hedge, plan and future words `ModelDraftMapper.isHedged` covers. Russian is
    /// covered too, but Apple Intelligence rejects it on iOS 27 (ADR 0027).
    public static let hedgeRuleLanguages: Set<String> = ["en"]

    private let drafter: any CaptureDrafting
    private let mapper = ModelDraftMapper()

    public init(drafter: any CaptureDrafting = SystemModelDrafter()) {
        self.drafter = drafter
    }

    public func interpret(_ input: CaptureInput) async throws -> MemoryProposal? {
        let text = input.payload.rawContent
        guard !text.isBlank, text.count <= Self.maximumInputLength else { return nil }
        // The hedge rule is the deterministic guard against a misread intention (REQ-CAPTURE-014); a
        // language it does not cover, or one that cannot be told reliably, is not sent to the model. The
        // locale is not a fallback: it says what the person set, not what they wrote.
        guard let language = CaptureLanguage.dominant(in: text),
              Self.hedgeRuleLanguages.contains(language.languageCode?.identifier ?? "")
        else {
            throw FoundationModelsInterpreterError.unsupportedLanguage
        }
        switch drafter.readiness(for: language) {
        case .ready:
            break
        case let .unavailable(reason):
            throw FoundationModelsInterpreterError.modelUnavailable(reason)
        case .unsupportedLanguage:
            throw FoundationModelsInterpreterError.unsupportedLanguage
        }
        // The mapper would drop any proposal for hedged wording anyway; not asking saves the latency.
        guard !ModelDraftMapper.isHedged(text) else { return nil }
        let draft = try await drafter.draft(text, localeIdentifier: input.localeIdentifier)
        try Task.checkCancellation()
        return mapper.proposal(from: draft, input: input)
    }
}

enum CaptureLanguage {
    /// Below this the recogniser is guessing; a few words with digits are easily misread.
    static let minimumConfidence = 0.6

    /// The language the capture is written in; `nil` when it cannot be told with confidence.
    static func dominant(in text: String) -> Locale.Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let top = recognizer.languageHypotheses(withMaximum: 1).max(by: { $0.value < $1.value }),
              top.key != .undetermined, top.value >= minimumConfidence else { return nil }
        return Locale.Language(identifier: top.key.rawValue)
    }
}

/// The on-device system model. A new session per capture: captures are independent, and a
/// session answers one request at a time.
public struct SystemModelDrafter: CaptureDrafting {
    private let model: SystemLanguageModel

    public init(model: SystemLanguageModel = .default) {
        self.model = model
    }

    public func readiness(for language: Locale.Language) -> ModelReadiness {
        switch model.availability {
        case .available:
            break
        case let .unavailable(reason):
            return .unavailable(Self.unavailability(reason))
        }
        return model.supportsLocale(Locale(identifier: language.minimalIdentifier)) ? .ready : .unsupportedLanguage
    }

    public func draft(_ text: String, localeIdentifier: String) async throws -> ModelDraft {
        let session = LanguageModelSession(model: model, instructions: Self.instructions(localeIdentifier))
        do {
            let response = try await session.respond(
                to: text,
                generating: CaptureDraftSchema.self,
                options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 120)
            )
            return response.content.draft
        } catch let error as LanguageModelSession.GenerationError {
            throw FoundationModelsInterpreterError.generationFailed(Self.failure(error))
        } catch let error as LanguageModelError {
            throw FoundationModelsInterpreterError.generationFailed(Self.failure(error))
        }
    }

    /// The prompt text is in English on purpose: Apple recommends writing the built-in prompt in a
    /// supported language and naming the person's locale with this exact phrase.
    static func instructions(_ localeIdentifier: String) -> String {
        var lines = [
            "You read one short note that a car owner wrote or dictated about their own car.",
            "Classify what the note reports. Copy numbers exactly as they are written in the note.",
            "maintenanceCompletion: the note says one maintenance operation was already done.",
            "carWash: the note says the car was already washed.",
            "odometerReading: the note states the car's current mileage.",
            "other: everything else, including plans, wishes, reminders, questions, prices without a service,"
                + " and notes about other topics.",
            "Never invent a number. Leave a number empty when the note does not contain it.",
        ]
        let locale = Locale(identifier: localeIdentifier)
        if !Locale.Language(identifier: "en_US").isEquivalent(to: locale.language) {
            lines.insert("The person's locale is \(localeIdentifier).", at: 0)
        }
        return lines.joined(separator: "\n")
    }

    private static func unavailability(
        _ reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> FoundationModelsInterpreterError.ModelUnavailability {
        switch reason {
        case .deviceNotEligible: .deviceNotEligible
        case .appleIntelligenceNotEnabled: .appleIntelligenceNotEnabled
        case .modelNotReady: .modelNotReady
        @unknown default: .unknown
        }
    }

    private static func failure(
        _ error: LanguageModelSession.GenerationError
    ) -> FoundationModelsInterpreterError.GenerationFailure {
        switch error {
        case .guardrailViolation: .guardrailViolation
        case .refusal: .refusal
        case .exceededContextWindowSize: .exceededContextWindow
        case .decodingFailure: .decodingFailure
        case .unsupportedLanguageOrLocale: .unsupportedLanguage
        case .rateLimited, .concurrentRequests: .rateLimited
        default: .other
        }
    }

    private static func failure(_ error: LanguageModelError) -> FoundationModelsInterpreterError.GenerationFailure {
        switch error {
        case .guardrailViolation: .guardrailViolation
        case .refusal: .refusal
        case .contextSizeExceeded: .exceededContextWindow
        case .unsupportedLanguageOrLocale: .unsupportedLanguage
        case .rateLimited: .rateLimited
        default: .other
        }
    }
}

/// The guided-generation schema. Property names and guides are model input, so they are plain
/// English; the kinds are only those the validator can use.
@Generable(description: "What one short note about a car reports")
struct CaptureDraftSchema {
    @Guide(
        description: "True only when the note reports something already done; false for plans, wishes, questions"
    )
    var reportsCompletedAction: Bool

    @Guide(description: "What the note reports")
    var kind: Kind

    @Guide(
        description: "For maintenanceCompletion, the one operation done; several if more; otherwise noOperation"
    )
    var operation: Operation

    @Guide(description: "Mileage in kilometres, exactly as written in the note")
    var odometerKm: Int?

    @Guide(description: "Price paid, exactly as written in the note")
    var amount: Int?

    @Generable
    enum Kind {
        case maintenanceCompletion
        case carWash
        case odometerReading
        case other
    }

    @Generable
    enum Operation {
        case engineOilChange
        case gearboxService
        case allWheelDriveCouplingService
        case brakeFluidChange
        case cabinFilterChange
        case airFilterChange
        case sparkPlugsChange
        case several
        case noOperation
    }

    var draft: ModelDraft {
        ModelDraft(
            kind: kind.draftKind,
            operation: operation.draftOperation,
            reportsCompletedAction: reportsCompletedAction,
            odometerKm: odometerKm,
            amount: amount
        )
    }
}

extension CaptureDraftSchema.Kind {
    var draftKind: ModelDraft.Kind {
        switch self {
        case .maintenanceCompletion: .maintenanceCompletion
        case .carWash: .carWash
        case .odometerReading: .odometerReading
        case .other: .other
        }
    }
}

extension CaptureDraftSchema.Operation {
    var draftOperation: ModelDraft.Operation {
        switch self {
        case .engineOilChange: .named(.engineOilService)
        case .gearboxService: .named(.dsgService)
        case .allWheelDriveCouplingService: .named(.awdCouplingService)
        case .brakeFluidChange: .named(.brakeFluid)
        case .cabinFilterChange: .named(.cabinFilter)
        case .airFilterChange: .named(.airFilter)
        case .sparkPlugsChange: .named(.sparkPlugs)
        case .several: .several
        case .noOperation: .notNamed
        }
    }
}
