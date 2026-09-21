import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(30 * 86400)

@MainActor
@Suite("Stop tracking an operation")
struct StopTrackingTests {
    private func makeModel(_ store: FakeCarMemoryStore) -> ServiceViewModel {
        ServiceViewModel(store: store, now: { now })
    }

    /// Oil every 10,000 km, done at 50,000 km twenty days ago, with a current reading.
    private func trackedOilWithHistory(_ store: FakeCarMemoryStore) async throws -> ServiceViewModel {
        let model = makeModel(store)
        let vehicleID = await store.vehicle.id
        _ = try await store.execute(
            .recordOdometerReading(.init(reading: OdometerReading(
                vehicleID: vehicleID,
                value: 59200,
                recordedAt: now
            ))),
            now: now
        )
        _ = try await store.execute(
            .recordVehicleEvent(.init(event: DomainFixtures.History.serviceVisit
                    .dated(now.addingTimeInterval(-86400)))),
            now: now
        )
        #expect(await model.track(.engineOilService, kilometersText: "10000", monthsText: ""))
        #expect(await model.confirmDone(
            .engineOilService,
            on: now.addingTimeInterval(-20 * 86400),
            odometerText: "50000"
        ))
        return model
    }

    @Test("REQ-MAINT-024: stopping tracking waits for a confirmation and a cancel changes nothing")
    func stoppingNeedsConfirmation() async throws {
        let store = FakeCarMemoryStore()
        let model = try await trackedOilWithHistory(store)
        let executedBefore = await store.executed.count
        let oil = try #require(model.state.operations.first)

        model.requestStopTracking(oil)

        let request = try #require(model.state.stopTrackingCandidate)
        #expect(request == StopTrackingRequest(operation: .engineOilService, fallsBackToOtherPolicy: false))
        #expect(request.message == "service.stopTracking.message")
        #expect(await store.executed.count == executedBefore)

        model.cancelStopTracking()

        #expect(model.state.stopTrackingCandidate == nil)
        #expect(await store.executed.count == executedBefore)
        #expect(model.state.operations.map(\.id) == [.engineOilService])
    }

    @Test("REQ-MAINT-023: stopping tracking removes the owner's policy only; completions and History stay")
    func stoppingKeepsHistory() async throws {
        let store = FakeCarMemoryStore()
        let model = try await trackedOilWithHistory(store)
        let completions = await store.completions
        let events = await store.events
        let oil = try #require(model.state.operations.first)

        model.requestStopTracking(oil)
        #expect(await model.confirmStopTracking(.engineOilService))

        #expect(model.state.operations.isEmpty && model.state.scope.isEmpty)
        #expect(model.state.stopTrackingCandidate == nil && model.state.listFailure == nil)
        #expect(await store.policies.isEmpty)
        #expect(await store.completions == completions && completions.count == 1)
        #expect(await store.events == events && events.count == 1)
        #expect(model.state.untrackedOperations.contains(.engineOilService))
    }

    @Test("REQ-MAINT-023: tracking again resumes from the kept completion, not from unknown")
    func trackingAgainResumesFromHistory() async throws {
        let store = FakeCarMemoryStore()
        let model = try await trackedOilWithHistory(store)
        try model.requestStopTracking(#require(model.state.operations.first))
        #expect(await model.confirmStopTracking(.engineOilService))

        #expect(await model.track(.engineOilService, kilometersText: "10000", monthsText: ""))

        let oil = try #require(model.state.operations.first)
        #expect(oil.lastCompletion != nil && oil.anchorKm == 60000 && oil.status == .approaching)
    }

    @Test("REQ-DOMAIN-006: an operation backed only by a recommendation offers no stop and removes nothing")
    func recommendationIsNotStopped() async throws {
        let store = FakeCarMemoryStore()
        let vehicleID = await store.vehicle.id
        let recommendation = MaintenancePolicy(operationID: .dsgService, distanceIntervalKm: 60000)
        _ = try await store.execute(
            .setMaintenancePolicy(.init(vehicleID: vehicleID, policy: recommendation)),
            now: now
        )
        let model = makeModel(store)
        await model.load()

        try model.requestStopTracking(#require(model.state.operations.first))

        #expect(model.state.stopTrackingCandidate == nil)
        await #expect(throws: CarMemoryStoreError.unknownPolicy) {
            try await store.execute(
                .stopTrackingOperation(.init(vehicleID: vehicleID, operationID: .dsgService)),
                now: now
            )
        }
        #expect(await store.policies == [recommendation])
    }

    @Test("REQ-MAINT-023: with a recommendation kept, the dialog says it applies and the operation stays on Service")
    func stoppingFallsBackToTheRecommendation() async throws {
        let store = FakeCarMemoryStore()
        let vehicleID = await store.vehicle.id
        let recommendation = MaintenancePolicy(operationID: .dsgService, distanceIntervalKm: 60000)
        _ = try await store.execute(
            .setMaintenancePolicy(.init(vehicleID: vehicleID, policy: recommendation)),
            now: now
        )
        let model = makeModel(store)
        #expect(await model.track(.dsgService, kilometersText: "40000", monthsText: ""))
        try model.requestStopTracking(#require(model.state.operations.first))

        let request = try #require(model.state.stopTrackingCandidate)
        #expect(request.fallsBackToOtherPolicy && request.message == "service.stopTracking.message.fallback")
        #expect(await model.confirmStopTracking(.dsgService))

        #expect(model.state.operations.map(\.policy) == [recommendation])
        #expect(await store.policies == [recommendation])
        #expect(!model.state.untrackedOperations.contains(.dsgService))
    }

    @Test("REQ-CAPTURE-009: a failed stop is reported on the list and the operation stays tracked")
    func failedStopIsReportedOnTheList() async throws {
        let store = FakeCarMemoryStore()
        let model = try await trackedOilWithHistory(store)
        try model.requestStopTracking(#require(model.state.operations.first))
        await store.failCommands()

        #expect(await !model.confirmStopTracking(.engineOilService))

        #expect(model.state.listFailure == .notSaved && model.state.failure == nil)
        #expect(model.state.operations.map(\.id) == [.engineOilService])
        #expect(await store.policies.count == 1)
    }

    @Test("REQ-MAINT-023: Car Board, Road and the Pit mileage question stop counting the operation after reload")
    func surfacesDropTheOperation() async throws {
        let store = FakeCarMemoryStore()
        let vehicleID = await store.vehicle.id
        let model = makeModel(store)
        // The only mileage is 200 days old, so this distance rule alone makes the Pit mileage question relevant.
        #expect(await model.track(.engineOilService, kilometersText: "10000", monthsText: ""))
        #expect(await model.confirmDone(
            .engineOilService,
            on: now.addingTimeInterval(-200 * 86400),
            odometerText: "50000"
        ))
        let registry = try PitQuestionRegistry.product()
        #expect(try await !registry.relevantQuestionIDs(maintenance: states(store)).isEmpty)

        try model.requestStopTracking(#require(model.state.operations.first))
        #expect(await model.confirmStopTracking(.engineOilService))

        let board = CarBoardViewModel(store: store, now: { now })
        let road = RoadViewModel(store: store, now: { now })
        await board.load()
        await road.load()
        #expect(board.state.service.isEmpty)
        #expect(try #require(road.state.projection).slots.isEmpty)
        #expect(try await registry.relevantQuestionIDs(maintenance: states(store)).isEmpty)
        #expect(await store.completions.map(\.vehicleID) == [vehicleID])
    }

    private func states(_ store: FakeCarMemoryStore) async throws -> [MaintenanceOperationState] {
        let completions = try await store.maintenanceCompletions()
        return try await MaintenanceEngine().states(
            policies: store.maintenancePolicies(),
            completions: completions,
            context: MaintenanceContext(
                now: now,
                latestReading: store.odometerReadings().latest,
                completions: completions
            )
        )
    }
}
