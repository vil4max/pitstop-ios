import CryptoKit
import Foundation
@testable import Pitstop
import SwiftData
import Testing

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let vehicleID = MaintenanceFixture.vehicleID
private let gregorian = Calendar(identifier: .gregorian)

private func completion(
    _ operation: MaintenanceOperationID,
    daysAgo: Double,
    km: Int?,
    before date: Date = now
) -> MaintenanceCompletion {
    MaintenanceCompletion(
        vehicleID: vehicleID, operationID: operation, performedAt: date - daysAgo * 86400, odometerKm: km
    )
}

private func reading(_ kilometers: Double, daysAgo: Double = 0, before date: Date = now) -> OdometerReading {
    OdometerReading(vehicleID: vehicleID, value: kilometers, recordedAt: date - daysAgo * 86400)
}

private func facts(
    _ policies: [MaintenancePolicy],
    completions: [MaintenanceCompletion] = [],
    reports: [VehicleServiceReport] = [],
    reading: OdometerReading? = nil
) -> NextServiceFacts {
    NextServiceFacts(
        hasVehicle: true, policies: policies, completions: completions, reports: reports, latestReading: reading
    )
}

private func summary(_ content: NextServiceContent) throws -> NextServiceSummary {
    guard case let .operation(summary) = content else {
        Issue.record("Expected an operation, got \(content)")
        throw CancellationError()
    }
    return summary
}

@Suite("Next-service widget content")
struct NextServiceContentTests {
    @Test("REQ-WIDGET-006: with no car there is nothing to show but the calm empty state")
    func noCarIsEmpty() {
        #expect(NextServiceContent(facts: .noCar, now: now) == .empty)
    }

    @Test("REQ-WIDGET-006: a car with nothing tracked shows the empty state, not a placeholder metric")
    func nothingTrackedIsEmpty() {
        #expect(NextServiceContent(facts: facts([], reading: reading(38800)), now: now) == .empty)
    }

    @Test("REQ-WIDGET-004: one tracked operation shows its name, status word and the fact that decided it")
    func oneOperation() throws {
        let content = NextServiceContent(facts: facts(
            [MaintenanceFixture.custom(.engineOilService, km: 15000, months: 12)],
            completions: [completion(.engineOilService, daysAgo: 200, km: 30000)],
            reading: reading(38800)
        ), now: now)
        let shown = try summary(content)
        #expect(shown.operation == .engineOilService)
        #expect(shown.status == .upToDate && shown.word == .upToDate)
        #expect(shown.fact == .progress(.kilometersAhead(6200), block: nil))
    }

    @Test("REQ-WIDGET-004: the widget shows the operation Service lists first, with the same word and fact")
    @MainActor
    func mostUrgentMatchesService() async throws {
        let store = FakeCarMemoryStore(vehicle: DomainFixtures.Vehicles.standard)
        let commands: [DomainCommand] = [
            .recordOdometerReading(.init(reading: reading(38800))),
            // Approaching by distance: 1,000 of 15,000 km left.
            .setMaintenancePolicy(.init(vehicleID: vehicleID, policy: MaintenanceFixture.custom(
                .engineOilService, km: 15000
            ))),
            .confirmMaintenanceCompletion(.init(completion: completion(.engineOilService, daysAgo: 100, km: 24800))),
            // Due by date: 24 months have passed.
            .setMaintenancePolicy(.init(vehicleID: vehicleID, policy: MaintenanceFixture.custom(
                .brakeFluid, months: 24
            ))),
            .confirmMaintenanceCompletion(.init(completion: completion(.brakeFluid, daysAgo: 800, km: nil))),
            // Unknown: tracked, never done.
            .setMaintenancePolicy(.init(vehicleID: vehicleID, policy: MaintenanceFixture.custom(
                .cabinFilter, km: 20000
            ))),
        ]
        for command in commands {
            try await store.execute(command, now: now)
        }
        let model = TestViewModels.service(store, now: now)
        await model.load()
        let first = try #require(model.state.operations.first)

        let shown = try await summary(NextServiceContent(facts: NextServiceFacts(
            hasVehicle: true,
            policies: store.maintenancePolicies(),
            completions: store.maintenanceCompletions(),
            reports: store.vehicleServiceReports(),
            latestReading: store.odometerReadings().latest
        ), now: now))
        #expect(first.id == .brakeFluid)
        #expect(shown == NextServiceSummary(first))
        #expect(shown.word == .due)
    }

