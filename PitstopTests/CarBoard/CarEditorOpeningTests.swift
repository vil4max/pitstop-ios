import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate

/// The in-memory store, except that reading the odometer can fail while commands still save, as when a read
/// hits a locked store that a write then gets through.
private actor ReadingReadFailingStore: CarMemoryStore {
    let base: FakeCarMemoryStore
    private var failsReadingReads = false

    init(base: FakeCarMemoryStore) {
        self.base = base
    }

    func failReadingReads() {
        failsReadingReads = true
    }

    func currentVehicle() async throws(CarMemoryStoreError) -> Vehicle {
        try await base.currentVehicle()
    }

    func odometerReadings() async throws(CarMemoryStoreError) -> [OdometerReading] {
        guard !failsReadingReads else { throw .storageFailure }
        return try await base.odometerReadings()
    }

    func notes() async throws(CarMemoryStoreError) -> [Note] {
        try await base.notes()
    }

    func historyEvents() async throws(CarMemoryStoreError) -> [HistoryEvent] {
        try await base.historyEvents()
    }

    func maintenancePolicies() async throws(CarMemoryStoreError) -> [MaintenancePolicy] {
        try await base.maintenancePolicies()
    }

    func maintenanceCompletions() async throws(CarMemoryStoreError) -> [MaintenanceCompletion] {
        try await base.maintenanceCompletions()
    }

    func plannedEvents() async throws(CarMemoryStoreError) -> [PlannedDatedEvent] {
        try await base.plannedEvents()
    }

    func vehicleServiceReports() async throws(CarMemoryStoreError) -> [VehicleServiceReport] {
        try await base.vehicleServiceReports()
    }

    func execute(_ command: DomainCommand, now: Date) async throws(CarMemoryStoreError) -> CommandResult {
        try await base.execute(command, now: now)
    }
}

/// Pit opens inside the car editor sheet (REQ-PIT-026), and a capture closing over the sheet reloads the board.
/// The editor then saves only what the owner changed since it opened.
@MainActor
@Suite("Car editor saves over what Pit recorded")
struct CarEditorOpeningTests {
    /// A board over Kestrel at 47 560 km, read `readingAge` before `now`, with the car editor opened over it.
    private static func boardWithOpenEditor(
        readingAge: TimeInterval
    ) async throws -> (FakeCarMemoryStore, CarBoardViewModel, CarEditorOpening) {
        let store = FakeCarMemoryStore(vehicle: Vehicle(id: Vehicle.provisionalID, name: "Kestrel"))
        let vehicleID = try await store.currentVehicle().id
        let reading = OdometerReading(
            vehicleID: vehicleID, value: 47560, recordedAt: now.addingTimeInterval(-readingAge)
        )
        _ = try await store.execute(.recordOdometerReading(.init(reading: reading)), now: now)
        let model = TestViewModels.carBoard(store, now: now)
        await model.load()
        #expect(model.state.mileage == .kilometers(47560))
        return (store, model, model.editorOpening)
    }

    /// Pit in the editor sheet records a reading, and the capture closing over the sheet reloads the board.
    private static func pitRecords(
        _ kilometers: Double, in store: FakeCarMemoryStore, board: CarBoardViewModel
    ) async throws {
        let vehicleID = try await store.currentVehicle().id
        let reading = OdometerReading(vehicleID: vehicleID, value: kilometers, recordedAt: now)
        _ = try await store.execute(.recordOdometerReading(.init(reading: reading)), now: now)
        await board.load()
    }

