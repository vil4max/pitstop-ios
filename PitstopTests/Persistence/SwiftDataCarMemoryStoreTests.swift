import Foundation
@testable import Pitstop
import SwiftData
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(90 * 86400)

private func makeStore(url: URL? = nil) throws -> SwiftDataCarMemoryStore {
    try SwiftDataCarMemoryStore(modelContainer: PersistenceContainer.make(storeURL: url))
}

@Suite("SwiftData car memory store")
struct SwiftDataCarMemoryStoreTests {
    @Test("REQ-BOARD-003: first launch creates one provisional, editable car and no facts")
    func firstLaunchCreatesProvisionalCar() async throws {
        let store = try makeStore()

        let vehicle = try await store.currentVehicle()

        #expect(vehicle.isProvisional)
        #expect(vehicle.name == ProvisionalCarContext.defaultName)
        #expect(vehicle.make == nil && vehicle.model == nil && vehicle.year == nil && vehicle.vin == nil)
        #expect(try await store.currentVehicle().id == vehicle.id)
    }

    @Test("REQ-DOMAIN-003: the provisional car creates no odometer reading or maintenance baseline")
    func provisionalCarHasNoReadings() async throws {
        let store = try makeStore()
        _ = try await store.currentVehicle()

        #expect(try await store.odometerReadings().latest == nil)
        #expect(try await store.maintenanceCompletions().isEmpty)
        #expect(try await store.maintenancePolicies().isEmpty)
        #expect(try await store.historyEvents().isEmpty)
    }

    @Test("REQ-DOMAIN-001: the latest reading is projected from history, not stored on the vehicle")
    func latestReadingIsProjected() async throws {
        let store = try makeStore()
        let vehicleID = try await store.currentVehicle().id
        for (offset, value) in [(0.0, 84200.0), (60, 86000), (30, 85500)] {
            let reading = OdometerReading(
                vehicleID: vehicleID,
                value: value,
                recordedAt: DomainFixtures.Odometers.baseDate.addingTimeInterval(offset * 86400)
            )
            try await store.execute(.recordOdometerReading(RecordOdometerReadingCommand(reading: reading)), now: now)
        }

        let readings = try await store.odometerReadings()

        #expect(readings.map(\.value) == [86000, 85500, 84200])
        #expect(readings.latest?.value == 86000)
    }

    @Test("REQ-CAPTURE-011: a raw note without any classification survives a relaunch")
    func rawNoteSurvivesRelaunch() async throws {
        let url = URL.temporaryDirectory.appending(path: "pitstop-\(UUID().uuidString).store")
        defer { Self.removeStore(at: url) }
        let vehicleID: VehicleID
        do {
            let store = try makeStore(url: url)
            vehicleID = try await store.currentVehicle().id
            try await store.execute(
                .createNote(CreateNoteCommand(vehicleID: vehicleID, rawText: "Стук справа спереди на лежачих")),
                now: now
            )
        }

        let reopened = try makeStore(url: url)

        let notes = try await reopened.notes()
        #expect(notes.map(\.rawText) == ["Стук справа спереди на лежачих"])
        #expect(notes.first?.canonicalContexts.isEmpty == true)
        #expect(notes.first?.status == .active)
        #expect(try await reopened.currentVehicle().id == vehicleID)
    }

