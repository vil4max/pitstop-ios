import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(400 * 86400)
private let day: TimeInterval = 86400

@MainActor
@Suite("Maintenance snapshot")
struct MaintenanceSnapshotTests {
    /// Every mileage source and every kind of anchor at once: a reading, completions with and without mileage,
    /// a dashboard reading with its odometer, and a planned date.
    private func seededStore() async throws -> FakeCarMemoryStore {
        let store = FakeCarMemoryStore()
        let vehicleID = await store.vehicle.id
        let policies = [
            MaintenancePolicy(operationID: .engineOilService, distanceIntervalKm: 10000, source: .userCustom),
            MaintenancePolicy(operationID: .brakeFluid, timeIntervalMonths: 24, source: .userCustom),
            MaintenancePolicy(operationID: .cabinFilter, distanceIntervalKm: 15000, source: .userCustom),
        ]
        for policy in policies {
            _ = try await store.execute(.setMaintenancePolicy(.init(vehicleID: vehicleID, policy: policy)), now: now)
        }
        let completions = [
            MaintenanceCompletion(
                vehicleID: vehicleID, operationID: .engineOilService,
                performedAt: now.addingTimeInterval(-200 * day), odometerKm: 52000
            ),
            MaintenanceCompletion(
                vehicleID: vehicleID, operationID: .brakeFluid, performedAt: now.addingTimeInterval(-700 * day)
            ),
            MaintenanceCompletion(
                vehicleID: vehicleID, operationID: .cabinFilter,
                performedAt: now.addingTimeInterval(-90 * day), odometerKm: 55000
            ),
        ]
        for completion in completions {
            _ = try await store.execute(.confirmMaintenanceCompletion(.init(completion: completion)), now: now)
        }
        let reading = OdometerReading(vehicleID: vehicleID, value: 58000, recordedAt: now.addingTimeInterval(-30 * day))
        _ = try await store.execute(.recordOdometerReading(.init(reading: reading)), now: now)
        await store.seed(
            VehicleServiceReport(
                vehicleID: vehicleID, operationID: .engineOilService,
                reportedAt: now.addingTimeInterval(-5 * day), odometerKm: 59000, remainingDays: 40
            ))
        let planned = PlannedDatedEvent(
            vehicleID: vehicleID, kind: .insuranceExpiry, date: now.addingTimeInterval(60 * day), createdAt: now
        )
        _ = try await store.execute(.addPlannedEvent(.init(event: planned)), now: now)
        return store
    }

    @Test("REQ-BOARD-026, REQ-BOARD-010: Service, Road, Car Board and Pit's questions read one snapshot alike")
    func surfacesAgree() async throws {
        let store = try await seededStore()
        let snapshot = try await MaintenanceSnapshot.read(from: store, now: now)
        let service = ServiceViewModel(store: store, now: { now })
        let road = RoadViewModel(store: store, now: { now })
        let board = CarBoardViewModel(store: store, now: { now })

        await service.load()
        await road.load()
        await board.load()

        // The newest mileage fact is the dashboard reading's odometer, not the older odometer reading.
        #expect(snapshot.context.observedKm == 59000)
        #expect(board.state.car.odometerKm == 59000)
        #expect(service.state.mileage == snapshot.context.mileage)
        #expect(service.state.operations == snapshot.states.byUrgency)
        #expect(board.state.service == service.state.operations)
        let projection = try #require(road.state.projection)
        #expect(board.state.road == projection)
        #expect(!projection.slots.isEmpty)
        // Pit decides which questions matter from the same states Service shows.
        let registry = try PitQuestionRegistry.product()
        #expect(
            registry.relevantQuestionIDs(maintenance: snapshot.states)
                == registry.relevantQuestionIDs(maintenance: service.state.operations))
    }
}
