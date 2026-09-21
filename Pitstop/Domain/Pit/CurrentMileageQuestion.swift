import Foundation

/// The first product question (DISC-002, ADR 0017): the car's current mileage, asked on Service only
/// while a tracked distance rule cannot be evaluated because the mileage is unknown or stale.
public enum CurrentMileageQuestion {
    /// Stable across releases: persisted state is keyed by it.
    public static let id = "service.currentMileage"

    public static let definition = PitQuestionDefinition(
        id: id,
        context: .service,
        priority: 10,
        value: PitQuestionValue(
            unlocks: .serviceStatus,
            claim: """
            Every tracked operation whose distance rule was blocked by unknown or stale mileage gets \
            remaining kilometres on Service, and its mileage milestone leaves Road's waiting list.
            """
        ),
        deferral: PitDeferralPath(
            // A reading holds exactly as long as the engine counts it as current; after that the question
            // is relevant again only if no newer mileage arrived meanwhile (ADR 0018).
            afterAnswer: .notBefore(MaintenanceRules.mileageStaleAfter),
            afterDeferral: .notBefore(14 * 24 * 60 * 60),
            afterDismissal: .never,
            withoutAnswer: """
            Service keeps the distance rule blocked and names the reason; a time rule still decides a \
            partial status. The user can record mileage in the car editor at any time.
            """
        )
    )

    /// An answer changes something only when a distance rule is blocked by the car's mileage. A rule
    /// blocked because the completion was saved without mileage is not fixed by today's reading.
    public static func isRelevant(_ states: some Sequence<MaintenanceOperationState>) -> Bool {
        states.contains { $0.distanceBlock == .mileageUnknown || $0.distanceBlock == .mileageStale }
    }
}

public extension PitQuestionRegistry {
    /// The registered questions whose answer would change something for the car right now. A question
    /// outside this set is not offered, however eligible it is otherwise (core C3, REQ-PIT-009).
    func relevantQuestionIDs(maintenance: [MaintenanceOperationState]) -> Set<String> {
        Set(definitions.map(\.id).filter { id in
            switch id {
            case CurrentMileageQuestion.id: CurrentMileageQuestion.isRelevant(maintenance)
            // A question with no relevance rule is never relevant, so it can never be asked by accident.
            default: false
            }
        })
    }
}

public extension PitAttentionPolicy {
    /// As `question(registry:states:activity:context:now:)`, limited to questions whose answer would
    /// change something now.
    func question(
        registry: PitQuestionRegistry,
        states: [PitQuestionState],
        relevant: Set<String>,
        activity: PitActivity,
        context: VisibleFeature,
        now: Date
    ) -> PitQuestion? {
        let budget = PitAttentionBudget(states)
        return question(
            from: registry.questions(with: states, now: now).filter { relevant.contains($0.id) },
            activity: activity,
            context: context,
            sinceLastInterruption: budget.sinceLastInterruption(now: now),
            sinceLastDismissal: budget.sinceLastDismissal(now: now)
        )
    }
}