    @Test("REQ-WIDGET-005: a tracked operation without a baseline is unknown and says nothing is counted")
    func unknownOperation() throws {
        let shown = try summary(NextServiceContent(facts: facts(
            [MaintenanceFixture.custom(.cabinFilter, km: 20000)], reading: reading(38800)
        ), now: now))
        #expect(shown.status == .unknown && shown.word == .unknown)
        #expect(shown.fact == .noBaseline)
    }

    @Test("REQ-WIDGET-005: a status that rests on the date alone says so and names the missing distance")
    func partialOperation() throws {
        let shown = try summary(NextServiceContent(facts: facts(
            [MaintenanceFixture.custom(.engineOilService, km: 15000, months: 12)],
            completions: [completion(.engineOilService, daysAgo: 30, km: nil)],
            reading: reading(38800)
        ), now: now))
        #expect(shown.status == .upToDate && shown.word == .upToDateByDate)
        guard case let .progress(.daysLeft(days)?, block: .completionMileageMissing) = shown.fact else {
            Issue.record("Unexpected fact \(shown.fact)")
            return
        }
        #expect(days > 300)
    }

    @Test("ADR-0036: Service still says the partial state in its own words after the shared decision")
    func serviceWordingUnchanged() throws {
        let context = MaintenanceContext(now: now, latestReading: reading(38800))
        let state = try #require(MaintenanceEngine().states(
            policies: [MaintenanceFixture.custom(.engineOilService, km: 15000, months: 12)],
            completions: [completion(.engineOilService, daysAgo: 30, km: nil)],
            context: context
        ).first)
        let days = try #require(state.remainingDays)
        #expect(state.statusLabel == "service.status.upToDate.byDate")
        // `Text` values do not compare by their words, so the decision behind the line is compared.
        #expect(state.progressFact == .progress(.daysLeft(days), block: .completionMileageMissing))
    }
}

@Suite("Next-service widget refresh")
struct NextServiceScheduleTests {
    private func expectBoundary(_ facts: NextServiceFacts, change: Date) {
        let before = NextServiceContent(facts: facts, now: change - NextServiceSchedule.minimumDelay / 5)
        #expect(before == NextServiceContent(facts: facts, now: now))
        #expect(NextServiceContent(facts: facts, now: change) != NextServiceContent(facts: facts, now: now))
    }

    @Test("REQ-WIDGET-010: the widget looks again when the mileage goes stale, not on a fixed clock")
    func refreshWhenMileageGoesStale() throws {
        let observed = now - 80 * 86400
        let shown = facts(
            [MaintenanceFixture.custom(.engineOilService, km: 10000)],
            completions: [completion(.engineOilService, daysAgo: 80, km: 30000)],
            reading: reading(35000, daysAgo: 80)
        )
        let change = try #require(NextServiceSchedule.nextChange(facts: shown, after: now))
        let stale = observed + MaintenanceRules.mileageStaleAfter
        #expect(change >= stale && change <= stale + 60)
        expectBoundary(shown, change: change)
        let after = try summary(NextServiceContent(facts: shown, now: change))
        #expect(after.fact == .progress(nil, block: .mileageStale))
    }

