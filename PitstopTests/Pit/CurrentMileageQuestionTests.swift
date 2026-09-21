import Foundation
@testable import Pitstop
import Testing

private let day: TimeInterval = 86400
private let hour: TimeInterval = 60 * 60
private let questionID = CurrentMileageQuestion.id

private func operation(
    _ policy: MaintenancePolicy = MaintenanceFixture.oil10k,
    block: DistanceBlock?
) -> MaintenanceOperationState {
    MaintenanceOperationState(
        policy: policy, lastCompletion: nil, status: .unknown, anchorKm: nil, anchorDate: nil,
        remainingKm: nil, remainingDays: nil, remainingFraction: nil, decidedBy: nil, distanceBlock: block
    )
}

@Suite("First Pit question: current mileage")
struct CurrentMileageQuestionTests {
    private let policy = PitAttentionPolicy()
    private let now = MaintenanceFixture.date(120)

    @Test("ADR-0017: the mileage question is a registered product question on Service that unlocks Service status")
    func questionIsRegistered() throws {
        let definition = try #require(PitQuestionRegistry.product().definition(for: questionID))
        #expect(definition.context == .service)
        #expect(definition.value.unlocks == .serviceStatus)
        #expect(definition.deferral.afterDismissal == .never)
        #expect(definition.deferral.afterDeferral == .notBefore(14 * day))
        // The answer holds exactly as long as the engine counts a reading as current (ADR 0018).
        #expect(definition.deferral.afterAnswer == .notBefore(MaintenanceRules.mileageStaleAfter))
    }

    @Test(
        "ADR-0017: the question is relevant only while a distance rule is blocked by unknown or stale mileage",
        arguments: [
            (DistanceBlock?.some(.mileageStale), true),
            (.some(.mileageUnknown), true),
            (.some(.completionMileageMissing), false),
            (.none, false),
        ]
    )
    func relevanceFollowsTheBlock(block: DistanceBlock?, isRelevant: Bool) throws {
        let registry = try PitQuestionRegistry.product()
        let relevant = registry.relevantQuestionIDs(maintenance: [operation(block: block)])
        #expect(relevant.contains(questionID) == isRelevant)
        #expect(CurrentMileageQuestion.isRelevant([operation(block: block)]) == isRelevant)
    }

