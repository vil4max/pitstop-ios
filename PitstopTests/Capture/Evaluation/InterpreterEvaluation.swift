import Foundation
@testable import Pitstop

/// Runs an interpreter over the golden set and scores it (ai-roadmap "Regression Suite"). A proposal
/// counts as correct only when its kind and every expected field match; a wrong field is both a false
/// positive and a false negative for that kind.
struct InterpreterEvaluation {
    struct Outcome: Sendable {
        let golden: GoldenCase
        let proposal: MemoryProposal?
        /// The interpreter's error, when it threw. Only closed error cases, never the wording.
        let failure: String?
        let latency: Duration

        var unavailable: Bool {
            failure != nil
        }
    }

    struct KindScore {
        var truePositives = 0
        var predicted = 0
        var expected = 0

        var precision: Double? {
            predicted == 0 ? nil : Double(truePositives) / Double(predicted)
        }

        var recall: Double? {
            expected == 0 ? nil : Double(truePositives) / Double(expected)
        }
    }

    let outcomes: [Outcome]

    static func run(
        _ interpreter: any SemanticInterpreting,
        on cases: [GoldenCase] = CaptureGoldenSet.cases
    ) async -> InterpreterEvaluation {
        var outcomes: [Outcome] = []
        let clock = ContinuousClock()
        for golden in cases {
            let input = CaptureInput(
                payload: .text(golden.text),
                source: .pitText,
                capturedAt: DomainFixtures.Odometers.baseDate,
                localeIdentifier: golden.locale
            )
            var proposal: MemoryProposal?
            var failure: String?
            let latency = await clock.measure {
                do {
                    proposal = try await interpreter.interpret(input)
                } catch {
                    failure = String(describing: error)
                }
            }
            outcomes.append(Outcome(golden: golden, proposal: proposal, failure: failure, latency: latency))
        }
        return InterpreterEvaluation(outcomes: outcomes)
    }

    static func matches(_ proposal: MemoryProposal?, _ expected: GoldenCase.Expected?) -> Bool {
        guard let proposal, let expected else { return proposal == nil && expected == nil }
        return proposal.kind == expected.kind
            && (expected.operation == nil || proposal.extractedOperationID == expected.operation)
            && proposal.extractedOdometerKm == expected.odometerKm
            && proposal.extractedAmount == expected.amount
    }

    var scores: [ProposalKind: KindScore] {
        var scores: [ProposalKind: KindScore] = [:]
        for outcome in outcomes {
            if let expected = outcome.golden.expected {
                scores[expected.kind, default: KindScore()].expected += 1
            }
            if let proposal = outcome.proposal {
                scores[proposal.kind, default: KindScore()].predicted += 1
            }
            if let kind = outcome.golden.expected?.kind, Self.matches(outcome.proposal, outcome.golden.expected) {
                scores[kind, default: KindScore()].truePositives += 1
            }
        }
        return scores
    }

    /// Proposals where the golden answer is "keep the wording": the hallucination and unsafe-mutation
    /// signal. A hedged case here would break REQ-CAPTURE-014.
    var unexpectedProposals: [Outcome] {
        outcomes.filter { $0.golden.expected == nil && $0.proposal != nil }
    }

    /// Work or an event proposed where the wording must stay raw: what REQ-CAPTURE-014 forbids.
    var unexpectedWork: [Outcome] {
        unexpectedProposals.filter { [.maintenanceCompletion, .vehicleEvent].contains($0.proposal?.kind) }
    }

    var unavailableCount: Int {
        outcomes.count { $0.unavailable }
    }

    var latencyBuckets: [LatencyBucket: Int] {
        outcomes.reduce(into: [:]) { buckets, outcome in
            buckets[LatencyBucket(outcome.latency), default: 0] += 1
        }
    }

    /// A plain-text table for the test log and ADR 0027.
    func report(title: String) -> String {
        func percent(_ value: Double?) -> String {
            value.map { String(format: "%.0f%%", $0 * 100) } ?? "n/a"
        }
        var lines = ["== \(title): \(outcomes.count) cases, \(unavailableCount) unavailable =="]
        for (kind, score) in scores.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            lines.append(
                "\(kind.rawValue): precision \(percent(score.precision)) (\(score.truePositives)/\(score.predicted)),"
                    + " recall \(percent(score.recall)) (\(score.truePositives)/\(score.expected))"
            )
        }
        for category in GoldenCase.Category.allCases {
            let inCategory = outcomes.filter { $0.golden.category == category }
            let correct = inCategory.count { Self.matches($0.proposal, $0.golden.expected) }
            lines.append("category \(category.rawValue): \(correct)/\(inCategory.count) correct")
        }
        lines.append("unexpected proposals: \(unexpectedProposals.count)")
        let buckets = latencyBuckets.sorted { $0.key.rawValue < $1.key.rawValue }
        lines.append("latency: " + buckets.map { "\($0.key.rawValue)=\($0.value)" }.joined(separator: ", "))
        for outcome in outcomes where !Self.matches(outcome.proposal, outcome.golden.expected) {
            let got = outcome.failure.map { "unavailable: \($0)" } ?? (outcome.proposal?.kind.rawValue ?? "none")
            lines.append("miss: \(outcome.golden.testDescription) -> \(got)")
        }
        return lines.joined(separator: "\n")
    }
}
