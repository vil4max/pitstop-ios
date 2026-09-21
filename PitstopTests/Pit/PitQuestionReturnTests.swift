import Foundation
@testable import Pitstop
import Testing

private let day: TimeInterval = 86400
private let hour: TimeInterval = 60 * 60
private let oil = PitQuestionFixtures.oilIntervalID
private let tyres = "fixture.tyrePressure"

/// DISC-003: when a resolved question may return. The clock is the `now` argument; nothing reads the
/// wall clock.
@Suite("Pit question return and repeat suppression")
struct PitQuestionReturnTests {
    private let policy = PitAttentionPolicy()
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// Both questions on Service: the oil fixture never returns after a dismissal; the tyre fixture
    /// returns 30 days after one and 60 days after an answer.
    private func registry() throws -> PitQuestionRegistry {
        try PitQuestionRegistry([
            PitQuestionFixtures.definition(),
            PitQuestionFixtures.definition(
                id: tyres, priority: 3, afterAnswer: .notBefore(60 * day), afterDismissal: .notBefore(30 * day)
            ),
        ])
    }

    private func ask(_ states: [PitQuestionState], at now: Date) throws -> String? {
        try policy.question(
            registry: registry(), states: states, activity: .idle, context: .service, now: now
        )?.id
    }

    private func apply(
        _ command: PitQuestionCommand,
        to state: PitQuestionState?,
        at moment: Date
    ) throws -> PitQuestionState {
        let path = try #require(registry().definition(for: command.questionID)).deferral
        return try command.applied(to: state, path: path, now: moment)
    }

    private func resolved(
        _ id: String,
        _ command: (String) -> PitQuestionCommand,
        at moment: Date
    ) throws -> PitQuestionState {
        let asked = try apply(.asked(questionID: id), to: nil, at: moment)
        return try apply(command(id), to: asked, at: moment)
    }

    @Test("REQ-PIT-012, ADR-0018: a deferred question returns only after its declared deferral interval")
    func deferralReturnsAfterInterval() throws {
        let states = try [
            resolved(oil, { .deferred(questionID: $0) }, at: start),
            resolved(tyres, { .answered(questionID: $0) }, at: start),
        ]

        #expect(try ask(states, at: start + 13 * hour) == nil)
        #expect(try ask(states, at: start + 30 * day - 1) == nil)
        #expect(try ask(states, at: start + 30 * day) == oil)
    }

    @Test("REQ-PIT-010, ADR-0018: a dismissal silences every question for 7 days and itself per its declared path")
    func dismissalSilencesAllThenFollowsItsPath() throws {
        let oilDismissed = try resolved(oil, { .dismissed(questionID: $0) }, at: start)
        #expect(try ask([oilDismissed], at: start + 7 * day - 1) == nil)
        // The other question is free after the global 7 days; the dismissed one never returns.
        #expect(try ask([oilDismissed], at: start + 7 * day) == tyres)

        let tyresDismissed = try resolved(tyres, { .dismissed(questionID: $0) }, at: start)
        let oilAnswered = try resolved(oil, { .answered(questionID: $0) }, at: start)
        let states = [tyresDismissed, oilAnswered]
        #expect(try ask(states, at: start + 7 * day) == nil)
        #expect(try ask(states, at: start + 30 * day - 1) == nil)
        #expect(try ask(states, at: start + 30 * day) == tyres)
    }

    @Test(
        "ADR-0018: a question whose declared return is never stays silent however long it waits",
        arguments: [PitQuestion.Resolution.answered, .dismissed]
    )
    func neverStaysNever(resolution: PitQuestion.Resolution) throws {
        let command: (String) -> PitQuestionCommand = resolution == .answered
            ? { .answered(questionID: $0) }
            : { .dismissed(questionID: $0) }
        let states = try [
            resolved(oil, command, at: start),
            resolved(tyres, { .answered(questionID: $0) }, at: start + 3650 * day),
        ]

        #expect(try ask(states, at: start + 3650 * day + 13 * hour) == nil)
    }

