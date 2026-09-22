import Foundation
@testable import Pitstop
import SwiftData
import Testing

private let now = Date(timeIntervalSince1970: 1_800_000_000)

/// A store written by a container that knows only `schema`, as an older build wrote it.
private func legacyContainer(_ schema: any VersionedSchema.Type, url: URL) throws -> ModelContainer {
    let legacy = Schema(versionedSchema: schema)
    return try ModelContainer(for: legacy, configurations: ModelConfiguration(schema: legacy, url: url))
}

/// Fictional car memory an older build could hold: a reading, an owner policy, a completion.
private func seed(_ store: SwiftDataCarMemoryStore) async throws -> VehicleID {
    let vehicleID = try await store.currentVehicle().id
    let commands: [DomainCommand] = [
        .recordOdometerReading(.init(reading: OdometerReading(vehicleID: vehicleID, value: 38800, recordedAt: now))),
        .setMaintenancePolicy(.init(vehicleID: vehicleID, policy: MaintenanceFixture.custom(
            .engineOilService, km: 15000, months: 12
        ))),
        .confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService, performedAt: now - 200 * 86400, odometerKm: 30000
        ))),
    ]
    for command in commands {
        try await store.execute(command, now: now)
    }
    return vehicleID
}

private func dashboard(_ vehicleID: VehicleID, unit: DistanceUnit = .kilometers) -> VehicleServiceReport {
    VehicleServiceReport(
        vehicleID: vehicleID, operationID: .engineOilService, reportedAt: now, odometerKm: 38800,
        remainingDistance: 3200, distanceUnit: unit, remainingDays: 45, source: .manualEntry
    )
}

/// After migration the old facts are intact, the new entity works and a reading survives a reopen.
private func expectMigrated(url: URL, vehicleID: VehicleID) async throws {
    do {
        let store = try TestStore.carMemory(url: url)
        #expect(try await store.maintenancePolicies().map(\.operationID) == [.engineOilService])
        #expect(try await store.maintenanceCompletions().map(\.odometerKm) == [30000])
        #expect(try await store.vehicleServiceReports().isEmpty)
        try await store.execute(.recordVehicleServiceReport(.init(report: dashboard(vehicleID))), now: now)
    }
    let reopened = try await TestStore.carMemory(url: url).vehicleServiceReports()
    #expect(reopened.map(\.remainingDistance) == [3200])
    #expect(reopened.map(\.remainingDays) == [45])
    #expect(reopened.map(\.odometerKm) == [38800])
}

@Suite("Schema V4 migration")
struct SchemaV4MigrationTests {
    @Test("REQ-MAINT-030: a version 3 store opens under version 4 with car memory and planned dates intact")
    func versionThreeStoreMigrates() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let vehicleID: VehicleID
        let insurance: PlannedDatedEvent
        do {
            let store = try SwiftDataCarMemoryStore(modelContainer: legacyContainer(PitstopSchemaV3.self, url: url))
            vehicleID = try await seed(store)
            insurance = PlannedDatedEvent(
                vehicleID: vehicleID, kind: .insuranceExpiry, date: now + 90 * 86400, createdAt: now
            )
            try await store.execute(.addPlannedEvent(.init(event: insurance)), now: now)
        }
        #expect(try await TestStore.carMemory(url: url).plannedEvents() == [insurance])
        try await expectMigrated(url: url, vehicleID: vehicleID)
    }

    @Test("REQ-MAINT-030: a version 1 store passes every stage and opens under version 4")
    func versionOneStoreMigrates() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let vehicleID: VehicleID
        do {
            vehicleID = try await seed(SwiftDataCarMemoryStore(
                modelContainer: legacyContainer(PitstopSchemaV1.self, url: url)
            ))
        }
        try await expectMigrated(url: url, vehicleID: vehicleID)
    }

    @Test("REQ-MAINT-030: a version 2 store passes the remaining stages and opens under version 4")
    func versionTwoStoreMigrates() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let vehicleID: VehicleID
        do {
            vehicleID = try await seed(SwiftDataCarMemoryStore(
                modelContainer: legacyContainer(PitstopSchemaV2.self, url: url)
            ))
        }
        try await expectMigrated(url: url, vehicleID: vehicleID)
    }

    @Test("ADR-0035: the migration plan chains V1 to V4 with one lightweight stage per version")
    func planChainsEveryVersion() {
        // A loop, not a key path: a key path on the existential metatype crashes the Swift 6.4 compiler.
        var versions: [Schema.Version] = []
        for schema in PitstopMigrationPlan.schemas {
            versions.append(schema.versionIdentifier)
        }
        #expect(versions == [
            Schema.Version(1, 0, 0), Schema.Version(2, 0, 0), Schema.Version(3, 0, 0), Schema.Version(4, 0, 0),
        ])
        #expect(PitstopMigrationPlan.stages.count == 3)
    }
}

@Suite("Dashboard readings in SwiftData")
struct SwiftDataVehicleServiceReportTests {
    @Test("REQ-MAINT-037: a reading in miles round-trips as miles, never re-read as kilometres")
    func milesRoundTrip() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let vehicleID = try await TestStore.carMemory(url: url).currentVehicle().id
        let report = dashboard(vehicleID, unit: .miles)
        try await TestStore.carMemory(url: url).execute(.recordVehicleServiceReport(.init(report: report)), now: now)
        let stored = try await TestStore.carMemory(url: url).vehicleServiceReports()
        #expect(stored == [report])
        #expect(stored.first?.distanceUnit == .miles && stored.first?.remainingDistance == 3200)
    }

    @Test("REQ-MAINT-031: a new reading replaces the operation's previous one; delete removes it")
    func oneReadingPerOperationAndDelete() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let store = try TestStore.carMemory(url: url)
        let vehicleID = try await store.currentVehicle().id
        try await store.execute(.recordVehicleServiceReport(.init(report: dashboard(vehicleID))), now: now)
        let newer = VehicleServiceReport(
            vehicleID: vehicleID, operationID: .engineOilService, reportedAt: now + 60, remainingDays: 30
        )
        try await store.execute(.recordVehicleServiceReport(.init(report: newer)), now: now + 60)
        // Both are stored; the newer one is the one that counts, and the older is still a mileage fact.
        #expect(try await store.vehicleServiceReports().newestPerOperation[.engineOilService] == newer)
        #expect(try await store.vehicleServiceReports().count == 2)

        let removed = try await store.execute(
            .removeVehicleServiceReport(.init(vehicleID: vehicleID, operationID: .engineOilService)), now: now + 60
        )
        #expect(removed == .vehicleServiceReportRemoved(newer))
        #expect(try await store.vehicleServiceReports().isEmpty)
        await #expect(throws: CarMemoryStoreError.unknownVehicleServiceReport) {
            try await store.execute(
                .removeVehicleServiceReport(.init(vehicleID: vehicleID, operationID: .engineOilService)), now: now
            )
        }
    }

    @Test("REQ-MAINT-030: an invalid reading is rejected and nothing is stored")
    func invalidReadingSavesNothing() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let store = try TestStore.carMemory(url: url)
        let vehicleID = try await store.currentVehicle().id
        let withoutOdometer = VehicleServiceReport(
            vehicleID: vehicleID, operationID: .engineOilService, reportedAt: now, remainingDistance: 3200
        )
        await #expect(throws: CarMemoryStoreError.invalidCommand(.reportOdometerMissing)) {
            try await store.execute(.recordVehicleServiceReport(.init(report: withoutOdometer)), now: now)
        }
        #expect(try await store.vehicleServiceReports().isEmpty)
    }
}
