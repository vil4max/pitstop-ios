import Foundation
@testable import Pitstop
import SwiftData
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(90 * 86400)

@MainActor
@Suite("SwiftData track several")
struct SwiftDataTrackSeveralTests {
    @Test("REQ-MAINT-027: the starter's confirmed items survive a reopen as the owner's own policies")
    func starterPoliciesPersist() async throws {
        let url = URL.temporaryDirectory.appending(path: "pitstop-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
            }
        }
        let store = try SwiftDataCarMemoryStore(modelContainer: PersistenceContainer.make(storeURL: url))
        let model = TrackSeveralViewModel(store: store, operations: MaintenanceOperationID.catalog, now: { now })
        model.gearbox = .dualClutch
        model.toggle(.dsgService)
        model.toggle(.cabinFilter)
        model.continueToIntervals()
        model.setKilometers("60000", for: .dsgService)
        model.setKilometers("15000", for: .cabinFilter)
        model.setMonths("12", for: .cabinFilter)
        #expect(model.continueToReview())

        await model.apply()

        #expect(model.failedOperations.isEmpty && model.savedCount == 2)
        let reopened = try SwiftDataCarMemoryStore(modelContainer: PersistenceContainer.make(storeURL: url))
        #expect(try await Set(reopened.maintenancePolicies()) == [
            MaintenancePolicy(operationID: .dsgService, distanceIntervalKm: 60000, source: .userCustom),
            MaintenancePolicy(
                operationID: .cabinFilter,
                distanceIntervalKm: 15000,
                timeIntervalMonths: 12,
                source: .userCustom
            ),
        ])
        // The gearbox answer is not a car fact: the vehicle keeps only what it had.
        #expect(try await reopened.currentVehicle() == store.currentVehicle())
    }
}
