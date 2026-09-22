import Foundation
@testable import Pitstop
import SwiftData
import Testing

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let oil = PitQuestionFixtures.oilIntervalID

/// A store written by a container that knows only `schema`, as an older build wrote it.
private func legacyContainer(_ schema: any VersionedSchema.Type, url: URL) throws -> ModelContainer {
    let legacy = Schema(versionedSchema: schema)
    return try ModelContainer(for: legacy, configurations: ModelConfiguration(schema: legacy, url: url))
}

private struct SeededFacts {
    let vehicleID: VehicleID
    let reading: OdometerReading
}

/// Car memory an older build could hold: a named car, a reading, an owner policy, a completion, a note.
private func seedCarMemory(_ store: SwiftDataCarMemoryStore) async throws -> SeededFacts {
    let vehicleID = try await store.currentVehicle().id
    let reading = OdometerReading(vehicleID: vehicleID, value: 42000, recordedAt: now)
    let policy = MaintenancePolicy(operationID: .engineOilService, distanceIntervalKm: 10000, source: .userCustom)
    let commands: [DomainCommand] = [
        .recordVehicleFact(.init(vehicleID: vehicleID, fact: VehicleFact(field: .name, value: "Kestrel"))),
        .recordOdometerReading(.init(reading: reading)),
        .setMaintenancePolicy(.init(vehicleID: vehicleID, policy: policy)),
        .confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService, performedAt: now, odometerKm: 41000
        ))),
        .createNote(CreateNoteCommand(vehicleID: vehicleID, rawText: "before the migration")),
    ]
    for command in commands {
        try await store.execute(command, now: now)
    }
    return SeededFacts(vehicleID: vehicleID, reading: reading)
}

private func expectCarMemory(_ facts: SeededFacts, in store: SwiftDataCarMemoryStore) async throws {
    let vehicle = try await store.currentVehicle()
    #expect(vehicle.id == facts.vehicleID && vehicle.name == "Kestrel")
    #expect(try await store.odometerReadings() == [facts.reading])
    #expect(try await store.maintenancePolicies().map(\.operationID) == [.engineOilService])
    #expect(try await store.maintenanceCompletions().map(\.odometerKm) == [41000])
    #expect(try await store.notes().map(\.rawText) == ["before the migration"])
    #expect(try await store.plannedEvents().isEmpty)
}

/// After migration the new entity works and a planned date survives another reopen.
private func expectPlannedDatesWork(url: URL, vehicleID: VehicleID) async throws {
    let insurance = PlannedDatedEvent(
        vehicleID: vehicleID, kind: .insuranceExpiry, date: now.addingTimeInterval(90 * 86400), createdAt: now
    )
    do {
        let store = try SwiftDataCarMemoryStore(modelContainer: PersistenceContainer.make(storeURL: url))
        try await store.execute(.addPlannedEvent(.init(event: insurance)), now: now)
    }
    let reopened = try SwiftDataCarMemoryStore(modelContainer: PersistenceContainer.make(storeURL: url))
    #expect(try await reopened.plannedEvents() == [insurance])
}

@Suite("Schema V3 migration")
struct SchemaV3MigrationTests {
    @Test("ADR-0032: a version 2 store opens under version 3 with car memory and question state intact")
    func versionTwoStoreMigrates() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let facts: SeededFacts
        do {
            let container = try legacyContainer(PitstopSchemaV2.self, url: url)
            facts = try await seedCarMemory(SwiftDataCarMemoryStore(modelContainer: container))
            let questions = try SwiftDataPitQuestionStore(
                modelContainer: container,
                registry: PitQuestionFixtures.registry()
            )
            try await questions.execute(.asked(questionID: oil), now: now)
            try await questions.execute(.deferred(questionID: oil), now: now + 5)
        }

        let container = try PersistenceContainer.make(storeURL: url)
        try await expectCarMemory(facts, in: SwiftDataCarMemoryStore(modelContainer: container))
        let questions = try SwiftDataPitQuestionStore(
            modelContainer: container,
            registry: PitQuestionFixtures.registry()
        )
        #expect(try await questions.questionStates() == [
            PitQuestionState(questionID: oil, resolution: .deferred, lastAskedAt: now, resolvedAt: now + 5),
        ])
        try await expectPlannedDatesWork(url: url, vehicleID: facts.vehicleID)
    }

    @Test("ADR-0032: a version 1 store passes both stages and opens under version 3 with car memory intact")
    func versionOneStoreMigrates() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let facts: SeededFacts
        do {
            let container = try legacyContainer(PitstopSchemaV1.self, url: url)
            facts = try await seedCarMemory(SwiftDataCarMemoryStore(modelContainer: container))
        }

        let container = try PersistenceContainer.make(storeURL: url)
        try await expectCarMemory(facts, in: SwiftDataCarMemoryStore(modelContainer: container))
        let questions = try SwiftDataPitQuestionStore(
            modelContainer: container,
            registry: PitQuestionFixtures.registry()
        )
        #expect(try await questions.questionStates().isEmpty)
        try await expectPlannedDatesWork(url: url, vehicleID: facts.vehicleID)
    }

    @Test("ADR-0032: the migration plan chains V1 to V2 to V3 before any later version")
    func planChainsEveryVersion() {
        // A loop, not a key path: a key path on the existential metatype crashes the Swift 6.4 compiler.
        var versions: [Schema.Version] = []
        for schema in PitstopMigrationPlan.schemas {
            versions.append(schema.versionIdentifier)
        }
        let (one, two, three) = (Schema.Version(1, 0, 0), Schema.Version(2, 0, 0), Schema.Version(3, 0, 0))
        #expect(Array(versions.prefix(3)) == [one, two, three])
        // The first two stages are V1 to V2 and V2 to V3, in that order, whatever versions follow.
        var stages: [[Schema.Version]] = []
        for stage in PitstopMigrationPlan.stages {
            if case let .lightweight(from, to) = stage {
                stages.append([from.versionIdentifier, to.versionIdentifier])
            } else {
                stages.append([])
            }
        }
        #expect(Array(stages.prefix(2)) == [[one, two], [two, three]])
    }
}