    @Test(
        "REQ-PIT-026, REQ-BOARD-026: a mileage Pit records while the car editor is open survives a body-only save",
        arguments: [86400.0, 100 * 86400.0]
    )
    func pitMileageSurvivesBodyOnlySave(readingAge: TimeInterval) async throws {
        let (store, model, opening) = try await Self.boardWithOpenEditor(readingAge: readingAge)
        let draft = CarEditorDraft(opening: opening)
        try await Self.pitRecords(48200, in: store, board: model)
        #expect(model.state.mileage == .kilometers(48200))

        #expect(await model.saveCar(
            name: draft.name, odometerText: draft.odometer, body: .sedan, photo: draft.photo, opening: opening
        ))

        #expect(await store.readings.map(\.valueInKilometers) == [47560, 48200], "the untouched mileage was recorded")
        #expect(model.state.mileage == .kilometers(48200))
        #expect(await store.vehicle.chosenBody == .sedan)
    }

    @Test("REQ-PIT-026: a name Pit records while the car editor is open is not put back by an untouched name")
    func pitNameSurvivesSave() async throws {
        let (store, model, opening) = try await Self.boardWithOpenEditor(readingAge: 86400)
        let draft = CarEditorDraft(opening: opening)
        let vehicleID = try await store.currentVehicle().id
        let fact = VehicleFact(field: .name, value: "Heron")
        _ = try await store.execute(.recordVehicleFact(.init(vehicleID: vehicleID, fact: fact)), now: now)
        await model.load()
        #expect(model.state.car.name == "Heron")

        #expect(await model.saveCar(
            name: draft.name, odometerText: draft.odometer, body: .sedan, photo: draft.photo, opening: opening
        ))

        #expect(await store.vehicle.name == "Heron")
        #expect(model.state.car.name == "Heron")
    }

    @Test("REQ-PIT-026, REQ-BOARD-026: a mileage the owner edits is saved even after Pit recorded one")
    func editedMileageIsSavedAfterPit() async throws {
        let (store, model, opening) = try await Self.boardWithOpenEditor(readingAge: 86400)
        try await Self.pitRecords(48200, in: store, board: model)

        #expect(await model.saveCar(name: "Kestrel", odometerText: "48500", opening: opening))

        #expect(await store.readings.map(\.valueInKilometers) == [47560, 48200, 48500])
        #expect(model.state.mileage == .kilometers(48500))
    }

    @Test("REQ-BOARD-026: the same number over a stale mileage is recorded when nothing newer arrived in the editor")
    func sameNumberOverStaleMileageIsRecordedFromTheEditor() async throws {
        let (store, model, opening) = try await Self.boardWithOpenEditor(readingAge: 100 * 86400)
        let draft = CarEditorDraft(opening: opening)

        #expect(await model.saveCar(
            name: draft.name, odometerText: draft.odometer, body: draft.bodyChange, photo: draft.photo, opening: opening
        ))

        let readings = await store.readings
        #expect(readings.map(\.valueInKilometers) == [47560, 47560])
        #expect(readings.last?.recordedAt == now)
        #expect(model.state.mileageRecency == .today)
    }

    // MARK: The board has not caught up with Pit

    /// Pit records 48 200 km in the store, and the board's reload after the capture does not show it.
    private static func pitRecordsUnseen(_ kilometers: Double, in store: FakeCarMemoryStore) async throws {
        let vehicleID = try await store.currentVehicle().id
        let reading = OdometerReading(vehicleID: vehicleID, value: kilometers, recordedAt: now)
        _ = try await store.execute(.recordOdometerReading(.init(reading: reading)), now: now)
    }

    @Test("REQ-BOARD-026, REQ-PIT-026: after Pit's capture, a failed board reload does not let the stale mileage back")
    func failedReloadKeepsPitMileage() async throws {
        let (store, model, opening) = try await Self.boardWithOpenEditor(readingAge: 100 * 86400)
        let draft = CarEditorDraft(opening: opening)
        try await Self.pitRecordsUnseen(48200, in: store)
        await store.failEverything()
        await model.load()
        #expect(model.state.isLoadFailed)
        #expect(model.state.mileage == .kilometers(47560), "the failed reload keeps the board's cache")
        await store.recover()

        #expect(await model.saveCar(
            name: draft.name, odometerText: draft.odometer, body: .sedan, photo: draft.photo, opening: opening
        ))

        #expect(await store.readings.map(\.valueInKilometers) == [47560, 48200], "the untouched mileage was recorded")
        #expect(model.state.mileage == .kilometers(48200))
        #expect(await store.vehicle.chosenBody == .sedan)
    }

    @Test("REQ-BOARD-026, REQ-PIT-026: saving before the board reloads after Pit's capture keeps Pit's mileage")
    func saveBeforeReloadKeepsPitMileage() async throws {
        let (store, model, opening) = try await Self.boardWithOpenEditor(readingAge: 100 * 86400)
        let draft = CarEditorDraft(opening: opening)
        try await Self.pitRecordsUnseen(48200, in: store)

        #expect(await model.saveCar(
            name: draft.name, odometerText: draft.odometer, body: .sedan, photo: draft.photo, opening: opening
        ))

        #expect(await store.readings.map(\.valueInKilometers) == [47560, 48200], "the untouched mileage was recorded")
        #expect(model.state.mileage == .kilometers(48200))
        #expect(await store.vehicle.chosenBody == .sedan)
    }

    @Test("REQ-BOARD-026: when the store cannot be read at save, nothing untouched is written and the body is saved")
    func unreadableStoreWritesNothingUntouched() async throws {
        let base = FakeCarMemoryStore(vehicle: Vehicle(id: Vehicle.provisionalID, name: "Kestrel"))
        let vehicleID = try await base.currentVehicle().id
        let reading = OdometerReading(
            vehicleID: vehicleID, value: 47560, recordedAt: now.addingTimeInterval(-100 * 86400)
        )
        _ = try await base.execute(.recordOdometerReading(.init(reading: reading)), now: now)
        let store = ReadingReadFailingStore(base: base)
        let model = CarBoardViewModel(store: store, now: { now })
        await model.load()
        let draft = CarEditorDraft(opening: model.editorOpening)
        await store.failReadingReads()

        #expect(await model.saveCar(
            name: draft.name, odometerText: draft.odometer, body: .sedan, photo: draft.photo, opening: draft.opening
        ))

        #expect(await base.readings.map(\.valueInKilometers) == [47560], "an untouched mileage was recorded unread")
        #expect(await base.vehicle.chosenBody == .sedan)
        #expect(await base.vehicle.name == "Kestrel")
    }
}