    @Test("REQ-WIDGET-010: a day count refreshes on the day boundary of its own anchor")
    func refreshWhenTheDayCountChanges() throws {
        // Three hours off a whole day, so the next day boundary is hours away rather than right now.
        let done = now - 300 * 86400 - 3 * 3600
        let anchor = try #require(gregorian.date(byAdding: .month, value: 12, to: done))
        let shown = facts(
            [MaintenanceFixture.custom(.brakeFluid, months: 12)],
            completions: [MaintenanceCompletion(vehicleID: vehicleID, operationID: .brakeFluid, performedAt: done)]
        )
        let days = try #require({ () -> Int? in
            guard case let .operation(summary) = NextServiceContent(facts: shown, now: now),
                  case let .progress(.daysLeft(days)?, _) = summary.fact else { return nil }
            return days
        }())
        let expected = anchor - Double(days) * 86400
        let change = try #require(NextServiceSchedule.nextChange(facts: shown, after: now))
        #expect(change >= expected && change <= expected + 60)
        expectBoundary(shown, change: change)
    }

    @Test("REQ-WIDGET-010: an approaching date anchor turns due at the anchor itself")
    func refreshWhenDue() throws {
        let done = now - 400 * 86400
        let anchor = try #require(gregorian.date(byAdding: .month, value: 12, to: done))
        // Half a day before the anchor the count already reads "almost", so the next change is due.
        let shownAt = anchor - 43200
        let shown = facts(
            [MaintenanceFixture.custom(.brakeFluid, months: 12)],
            completions: [MaintenanceCompletion(vehicleID: vehicleID, operationID: .brakeFluid, performedAt: done)]
        )
        let before = try summary(NextServiceContent(facts: shown, now: shownAt))
        #expect(before.word == .approaching && before.fact == .progress(.almost, block: nil))
        let change = try #require(NextServiceSchedule.nextChange(facts: shown, after: shownAt))
        #expect(change >= anchor && change <= anchor + 60)
        #expect(try summary(NextServiceContent(facts: shown, now: change)).word == .due)
    }

    @Test("REQ-WIDGET-010: content that time cannot change asks for no refresh")
    func noTimeBasedChange() {
        #expect(NextServiceSchedule.nextChange(facts: .noCar, after: now) == nil)
        let unknown = facts([MaintenanceFixture.custom(.cabinFilter, km: 20000)])
        #expect(NextServiceSchedule.nextChange(facts: unknown, after: now) == nil)
    }

    @Test("REQ-WIDGET-010: a change due within minutes is scheduled no sooner than WidgetKit allows")
    func refreshKeepsTheMinimumDelay() throws {
        let done = now - 300 * 86400
        let anchor = try #require(gregorian.date(byAdding: .month, value: 12, to: done))
        let shownAt = anchor - (30 * 86400 + 100)
        let shown = facts(
            [MaintenanceFixture.custom(.brakeFluid, months: 12)],
            completions: [MaintenanceCompletion(vehicleID: vehicleID, operationID: .brakeFluid, performedAt: done)]
        )
        let change = try #require(NextServiceSchedule.nextChange(facts: shown, after: shownAt))
        #expect(change == shownAt + NextServiceSchedule.minimumDelay)
    }

    @Test("REQ-WIDGET-006: an unreadable store shows the unavailable state and is tried again later")
    func unreadableStoreRetries() {
        let plan = NextServiceTimelinePlan(now: now) { throw NextServiceStoreReader.ReadError.storeUnavailable }
        #expect(plan.content == .unavailable)
        #expect(plan.refreshDate == now + NextServiceTimelinePlan.retryAfterUnavailable)
    }

    @Test("REQ-WIDGET-006: before the app has a store to read the widget is calm and waits for the app")
    func noStoreYetIsEmpty() {
        let plan = NextServiceTimelinePlan(now: now) { nil }
        #expect(plan == NextServiceTimelinePlan(now: now) { .noCar })
        #expect(plan.content == .empty && plan.refreshDate == nil)
    }
}

