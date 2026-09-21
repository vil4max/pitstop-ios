import Foundation
@testable import Pitstop
import Synchronization
import Testing

/// Stands in for the language model: answers with a fixed draft and counts the requests.
final class FakeDrafter: CaptureDrafting {
    private let readinessValue: ModelReadiness
    private let result: Result<ModelDraft, FoundationModelsInterpreterError>
    private let calls = Mutex(0)

    init(
        _ draft: ModelDraft = ModelDraft(kind: .other),
        readiness: ModelReadiness = .ready,
        failure: FoundationModelsInterpreterError? = nil
    ) {
        readinessValue = readiness
        result = failure.map { .failure($0) } ?? .success(draft)
    }

    var callCount: Int {
        calls.withLock { $0 }
    }

    func readiness(for _: Locale.Language) -> ModelReadiness {
        readinessValue
    }

    func draft(_: String, localeIdentifier _: String) async throws -> ModelDraft {
        calls.withLock { $0 += 1 }
        return try result.get()
    }
}

/// English, the only language the hedge rule covers and the model is asked about (ADR 0027).
private func englishInput(_ text: String) -> CaptureInput {
    CaptureInput(
        payload: .text(text),
        source: .pitText,
        capturedAt: DomainFixtures.Odometers.baseDate,
        localeIdentifier: "en_US",
        selectedVehicleID: DomainFixtures.Vehicles.defaultID
    )
}

private func interpret(_ text: String, with drafter: FakeDrafter) async throws -> MemoryProposal? {
    try await FoundationModelsInterpreter(drafter: drafter).interpret(englishInput(text))
}

@Suite("Foundation Models interpreter")
struct FoundationModelsInterpreterTests {
    @Test("ADR-0027: a completion draft becomes a proposal that keeps the wording and needs confirmation")
    func completionDraftIsProposed() async throws {
        let text = "Changed the engine oil at 85 000 km"
        let drafter = FakeDrafter(ModelDraft(
            kind: .maintenanceCompletion, operation: .named(.engineOilService), odometerKm: 85000
        ))
        let input = englishInput(text)

        let proposal = try #require(await FoundationModelsInterpreter(drafter: drafter).interpret(input))

        #expect(proposal.kind == .maintenanceCompletion)
        #expect(proposal.extractedOperationID == .engineOilService)
        #expect(proposal.extractedOdometerKm == 85000)
        #expect(proposal.rawText == text)
        #expect(proposal.sourceInputID == input.id)
        let outcome = try ConfirmationPolicy().outcome(for: validated(proposal, input: input))
        #expect(outcome == .confirmCompact)
    }

    @Test("ADR-0027: a model odometer reading is confirmed, never auto-accepted like a rule's reading")
    func modelReadingNeedsConfirmation() async throws {
        let input = englishInput("The odometer on my car shows 91200 km today")
        let drafter = FakeDrafter(ModelDraft(kind: .odometerReading, odometerKm: 91200))

        let proposal = try #require(await FoundationModelsInterpreter(drafter: drafter).interpret(input))

        #expect(proposal.confidence == ModelDraftMapper.modelConfidence)
        #expect(try ConfirmationPolicy().outcome(for: validated(proposal, input: input)) == .confirmCompact)
    }

    @Test(
        "REQ-CAPTURE-014: hedged wording never becomes work, and the model is not even asked",
        arguments: [
            "need to change the oil", "did I change the oil?", "Going to change the oil at 90000 km",
            "Will wash the car tomorrow", "I'll replace the cabin filter", "Have to book the brake fluid change",
            "Planning to replace the spark plugs", "oil change next week",
        ]
    )
    func hedgedWordingIsNotInterpreted(text: String) async throws {
        let drafter = FakeDrafter(ModelDraft(kind: .maintenanceCompletion, operation: .named(.engineOilService)))

        #expect(try await interpret(text, with: drafter) == nil)
        #expect(drafter.callCount == 0)
    }

    @Test("REQ-CAPTURE-014: the mapper drops a proposal for hedged wording even when a model returned one")
    func mapperDropsHedgedWording() {
        let draft = ModelDraft(kind: .maintenanceCompletion, operation: .named(.brakeFluid))
        #expect(ModelDraftMapper().proposal(from: draft, input: englishInput("should replace brake fluid")) == nil)
    }

    @Test(
        "REQ-CAPTURE-014: a plan stays a note even when the model reports it as done",
        arguments: ["Going to change the oil at 90000 km", "spark plugs tomorrow morning", "will wash it soon"]
    )
    func deterministicGuardOverridesModel(text: String) {
        let draft = ModelDraft(
            kind: .maintenanceCompletion, operation: .named(.engineOilService), reportsCompletedAction: true
        )
        #expect(ModelDraftMapper().proposal(from: draft, input: englishInput(text)) == nil)
    }

