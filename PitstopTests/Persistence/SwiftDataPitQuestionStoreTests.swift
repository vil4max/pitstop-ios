import Foundation
@testable import Pitstop
import SwiftData
import Testing

private let oil = PitQuestionFixtures.oilIntervalID
private let road = PitQuestionFixtures.roadHorizonID
private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let hour: TimeInterval = 60 * 60

private func makeStore(url: URL? = nil) throws -> SwiftDataPitQuestionStore {
    try SwiftDataPitQuestionStore(
        modelContainer: PersistenceContainer.make(storeURL: url),
        registry: PitQuestionFixtures.registry()
    )
}

@Suite("SwiftData Pit question store")
struct SwiftDataPitQuestionStoreTests {
    @Test("REQ-PIT-012: a deferred question stays deferred after the store is reopened")
    func deferralSurvivesReopen() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        do {
            let store = try makeStore(url: url)
            try await store.execute(.asked(questionID: oil), now: now)
            try await store.execute(.deferred(questionID: oil), now: now + 5)
        }

        let reopened = try makeStore(url: url)

        let states = try await reopened.questionStates()
        let expected = PitQuestionState(questionID: oil, resolution: .deferred, lastAskedAt: now, resolvedAt: now + 5)
        #expect(states == [expected])
        let questions = try PitQuestionFixtures.registry().questions(with: states, now: now + 5)
        #expect(questions.first { $0.id == oil }?.resolution == .deferred)
    }

    @Test("REQ-PIT-010: persisted interruption and dismissal times feed the attention policy")
    func persistedBudgetFeedsPolicy() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        do {
            let store = try makeStore(url: url)
            try await store.execute(.asked(questionID: road), now: now)
            try await store.execute(.dismissed(questionID: road), now: now)
        }
        let states = try await makeStore(url: url).questionStates()
        let registry = try PitQuestionFixtures.registry()
        let policy = PitAttentionPolicy()

        func asked(after elapsed: TimeInterval) -> PitQuestion? {
            policy.question(registry: registry, states: states, activity: .idle, context: .service, now: now + elapsed)
        }

        #expect(asked(after: 13 * hour) == nil)
        #expect(asked(after: PitAttentionPolicy.dismissalCooldown)?.id == oil)
        #expect(policy.question(
            registry: registry,
            states: states,
            activity: .idle,
            context: .road,
            now: now + PitAttentionPolicy.dismissalCooldown
        ) == nil)
    }

    @Test("ADR-0016: a command for an unregistered question is rejected and nothing is saved")
    func unregisteredQuestionIsRejected() async throws {
        let store = try makeStore()

        await #expect(throws: PitQuestionStoreError.unknownQuestion) {
            try await store.execute(.asked(questionID: "adhoc.question"), now: now)
        }
        #expect(try await store.questionStates().isEmpty)
    }

    @Test("ADR-0016: a rejected command leaves the stored state unchanged")
    func rejectedCommandChangesNothing() async throws {
        let store = try makeStore()
        let answered = try await store.execute(.answered(questionID: oil), now: now)

        await #expect(throws: PitQuestionStoreError.alreadyAnswered) {
            try await store.execute(.dismissed(questionID: oil), now: now + 60)
        }
        #expect(try await store.questionStates() == [answered])
    }

    @Test("ADR-0018: an ask for an answered question that never returns is rejected and nothing is saved")
    func askBeforeReturnChangesNothing() async throws {
        let store = try makeStore()
        let answered = try await store.execute(.answered(questionID: oil), now: now)

        await #expect(throws: PitQuestionStoreError.notReturned) {
            try await store.execute(.asked(questionID: oil), now: now + 3650 * 24 * hour)
        }
        #expect(try await store.questionStates() == [answered])
    }

    @Test("ADR-0018: an unreadable stored resolution reads as closed and never returns")
    func unreadableResolutionStaysClosed() async throws {
        let container = try PersistenceContainer.make(storeURL: nil)
        let context = ModelContext(container)
        context.insert(PitstopSchemaV2.PitQuestionStateRecord(
            questionID: oil, resolution: "retired-resolution", lastAskedAt: now, lastDismissedAt: nil,
            resolvedAt: now
        ))
        try context.save()
        let store = try SwiftDataPitQuestionStore(modelContainer: container, registry: PitQuestionFixtures.registry())
        let later = now + 3650 * 24 * hour

        let states = try await store.questionStates()
        #expect(states.map(\.resolution) == [.closed])
        #expect(try PitAttentionPolicy().question(
            registry: PitQuestionFixtures.registry(), states: states, activity: .idle, context: .service, now: later
        ) == nil)
        await #expect(throws: PitQuestionStoreError.notReturned) {
            try await store.execute(.asked(questionID: oil), now: later)
        }
    }

    @Test("ADR-0007: a version 1 store opens under the current version with car memory intact")
    func versionOneStoreMigrates() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let vehicleID: VehicleID
        do {
            let writer = try LegacyStoreWriter(PitstopSchemaV1.self, url: url)
            vehicleID = writer.car()
            writer.insert(Note(vehicleID: vehicleID, rawText: "до миграции", createdAt: now))
            try writer.save()
        }

        let container = try PersistenceContainer.make(storeURL: url)
        let carMemory = SwiftDataCarMemoryStore(modelContainer: container)
        let questions = try SwiftDataPitQuestionStore(
            modelContainer: container,
            registry: PitQuestionFixtures.registry()
        )

        #expect(try await carMemory.currentVehicle().id == vehicleID)
        #expect(try await carMemory.notes().map(\.rawText) == ["до миграции"])
        #expect(try await questions.questionStates().isEmpty)
        try await questions.execute(.answered(questionID: oil), now: now)
        #expect(try await questions.questionStates().map(\.resolution) == [.answered])
    }
}