/// Fingerprints of the database and its write-ahead log: a read-only reader must leave both byte for byte.
/// `-shm` is left out: it is SQLite's shared-memory index, which every reader, read-only or not, updates
/// with its read marks and which holds no data. A file that vanishes while it is hashed reads as absent.
private func fingerprint(of store: URL) -> [String: String] {
    var result: [String: String] = [:]
    for file in StoreLocation.files(of: store) where !file.path.hasSuffix("-shm") {
        guard let data = try? Data(contentsOf: file) else { continue }
        result[file.lastPathComponent] = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    return result
}

/// A container closes its SQLite files asynchronously after release; wait until the files stop changing,
/// so the comparison sees only what the reader did.
private func settledFingerprint(of store: URL) async throws -> [String: String] {
    var previous = fingerprint(of: store)
    for _ in 0 ..< 20 {
        try await Task.sleep(for: .milliseconds(100))
        let current = fingerprint(of: store)
        if current == previous {
            return current
        }
        previous = current
    }
    return previous
}

@Suite("Next-service widget store access")
struct NextServiceStoreReaderTests {
    private func seeded(at url: URL) async throws -> SwiftDataCarMemoryStore {
        let store = try TestStore.carMemory(url: url)
        let id = try await store.currentVehicle().id
        let commands: [DomainCommand] = [
            .recordOdometerReading(.init(reading: OdometerReading(vehicleID: id, value: 38800, recordedAt: now))),
            .setMaintenancePolicy(.init(vehicleID: id, policy: MaintenanceFixture.custom(
                .engineOilService, km: 15000, months: 12
            ))),
            .confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
                vehicleID: id, operationID: .engineOilService, performedAt: now - 200 * 86400, odometerKm: 30000
            ))),
            .createNote(.init(vehicleID: id, rawText: "Fictional note the widget must never read")),
            .recordVehicleServiceReport(.init(report: VehicleServiceReport(
                vehicleID: id, operationID: .engineOilService, reportedAt: now, odometerKm: 38800,
                remainingDistance: 3200, distanceUnit: .kilometers, remainingDays: 45, source: .manualEntry
            ))),
            .recordVehicleServiceReport(.init(report: VehicleServiceReport(
                vehicleID: id, operationID: .brakeFluid, reportedAt: now, remainingDays: 90
            ))),
        ]
        for command in commands {
            try await store.execute(command, now: now)
        }
        return store
    }

    @Test("REQ-WIDGET-008: the reader sees exactly the maintenance facts Service reads and changes no data byte")
    func readsWhatServiceReads() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        do {
            _ = try await seeded(at: url)
        }
        let before = try await settledFingerprint(of: url)
        let read = try NextServiceStoreReader.facts(at: url)
        let after = try await settledFingerprint(of: url)
        #expect(after == before)

        let store = try TestStore.carMemory(url: url)
        #expect(read.hasVehicle)
        #expect(try await read.policies == store.maintenancePolicies())
        #expect(try await Set(read.completions) == Set(store.maintenanceCompletions()))
        #expect(read.reports.count == 2)
        #expect(try await Set(read.reports) == Set(store.vehicleServiceReports()))
        #expect(try await read.latestReading == store.odometerReadings().latest)
    }

    @Test("REQ-WIDGET-008: the widget reads while the app holds the store open and sees saved facts")
    func readsBesideTheApp() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let app = try await seeded(at: url)
        #expect(try NextServiceStoreReader.facts(at: url).policies.map(\.operationID) == [.engineOilService])
        let id = try await app.currentVehicle().id
        try await app.execute(.setMaintenancePolicy(.init(vehicleID: id, policy: MaintenanceFixture.custom(
            .brakeFluid, months: 24
        ))), now: now)
        let policies = try NextServiceStoreReader.facts(at: url).policies.map(\.operationID)
        #expect(policies == [.brakeFluid, .engineOilService])
    }

    @Test("REQ-WIDGET-008: a store of an older schema is not migrated by the widget; it stays byte for byte")
    func olderStoreIsNeverMigrated() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        do {
            let writer = try LegacyStoreWriter(PitstopSchemaV3.self, url: url)
            writer.car()
            try writer.save()
        }
        let before = try await settledFingerprint(of: url)
        #expect(throws: NextServiceStoreReader.ReadError.storeUnavailable) {
            try NextServiceStoreReader.facts(at: url)
        }
        let after = try await settledFingerprint(of: url)
        #expect(after == before)
    }

    @Test("REQ-WIDGET-008: a store without the move marker is not read, so a copy in progress is never opened")
    func unmarkedStoreIsNotReadable() throws {
        let directory = URL.temporaryDirectory.appending(path: "pitstop-read-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = directory.appending(path: StoreLocation.storeFileName)
        try Data("partial".utf8).write(to: store)
        #expect(StoreLocation.readableStore(at: store) == nil)
        try Data().write(to: StoreLocation.movedMarkerURL(for: store))
        #expect(StoreLocation.readableStore(at: store) == store)
    }
}
