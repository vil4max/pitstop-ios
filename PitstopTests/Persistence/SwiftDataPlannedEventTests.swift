import Foundation
@testable import Pitstop
import SwiftData
import Testing

private let now = DomainFixtures.Odometers.baseDate
private let day: TimeInterval = 86400

private func planned(
    _ vehicleID: VehicleID,
    _ kind: PlannedDatedEvent.Kind = .insuranceExpiry,
    inDays days: Double,
    id: UUID = UUID()
) -> PlannedDatedEvent {
    PlannedDatedEvent(
        id: id,
        vehicleID: vehicleID,
        kind: kind,
        date: now.addingTimeInterval(days * day),
        createdAt: now
    )
}

@Suite("SwiftData planned dates")
struct SwiftDataPlannedEventTests {
    @Test("REQ-ROAD-021: planned dates survive a reopen, earliest first, with only kind, date and label")
    func roundTripSurvivesReopen() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let insurance: PlannedDatedEvent
        let tyres: PlannedDatedEvent
        do {
            let store = try TestStore.carMemory(url: url)
            let vehicleID = try await store.currentVehicle().id
            insurance = planned(vehicleID, inDays: 200)
            tyres = planned(vehicleID, .other(label: "Winter tyres"), inDays: 30)
            #expect(try await store.execute(.addPlannedEvent(.init(event: insurance)), now: now)
                == .plannedEventAdded(insurance))
            try await store.execute(.addPlannedEvent(.init(event: tyres)), now: now)
        }

        let reopened = try TestStore.carMemory(url: url)

        #expect(try await reopened.plannedEvents() == [tyres, insurance])
        // A plan is not a fact: History and maintenance stay empty (core C5).
        #expect(try await reopened.historyEvents().isEmpty)
        #expect(try await reopened.maintenanceCompletions().isEmpty)
    }

    @Test("REQ-ROAD-019: a correction keeps identity, vehicle and creation time, and survives a reopen")
    func correctionKeepsIdentity() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let original: PlannedDatedEvent
        do {
            let store = try TestStore.carMemory(url: url)
            let vehicleID = try await store.currentVehicle().id
            original = planned(vehicleID, .other(label: "Warranty"), inDays: 100)
            try await store.execute(.addPlannedEvent(.init(event: original)), now: now)
            let corrected = PlannedDatedEvent(
                id: original.id,
                vehicleID: vehicleID,
                kind: .other(label: "Warranty ends"),
                date: now.addingTimeInterval(120 * day),
                createdAt: now.addingTimeInterval(999)
            )
            let result = try await store.execute(.updatePlannedEvent(.init(event: corrected)), now: now + 60)
            guard case let .plannedEventUpdated(updated) = result else {
                Issue.record("unexpected result \(result)")
                return
            }
            #expect(updated.createdAt == now)
        }

        let stored = try #require(try await TestStore.carMemory(url: url).plannedEvents().first)
        #expect(stored.id == original.id && stored.createdAt == original.createdAt)
        #expect(stored.kind == .other(label: "Warranty ends"))
        #expect(stored.date == now.addingTimeInterval(120 * day))
    }

    @Test("REQ-ROAD-019: deleting removes only that date; unknown IDs are rejected")
    func removal() async throws {
        let store = try TestStore.carMemory()
        let vehicleID = try await store.currentVehicle().id
        let insurance = planned(vehicleID, inDays: 40)
        let tyres = planned(vehicleID, .other(label: nil), inDays: 50)
        try await store.execute(.addPlannedEvent(.init(event: insurance)), now: now)
        try await store.execute(.addPlannedEvent(.init(event: tyres)), now: now)

        #expect(try await store.execute(.removePlannedEvent(.init(eventID: insurance.id)), now: now)
            == .plannedEventRemoved(insurance))

        #expect(try await store.plannedEvents() == [tyres])
        await #expect(throws: CarMemoryStoreError.unknownPlannedEvent) {
            try await store.execute(.removePlannedEvent(.init(eventID: insurance.id)), now: now)
        }
        await #expect(throws: CarMemoryStoreError.unknownPlannedEvent) {
            try await store.execute(.updatePlannedEvent(.init(event: insurance)), now: now)
        }
    }

    @Test("REQ-ROAD-017: invalid, foreign or repeated plans are rejected and nothing is saved")
    func rejectedCommandsSaveNothing() async throws {
        let store = try TestStore.carMemory()
        let vehicleID = try await store.currentVehicle().id
        let stored = planned(vehicleID, .other(label: nil), inDays: 10)
        try await store.execute(.addPlannedEvent(.init(event: stored)), now: now)

        await #expect(throws: CarMemoryStoreError.invalidCommand(.plannedDateOutOfRange)) {
            try await store.execute(.addPlannedEvent(.init(event: planned(vehicleID, inDays: -20))), now: now)
        }
        await #expect(throws: CarMemoryStoreError.invalidCommand(.plannedLabelTooLong)) {
            let label = String(repeating: "x", count: PlannedEventLimits.maximumLabelLength + 1)
            try await store.execute(
                .addPlannedEvent(.init(event: planned(vehicleID, .other(label: label), inDays: 5))),
                now: now
            )
        }
        await #expect(throws: CarMemoryStoreError.unknownVehicle) {
            try await store.execute(.addPlannedEvent(.init(event: planned(VehicleID(), inDays: 5))), now: now)
        }
        await #expect(throws: CarMemoryStoreError.duplicateRecord) {
            try await store.execute(
                .addPlannedEvent(.init(event: planned(vehicleID, inDays: 5, id: stored.id))),
                now: now
            )
        }
        // A correction can never move a plan to another vehicle.
        let moved = PlannedDatedEvent(
            id: stored.id, vehicleID: VehicleID(), kind: stored.kind, date: stored.date, createdAt: now
        )
        await #expect(throws: CarMemoryStoreError.unknownVehicle) {
            try await store.execute(.updatePlannedEvent(.init(event: moved)), now: now)
        }

        #expect(try await store.plannedEvents() == [stored])
    }

    @Test("REQ-ROAD-018: one insurance expiry on Road per car; one that has left Road does not count")
    func oneInsuranceOnRoad() async throws {
        let store = try TestStore.carMemory()
        let vehicleID = try await store.currentVehicle().id
        let expired = planned(vehicleID, inDays: -14)
        try await store.execute(.addPlannedEvent(.init(event: expired)), now: now)
        let later = now.addingTimeInterval(0.5 * day)

        // Half a day later the old one is past the grace period, so a new expiry may be planned.
        let renewed = planned(vehicleID, inDays: 351)
        try await store.execute(.addPlannedEvent(.init(event: renewed)), now: later)

        await #expect(throws: CarMemoryStoreError.insuranceExpiryAlreadyPlanned) {
            try await store.execute(.addPlannedEvent(.init(event: planned(vehicleID, inDays: 60))), now: later)
        }
        // Turning another date into an insurance expiry is the same conflict; correcting the one on Road is not.
        let tyres = planned(vehicleID, .other(label: "Tyres"), inDays: 90)
        try await store.execute(.addPlannedEvent(.init(event: tyres)), now: later)
        let asInsurance = PlannedDatedEvent(
            id: tyres.id, vehicleID: vehicleID, kind: .insuranceExpiry, date: tyres.date, createdAt: now
        )
        await #expect(throws: CarMemoryStoreError.insuranceExpiryAlreadyPlanned) {
            try await store.execute(.updatePlannedEvent(.init(event: asInsurance)), now: later)
        }
        let moved = PlannedDatedEvent(
            id: renewed.id, vehicleID: vehicleID, kind: .insuranceExpiry,
            date: now.addingTimeInterval(365 * day), createdAt: now
        )
        try await store.execute(.updatePlannedEvent(.init(event: moved)), now: later)

        let stored = try await store.plannedEvents()
        #expect(stored.map(\.id) == [expired.id, tyres.id, renewed.id])
        #expect(stored.filter(\.isInsuranceExpiry).count == 2)
    }

    @Test("ADR-0032: a stored kind this version cannot read stays visible as the owner's own date")
    func unknownKindReadsAsOther() async throws {
        let container = try PersistenceContainer.make(storeURL: nil)
        let store = SwiftDataCarMemoryStore(modelContainer: container)
        let vehicleID = try await store.currentVehicle().id
        let context = ModelContext(container)
        context.insert(PitstopSchemaV3.PlannedVehicleEventRecord(
            id: UUID(), vehicleID: vehicleID.rawValue, kind: "futureKind", label: "Inspection",
            date: now.addingTimeInterval(20 * day), createdAt: now
        ))
        try context.save()

        let read = try #require(try await store.plannedEvents().first)
        #expect(read.kind == .other(label: "Inspection"))
        // It never blocks a new insurance expiry.
        try await store.execute(.addPlannedEvent(.init(event: planned(vehicleID, inDays: 30))), now: now)
    }

    @Test("REQ-ROAD-017: a failed save reports failure and the plan never appears later")
    func failedSaveLeavesNothing() async throws {
        let store = try TestStore.carMemory()
        let vehicleID = try await store.currentVehicle().id

        await store.failNextSave()
        await #expect(throws: CarMemoryStoreError.storageFailure) {
            try await store.execute(.addPlannedEvent(.init(event: planned(vehicleID, inDays: 30))), now: now)
        }

        #expect(try await store.plannedEvents().isEmpty)
    }
}
