import Foundation
@testable import Pitstop
import Testing

/// DISC-002: Pit's mileage question through the real SwiftData stores, sharing one container as the app
/// does, to what Service and Road show. Nothing here is faked except the clock.
private let now = MaintenanceFixture.date(120)

@MainActor
private struct App {
    let store: SwiftDataCarMemoryStore
    let questions: SwiftDataPitQuestionStore
    let pit: PitQuestionViewModel
    let capture: PitCaptureViewModel
    let service: ServiceViewModel
    let road: RoadViewModel

    init() throws {
        let container = try PersistenceContainer.make(storeURL: nil)
        let registry = try PitQuestionRegistry.product()
        store = SwiftDataCarMemoryStore(modelContainer: container)
        questions = SwiftDataPitQuestionStore(modelContainer: container, registry: registry)
        pit = PitQuestionViewModel(questions: questions, store: store, registry: registry, now: { now })
        capture = PitCaptureViewModel(
            pipeline: RememberPipeline(store: store, interpreter: RuleBasedInterpreter(), now: { now }),
            now: { now }
        )
        service = ServiceViewModel(store: store, now: { now })
        road = RoadViewModel(store: store, now: { now })
    }

    /// Oil every 10,000 km, last done at 50,000 km; the newest observation is 120 days old, so stale.
    func seedStaleMileage() async throws {
        let vehicleID = try await store.currentVehicle().id
        let past = MaintenanceFixture.date(0)
        try await store.execute(.setMaintenancePolicy(.init(vehicleID: vehicleID, policy: MaintenanceFixture.oil10k)),
                                now: past)
        try await store.execute(.confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService, performedAt: past, odometerKm: 50000
        ))), now: past)
    }

    func questionState() async throws -> PitQuestionState? {
        try await questions.questionStates().first { $0.questionID == CurrentMileageQuestion.id }
    }

    func oilOnRoad() -> RoadMilestone? {
        road.state.projection?.slots.flatMap(\.milestones).first { $0.subject == .maintenance(.engineOilService) }
    }
}

@Suite("Mileage question end to end")
@MainActor
struct MileageQuestionEndToEndTests {
    @Test("ADR-0017, REQ-ROAD-006: before the answer Service and Road cannot count kilometres; after it both do")
    func answerUnlocksServiceAndRoad() async throws {
        let app = try App()
        try await app.seedStaleMileage()
        await app.service.load()
        await app.road.load()
        #expect(app.service.state.operations.first?.distanceBlock == .mileageStale)
        #expect(app.service.state.operations.first?.remainingKm == nil)
        #expect(app.road.state.projection?.waitingForMileage.map(\.subject) == [.maintenance(.engineOilService)])
        #expect(app.oilOnRoad() == nil)

        #expect(await app.pit.evaluate(context: .service, activity: .idle))
        app.pit.answerText = "58 000"
        #expect(await app.pit.answer())
        await app.service.load()
        await app.road.load()

        let oil = try #require(app.service.state.operations.first)
        #expect(oil.distanceBlock == nil && oil.remainingKm == 2000)
        #expect(app.road.state.projection?.waitingForMileage.isEmpty == true)
        let milestone = try #require(app.oilOnRoad())
        #expect(milestone.mileageDependency == nil && milestone.remainingKm == 2000)
    }

    @Test("ADR-0016, REQ-PIT-008: the answer and the reading are both persisted, so the question never returns")
    func answerIsPersisted() async throws {
        let app = try App()
        try await app.seedStaleMileage()
        #expect(await app.pit.evaluate(context: .service, activity: .idle))
        app.pit.answerText = "58000"
        #expect(await app.pit.answer())

        let state = try #require(await app.questionState())
        #expect(state.resolution == .answered && state.lastAskedAt == now)
        #expect(try await app.store.odometerReadings().latest?.valueInKilometers == 58000)
        app.pit.acknowledge()
        #expect(await !app.pit.evaluate(context: .service, activity: .idle))
    }

    @Test("REQ-PIT-012: 'I don't know yet' is persisted as a deferral and Service keeps naming the blocked rule")
    func notKnownKeepsUnknown() async throws {
        let app = try App()
        try await app.seedStaleMileage()
        #expect(await app.pit.evaluate(context: .service, activity: .idle))

        await app.pit.deferAnswer()
        await app.service.load()

        let state = try #require(await app.questionState())
        #expect(state.resolution == .deferred)
        #expect(app.service.state.operations.first?.distanceBlock == .mileageStale)
    }

    @Test("REQ-PIT-013, REQ-PIT-003: a note is captured while the question waits; the question stays pending")
    func captureWorksWhileQuestionPending() async throws {
        let app = try App()
        try await app.seedStaleMileage()
        #expect(await app.pit.evaluate(context: .service, activity: .idle))

        app.capture.text = "стук справа при повороте"
        await app.capture.submit(from: .service)

        #expect(app.capture.phase == .saved(.notes, preservedRaw: true))
        #expect(app.pit.isAsking)
        #expect(try await app.questionState()?.resolution == .unresolved)
        app.pit.answerText = "58000"
        #expect(await app.pit.answer())
        #expect(try await app.questionState()?.resolution == .answered)
    }

    @Test("REQ-PIT-009: a mileage saved through capture silences the pending question without resolving it")
    func captureMileageSilencesQuestion() async throws {
        let app = try App()
        try await app.seedStaleMileage()
        // The startle beat passes at once; idle waits really suspend, so the idle loop that starts once the
        // knock ends cannot spin the main actor.
        let pit = PitPresenceModel(sleep: { seconds in
            if seconds >= 1 {
                try await Task.sleep(for: .seconds(3600))
            }
        })
        defer { pit.stop() }
        #expect(await app.pit.evaluate(context: .service) { pit.activity })
        await pit.askPermissionToInterrupt()

        app.capture.text = "пробег 84200"
        await app.capture.submit(from: .service)
        if case .confirming = app.capture.phase {
            await app.capture.confirm()
        }
        #expect(app.capture.phase == .saved(.carBoard, preservedRaw: false))
        await app.pit.revalidate()
        // RootView ends Pit's question when the model stops asking.
        if !app.pit.isAsking {
            pit.endQuestion()
        }

        #expect(app.pit.phase == .silent)
        #expect(pit.state != .knock && !pit.activity.contains(.askingQuestion))
        let state = try #require(await app.questionState())
        #expect(state.resolution == .unresolved && state.resolvedAt == nil)
        #expect(try await app.store.odometerReadings().count == 1)
    }

    @Test("ADR-0017: while the mileage is still stale, re-checking keeps the question pending")
    func revalidateKeepsRelevantQuestion() async throws {
        let app = try App()
        try await app.seedStaleMileage()
        #expect(await app.pit.evaluate(context: .service, activity: .idle))

        await app.pit.revalidate()

        #expect(app.pit.isAsking)
    }
}
