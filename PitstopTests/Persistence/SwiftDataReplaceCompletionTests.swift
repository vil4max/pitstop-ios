import Foundation
@testable import Pitstop
import Testing

private let performed = DomainFixtures.Odometers.baseDate
private let now = performed.addingTimeInterval(86400)

/// "Replace with mine" in Mark as done revokes Pit's completion and stores the owner's as one command, so the store
/// never holds both (two completions of the same work) or neither (the work lost) (REQ-NEW-3).
@Suite("Replacing a completion in one transaction")
struct SwiftDataReplaceCompletionTests {
    private struct Stored {
        let store: SwiftDataCarMemoryStore
        let pits: MaintenanceCompletion
        let brakes: MaintenanceCompletion
        let owners: MaintenanceCompletion
    }

    /// Pit's oil change and an unrelated brake fluid change on disk, and the owner's oil entry, not stored yet.
    private func stored(at url: URL) async throws -> Stored {
        let store = try TestStore.carMemory(url: url)
        let vehicleID = try await store.currentVehicle().id
        let pits = MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService, performedAt: performed, odometerKm: 85000
        )
        let brakes = MaintenanceCompletion(vehicleID: vehicleID, operationID: .brakeFluid, performedAt: performed)
        for completion in [pits, brakes] {
            try await store.execute(.confirmMaintenanceCompletion(.init(completion: completion)), now: now)
        }
        let owners = MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService, performedAt: performed, odometerKm: 86000
        )
        return Stored(store: store, pits: pits, brakes: brakes, owners: owners)
    }

    @Test("REQ-NEW-3: replacing Pit's completion revokes it and stores the owner's with one command")
    func replaceSwapsTheCompletion() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let fixture = try await stored(at: url)

        let result = try await fixture.store.execute(
            .replaceMaintenanceCompletion(.init(replacedIDs: [fixture.pits.id], completion: fixture.owners)),
            now: now
        )

        #expect(result == .completionConfirmed(fixture.owners))
        let reopened = try await TestStore.carMemory(url: url).maintenanceCompletions()
        #expect(Set(reopened) == [fixture.brakes, fixture.owners])
    }

    @Test("REQ-NEW-15: when any part of a replace fails, neither the revoke nor the owner's completion is stored")
    func failedReplaceChangesNothing() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let fixture = try await stored(at: url)
        let store = fixture.store

        // One of the completions to replace is gone.
        await #expect(throws: CarMemoryStoreError.unknownCompletion) {
            try await store.execute(
                .replaceMaintenanceCompletion(.init(
                    replacedIDs: [fixture.pits.id, UUID()],
                    completion: fixture.owners
                )),
                now: now
            )
        }
        // Another operation's completion is not the same work, so it cannot be replaced by an oil change.
        await #expect(throws: CarMemoryStoreError.unknownCompletion) {
            try await store.execute(
                .replaceMaintenanceCompletion(.init(replacedIDs: [fixture.brakes.id], completion: fixture.owners)),
                now: now
            )
        }
        // The single save fails after both changes were applied.
        await store.failNextSave()
        await #expect(throws: CarMemoryStoreError.storageFailure) {
            try await store.execute(
                .replaceMaintenanceCompletion(.init(replacedIDs: [fixture.pits.id], completion: fixture.owners)),
                now: now
            )
        }

        #expect(try await Set(store.maintenanceCompletions()) == [fixture.pits, fixture.brakes])
        let reopened = try await TestStore.carMemory(url: url).maintenanceCompletions()
        #expect(Set(reopened) == [fixture.pits, fixture.brakes])
    }

    @Test("REQ-NEW-15: a replace is validated as a confirmation: no future date and a plausible odometer")
    func replaceIsValidatedLikeAConfirmation() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let fixture = try await stored(at: url)
        let future = MaintenanceCompletion(
            vehicleID: fixture.owners.vehicleID, operationID: .engineOilService, performedAt: now + 3 * 86400
        )

        await #expect(throws: CarMemoryStoreError.invalidCommand(.dateInFuture)) {
            try await fixture.store.execute(
                .replaceMaintenanceCompletion(.init(replacedIDs: [fixture.pits.id], completion: future)), now: now
            )
        }
        #expect(try await Set(fixture.store.maintenanceCompletions()) == [fixture.pits, fixture.brakes])
    }
}
