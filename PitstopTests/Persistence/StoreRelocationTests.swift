import Foundation
@testable import Pitstop
import SwiftData
import Testing

private let now = Date(timeIntervalSince1970: 1_800_000_000)

/// An app container and a group container under one temporary directory, removed after the test.
private struct Containers {
    let root = URL.temporaryDirectory.appending(path: "pitstop-move-\(UUID().uuidString)")

    var legacyStore: URL {
        root.appending(path: "app/Library/Application Support/Pitstop.store")
    }

    var groupStore: URL {
        StoreLocation.groupStoreURL(in: root.appending(path: "group"))
    }

    var marker: URL {
        StoreLocation.movedMarkerURL(for: groupStore)
    }

    init() throws {
        try FileManager.default.createDirectory(
            at: legacyStore.deletingLastPathComponent(), withIntermediateDirectories: true
        )
    }

    func relocation(files: any StoreFileOperations = FileManagerStoreFiles()) -> StoreRelocation {
        StoreRelocation(legacyStore: legacyStore, groupStore: groupStore, files: files)
    }

    func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func anyFileExists(of store: URL) -> Bool {
        StoreLocation.files(of: store).contains(where: exists)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

/// A store written by a container that knows only `schema`, as an older TestFlight build wrote it.
private func legacyStore(_ schema: any VersionedSchema.Type, url: URL) throws -> SwiftDataCarMemoryStore {
    let legacy = Schema(versionedSchema: schema)
    let container = try ModelContainer(for: legacy, configurations: ModelConfiguration(schema: legacy, url: url))
    return SwiftDataCarMemoryStore(modelContainer: container)
}

/// Fictional facts every shipped schema can hold: a reading, the owner's oil interval, a completion.
private func seedCarMemory(_ store: SwiftDataCarMemoryStore) async throws -> VehicleID {
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

/// A released container closes its SQLite files a moment later; wait until they stop changing, as they
/// have at launch, so the recorded identities describe the files the move sees.
private func settle(_ store: URL) async throws {
    let files = FileManagerStoreFiles()
    var previous = StoreLocation.files(of: store).map(files.identity(of:))
    for _ in 0 ..< 20 {
        try await Task.sleep(for: .milliseconds(100))
        let current = StoreLocation.files(of: store).map(files.identity(of:))
        if current == previous {
            return
        }
        previous = current
    }
}

private func expectCarMemory(at url: URL) async throws {
    let store = try TestStore.carMemory(url: url)
    #expect(try await store.odometerReadings().map(\.value) == [38800])
    #expect(try await store.maintenancePolicies().map(\.operationID) == [.engineOilService])
    #expect(try await store.maintenanceCompletions().map(\.odometerKm) == [30000])
}

@Suite("Store move into the App Group container")
struct StoreRelocationTests {
    @Test("REQ-WIDGET-003: a fresh install starts in the group container and marks it as the store")
    func freshInstall() async throws {
        let containers = try Containers()
        defer { containers.remove() }
        let (store, outcome) = containers.relocation().prepare()
        #expect(outcome == .freshInstall)
        #expect(store == containers.groupStore)
        #expect(containers.exists(containers.marker))
        #expect(!containers.anyFileExists(of: containers.legacyStore))
        // The app opens it as usual and the next launch changes nothing.
        let vehicle = try await TestStore.carMemory(url: store).currentVehicle()
        #expect(vehicle.isProvisional)
        #expect(containers.relocation().prepare() == (containers.groupStore, .alreadyMoved))
    }

    @Test("REQ-WIDGET-001: a version 2 store moves once, opens under version 4 and keeps its facts")
    func versionTwoStoreMoves() async throws {
        let containers = try Containers()
        defer { containers.remove() }
        _ = try await seedCarMemory(legacyStore(PitstopSchemaV2.self, url: containers.legacyStore))
        try await expectMoved(containers)
        try await expectCarMemory(at: containers.groupStore)
    }

    @Test("REQ-WIDGET-001: a version 3 store moves with its planned dates")
    func versionThreeStoreMoves() async throws {
        let containers = try Containers()
        defer { containers.remove() }
        let insurance: PlannedDatedEvent
        do {
            let store = try legacyStore(PitstopSchemaV3.self, url: containers.legacyStore)
            let vehicleID = try await seedCarMemory(store)
            insurance = PlannedDatedEvent(
                vehicleID: vehicleID, kind: .insuranceExpiry, date: now + 90 * 86400, createdAt: now
            )
            try await store.execute(.addPlannedEvent(.init(event: insurance)), now: now)
        }
        try await expectMoved(containers)
        try await expectCarMemory(at: containers.groupStore)
        #expect(try await TestStore.carMemory(url: containers.groupStore).plannedEvents() == [insurance])
    }

    @Test("REQ-WIDGET-001: a version 4 store moves with its dashboard readings")
    func versionFourStoreMoves() async throws {
        let containers = try Containers()
        defer { containers.remove() }
        let report: VehicleServiceReport
        do {
            let store = try TestStore.carMemory(url: containers.legacyStore)
            let vehicleID = try await seedCarMemory(store)
            report = VehicleServiceReport(
                vehicleID: vehicleID, operationID: .engineOilService, reportedAt: now, odometerKm: 38800,
                remainingDistance: 3200, distanceUnit: .kilometers, remainingDays: 45, source: .manualEntry
            )
            try await store.execute(.recordVehicleServiceReport(.init(report: report)), now: now)
        }
        try await expectMoved(containers)
        try await expectCarMemory(at: containers.groupStore)
        let reports = try await TestStore.carMemory(url: containers.groupStore).vehicleServiceReports()
        #expect(reports.map(\.remainingDistance) == [3200])
        #expect(reports.map(\.id) == [report.id])
    }

    @Test("REQ-WIDGET-002: a copy interrupted before the mark is discarded and the move runs again")
    func interruptedCopyIsRedone() async throws {
        let containers = try Containers()
        defer { containers.remove() }
        _ = try await seedCarMemory(TestStore.carMemory(url: containers.legacyStore))
        // What a crash half way through the copy leaves: a truncated file and no marker.
        try FileManager.default.createDirectory(
            at: containers.groupStore.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data("partial".utf8).write(to: containers.groupStore)
        try await expectMoved(containers)
        try await expectCarMemory(at: containers.groupStore)
    }

    @Test("REQ-WIDGET-002: an old store that changed after the move is kept as a dated backup, never deleted")
    func changedLeftoverIsBackedUp() async throws {
        let containers = try Containers()
        defer { containers.remove() }
        _ = try await seedCarMemory(TestStore.carMemory(url: containers.legacyStore))
        #expect(containers.relocation().prepare().outcome == .moved)
        // The group store gains a fact; then a downgraded build writes a new store at the old location.
        do {
            let store = try TestStore.carMemory(url: containers.groupStore)
            let vehicleID = try await store.currentVehicle().id
            try await store.execute(.setMaintenancePolicy(.init(vehicleID: vehicleID, policy: MaintenanceFixture.custom(
                .brakeFluid, months: 24
            ))), now: now)
        }
        _ = try await seedCarMemory(TestStore.carMemory(url: containers.legacyStore))
        try await settle(containers.legacyStore)

        var relocation = containers.relocation()
        relocation.now = { now }
        let (store, outcome) = relocation.prepare()
        let backup = URL(fileURLWithPath: containers.legacyStore.path + ".leftover-20270115-080000")
        #expect(outcome == .leftoverBackedUp(backup))
        #expect(store == containers.groupStore)
        #expect(!containers.anyFileExists(of: containers.legacyStore))
        // The downgraded build's facts are kept as they were, not merged.
        try await expectCarMemory(at: backup)
        let policies = try await TestStore.carMemory(url: containers.groupStore).maintenancePolicies()
        #expect(policies.map(\.operationID) == [.brakeFluid, .engineOilService])
    }

    @Test("REQ-WIDGET-002: a backup that cannot be completed puts every renamed file back")
    func failedBackupIsUndone() async throws {
        let containers = try Containers()
        defer { containers.remove() }
        #expect(containers.relocation().prepare().outcome == .freshInstall)
        // A downgraded build writes at the old location and keeps it open, so all three files exist.
        let writer = try TestStore.carMemory(url: containers.legacyStore)
        _ = try await seedCarMemory(writer)
        let present = StoreLocation.files(of: containers.legacyStore).filter(containers.exists)
        try #require(present.count == 3)

        let result = containers.relocation(files: FailingStoreFiles(failing: .moveOf(suffix: "-shm"))).prepare()
        #expect(result.outcome == .leftoverKept)
        #expect(StoreLocation.files(of: containers.legacyStore).filter(containers.exists) == present)
        let backups = try FileManager.default.contentsOfDirectory(
            atPath: containers.legacyStore.deletingLastPathComponent().path
        ).filter { $0.contains(".leftover-") }
        #expect(backups.isEmpty)
    }

    @Test("REQ-WIDGET-002: an old store that is exactly what was copied is deleted on the next launch")
    func unchangedLeftoverIsRemoved() async throws {
        let containers = try Containers()
        defer { containers.remove() }
        _ = try await seedCarMemory(TestStore.carMemory(url: containers.legacyStore))
        try await settle(containers.legacyStore)
        let oldDirectory = containers.legacyStore.deletingLastPathComponent()
        let stuck = containers.relocation(files: FailingStoreFiles(failing: .removeUnder(oldDirectory)))
        #expect(stuck.prepare().outcome == .moved)
        #expect(containers.exists(containers.legacyStore))

        #expect(containers.relocation().prepare() == (containers.groupStore, .leftoverRemoved))
        #expect(!containers.anyFileExists(of: containers.legacyStore))
        try await expectCarMemory(at: containers.groupStore)
    }

    @Test("REQ-WIDGET-002: a stale unmarked copy that cannot be deleted does not block the move")
    func undeletableStaleCopyDoesNotBlock() async throws {
        let containers = try Containers()
        defer { containers.remove() }
        _ = try await seedCarMemory(TestStore.carMemory(url: containers.legacyStore))
        let groupDirectory = containers.groupStore.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: groupDirectory, withIntermediateDirectories: true)
        for file in StoreLocation.files(of: containers.groupStore) {
            try Data("stale".utf8).write(to: file)
        }
        let relocation = containers.relocation(files: FailingStoreFiles(failing: .removeUnder(groupDirectory)))
        #expect(relocation.prepare().outcome == .moved)
        try await expectCarMemory(at: containers.groupStore)
    }

    @Test("REQ-WIDGET-003: after a move, a build without the App Group opens nothing durable")
    func missingGroupAfterMoveKeepsNothing() async throws {
        let containers = try Containers()
        defer { containers.remove() }
        _ = try await seedCarMemory(TestStore.carMemory(url: containers.legacyStore))
        #expect(containers.relocation().prepare().outcome == .moved)
        let unsigned = StoreRelocation(legacyStore: containers.legacyStore, groupStore: nil)
        let result = unsigned.prepare()
        #expect(result.store == nil && result.outcome == .groupUnavailableAfterMove)
        #expect(!containers.anyFileExists(of: containers.legacyStore))
    }

    @Test(
        "REQ-WIDGET-002: a failed copy keeps the old store in use, leaves no partial copy, and retries next launch",
        arguments: ["", "-wal", "-shm"]
    )
    func failedCopyKeepsOldStore(suffix: String) async throws {
        let containers = try Containers()
        defer { containers.remove() }
        // Keeping the writer open leaves all three SQLite files in place, so each copy can fail.
        var writer: SwiftDataCarMemoryStore? = try TestStore.carMemory(url: containers.legacyStore)
        _ = try await seedCarMemory(#require(writer))
        let files = StoreLocation.files(of: containers.legacyStore).filter(containers.exists)
        try #require(files.count == 3, "The seeded store left no -wal/-shm files to copy")

        let (store, outcome) = containers.relocation(files: FailingStoreFiles(failing: .copyOf(suffix: suffix)))
            .prepare()
        #expect(outcome == .keptLegacy(.copy))
        #expect(store == containers.legacyStore)
        #expect(!containers.anyFileExists(of: containers.groupStore))
        #expect(!containers.exists(containers.marker))
        #expect(StoreLocation.files(of: containers.legacyStore).filter(containers.exists) == files)
        try await expectCarMemory(at: containers.legacyStore)
        // At launch nothing has the old store open; release it before the retry, as a relaunch would.
        writer = nil
        #expect(containers.relocation().prepare().outcome == .moved)
        try await expectCarMemory(at: containers.groupStore)
    }

    @Test("REQ-WIDGET-002: a copy that does not open is discarded and the old store stays")
    func unreadableCopyKeepsOldStore() async throws {
        let containers = try Containers()
        defer { containers.remove() }
        _ = try await seedCarMemory(TestStore.carMemory(url: containers.legacyStore))
        var relocation = containers.relocation()
        relocation.verify = { _ in throw CocoaError(.fileReadCorruptFile) }
        #expect(relocation.prepare() == (containers.legacyStore, .keptLegacy(.verify)))
        #expect(!containers.anyFileExists(of: containers.groupStore))
        try await expectCarMemory(at: containers.legacyStore)
    }

    @Test("REQ-WIDGET-002: without the mark the move does not count and the old store stays")
    func failedMarkerKeepsOldStore() async throws {
        let containers = try Containers()
        defer { containers.remove() }
        _ = try await seedCarMemory(TestStore.carMemory(url: containers.legacyStore))
        let result = containers.relocation(files: FailingStoreFiles(failing: .marker)).prepare()
        #expect(result == (containers.legacyStore, .keptLegacy(.marker)))
        #expect(!containers.anyFileExists(of: containers.groupStore))
        try await expectCarMemory(at: containers.legacyStore)
    }

    @Test("REQ-WIDGET-003: without an App Group container the store stays where it is")
    func missingGroupKeepsOldLocation() throws {
        let containers = try Containers()
        defer { containers.remove() }
        let relocation = StoreRelocation(legacyStore: containers.legacyStore, groupStore: nil)
        #expect(relocation.prepare() == (containers.legacyStore, .groupUnavailable))
    }

    /// Not a signing check: the simulator resolves a group container regardless of entitlements. The
    /// entitlement is checked on the device and by the Xcode Cloud archive (DEV-WIDGET).
    @Test("REQ-WIDGET-003: the group identifier resolves to a container in the test host")
    func groupIdentifierResolves() {
        #expect(StoreLocation.groupContainerURL() != nil)
    }

    private func expectMoved(_ containers: Containers) async throws {
        let (store, outcome) = containers.relocation().prepare()
        #expect(outcome == .moved)
        #expect(store == containers.groupStore)
        #expect(containers.exists(containers.marker))
        #expect(!containers.anyFileExists(of: containers.legacyStore))
        #expect(containers.relocation().prepare() == (containers.groupStore, .alreadyMoved))
    }
}