    @Test("REQ-PIT-009: with nothing tracked the answer would change nothing, so the question is not asked")
    func nothingTrackedIsNotAsked() throws {
        let registry = try PitQuestionRegistry.product()
        #expect(registry.relevantQuestionIDs(maintenance: []).isEmpty)
        #expect(policy.question(
            registry: registry, states: [], relevant: [], activity: .idle, context: .service, now: now
        ) == nil)
    }

    @Test("ADR-0017: a question without a relevance rule is never relevant")
    func unknownQuestionIsNeverRelevant() throws {
        let registry = try PitQuestionFixtures.registry()
        #expect(registry.relevantQuestionIDs(maintenance: [operation(block: .mileageStale)]).isEmpty)
    }

    @Test("REQ-PIT-007: the mileage question is asked on Service only", arguments: VisibleFeature.allCases)
    func askedOnServiceOnly(context: VisibleFeature) throws {
        let asked = try policy.question(
            registry: PitQuestionRegistry.product(), states: [], relevant: [questionID],
            activity: .idle, context: context, now: now
        )
        #expect((asked?.id == questionID) == (context == .service))
    }

    @Test("REQ-PIT-006, REQ-PIT-018: Reduce Motion alone is not activity; anything else still blocks the question")
    func reduceMotionIsNotBusy() throws {
        let registry = try PitQuestionRegistry.product()
        func ask(_ activity: PitActivity) -> PitQuestion? {
            policy.question(
                registry: registry, states: [], relevant: [questionID],
                activity: activity, context: .service, now: now
            )
        }
        #expect(ask(.reduceMotion)?.id == questionID)
        #expect(ask([.reduceMotion, .editing]) == nil)
        #expect(ask(.askingQuestion) == nil)
    }

    @Test("REQ-PIT-010: the mileage question waits out the interruption and dismissal cooldowns")
    func cooldownsApply() throws {
        let registry = try PitQuestionRegistry.product()
        func ask(_ states: [PitQuestionState]) -> PitQuestion? {
            policy.question(
                registry: registry, states: states, relevant: [questionID],
                activity: .idle, context: .service, now: now
            )
        }
        let recentlyAsked = PitQuestionState(questionID: questionID, lastAskedAt: now - hour)
        #expect(ask([recentlyAsked]) == nil)
        let askedLongAgo = PitQuestionState(questionID: questionID, lastAskedAt: now - 13 * hour)
        #expect(ask([askedLongAgo])?.id == questionID)
        // Another question's dismissal silences this one too: the budget is global.
        let otherDismissed = PitQuestionState(questionID: "retired", lastAskedAt: now - 8 * day,
                                              lastDismissedAt: now - 6 * day)
        #expect(ask([otherDismissed]) == nil)
    }

    @Test(
        "REQ-PIT-008, REQ-PIT-012: an answered, deferred, or dismissed mileage question is not asked again early",
        arguments: [PitQuestion.Resolution.answered, .deferred, .dismissed]
    )
    func resolvedIsNotAskedAgain(resolution: PitQuestion.Resolution) throws {
        // Past every cooldown, inside every declared return interval (14 days is the shortest).
        let state = PitQuestionState(questionID: questionID, resolution: resolution, lastAskedAt: now - 13 * day,
                                     lastDismissedAt: resolution == .dismissed ? now - 13 * day : nil,
                                     resolvedAt: now - 13 * day)
        #expect(try policy.question(
            registry: PitQuestionRegistry.product(), states: [state], relevant: [questionID],
            activity: .idle, context: .service, now: now
        ) == nil)
    }
}

@MainActor
@Suite("Pit question view model")
struct PitQuestionViewModelTests {
    let now = MaintenanceFixture.date(120)

