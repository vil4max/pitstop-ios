import Foundation
@testable import Pitstop
import SwiftData
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(90 * 86400)

private func makeStore(url: URL? = nil) throws -> SwiftDataCarMemoryStore {
    try SwiftDataCarMemoryStore(modelContainer: PersistenceContainer.make(storeURL: url))
}

@Suite("SwiftData stop tracking")
struct SwiftDataStopTrackingTests {
    @Test("REQ-MAINT-023: stopping tracking deletes the owner's policy on disk and keeps every other record")
    func stopTrackingKeepsHistoryOnDisk() async throws {
        let url = URL.temporaryDirectory.appending(path: "pitstop-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
            }
        }
        let store = try makeStore(url: url)
        let vehicleID = try await store.currentVehicle().id
        let custom = MaintenancePolicy(operationID: .engineOilService, distanceIntervalKm: 10000, source: .userCustom)
        let recommendation = MaintenancePolicy(operationID: .engineOilService, distanceIntervalKm: 15000)
        let brakes = MaintenancePolicy(operationID: .brakeFluid, timeIntervalMonths: 24, source: .userCustom)
        let completion = MaintenanceCompletion(
            vehicleID: vehicleID,
            operationID: .engineOilService,
            performedAt: DomainFixtures.Odometers.baseDate,
            odometerKm: 84200
        )
        let event = HistoryEvent(vehicleID: vehicleID, kind: .service, date: DomainFixtures.Odometers.baseDate)
        for policy in [custom, recommendation, brakes] {
            try await store.execute(.setMaintenancePolicy(.init(vehicleID: vehicleID, policy: policy)), now: now)
        }
        try await store.execute(.confirmMaintenanceCompletion(.init(completion: completion)), now: now)
        try await store.execute(.recordVehicleEvent(.init(event: event)), now: now)

        let result = try await store.execute(
            .stopTrackingOperation(.init(vehicleID: vehicleID, operationID: .engineOilService)),
            now: now
        )

        #expect(result == .trackingStopped(custom))
        let reopened = try makeStore(url: url)
        #expect(try await Set(reopened.maintenancePolicies()) == [recommendation, brakes])
        #expect(try await reopened.maintenanceCompletions() == [completion])
        #expect(try await reopened.historyEvents() == [event])
    }

    @Test("REQ-MAINT-023: stopping an operation the owner does not track is rejected and saves nothing")
    func stopTrackingUnknownPolicyIsRejected() async throws {
        let store = try makeStore()
        let vehicleID = try await store.currentVehicle().id
        let recommendation = MaintenancePolicy(operationID: .dsgService, distanceIntervalKm: 60000)
        try await store.execute(.setMaintenancePolicy(.init(vehicleID: vehicleID, policy: recommendation)), now: now)

        for operation in [MaintenanceOperationID.dsgService, .airFilter] {
            await #expect(throws: CarMemoryStoreError.unknownPolicy) {
                try await store.execute(
                    .stopTrackingOperation(.init(vehicleID: vehicleID, operationID: operation)),
                    now: now
                )
            }
        }
        await #expect(throws: CarMemoryStoreError.unknownVehicle) {
            try await store.execute(
                .stopTrackingOperation(.init(vehicleID: VehicleID(), operationID: .dsgService)),
                now: now
            )
        }
        #expect(try await store.maintenancePolicies() == [recommendation])
    }

    @Test("REQ-MAINT-023: another vehicle's policy for the same operation survives")
    func otherVehiclePolicySurvives() async throws {
        let container = try PersistenceContainer.make(storeURL: nil)
        let store = SwiftDataCarMemoryStore(modelContainer: container)
        let vehicleID = try await store.currentVehicle().id
        let other = MaintenancePolicy(operationID: .engineOilService, distanceIntervalKm: 8000, source: .userCustom)
        try insertRaw(other, vehicle: VehicleID(), source: "userCustom", into: container)
        try await store.execute(
            .setMaintenancePolicy(.init(vehicleID: vehicleID, policy: MaintenanceFixture.oil10k)),
            now: now
        )

        try await store.execute(
            .stopTrackingOperation(.init(vehicleID: vehicleID, operationID: .engineOilService)),
            now: now
        )

        #expect(try await store.maintenancePolicies() == [other])
    }

    @Test("ADR-0031: a stored rule with an unrecognised source is not the owner's and cannot be stopped")
    func unrecognisedSourceIsNotOwned() async throws {
        let container = try PersistenceContainer.make(storeURL: nil)
        let store = SwiftDataCarMemoryStore(modelContainer: container)
        let vehicleID = try await store.currentVehicle().id
        let policy = MaintenancePolicy(operationID: .brakeFluid, timeIntervalMonths: 24)
        try insertRaw(policy, vehicle: vehicleID, source: "futureSource", into: container)

        let stored = try await store.maintenancePolicies()

        #expect(stored.map(\.source) == [.defaultRecommendation])
        await #expect(throws: CarMemoryStoreError.unknownPolicy) {
            try await store.execute(
                .stopTrackingOperation(.init(vehicleID: vehicleID, operationID: .brakeFluid)),
                now: now
            )
        }
        #expect(try await store.maintenancePolicies().count == 1)
    }

    /// Writes a row the command path cannot: another vehicle, or a source this version does not know.
    private func insertRaw(
        _ policy: MaintenancePolicy,
        vehicle: VehicleID,
        source: String,
        into container: ModelContainer
    ) throws {
        let context = ModelContext(container)
        context.insert(PitstopSchemaV1.MaintenancePolicyRecord(
            vehicleID: vehicle.rawValue,
            operationID: policy.operationID.rawValue,
            distanceIntervalKm: policy.distanceIntervalKm,
            timeIntervalMonths: policy.timeIntervalMonths,
            source: source
        ))
        try context.save()
    }
}
