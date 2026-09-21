import Foundation
@testable import Pitstop
import Testing

@Suite("Pit question registry")
struct PitQuestionRegistryTests {
    @Test("REQ-PIT-009: a question whose value claim is blank cannot be registered")
    func blankValueIsRejected() {
        #expect(throws: PitQuestionRegistry.RegistrationError.blankValueClaim(PitQuestionFixtures.oilIntervalID)) {
            try PitQuestionRegistry([PitQuestionFixtures.definition(claim: "  ")])
        }
    }

    @Test("ADR-0016: a question without a declared deferral path cannot be registered")
    func blankDeferralPathIsRejected() {
        #expect(throws: PitQuestionRegistry.RegistrationError.blankFallback(PitQuestionFixtures.oilIntervalID)) {
            try PitQuestionRegistry([PitQuestionFixtures.definition(withoutAnswer: "")])
        }
        #expect(throws: PitQuestionRegistry.RegistrationError.nonPositiveReturn(PitQuestionFixtures.oilIntervalID)) {
            try PitQuestionRegistry([PitQuestionFixtures.definition(afterDeferral: .notBefore(0))])
        }
        #expect(throws: PitQuestionRegistry.RegistrationError.nonPositiveReturn(PitQuestionFixtures.oilIntervalID)) {
            try PitQuestionRegistry([PitQuestionFixtures.definition(afterAnswer: .notBefore(-1))])
        }
    }

    @Test("ADR-0016: a question ID is registered once, because persisted state is keyed by it")
    func duplicateIDsAreRejected() {
        #expect(throws: PitQuestionRegistry.RegistrationError.duplicateID(PitQuestionFixtures.oilIntervalID)) {
            try PitQuestionRegistry([PitQuestionFixtures.definition(), PitQuestionFixtures.definition(priority: 1)])
        }
        #expect(throws: PitQuestionRegistry.RegistrationError.blankID) {
            try PitQuestionRegistry([PitQuestionFixtures.definition(id: " ")])
        }
    }

    @Test("ADR-0016: every product question declares its value and deferral path")
    func productRegistryIsValid() throws {
        let registry = try PitQuestionRegistry.product()
        #expect(registry.definitions.count == PitQuestionRegistry.productDefinitions.count)
    }

    @Test("REQ-PIT-008: stored resolutions reach the policy; unknown stored IDs are ignored")
    func statesJoinDefinitions() throws {
        let registry = try PitQuestionFixtures.registry()
        let states = [
            PitQuestionState(questionID: PitQuestionFixtures.oilIntervalID, resolution: .deferred),
            PitQuestionState(questionID: "retired.question", resolution: .unresolved),
        ]

        let questions = registry.questions(with: states, now: Date(timeIntervalSince1970: 1_800_000_000))

        #expect(questions.map(\.id) == [PitQuestionFixtures.oilIntervalID, PitQuestionFixtures.roadHorizonID])
        #expect(questions.map(\.resolution) == [.deferred, .unresolved])
        #expect(questions.allSatisfy { $0.unlocks != nil })
    }
}

@Suite("Pit question state")
struct PitQuestionStateTests {
    private let id = PitQuestionFixtures.oilIntervalID
    private let path = PitQuestionFixtures.definition().deferral
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("REQ-PIT-010: a dismissal keeps its own time even after a later answer")
    func dismissalTimeSurvivesAnswer() throws {
        let dismissed = try PitQuestionCommand.dismissed(questionID: id).applied(to: nil, path: path, now: now)
        let answered = try PitQuestionCommand.answered(questionID: id).applied(to: dismissed, path: path, now: now + 60)

        #expect(answered.resolution == .answered)
        #expect(answered.lastDismissedAt == now)
        #expect(answered.resolvedAt == now + 60)
    }

    @Test(
        "REQ-PIT-010: a resolution without a recorded ask still starts the interruption cooldown",
        arguments: [
            PitQuestionCommand.answered(questionID: PitQuestionFixtures.oilIntervalID),
            .deferred(questionID: PitQuestionFixtures.oilIntervalID),
            .dismissed(questionID: PitQuestionFixtures.oilIntervalID),
        ]
    )
    func resolutionStartsInterruptionCooldown(command: PitQuestionCommand) throws {
        let resolved = try command.applied(to: nil, path: path, now: now)
        #expect(resolved.lastAskedAt == now)

        let asked = try PitQuestionCommand.asked(questionID: id).applied(to: nil, path: path, now: now - 60)
        #expect(try command.applied(to: asked, path: path, now: now).lastAskedAt == now - 60)
        #expect(PitAttentionBudget([resolved]).sinceLastInterruption(now: now + 60) == 60)
    }

    @Test("ADR-0016: an answered question cannot be deferred or dismissed afterwards")
    func answerIsFinal() throws {
        let answered = try PitQuestionCommand.answered(questionID: id).applied(to: nil, path: path, now: now)
        #expect(throws: PitQuestionStoreError.alreadyAnswered) {
            try PitQuestionCommand.deferred(questionID: id).applied(to: answered, path: path, now: now)
        }
        #expect(throws: PitQuestionStoreError.alreadyAnswered) {
            try PitQuestionCommand.dismissed(questionID: id).applied(to: answered, path: path, now: now)
        }
    }

    @Test("REQ-PIT-010: the budget takes the latest interruption and dismissal across all questions")
    func budgetSpansQuestions() {
        let budget = PitAttentionBudget([
            PitQuestionState(questionID: "a", lastAskedAt: now - 100, lastDismissedAt: now - 100),
            PitQuestionState(questionID: "b", lastAskedAt: now - 10),
        ])
        #expect(budget.sinceLastInterruption(now: now) == 10)
        #expect(budget.sinceLastDismissal(now: now) == 100)
        #expect(PitAttentionBudget([]).sinceLastInterruption(now: now) == .infinity)
    }
}