    @Test("REQ-CAPTURE-021: an invalid command is rejected and nothing is saved")
    func invalidCommandSavesNothing() async throws {
        let store = try makeStore()
        let vehicleID = try await store.currentVehicle().id
        let negative = OdometerReading(vehicleID: vehicleID, value: -10, recordedAt: now)

        await #expect(throws: CarMemoryStoreError.invalidCommand(.odometerOutOfRange)) {
            try await store.execute(.recordOdometerReading(RecordOdometerReadingCommand(reading: negative)), now: now)
        }
        await #expect(throws: CarMemoryStoreError.invalidCommand(.emptyNoteText)) {
            try await store.execute(.createNote(CreateNoteCommand(rawText: " ")), now: now)
        }

        #expect(try await store.odometerReadings().isEmpty)
        #expect(try await store.notes().isEmpty)
    }

    @Test("ADR-0007: a command for a vehicle the store does not own writes nothing, not even a provisional car")
    func foreignVehicleIsRejected() async throws {
        let url = URL.temporaryDirectory.appending(path: "pitstop-\(UUID().uuidString).store")
        defer { Self.removeStore(at: url) }
        let store = try makeStore(url: url)
        let foreignNote = CreateNoteCommand(vehicleID: DomainFixtures.Vehicles.secondaryID, rawText: "чужая машина")

        await #expect(throws: CarMemoryStoreError.unknownVehicle) {
            try await store.execute(.createNote(foreignNote), now: now)
        }
        await #expect(throws: CarMemoryStoreError.unknownVehicle) {
            try await store.execute(
                .recordOdometerReading(RecordOdometerReadingCommand(reading: DomainFixtures.Odometers.reading84k)),
                now: now
            )
        }

        let reopened = try makeStore(url: url)
        #expect(try await reopened.odometerReadings().isEmpty)
        #expect(try await reopened.notes().isEmpty)
        // The rejected commands created no car: the first read still makes the provisional one.
        #expect(try await reopened.currentVehicle().isProvisional)
    }

    @Test("REQ-BOARD-003: a confirmed fact edits the car and ends the provisional state")
    func vehicleFactEndsProvisionalState() async throws {
        let store = try makeStore()
        let vehicleID = try await store.currentVehicle().id

        let result = try await store.execute(
            .recordVehicleFact(RecordVehicleFactCommand(
                vehicleID: vehicleID,
                fact: VehicleFact(field: .name, value: " Arteon ")
            )),
            now: now
        )

        let vehicle = try await store.currentVehicle()
        #expect(result == .vehicleUpdated(vehicle))
        #expect(vehicle.name == "Arteon")
        #expect(!vehicle.isProvisional)
        #expect(vehicle.id == vehicleID)
    }

    @Test("REQ-DOMAIN-006: a custom policy becomes effective and the recommendation record stays unchanged")
    func customPolicyReplacesEffectivePolicy() async throws {
        let store = try makeStore()
        let vehicleID = try await store.currentVehicle().id
        for policy in [
            DomainFixtures.Maintenance.standardOilPolicy,
            DomainFixtures.Maintenance.brakeFluidPolicy,
            DomainFixtures.Maintenance.severeOilPolicy,
        ] {
            try await store.execute(
                .setMaintenancePolicy(SetMaintenancePolicyCommand(vehicleID: vehicleID, policy: policy)),
                now: now
            )
        }

        let policies = try await store.maintenancePolicies()

        #expect(Set(policies) == Set([
            DomainFixtures.Maintenance.standardOilPolicy,
            DomainFixtures.Maintenance.severeOilPolicy,
            DomainFixtures.Maintenance.brakeFluidPolicy,
        ]))
        #expect(policies.effective == [
            DomainFixtures.Maintenance.brakeFluidPolicy,
            DomainFixtures.Maintenance.severeOilPolicy,
        ])
    }

    @Test("ADR-0007: confirming a completion stores that completion and no history event")
    func completionIsStoredForConfirmedOperationOnly() async throws {
        let store = try makeStore()
        let vehicleID = try await store.currentVehicle().id
        let completion = MaintenanceCompletion(
            vehicleID: vehicleID,
            operationID: .engineOilService,
            performedAt: DomainFixtures.Odometers.baseDate,
            odometerKm: 84200
        )

        try await store.execute(
            .confirmMaintenanceCompletion(ConfirmMaintenanceCompletionCommand(completion: completion)),
            now: now
        )

        #expect(try await store.maintenanceCompletions() == [completion])
        #expect(try await store.historyEvents().isEmpty)
    }

    @Test("REQ-DOMAIN-015: saving a note about intended work creates no history event or completion")
    func noteCreatesNoHistory() async throws {
        let store = try makeStore()
        let vehicleID = try await store.currentVehicle().id

        try await store.execute(
            .createNote(CreateNoteCommand(
                vehicleID: vehicleID,
                rawText: "заменить дворники",
                canonicalContexts: [.service]
            )),
            now: now
        )

        #expect(try await store.historyEvents().isEmpty)
        #expect(try await store.maintenanceCompletions().isEmpty)
        #expect(try await store.notes().first?.canonicalContexts == [.service])
    }

    @Test("ADR-0007: events, money, and note contexts read back exactly from disk, newest first")
    func historyEventsRoundTrip() async throws {
        let url = URL.temporaryDirectory.appending(path: "pitstop-\(UUID().uuidString).store")
        defer { Self.removeStore(at: url) }
        let store = try makeStore(url: url)
        let vehicleID = try await store.currentVehicle().id
        let wash = HistoryEvent(
            vehicleID: vehicleID,
            kind: .carWash,
            date: DomainFixtures.Odometers.baseDate.addingTimeInterval(5 * 86400),
            odometerKm: 84400,
            amount: Decimal(string: "1200.50"),
            note: "Комплексная мойка"
        )
        let service = HistoryEvent(
            vehicleID: vehicleID,
            kind: .service,
            date: DomainFixtures.Odometers.baseDate,
            amount: 12500
        )

        try await store.execute(.recordExpense(RecordExpenseCommand(event: service)), now: now)
        try await store.execute(.recordVehicleEvent(RecordVehicleEventCommand(event: wash)), now: now)

        try await store.execute(
            .createNote(CreateNoteCommand(
                vehicleID: vehicleID,
                rawText: "омывайка",
                canonicalContexts: [.shopping, .carWash]
            )),
            now: now
        )

        let reopened = try makeStore(url: url)
        #expect(try await reopened.historyEvents() == [wash, service])
        #expect(try await reopened.notes().first?.canonicalContexts == [.shopping, .carWash])
    }

    @Test("REQ-CAPTURE-009: a failed save reports failure and the write never appears later")
    func failedSaveLeavesNothingBehind() async throws {
        let url = URL.temporaryDirectory.appending(path: "pitstop-\(UUID().uuidString).store")
        defer { Self.removeStore(at: url) }
        let store = try makeStore(url: url)
        let vehicleID = try await store.currentVehicle().id
        let rename = RecordVehicleFactCommand(vehicleID: vehicleID, fact: VehicleFact(field: .name, value: "Arteon"))

        await store.failNextSave()
        await #expect(throws: CarMemoryStoreError.storageFailure) {
            try await store.execute(.createNote(CreateNoteCommand(rawText: "потерянная")), now: now)
        }
        await store.failNextSave()
        await #expect(throws: CarMemoryStoreError.storageFailure) {
            try await store.execute(.recordVehicleFact(rename), now: now)
        }
        try await store.execute(.createNote(CreateNoteCommand(rawText: "сохранённая")), now: now)

        #expect(try await store.currentVehicle().name == ProvisionalCarContext.defaultName)
        let reopened = try makeStore(url: url)
        #expect(try await reopened.notes().map(\.rawText) == ["сохранённая"])
        #expect(try await reopened.currentVehicle().isProvisional)
    }

    @Test("ADR-0007: repeating a command with a known ID never rewrites the stored record")
    func duplicateIDIsRejected() async throws {
        let store = try makeStore()
        let vehicleID = try await store.currentVehicle().id
        let id = UUID()
        let first = OdometerReading(
            id: id,
            vehicleID: vehicleID,
            value: 84200,
            recordedAt: DomainFixtures.Odometers.baseDate
        )
        let second = OdometerReading(
            id: id,
            vehicleID: vehicleID,
            value: 10,
            recordedAt: DomainFixtures.Odometers.baseDate
        )

        try await store.execute(.recordOdometerReading(RecordOdometerReadingCommand(reading: first)), now: now)
        await #expect(throws: CarMemoryStoreError.duplicateRecord) {
            try await store.execute(.recordOdometerReading(RecordOdometerReadingCommand(reading: second)), now: now)
        }

        #expect(try await store.odometerReadings() == [first])
    }

    @Test("ADR-0007: two stores on one file converge on the same provisional car")
    func provisionalCarIsSharedAcrossStores() async throws {
        let url = URL.temporaryDirectory.appending(path: "pitstop-\(UUID().uuidString).store")
        defer { Self.removeStore(at: url) }
        let app = try makeStore(url: url)
        let systemExtension = try makeStore(url: url)

        let first = try await app.currentVehicle()
        let second = try await systemExtension.currentVehicle()

        #expect(first.id == second.id)
        #expect(first.id == Vehicle.provisionalID)
    }

    private static func removeStore(at url: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }
}