    @Test("ADR-0018: an answer holds for its declared interval; relevance decides after that")
    func answerHoldsForItsInterval() throws {
        let states = try [
            resolved(oil, { .answered(questionID: $0) }, at: start),
            resolved(tyres, { .answered(questionID: $0) }, at: start),
        ]
        func ask(relevant: Set<String>, at now: Date) throws -> String? {
            try policy.question(
                registry: registry(), states: states, relevant: relevant,
                activity: .idle, context: .service, now: now
            )?.id
        }

        #expect(try ask(relevant: [tyres], at: start + 60 * day - 1) == nil)
        #expect(try ask(relevant: [tyres], at: start + 60 * day) == tyres)
        // The answer still unlocks its value, so the question stays quiet after the interval too.
        #expect(try ask(relevant: [], at: start + 60 * day) == nil)
    }

    @Test("REQ-PIT-010, ADR-0018: a question whose return is due still waits 12 hours after any ask")
    func returnWaitsForInterruptionCooldown() throws {
        let oilDeferred = try resolved(oil, { .deferred(questionID: $0) }, at: start)
        let due = start + 30 * day
        let tyresAsked = try apply(.asked(questionID: tyres), to: nil, at: due - hour)
        let tyresAnswered = try apply(.answered(questionID: tyres), to: tyresAsked, at: due)

        #expect(try ask([oilDeferred, tyresAnswered], at: due) == nil)
        #expect(try ask([oilDeferred, tyresAnswered], at: due + 10 * hour) == nil)
        #expect(try ask([oilDeferred, tyresAnswered], at: due + 11 * hour) == oil)
    }

    @Test("ADR-0018: asking a returned question opens it again, so the new ask can be answered or declined")
    func askReopensReturnedQuestion() throws {
        let answered = try resolved(tyres, { .answered(questionID: $0) }, at: start)
        let returnedAt = start + 60 * day
        let reasked = try apply(.asked(questionID: tyres), to: answered, at: returnedAt)

        #expect(reasked.resolution == .unresolved && reasked.resolvedAt == nil)
        #expect(reasked.lastAskedAt == returnedAt)
        let deferred = try apply(.deferred(questionID: tyres), to: reasked, at: returnedAt)
        #expect(deferred.resolution == .deferred && deferred.resolvedAt == returnedAt)
        // An unanswered re-ask is an open question again: it returns after the interruption cooldown.
        let oilAnswered = try resolved(oil, { .answered(questionID: $0) }, at: start)
        #expect(try ask([reasked, oilAnswered], at: returnedAt + 12 * hour) == tyres)
    }

    @Test("ADR-0018: an ask for a resolved question whose return has not come is rejected")
    func askBeforeReturnIsRejected() throws {
        let cases = try [
            // `.never` after an answer, however late the ask.
            (resolved(oil, { .answered(questionID: $0) }, at: start), start + 3650 * day),
            // An answer inside its 60-day interval.
            (resolved(tyres, { .answered(questionID: $0) }, at: start), start + 60 * day - 1),
            // A deferral inside its 30-day interval.
            (resolved(oil, { .deferred(questionID: $0) }, at: start), start + 30 * day - 1),
            // `.never` after a dismissal.
            (resolved(oil, { .dismissed(questionID: $0) }, at: start), start + 3650 * day),
        ]
        for (state, moment) in cases {
            #expect(throws: PitQuestionStoreError.notReturned) {
                try apply(.asked(questionID: state.questionID), to: state, at: moment)
            }
        }
    }

    @Test("ADR-0018: a resolution without a recorded time cannot be measured, so the question stays closed")
    func resolutionWithoutTimeStaysClosed() throws {
        let state = PitQuestionState(questionID: oil, resolution: .deferred, lastAskedAt: start)
        // The unasked lower-priority question is chosen instead of the closed one.
        #expect(try ask([state], at: start + 3650 * day) == tyres)
    }
}