    @Test("ADR-0027: the model's own reading of an intention can only suppress a proposal")
    func modelIntentionSuppresses() async throws {
        let drafter = FakeDrafter(ModelDraft(
            kind: .maintenanceCompletion, operation: .named(.sparkPlugs), reportsCompletedAction: false
        ))
        #expect(try await interpret("new spark plugs in the car", with: drafter) == nil)
        #expect(drafter.callCount == 1)
    }

    @Test(
        "ADR-0027: text whose language cannot be told is not sent to the model, whatever the locale",
        arguments: ["84200", "ок"]
    )
    func unknownLanguageIsNotSent(text: String) async {
        let drafter = FakeDrafter(ModelDraft(kind: .odometerReading, odometerKm: 84200))
        await #expect(throws: FoundationModelsInterpreterError.unsupportedLanguage) {
            try await interpret(text, with: drafter)
        }
        #expect(drafter.callCount == 0)
    }

    @Test("ADR-0027: a language the hedge rule does not cover is never sent to the model")
    func uncoveredLanguageIsNotSent() async {
        let drafter = FakeDrafter(ModelDraft(kind: .carWash))
        let input = CaptureInput(
            payload: .text("J'ai lavé la voiture pour vingt euros"),
            source: .pitText,
            capturedAt: DomainFixtures.Odometers.baseDate,
            localeIdentifier: "fr_FR"
        )
        await #expect(throws: FoundationModelsInterpreterError.unsupportedLanguage) {
            try await FoundationModelsInterpreter(drafter: drafter).interpret(input)
        }
        #expect(drafter.callCount == 0)
    }

    @Test("ADR-0027: a number written as a mileage is never taken as a price")
    func mileageIsNotAPrice() async throws {
        let text = "Washed the car at 84200 for 600"
        let wrong = try #require(await interpret(text, with: FakeDrafter(ModelDraft(kind: .carWash, amount: 84200))))
        #expect(wrong.extractedAmount == nil)
        let right = try #require(await interpret(text, with: FakeDrafter(ModelDraft(kind: .carWash, amount: 600))))
        #expect(right.extractedAmount == 600)
        let unit = try #require(await interpret(
            "washed the car, 84 200 km, paid 700",
            with: FakeDrafter(ModelDraft(kind: .carWash, amount: 84200))
        ))
        #expect(unit.extractedAmount == nil)
    }

    @Test("ADR-0027: a number the user did not write is dropped")
    func ungroundedNumbersAreDropped() async throws {
        let wash = FakeDrafter(ModelDraft(kind: .carWash, odometerKm: 90000, amount: 700))
        let proposal = try #require(await interpret("washed the car for 500", with: wash))
        #expect(proposal.extractedOdometerKm == nil)
        #expect(proposal.extractedAmount == nil)

        let reading = FakeDrafter(ModelDraft(kind: .odometerReading, odometerKm: 84000))
        #expect(try await interpret("mileage is now eighty four thousand", with: reading) == nil)
    }

    @Test("ADR-0027: grounded numbers include grouped digits and thousands written as words")
    func groundedNumbers() {
        let numbers = GroundedNumbers("пробег 84 200, мойка за 1500 и 85к, ещё 90 тыс")
        for value in [84200.0, 84, 1500, 85000, 90000] {
            #expect(numbers.contains(value), "\(value)")
        }
        #expect(!numbers.contains(200))
        #expect(!numbers.contains(8420))
        #expect(numbers.isMileage(84200))
        #expect(!numbers.isMileage(1500))
    }

    @Test(
        "ADR-0011: unsupported drafts propose nothing",
        arguments: [
            ModelDraft(kind: .other),
            ModelDraft(kind: .maintenanceCompletion, operation: .several),
            ModelDraft(kind: .maintenanceCompletion, operation: .notNamed),
            ModelDraft(kind: .maintenanceCompletion, operation: .named("timingBelt")),
        ]
    )
    func unsupportedDraftsProposeNothing(draft: ModelDraft) async throws {
        #expect(try await interpret("had the car at the garage today", with: FakeDrafter(draft)) == nil)
    }

    @Test(
        "REQ-CAPTURE-007: an unavailable model or language throws, so the wording is kept raw",
        arguments: [
            (ModelReadiness.unavailable(.appleIntelligenceNotEnabled),
             FoundationModelsInterpreterError.modelUnavailable(.appleIntelligenceNotEnabled)),
            (ModelReadiness.unavailable(.deviceNotEligible), .modelUnavailable(.deviceNotEligible)),
            (ModelReadiness.unsupportedLanguage, .unsupportedLanguage),
        ]
    )
    func unavailableModelThrows(readiness: ModelReadiness, expected: FoundationModelsInterpreterError) async {
        let drafter = FakeDrafter(readiness: readiness)
        await #expect(throws: expected) {
            try await interpret("changed the oil at 85000", with: drafter)
        }
        #expect(drafter.callCount == 0)
    }

    @Test("REQ-CAPTURE-007: a generation failure throws instead of guessing")
    func generationFailureThrows() async {
        let drafter = FakeDrafter(failure: .generationFailed(.guardrailViolation))
        await #expect(throws: FoundationModelsInterpreterError.generationFailed(.guardrailViolation)) {
            try await interpret("washed the car", with: drafter)
        }
    }

    @Test("ADR-0027: long text is not sent to the model")
    func longTextIsNotInterpreted() async throws {
        let drafter = FakeDrafter(ModelDraft(kind: .carWash))
        let text = String(repeating: "washed the car ", count: 40)
        #expect(try await interpret(text, with: drafter) == nil)
        #expect(drafter.callCount == 0)
    }

    @Test("REQ-CAPTURE-007: an unavailable model in the pipeline saves the wording as a note")
    func pipelineKeepsWordingWhenModelIsUnavailable() async throws {
        let store = FakeCarMemoryStore()
        let pipeline = RememberPipeline(
            store: store,
            interpreter: FoundationModelsInterpreter(drafter: FakeDrafter(readiness: .unsupportedLanguage)),
            now: { captureTestNow }
        )

        let outcome = try await pipeline.remember(captureInput("помыл машину за 700"), mode: .interpreted)

        guard case let .saved(_, preservedRaw) = outcome else {
            Issue.record("expected a saved note, got \(outcome)")
            return
        }
        #expect(preservedRaw)
        #expect(await store.storedNotes.map(\.rawText) == ["помыл машину за 700"])
    }

    @Test("ADR-0027: the instructions name a non-US locale with Apple's exact phrase")
    func instructionsNameTheLocale() {
        #expect(SystemModelDrafter.instructions("ru_RU").hasPrefix("The person's locale is ru_RU."))
        #expect(!SystemModelDrafter.instructions("en_US").contains("The person's locale"))
    }
}

