import Foundation
import Observation

/// A question Pit is asking, with what the surface needs to word it. Each case is one registered question.
enum PitAskedQuestion: Equatable {
    /// `lastKnownKm` is the newest observation, shown as the last one recorded, never as today's (core C2).
    case currentMileage(lastKnownKm: Int?)

    var id: String {
        switch self {
        case .currentMileage: CurrentMileageQuestion.id
        }
    }
}

enum PitQuestionPhase: Equatable {
    case silent
    case asking(PitAskedQuestion)
    case working(PitAskedQuestion)
    /// The reading was saved; the surface says what was recorded until the sheet closes.
    case answered(kilometers: Int)
}

enum PitQuestionFailure: Equatable {
    case invalidMileage
    case notSaved
}

/// Pit's one discovery question (ADR 0017). It decides nothing about eligibility — the attention policy
/// and the registry do — and it writes car facts only through a `DomainCommand`.
@MainActor
@Observable
final class PitQuestionViewModel {
    private(set) var phase: PitQuestionPhase = .silent
    private(set) var failure: PitQuestionFailure?
    var answerText = ""

    private let questions: any PitQuestionStateStore
    private let store: any CarMemoryStore
    private let registry: PitQuestionRegistry
    private let policy: PitAttentionPolicy
    private let analytics: any AnalyticsTracking<OdometerAnalyticsEvent>
    private let now: @Sendable () -> Date
    private var isEvaluating = false

    init(
        questions: any PitQuestionStateStore,
        store: any CarMemoryStore,
        registry: PitQuestionRegistry,
        policy: PitAttentionPolicy = PitAttentionPolicy(),
        analytics: any AnalyticsTracking<OdometerAnalyticsEvent> = NoAnalyticsTracker(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.questions = questions
        self.store = store
        self.registry = registry
        self.policy = policy
        self.analytics = analytics
        self.now = now
    }

    /// Pit is waiting for the user to answer, defer, or dismiss.
    var isAsking: Bool {
        switch phase {
        case .asking, .working: true
        case .silent, .answered: false
        }
    }

    /// Returns `true` when a question was asked and Pit should knock. The ask is recorded before it is
    /// shown: if it cannot be recorded, Pit stays silent rather than ask without a cooldown (REQ-PIT-010).
    /// `activity` is read live, because the reads below suspend and the user may start something meanwhile.
    func evaluate(context: VisibleFeature, activity: () -> PitActivity) async -> Bool {
        guard phase == .silent, !isEvaluating else { return false }
        isEvaluating = true
        defer { isEvaluating = false }
        do {
            let moment = now()
            let (maintenance, relevant) = try await relevance(at: moment)
            let chosen = try await policy.question(
                registry: registry,
                states: questions.questionStates(),
                relevant: relevant,
                activity: activity(),
                context: context,
                now: moment
            )
            guard let chosen, let asked = Self.asked(chosen.id, maintenance: maintenance) else { return false }
            // The user left the surface, or opened a sheet or started typing, while the facts were read:
            // the question no longer belongs here, or the interface is no longer idle (REQ-PIT-006).
            guard !Task.isCancelled, policy.allowsInterruption(activity()) else { return false }
            try await questions.execute(.asked(questionID: asked.id), now: moment)
            phase = .asking(asked)
            return true
        } catch {
            return false
        }
    }

    /// The facts changed some other way — a mileage saved through capture, say. A pending question whose
    /// answer would no longer change anything goes quiet without a resolution, so it can be asked again
    /// once it is relevant again (core C3). A read failure keeps the question: the facts are unknown.
    func revalidate() async {
        guard case let .asking(question) = phase,
              let relevant = try? await relevance(at: now()).relevant,
              !relevant.contains(question.id),
              // An answer started while the facts were read wins; it still records a fresh reading.
              phase == .asking(question)
        else { return }
        answerText = ""
        failure = nil
        phase = .silent
    }

    private func relevance(at moment: Date) async throws
        -> (maintenance: MaintenanceContext, relevant: Set<String>)
    {
        let completions = try await store.maintenanceCompletions()
        let maintenance = try await MaintenanceContext(
            now: moment,
            latestReading: store.odometerReadings().latest,
            completions: completions
        )
        let operations = try await MaintenanceEngine().states(
            policies: store.maintenancePolicies(),
            completions: completions,
            context: maintenance
        )
        return (maintenance, registry.relevantQuestionIDs(maintenance: operations))
    }

    /// Validated like the car editor's mileage. The reading is written with a domain command; the question
    /// is resolved only after the reading is saved.
    @discardableResult
    func answer() async -> Bool {
        guard case let .asking(question) = phase else { return false }
        guard case let .value(kilometers) = InputParsing.kilometers(from: answerText) else {
            failure = .invalidMileage
            return false
        }
        phase = .working(question)
        failure = nil
        let moment = now()
        do {
            let vehicleID = try await store.currentVehicle().id
            let reading = OdometerReading(vehicleID: vehicleID, value: Double(kilometers), recordedAt: moment)
            try await store.execute(.recordOdometerReading(.init(reading: reading)), now: moment)
        } catch {
            phase = .asking(question)
            if case .invalidCommand = error {
                failure = .invalidMileage
            } else {
                failure = .notSaved
            }
            return false
        }
        analytics.track(.odometerUpdated(source: .explicit, anomalyConfirmation: .noAnomaly))
        // The reading is the fact; the resolution is bookkeeping. If it is lost, the mileage is now current,
        // so relevance keeps the question from returning anyway.
        _ = try? await questions.execute(.answered(questionID: question.id), now: moment)
        answerText = ""
        phase = .answered(kilometers: kilometers)
        return true
    }

    /// "I don't know yet": nothing is written about the car, only that the question was deferred.
    func deferAnswer() async {
        await decline { .deferred(questionID: $0) }
    }

    func dismiss() async {
        await decline { .dismissed(questionID: $0) }
    }

    /// The sheet closed: an answered question has said what it recorded, and Pit goes quiet.
    func acknowledge() {
        if case .answered = phase {
            phase = .silent
        }
    }

    func dismissFailure() {
        failure = nil
    }

    /// Pit accepts silence: a failed write is not reported. The ask was recorded, so the interruption
    /// cooldown still holds; at worst the question returns after it instead of when declared.
    private func decline(_ command: (String) -> PitQuestionCommand) async {
        guard case let .asking(question) = phase else { return }
        phase = .working(question)
        _ = try? await questions.execute(command(question.id), now: now())
        answerText = ""
        failure = nil
        phase = .silent
    }

    private static func asked(_ id: String, maintenance: MaintenanceContext) -> PitAskedQuestion? {
        switch id {
        case CurrentMileageQuestion.id:
            .currentMileage(lastKnownKm: maintenance.observedKm.map { Int($0.rounded()) })
        default:
            // A registered question with no wording on this surface is not asked.
            nil
        }
    }
}
