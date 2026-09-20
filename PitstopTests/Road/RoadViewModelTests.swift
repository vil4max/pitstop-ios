import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(30 * 86400)

@MainActor
@Suite("Road view model")
struct RoadViewModelTests {
    private func seed(_ store: FakeCarMemoryStore) async throws {
        let vehicleID = await store.vehicle.id
        let policy = MaintenancePolicy(operationID: .engineOilService, distanceIntervalKm: 10000, source: .userCustom)
        let completion = MaintenanceCompletion(
            vehicleID: vehicleID,
            operationID: .engineOilService,
            performedAt: now.addingTimeInterval(-20 * 86400),
            odometerKm: 50000
        )
        let reading = OdometerReading(vehicleID: vehicleID, value: 59200, recordedAt: now)
        _ = try await store.execute(.setMaintenancePolicy(.init(vehicleID: vehicleID, policy: policy)), now: now)
        _ = try await store.execute(.confirmMaintenanceCompletion(.init(completion: completion)), now: now)
        _ = try await store.execute(.recordOdometerReading(.init(reading: reading)), now: now)
    }

    @Test("REQ-ROAD-009: with nothing recorded the road state is an honest empty projection")
    func emptyStoreGivesEmptyRoad() async throws {
        let model = RoadViewModel(store: FakeCarMemoryStore(), now: { now })
        await model.load()
        let road = try #require(model.state.projection)
        #expect(road.slots.isEmpty && road.horizon == .noKnownMilestones && road.past == nil)
    }

    @Test("REQ-ROAD-001: a stored approaching maintenance anchor reaches the Road surface as its first milestone")
    func stateIsTheProjection() async throws {
        let store = FakeCarMemoryStore()
        try await seed(store)
        let model = RoadViewModel(store: store, now: { now })

        await model.load()

        let road = try #require(model.state.projection)
        let lead = try #require(road.slots.first?.lead)
        #expect(lead.subject == .maintenance(.engineOilService))
        #expect(lead.state == .approaching && lead.remainingKm == 800)
        #expect(road.past?.count == 1)
    }

    @Test("REQ-BOARD-010: Car Board and the Road screen project the same road from the same facts")
    func tileUsesTheSameProjection() async throws {
        let store = FakeCarMemoryStore()
        try await seed(store)
        let vehicleID = await store.vehicle.id
        // More operations, so Car Board's urgency-sorted input differs in order from the store's.
        for (operation, months, daysAgo) in [(MaintenanceOperationID.brakeFluid, 24, 700.0), (.cabinFilter, 12, 100)] {
            let policy = MaintenancePolicy(operationID: operation, timeIntervalMonths: months, source: .userCustom)
            let done = MaintenanceCompletion(
                vehicleID: vehicleID,
                operationID: operation,
                performedAt: now.addingTimeInterval(-daysAgo * 86400)
            )
            _ = try await store.execute(.setMaintenancePolicy(.init(vehicleID: vehicleID, policy: policy)), now: now)
            _ = try await store.execute(.confirmMaintenanceCompletion(.init(completion: done)), now: now)
        }
        let board = CarBoardViewModel(store: store, now: { now })
        let screen = RoadViewModel(store: store, now: { now })

        await board.load()
        await screen.load()

        let tile = try #require(board.state.road)
        #expect(tile == screen.state.projection)
        #expect(tile.slots.count == 3)
    }

    @Test("a load failure keeps the last projection on screen and reports the failure")
    func loadFailureKeepsLastProjection() async throws {
        let store = FakeCarMemoryStore()
        try await seed(store)
        let model = RoadViewModel(store: store, now: { now })
        await model.load()
        let before = model.state.projection
        await store.failEverything()

        await model.load()

        #expect(model.state.isLoadFailed)
        #expect(model.state.projection == before)
    }
}