@Suite("Interpreter chain")
struct InterpreterChainTests {
    @Test("ADR-0027: the rules answer first and the model is not asked")
    func rulesAnswerFirst() async throws {
        let drafter = FakeDrafter(ModelDraft(kind: .carWash))
        let chain = InterpreterChain([RuleBasedInterpreter(), FoundationModelsInterpreter(drafter: drafter)])

        let proposal = try #require(await chain.interpret(captureInput("поменял масло на 85000")))

        #expect(proposal.kind == .maintenanceCompletion)
        #expect(proposal.confidence == nil)
        #expect(drafter.callCount == 0)
    }

    @Test("ADR-0027: the model is asked only when the rules find no meaning")
    func modelWidensRecall() async throws {
        let drafter = FakeDrafter(ModelDraft(kind: .carWash, amount: 600))
        let chain = InterpreterChain([RuleBasedInterpreter(), FoundationModelsInterpreter(drafter: drafter)])

        let proposal = try #require(await chain.interpret(englishInput("took the car through the car wash, 600")))

        #expect(proposal.kind == .vehicleEvent)
        #expect(proposal.extractedAmount == 600)
        #expect(drafter.callCount == 1)
    }

    @Test("ADR-0011: an unavailable last member is reported as unavailable")
    func unavailableMemberThrows() async {
        let chain = InterpreterChain([
            RuleBasedInterpreter(),
            FoundationModelsInterpreter(drafter: FakeDrafter(readiness: .unsupportedLanguage)),
        ])
        await #expect(throws: FoundationModelsInterpreterError.unsupportedLanguage) {
            try await chain.interpret(captureInput("заехал в сервис"))
        }
    }

    @Test("ADR-0027: Foundation Models is off unless the DEBUG launch argument asks for it")
    func compositionIsOffByDefault() {
        #expect(InterpreterComposition(arguments: []) == .ruleBased)
        #expect(InterpreterComposition(arguments: []).version == .ruleBasedV1)
        #expect(AppEnvironment.live(arguments: [AppEnvironment.inMemoryArgument]).interpretation == .ruleBased)
        #if DEBUG
            let enabled = InterpreterComposition(arguments: [AppEnvironment.foundationModelsArgument])
            #expect(enabled == .ruleBasedThenFoundationModels)
            #expect(enabled.version == .ruleBasedThenFoundationModelsV1)
        #endif
    }
}