    /// Oil every 10,000 km, done at 50,000 km on day 0. With `readingDay` 0 the mileage is stale at day 120.
    func makeStores(readingDay: Double = 0) async throws -> (FakeCarMemoryStore, FakePitQuestionStore) {
        let store = FakeCarMemoryStore()
        let vehicleID = await store.vehicle.id
        let past = MaintenanceFixture.date(readingDay)
        try await store.execute(.setMaintenancePolicy(.init(vehicleID: vehicleID, policy: MaintenanceFixture.oil10k)),
                                now: past)
        try await store.execute(.confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService, performedAt: MaintenanceFixture.date(0),
            odometerKm: 50000
        ))), now: past)
        try await store.execute(.recordOdometerReading(.init(reading: OdometerReading(
            vehicleID: vehicleID, value: 51000, recordedAt: past
        ))), now: past)
        return try (store, FakePitQuestionStore(registry: PitQuestionRegistry.product()))
    }

    private func makeModel(_ store: FakeCarMemoryStore, _ questions: FakePitQuestionStore) throws
        -> PitQuestionViewModel
    {
        let moment = now
        return try PitQuestionViewModel(
            questions: questions, store: store, registry: PitQuestionRegistry.product(), now: { moment }
        )
    }

    func askedModel() async throws -> (PitQuestionViewModel, FakeCarMemoryStore, FakePitQuestionStore) {
        let (store, questions) = try await makeStores()
        let model = try makeModel(store, questions)
        #expect(await model.evaluate(context: .service, activity: .idle))
        return (model, store, questions)
    }

    @Test("ADR-0017: with stale mileage on Service, Pit asks and the ask is recorded when shown")
    func staleMileageIsAsked() async throws {
        let (model, _, questions) = try await askedModel()

        #expect(model.phase == .asking(.currentMileage(lastKnownKm: 51000)))
        #expect(model.isAsking)
        #expect(await questions.executed == [.asked(questionID: questionID)])
        #expect(await questions.states[questionID]?.lastAskedAt == now)
        #expect(await questions.states[questionID]?.resolution == .unresolved)
    }

    @Test("ADR-0017: with current mileage the answer would change nothing, so Pit stays silent")
    func currentMileageIsNotAsked() async throws {
        let (store, questions) = try await makeStores(readingDay: 119)
        let model = try makeModel(store, questions)

        #expect(await !model.evaluate(context: .service, activity: .idle))
        #expect(model.phase == .silent)
        #expect(await questions.executed.isEmpty)
    }

    @Test("REQ-PIT-006, REQ-PIT-007: not while the user is busy, and not away from Service")
    func busyOrElsewhereIsNotAsked() async throws {
        let (store, questions) = try await makeStores()
        let model = try makeModel(store, questions)

        #expect(await !model.evaluate(context: .service, activity: .capturing))
        #expect(await !model.evaluate(context: .carBoard, activity: .idle))
        #expect(await !model.evaluate(context: .road, activity: .idle))
        #expect(await questions.executed.isEmpty)
    }

    @Test("REQ-PIT-010: when the ask cannot be recorded, Pit does not ask at all")
    func unrecordedAskIsNotShown() async throws {
        let (store, questions) = try await makeStores()
        // Reads succeed, so the question is chosen; only recording the ask fails.
        await questions.failCommands()
        let model = try makeModel(store, questions)

        #expect(await !model.evaluate(context: .service, activity: .idle))
        #expect(model.phase == .silent)
        #expect(await questions.states.isEmpty)
    }

    @Test("REQ-PIT-008: when question state cannot be read, Pit does not ask")
    func unreadableStateIsNotAsked() async throws {
        let (store, questions) = try await makeStores()
        await questions.failEverything()
        let model = try makeModel(store, questions)

        #expect(await !model.evaluate(context: .service, activity: .idle))
        #expect(model.phase == .silent)
    }

    @Test("REQ-PIT-006: a sheet opened while the facts are read stops the ask before it is recorded")
    func activityIsReadAgainBeforeRecording() async throws {
        let (store, questions) = try await makeStores()
        let model = try makeModel(store, questions)
        var reads = 0

        let asked = await model.evaluate(context: .service) {
            reads += 1
            return reads == 1 ? .idle : .capturing
        }

        #expect(!asked && reads == 2)
        #expect(model.phase == .silent)
        #expect(await questions.executed.isEmpty)
    }

    @Test("REQ-PIT-018: with Reduce Motion Pit still asks, and asks with the knock alone")
    func reduceMotionStillAsks() async throws {
        let (store, questions) = try await makeStores()
        let model = try makeModel(store, questions)
        var shown: [PitState] = []
        let pit = PitPresenceModel(sleep: { _ in }, onShow: { shown.append($0) })
        pit.setReduceMotion(true)

        #expect(await model.evaluate(context: .service) { pit.activity })
        await pit.askPermissionToInterrupt()

        #expect(model.isAsking)
        #expect(shown == [.knock])
    }

    @Test("REQ-PIT-010: an ask left unanswered is recorded, so the next launch waits out the 12-hour cooldown")
    func unansweredAskStartsPersistedCooldown() async throws {
        let (_, store, questions) = try await askedModel()
        func relaunched(after interval: TimeInterval) throws -> PitQuestionViewModel {
            try PitQuestionViewModel(
                questions: questions, store: store, registry: PitQuestionRegistry.product(),
                now: { [now] in now + interval }
            )
        }

        #expect(try await !relaunched(after: 11 * hour).evaluate(context: .service, activity: .idle))
        #expect(try await relaunched(after: 13 * hour).evaluate(context: .service, activity: .idle))
    }

    @Test("REQ-PIT-003: while a question is pending, no second one is evaluated")
    func onePendingQuestion() async throws {
        let (model, _, questions) = try await askedModel()

        #expect(await !model.evaluate(context: .service, activity: .idle))
        #expect(await questions.executed.count == 1)
    }

    @Test("ADR-0017: an answer records a reading through a domain command and resolves the question")
    func answerRecordsReading() async throws {
        let (model, store, questions) = try await askedModel()
        model.answerText = "61 500"

        #expect(await model.answer())

        let reading = try #require(await store.readings.first { $0.recordedAt == now })
        #expect(reading.valueInKilometers == 61500)
        #expect(await store.executed.last == .recordOdometerReading(.init(reading: reading)))
        #expect(await questions.states[questionID]?.resolution == .answered)
        #expect(model.phase == .answered(kilometers: 61500))
        #expect(!model.isAsking && model.answerText.isEmpty)
    }

    @Test("ADR-0017: after the answer Service counts kilometres, and the question is not asked again")
    func answerUnblocksService() async throws {
        let (model, store, _) = try await askedModel()
        let service = ServiceViewModel(store: store, now: { [now] in now })
        await service.load()
        #expect(service.state.operations.first?.distanceBlock == .mileageStale)

        model.answerText = "61500"
        #expect(await model.answer())
        await service.load()

        let oil = try #require(service.state.operations.first)
        #expect(oil.distanceBlock == nil)
        #expect(oil.remainingKm == -1500 && oil.status == .due)
        model.acknowledge()
        #expect(model.phase == .silent)
        #expect(await !model.evaluate(context: .service, activity: .idle))
    }

    @Test(
        "ADR-0017: the answer is validated like the car editor's mileage; nothing is written on failure",
        arguments: ["", "  ", "abc", "61.5", "1,5", "-100", "100000000"]
    )
    func invalidAnswerIsRejected(text: String) async throws {
        let (model, store, questions) = try await askedModel()
        let written = await store.executed.count
        model.answerText = text

        #expect(await !model.answer())

        #expect(model.failure == .invalidMileage)
        #expect(model.phase == .asking(.currentMileage(lastKnownKm: 51000)))
        #expect(await store.executed.count == written)
        #expect(await questions.states[questionID]?.resolution == .unresolved)
    }

    @Test("ADR-0017: a reading that cannot be saved leaves the question open and says so")
    func failedReadingKeepsQuestion() async throws {
        let (model, store, questions) = try await askedModel()
        await store.failCommands()
        model.answerText = "61500"

        #expect(await !model.answer())

        #expect(model.failure == .notSaved)
        #expect(model.isAsking)
        #expect(await questions.states[questionID]?.resolution == .unresolved)
    }

    @Test("REQ-PIT-012: 'I don't know yet' records a deferral, writes no mileage, and is not asked again")
    func notKnownRecordsDeferral() async throws {
        let (model, store, questions) = try await askedModel()

        await model.deferAnswer()

        #expect(model.phase == .silent)
        #expect(await questions.states[questionID]?.resolution == .deferred)
        #expect(await store.readings.count == 1)
        let tomorrow = try PitQuestionViewModel(
            questions: questions, store: store, registry: PitQuestionRegistry.product(),
            now: { [now] in now + day }
        )
        #expect(await !tomorrow.evaluate(context: .service, activity: .idle))
    }

    @Test("REQ-PIT-010: 'don't ask' records a dismissal, which starts the dismissal cooldown")
    func dismissRecordsDismissal() async throws {
        let (model, _, questions) = try await askedModel()

        await model.dismiss()

        #expect(model.phase == .silent)
        let state = try #require(await questions.states[questionID])
        #expect(state.resolution == .dismissed && state.lastDismissedAt == now)
    }

    @Test("ADR-0017: only a pending question can be answered, deferred, or dismissed")
    func silentModelIgnoresActions() async throws {
        let (store, questions) = try await makeStores()
        let model = try makeModel(store, questions)
        model.answerText = "61500"

        #expect(await !model.answer())
        await model.deferAnswer()
        await model.dismiss()

        #expect(await questions.executed.isEmpty)
        #expect(await store.readings.count == 1)
    }
}
