import Foundation
@testable import Pitstop
import SwiftData
import Testing

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let oil = PitQuestionFixtures.oilIntervalID

/// Fictional car memory an older build could hold, one fact of every entity its schema knows.
private struct LegacyFacts {
    let vehicleID = VehicleID()
    var reading: OdometerReading {
        OdometerReading(id: fixedID(1), vehicleID: vehicleID, value: 42000, recordedAt: now)
    }

    var policy: MaintenancePolicy {
        MaintenancePolicy(operationID: .engineOilService, distanceIntervalKm: 10000, source: .userCustom)
    }

    var completion: MaintenanceCompletion {
        MaintenanceCompletion(
            id: fixedID(2), vehicleID: vehicleID, operationID: .engineOilService, performedAt: now, odometerKm: 41000
        )
    }

    var note: Note {
        Note(id: fixedID(3), vehicleID: vehicleID, rawText: "before version 5", createdAt: now)
    }

    var planned: PlannedDatedEvent {
        PlannedDatedEvent(
            id: fixedID(4), vehicleID: vehicleID, kind: .insuranceExpiry, date: now + 90 * 86400, createdAt: now
        )
    }

    var report: VehicleServiceReport {
        VehicleServiceReport(
            id: fixedID(5), vehicleID: vehicleID, operationID: .engineOilService, reportedAt: now,
            odometerKm: 42000, remainingDistance: 3200, remainingDays: 45, source: .manualEntry
        )
    }

    private func fixedID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index)) ?? UUID()
    }
}

/// Writes the store with the record classes of `schema` only, as the build that shipped it did. Today's
/// store actor is never used here: its car record is V5's, which an older container does not know.
private func writeLegacyStore(_ schema: any VersionedSchema.Type, url: URL, facts: LegacyFacts) throws {
    let legacy = Schema(versionedSchema: schema)
    let container = try ModelContainer(for: legacy, configurations: ModelConfiguration(schema: legacy, url: url))
    let context = ModelContext(container)
    let car = PitstopSchemaV1.VehicleRecord(
        id: facts.vehicleID.rawValue, name: "Kestrel", isProvisional: false, createdAt: now
    )
    car.make = "Fictional"
    car.model = "Wagon"
    car.year = 2019
    context.insert(car)
    context.insert(PitstopSchemaV1.OdometerReadingRecord(facts.reading))
    context.insert(PitstopSchemaV1.MaintenancePolicyRecord(facts.policy, vehicleID: facts.vehicleID))
    context.insert(PitstopSchemaV1.MaintenanceCompletionRecord(facts.completion))
    context.insert(PitstopSchemaV1.NoteRecord(facts.note))
    let version = schema.versionIdentifier.major
    if version >= 2 {
        context.insert(PitstopSchemaV2.PitQuestionStateRecord(
            questionID: oil, resolution: "deferred", lastAskedAt: now, lastDismissedAt: nil, resolvedAt: nil
        ))
    }
    if version >= 3 {
        context.insert(PitstopSchemaV3.PlannedVehicleEventRecord(facts.planned))
    }
    if version >= 4 {
        context.insert(PitstopSchemaV4.VehicleServiceReportRecord(facts.report))
    }
    try context.save()
}

/// Every fact the older build wrote reads back unchanged, and the car has no profile yet.
private func expectIntact(_ facts: LegacyFacts, url: URL, version: Int) async throws {
    let container = try PersistenceContainer.make(storeURL: url)
    let store = SwiftDataCarMemoryStore(modelContainer: container)
    let car = try await store.currentVehicle()
    #expect(car.id == facts.vehicleID && car.name == "Kestrel" && !car.isProvisional)
    #expect(car.make == "Fictional" && car.model == "Wagon" && car.year == 2019)
    #expect(car.chosenBody == nil && car.body == .suv && car.photoID == nil)
    #expect(try await store.odometerReadings() == [facts.reading])
    #expect(try await store.maintenancePolicies() == [facts.policy])
    #expect(try await store.maintenanceCompletions() == [facts.completion])
    #expect(try await store.notes().map(\.rawText) == [facts.note.rawText])
    let questions = try ModelContext(container).fetch(FetchDescriptor<PitstopSchemaV2.PitQuestionStateRecord>())
    #expect(questions.map(\.questionID) == (version >= 2 ? [oil] : []))
    #expect(try await store.plannedEvents() == (version >= 3 ? [facts.planned] : []))
    #expect(try await store.vehicleServiceReports().map(\.id) == (version >= 4 ? [facts.report.id] : []))
}

/// After the migration the new columns work and survive a reopen.
private func expectProfileRoundTrips(url: URL, vehicleID: VehicleID) async throws {
    let photo = CarPhotoID()
    do {
        let store = try TestStore.carMemory(url: url)
        try await store.execute(.setCarBody(.init(vehicleID: vehicleID, body: .sedan)), now: now)
        try await store.execute(.setCarPhoto(.init(vehicleID: vehicleID, photoID: photo)), now: now)
    }
    let car = try await TestStore.carMemory(url: url).currentVehicle()
    #expect(car.chosenBody == .sedan && car.photoID == photo && car.name == "Kestrel")
}

