import Foundation
@testable import Pitstop

/// Test-only questions; product questions live in `PitQuestionRegistry.productDefinitions`.
enum PitQuestionFixtures {
    static let oilIntervalID = "fixture.oilInterval"
    static let roadHorizonID = "fixture.roadHorizon"

    static func definition(
        id: String = oilIntervalID,
        context: VisibleFeature = .service,
        priority: Int = 5,
        claim: String = "Service status uses the user's own oil interval",
        withoutAnswer: String = "Service keeps the interval unknown and shows no oil due date",
        afterDeferral: PitDeferralPath.Return = .notBefore(30 * 24 * 60 * 60)
    ) -> PitQuestionDefinition {
        PitQuestionDefinition(
            id: id,
            context: context,
            priority: priority,
            value: PitQuestionValue(unlocks: .serviceStatus, claim: claim),
            deferral: PitDeferralPath(
                afterDeferral: afterDeferral,
                afterDismissal: .never,
                withoutAnswer: withoutAnswer
            )
        )
    }

    static func registry() throws -> PitQuestionRegistry {
        try PitQuestionRegistry([
            definition(),
            definition(id: roadHorizonID, context: .road, priority: 3),
        ])
    }
}
