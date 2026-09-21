import Foundation
@testable import Pitstop
import Testing

private let day: TimeInterval = 86400
private let questionID = CurrentMileageQuestion.id

/// DISC-003 (ADR 0018): when the mileage question returns after an answer, a deferral, or a dismissal.
extension PitQuestionViewModelTests {
    private func relaunched(
        _ store: FakeCarMemoryStore,
        _ questions: FakePitQuestionStore,
        after interval: TimeInterval
    ) throws -> PitQuestionViewModel {
        try PitQuestionViewModel(
            questions: questions, store: store, registry: PitQuestionRegistry.product(),
            now: { [now] in now + interval }
        )
    }

    @Test("ADR-0018: an answered mileage question stays quiet while the mileage is current and returns once stale")
    func answeredReturnsWhenMileageIsStale() async throws {
        let (model, store, questions) = try await askedModel()
        model.answerText = "61500"
        #expect(await model.answer())

        #expect(try await !relaunched(store, questions, after: 89 * day).evaluate(context: .service, activity: .idle))
        // A reading from the car editor keeps the mileage current past the answer's own interval.
        let vehicleID = await store.vehicle.id
        try await store.execute(.recordOdometerReading(.init(reading: OdometerReading(
            vehicleID: vehicleID, value: 63000, recordedAt: now + 80 * day
        ))), now: now + 80 * day)
        #expect(try await !relaunched(store, questions, after: 91 * day).evaluate(context: .service, activity: .idle))

        let later = try relaunched(store, questions, after: 171 * day)
        #expect(await later.evaluate(context: .service, activity: .idle))
        #expect(later.phase == .asking(.currentMileage(lastKnownKm: 63000)))
        #expect(await questions.states[questionID]?.resolution == .unresolved)
    }

    @Test("REQ-PIT-012, ADR-0018: a deferred mileage question returns after 14 days while the mileage is stale")
    func deferredReturnsAfterFourteenDays() async throws {
        let (model, store, questions) = try await askedModel()
        await model.deferAnswer()

        #expect(try await !relaunched(store, questions, after: 14 * day - 1)
            .evaluate(context: .service, activity: .idle))
        let returned = try relaunched(store, questions, after: 14 * day)
        #expect(await returned.evaluate(context: .service, activity: .idle))

        // The returned question can be declined again, and the new deferral restarts its interval.
        await returned.deferAnswer()
        let state = try #require(await questions.states[questionID])
        #expect(state.resolution == .deferred && state.resolvedAt == now + 14 * day)
    }

    @Test("ADR-0018: 'don't ask' is final for the mileage question, even a year later with the mileage stale")
    func dismissedNeverReturns() async throws {
        let (model, store, questions) = try await askedModel()
        await model.dismiss()

        #expect(try await !relaunched(store, questions, after: 365 * day).evaluate(context: .service, activity: .idle))
    }
}
