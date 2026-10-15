import Foundation
@testable import Pitstop
import SwiftData
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(90 * 86400)

@Suite("SwiftData completion revoke")
struct SwiftDataCompletionRevokeTests {
    @Test("ADR-0010: a revoked completion is gone after reopening, and an unknown ID changes nothing")
    func revokeSurvivesRelaunch() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let store = try TestStore.carMemory(url: url)
        let vehicleID = try await store.currentVehicle().id
        let kept = MaintenanceCompletion(
            vehicleID: vehicleID,
            operationID: .brakeFluid,
            performedAt: DomainFixtures.Odometers.baseDate
        )
        let mistaken = MaintenanceCompletion(
            vehicleID: vehicleID,
            operationID: .engineOilService,
            performedAt: DomainFixtures.Odometers.baseDate
        )
        for completion in [kept, mistaken] {
            try await store.execute(.confirmMaintenanceCompletion(.init(completion: completion)), now: now)
        }

        try await store.execute(.revokeMaintenanceCompletion(.init(completionID: mistaken.id)), now: now)
        await #expect(throws: CarMemoryStoreError.unknownCompletion) {
            try await store.execute(.revokeMaintenanceCompletion(.init(completionID: UUID())), now: now)
        }

        #expect(try await TestStore.carMemory(url: url).maintenanceCompletions() == [kept])
    }

    @Test("ADR-0020: an operation outside the catalog keeps its identity on disk and in the engine")
    func uncataloguedOperationKeepsIdentity() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let operation = MaintenanceOperationID(rawValue: "coolantService")
        let store = try TestStore.carMemory(url: url)
        let vehicleID = try await store.currentVehicle().id
        let policy = MaintenancePolicy(operationID: operation, timeIntervalMonths: 48, source: .userCustom)
        let completion = MaintenanceCompletion(
            vehicleID: vehicleID,
            operationID: operation,
            performedAt: DomainFixtures.Odometers.baseDate
        )
        try await store.execute(.setMaintenancePolicy(.init(vehicleID: vehicleID, policy: policy)), now: now)
        try await store.execute(.confirmMaintenanceCompletion(.init(completion: completion)), now: now)

        let reopened = try TestStore.carMemory(url: url)
        let states = try await MaintenanceEngine().states(
            policies: reopened.maintenancePolicies(),
            completions: reopened.maintenanceCompletions(),
            context: MaintenanceContext(now: now, latestReading: nil)
        )

        #expect(!MaintenanceOperationID.catalog.contains(operation))
        #expect(states.map(\.id) == [operation])
        #expect(states.first?.lastCompletion == completion)
        #expect(states.first?.status == .upToDate)
    }
}

@Suite("SwiftData event correction")
struct SwiftDataEventCorrectionTests {
    @Test("REQ-DOMAIN-016: a corrected event reads back from disk with the same identity")
    func correctionSurvivesRelaunch() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let store = try TestStore.carMemory(url: url)
        let vehicleID = try await store.currentVehicle().id
        let event = HistoryEvent(vehicleID: vehicleID, kind: .service, date: DomainFixtures.Odometers.baseDate)
        try await store.execute(.recordVehicleEvent(RecordVehicleEventCommand(event: event)), now: now)

        let corrected = HistoryEvent(
            id: event.id,
            vehicleID: vehicleID,
            kind: .service,
            date: DomainFixtures.Odometers.baseDate,
            odometerKm: 84200,
            amount: 12500,
            note: "замена масла"
        )
        try await store.execute(.correctVehicleEvent(CorrectVehicleEventCommand(event: corrected)), now: now)

        #expect(try await TestStore.carMemory(url: url).historyEvents() == [corrected])
    }

    @Test("ADR-0007: correcting an event that does not exist fails and writes nothing")
    func unknownEventIsRejected() async throws {
        let store = try TestStore.carMemory()
        let vehicleID = try await store.currentVehicle().id
        let ghost = HistoryEvent(vehicleID: vehicleID, kind: .other, date: DomainFixtures.Odometers.baseDate)
        await #expect(throws: CarMemoryStoreError.unknownEvent) {
            try await store.execute(.correctVehicleEvent(CorrectVehicleEventCommand(event: ghost)), now: now)
        }
        #expect(try await store.historyEvents().isEmpty)
    }

    @Test("ADR-0007: a correction cannot move an event to another vehicle")
    func correctionCannotChangeVehicle() async throws {
        let store = try TestStore.carMemory()
        let vehicleID = try await store.currentVehicle().id
        let event = HistoryEvent(vehicleID: vehicleID, kind: .carWash, date: DomainFixtures.Odometers.baseDate)
        try await store.execute(.recordVehicleEvent(RecordVehicleEventCommand(event: event)), now: now)
        let moved = HistoryEvent(
            id: event.id,
            vehicleID: DomainFixtures.Vehicles.secondaryID,
            kind: .carWash,
            date: DomainFixtures.Odometers.baseDate
        )

        await #expect(throws: CarMemoryStoreError.self) {
            try await store.execute(.correctVehicleEvent(CorrectVehicleEventCommand(event: moved)), now: now)
        }
        #expect(try await store.historyEvents() == [event])
    }
}