@Suite("SwiftData note updates")
struct SwiftDataNoteUpdateTests {
    @Test("REQ-CAPTURE-012: a corrected and archived note reads back from disk with its identity")
    func noteUpdateSurvivesRelaunch() async throws {
        let url = URL.temporaryDirectory.appending(path: "pitstop-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
            }
        }
        let store = try makeStore(url: url)
        guard case let .noteCreated(note) = try await store.execute(
            .createNote(CreateNoteCommand(rawText: "заменить дворники")),
            now: now
        ) else {
            Issue.record("expected a created note")
            return
        }

        try await store.execute(
            .updateNote(UpdateNoteCommand(noteID: note.id, rawText: "заменить задний дворник")),
            now: now
        )
        try await store.execute(.updateNote(UpdateNoteCommand(noteID: note.id, status: .archived)), now: now)

        let reopened = try await makeStore(url: url).notes()
        #expect(reopened.count == 1)
        #expect(reopened.first?.id == note.id)
        #expect(reopened.first?.rawText == "заменить задний дворник")
        #expect(reopened.first?.status == .archived)
        #expect(reopened.first?.createdAt == note.createdAt)
        // REQ-DOMAIN-013: archiving and correcting a note record no work and no event.
        #expect(try await store.historyEvents().isEmpty)
        #expect(try await store.maintenanceCompletions().isEmpty)
    }

    @Test("ADR-0007: updating a note that does not exist fails and writes nothing")
    func unknownNoteIsRejected() async throws {
        let store = try makeStore()
        await #expect(throws: CarMemoryStoreError.unknownNote) {
            try await store.execute(.updateNote(UpdateNoteCommand(noteID: UUID(), status: .archived)), now: now)
        }
        #expect(try await store.notes().isEmpty)
    }
}

@Suite("SwiftData event correction")
struct SwiftDataEventCorrectionTests {
    @Test("REQ-DOMAIN-016: a corrected event reads back from disk with the same identity")
    func correctionSurvivesRelaunch() async throws {
        let url = URL.temporaryDirectory.appending(path: "pitstop-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
            }
        }
        let store = try makeStore(url: url)
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

        #expect(try await makeStore(url: url).historyEvents() == [corrected])
    }

    @Test("ADR-0007: correcting an event that does not exist fails and writes nothing")
    func unknownEventIsRejected() async throws {
        let store = try makeStore()
        let vehicleID = try await store.currentVehicle().id
        let ghost = HistoryEvent(vehicleID: vehicleID, kind: .other, date: DomainFixtures.Odometers.baseDate)
        await #expect(throws: CarMemoryStoreError.unknownEvent) {
            try await store.execute(.correctVehicleEvent(CorrectVehicleEventCommand(event: ghost)), now: now)
        }
        #expect(try await store.historyEvents().isEmpty)
    }

    @Test("ADR-0007: a correction cannot move an event to another vehicle")
    func correctionCannotChangeVehicle() async throws {
        let store = try makeStore()
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