@Suite("Schema V5 migration")
struct SchemaV5MigrationTests {
    @Test(
        "ADR-0040: every earlier store opens under version 5 with its data intact and the car without a profile",
        arguments: [1, 2, 3, 4]
    )
    func earlierStoreMigrates(version: Int) async throws {
        let schemas: [Int: any VersionedSchema.Type] = [
            1: PitstopSchemaV1.self, 2: PitstopSchemaV2.self, 3: PitstopSchemaV3.self, 4: PitstopSchemaV4.self,
        ]
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let facts = LegacyFacts()
        try writeLegacyStore(#require(schemas[version]), url: url, facts: facts)
        try await expectIntact(facts, url: url, version: version)
        try await expectProfileRoundTrips(url: url, vehicleID: facts.vehicleID)
    }

    @Test("REQ-BOARD-030: the chosen body and the photo id round-trip through the store and clear to none")
    func profileRoundTrips() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let vehicleID = try await TestStore.carMemory(url: url).currentVehicle().id
        let photo = CarPhotoID()
        do {
            let store = try TestStore.carMemory(url: url)
            let result = try await store.execute(.setCarBody(.init(vehicleID: vehicleID, body: .sedan)), now: now)
            #expect(try await result == .vehicleUpdated(store.currentVehicle()))
            try await store.execute(.setCarPhoto(.init(vehicleID: vehicleID, photoID: photo)), now: now)
        }
        let saved = try await TestStore.carMemory(url: url).currentVehicle()
        #expect(saved.chosenBody == .sedan && saved.body == .sedan && saved.photoID == photo)
        // A profile is not a vehicle fact: the first-launch car keeps its placeholder name.
        #expect(saved.isProvisional && saved.name == ProvisionalCarContext.defaultName)

        do {
            let store = try TestStore.carMemory(url: url)
            try await store.execute(.setCarBody(.init(vehicleID: vehicleID, body: nil)), now: now)
            try await store.execute(.setCarPhoto(.init(vehicleID: vehicleID, photoID: nil)), now: now)
        }
        let cleared = try await TestStore.carMemory(url: url).currentVehicle()
        #expect(cleared.chosenBody == nil && cleared.body == .suv && cleared.photoID == nil)
    }

    @Test("REQ-BOARD-033: a profile command for another car is rejected and stores no reference")
    func unknownVehicleStoresNothing() async throws {
        let store = try TestStore.carMemory()
        await #expect(throws: CarMemoryStoreError.unknownVehicle) {
            try await store.execute(.setCarPhoto(.init(vehicleID: VehicleID(), photoID: CarPhotoID())), now: now)
        }
        await #expect(throws: CarMemoryStoreError.unknownVehicle) {
            try await store.execute(.setCarBody(.init(vehicleID: VehicleID(), body: .sedan)), now: now)
        }
        let car = try await store.currentVehicle()
        #expect(car.photoID == nil && car.chosenBody == nil)
    }

    @Test("ADR-0040: a stored body this build does not know reads as no choice, so the car shows as SUV")
    func unknownStoredBodyReadsAsNoChoice() throws {
        let container = try PersistenceContainer.make(storeURL: nil)
        let context = ModelContext(container)
        let record = PitstopSchemaV5.VehicleRecord(id: UUID(), name: "Kestrel", isProvisional: false, createdAt: now)
        record.body = "hatchback"
        context.insert(record)
        try context.save()
        #expect(record.domain.chosenBody == nil && record.domain.body == .suv)
    }

    @Test("ADR-0040: the widget reader opens a version 5 store the app wrote")
    func widgetReadsVersionFive() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        do {
            let store = try TestStore.carMemory(url: url)
            let vehicleID = try await store.currentVehicle().id
            try await store.execute(.setCarBody(.init(vehicleID: vehicleID, body: .sedan)), now: now)
        }
        let readOnly = try PersistenceContainer.makeReadOnly(storeURL: url)
        #expect(readOnly.schema.entities.map(\.name).sorted()
            == Schema(versionedSchema: PitstopSchemaV5.self).entities.map(\.name).sorted())
        #expect(try NextServiceStoreReader.facts(at: url).hasVehicle)
    }

    @Test("ADR-0040: the migration plan chains V1 to V5 with one lightweight stage per version")
    func planChainsEveryVersion() {
        // A loop, not a key path: a key path on the existential metatype crashes the Swift 6.4 compiler.
        var versions: [Schema.Version] = []
        for schema in PitstopMigrationPlan.schemas {
            versions.append(schema.versionIdentifier)
        }
        #expect(versions == [
            Schema.Version(1, 0, 0), Schema.Version(2, 0, 0), Schema.Version(3, 0, 0), Schema.Version(4, 0, 0),
            Schema.Version(5, 0, 0),
        ])
        var stages: [[Schema.Version]] = []
        for stage in PitstopMigrationPlan.stages {
            if case let .lightweight(from, to) = stage {
                stages.append([from.versionIdentifier, to.versionIdentifier])
            } else {
                stages.append([])
            }
        }
        #expect(stages.last == [Schema.Version(4, 0, 0), Schema.Version(5, 0, 0)])
        #expect(stages.count == 4)
    }
}
