import Foundation
import FoundationModels
@testable import Pitstop
import Testing

extension Tag {
    /// Model-quality evaluation; the real-model lane runs only on request (test-strategy, ADR 0027).
    @Tag static var aiEvaluation: Self
}

/// `TEST_RUNNER_PITSTOP_AI_EVAL=1 xcodebuild test ...` opts in. `just verify` never sets it, so the
/// gate stays deterministic and never needs the model.
private let realModelLaneRequested = ProcessInfo.processInfo.environment["PITSTOP_AI_EVAL"] == "1"

@Suite("Interpreter evaluation", .tags(.aiEvaluation))
struct InterpreterEvaluationTests {
    @Test("ADR-0027: the golden set covers every category, locale, and supported kind")
    func goldenSetIsBalanced() {
        let cases = CaptureGoldenSet.cases
        for category in GoldenCase.Category.allCases {
            #expect(cases.contains { $0.category == category }, "\(category)")
        }
        for locale in ["ru_RU", "en_US", "uk_UA"] {
            #expect(cases.contains { $0.locale == locale }, "\(locale)")
        }
        let kinds = Set(cases.compactMap(\.expected?.kind))
        #expect(kinds == [.maintenanceCompletion, .vehicleEvent, .odometerReading])
        // Only positive cases carry an expected proposal.
        #expect(cases.allSatisfy { ($0.expected != nil) == ($0.category == .positive) })
    }

    @Test("REQ-CAPTURE-014: the rule-based baseline never turns wording that must stay raw into work")
    func ruleBasedBaseline() async {
        let evaluation = await InterpreterEvaluation.run(RuleBasedInterpreter())
        record(evaluation.report(title: "rule_based_1"), named: "rule_based_1")

        #expect(evaluation.unavailableCount == 0)
        #expect(evaluation.unexpectedWork.map(\.golden.text) == [])
        // Everything else is reported, not asserted. Known rule misses (ADR 0027): an English plan with
        // "at 90000 km" becomes an odometer reading, and a service the rules do not recognise, stated
        // with its mileage, becomes one too. The shipped rules are unchanged by CAP-005 (ADR 0011).
    }

    @Test(
        "ADR-0027: probe the on-device model's availability and languages",
        .enabled(if: realModelLaneRequested, "set TEST_RUNNER_PITSTOP_AI_EVAL=1 to run the model lane")
    )
    func probeModel() {
        let model = SystemLanguageModel.default
        let languages = model.supportedLanguages.map(\.minimalIdentifier).sorted()
        var lines = [
            "availability: \(model.availability)",
            "contextSize: \(model.contextSize)",
            "supportedLanguages: \(languages.joined(separator: ", "))",
        ]
        for identifier in ["ru_RU", "uk_UA", "en_US"] {
            lines.append("supportsLocale(\(identifier)): \(model.supportsLocale(Locale(identifier: identifier)))")
        }
        record(lines.joined(separator: "\n"), named: "model_probe")
    }

    @Test(
        "ADR-0027: evaluate Foundation Models on the golden set",
        .enabled(if: realModelLaneRequested, "set TEST_RUNNER_PITSTOP_AI_EVAL=1 to run the model lane"),
        .enabled(if: SystemLanguageModel.default.isAvailable, "the on-device model is unavailable here"),
        .timeLimit(.minutes(10))
    )
    func evaluateFoundationModels() async {
        let model = await InterpreterEvaluation.run(FoundationModelsInterpreter())
        record(model.report(title: "foundation_models_1 alone"), named: "foundation_models_1")
        let chain = await InterpreterEvaluation.run(
            InterpreterChain([RuleBasedInterpreter(), FoundationModelsInterpreter()])
        )
        let rules = await InterpreterEvaluation.run(RuleBasedInterpreter())
        record(chain.report(title: "rule_based_1 then foundation_models_1"), named: "chain")

        // Quality is reported, not asserted; safety is asserted.
        #expect(chain.unexpectedWork.map(\.golden.text) == [])
        // The model adds no unexpected proposal of any kind on top of the rules.
        #expect(chain.unexpectedProposals.count == rules.unexpectedProposals.count)
    }
}

/// Hosted tests do not capture standard output, so reports travel as result-bundle attachments
/// (`xcrun xcresulttool export attachments`).
private func record(_ report: String, named name: String) {
    Attachment.record(report, named: "\(name).txt")
}
