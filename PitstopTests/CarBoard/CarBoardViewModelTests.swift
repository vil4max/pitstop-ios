import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = now

    var date: Date {
        lock.withLock { current }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { current += interval }
    }
}

@MainActor
@Suite("Car Board view model")
struct CarBoardViewModelTests {
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    @Test("REQ-BOARD-001: Car Board has a usable state before and after the first load, with no setup step")
    func firstLaunchNeedsNoSetup() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.carBoard(store, now: now)
        #expect(model.state.car == .firstLaunch)

        await model.load()

        #expect(model.state.car.name == ProvisionalCarContext.defaultName)
        #expect(model.state.car.isProvisional)
        #expect(model.state.failure == nil)
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-GRAMMAR-004, REQ-BOARD-018: a first-launch board shows no placeholder metric, only sparse lines")
    func firstLaunchBoardHasNoPlaceholderMetric() async throws {
        let model = TestViewModels.carBoard(FakeCarMemoryStore(), now: now)
        await model.load()
        let state = model.state

        #expect(state.mileage == .unknown, "a label, never 0 km (REQ-BOARD-004)")
        #expect(state.mileageRecency == nil, "no observation, so no age")
        #expect(state.car.isProvisional, "the one useful action is naming the car")
        let road = try #require(state.road)
        #expect(road.isCompletelyEmpty)
        for kind in CarBoardTileKind.allCases {
            let tile = CarBoardTileContent(
                kind: kind, notes: state.notes, history: state.history, service: state.service, road: state.road
            )
            #expect(tile.primary == .sparseHeadline(kind))
            #expect(tile.secondary == .sparseDetail(kind))
            #expect(tile.status == nil, "no state exists, so no chip")
            #expect(tile.roadSlots.isEmpty, "no milestone is invented")
        }
    }

    @Test("REQ-BOARD-002: the provisional car shows its display name and no vehicle facts")
    func provisionalCarHasNoFacts() async {
        let model = TestViewModels.carBoard(FakeCarMemoryStore(), now: now)
        await model.load()
        #expect(model.state.car.make == nil && model.state.car.model == nil && model.state.car.year == nil)
        #expect(model.state.mileage == .unknown)
    }

    @Test("REQ-BOARD-004: a blank mileage field records no reading and mileage stays unknown")
    func blankMileageRecordsNothing() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.carBoard(store, now: now)
        await model.load()

        let saved = await model.saveCar(name: "Kestrel", odometerText: "  ")

        #expect(saved)
        #expect(model.state.mileage == .unknown)
        #expect(await store.readings.isEmpty)
        #expect(model.state.car.name == "Kestrel")
        #expect(!model.state.car.isProvisional)
    }

    @Test("REQ-BOARD-005: a supplied zero reading is recorded and shown as 0 km")
    func zeroReadingIsRecorded() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.carBoard(store, now: now)
        await model.load()

        #expect(await model.saveCar(name: ProvisionalCarContext.defaultName, odometerText: "0"))

        #expect(model.state.mileage == .kilometers(0))
        #expect(await store.readings.map(\.value) == [0])
        #expect(await store.readings.first?.source == .manualEntry)
        // Supplying mileage alone is not a vehicle fact, so the name placeholder stays provisional.
        #expect(model.state.car.isProvisional)
    }

    @Test("REQ-BOARD-026: a completion saved with its mileage, newer than any reading, is the header mileage")
    func completionMileageDrivesHeader() async throws {
        let store = FakeCarMemoryStore()
        let vehicleID = try await store.currentVehicle().id
        let reading = OdometerReading(
            vehicleID: vehicleID,
            value: 80000,
            recordedAt: now.addingTimeInterval(-20 * 86400)
        )
        _ = try await store.execute(.recordOdometerReading(.init(reading: reading)), now: now)
        let completion = MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService,
            performedAt: now.addingTimeInterval(-2 * 86400), odometerKm: 84200
        )
        _ = try await store.execute(.confirmMaintenanceCompletion(.init(completion: completion)), now: now)
        let model = TestViewModels.carBoard(store, now: now)

        await model.load()

        #expect(model.state.mileage == .kilometers(84200))
        #expect(model.state.car.odometerKm == 84200)
    }

    @Test("REQ-BOARD-026: saving the same number over a stale mileage records a fresh reading")
    func sameNumberOverStaleMileageIsRecorded() async throws {
        let store = FakeCarMemoryStore()
        let vehicleID = try await store.currentVehicle().id
        let completion = MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService,
            performedAt: now.addingTimeInterval(-100 * 86400), odometerKm: 84200
        )
        _ = try await store.execute(.confirmMaintenanceCompletion(.init(completion: completion)), now: now)
        let model = TestViewModels.carBoard(store, now: now)
        await model.load()
        #expect(model.state.mileage == .kilometers(84200))

        #expect(await model.saveCar(name: "", odometerText: "84200"))

        #expect(await store.readings.map(\.valueInKilometers) == [84200])
    }

    @Test("REQ-BOARD-027: the hero shows the age of the newest reading, from the reading's own date")
    func recencyFollowsReadingDate() async throws {
        let store = FakeCarMemoryStore()
        let vehicleID = try await store.currentVehicle().id
        let reading = OdometerReading(
            vehicleID: vehicleID,
            value: 47560,
            recordedAt: now.addingTimeInterval(-9 * 86400)
        )
        _ = try await store.execute(.recordOdometerReading(.init(reading: reading)), now: now)
        let model = CarBoardViewModel(store: store, now: { now }, calendar: Self.utc)

        await model.load()

        #expect(model.state.mileage == .kilometers(47560))
        #expect(model.state.mileageRecency == .days(9))
    }

    @Test("REQ-BOARD-027: a completion saved with its mileage dates the mileage with its own date")
    func recencyFollowsCompletionDate() async throws {
        let store = FakeCarMemoryStore()
        let vehicleID = try await store.currentVehicle().id
        let reading = OdometerReading(
            vehicleID: vehicleID,
            value: 80000,
            recordedAt: now.addingTimeInterval(-40 * 86400)
        )
        _ = try await store.execute(.recordOdometerReading(.init(reading: reading)), now: now)
        let withMileage = MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService,
            performedAt: now.addingTimeInterval(-3 * 86400), odometerKm: 84200
        )
        _ = try await store.execute(.confirmMaintenanceCompletion(.init(completion: withMileage)), now: now)
        // A newer completion without mileage says nothing about where the car is, so it dates nothing.
        let withoutMileage = MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .cabinFilter,
            performedAt: now.addingTimeInterval(-1 * 86400), odometerKm: nil
        )
        _ = try await store.execute(.confirmMaintenanceCompletion(.init(completion: withoutMileage)), now: now)
        let model = CarBoardViewModel(store: store, now: { now }, calendar: Self.utc)

        await model.load()

        #expect(model.state.mileage == .kilometers(84200))
        #expect(model.state.mileageRecency == .days(3))
    }

    @Test("REQ-BOARD-027: without a mileage observation there is no age, and the mileage stays unknown")
    func noObservationHasNoRecency() async {
        let model = CarBoardViewModel(store: FakeCarMemoryStore(), now: { now }, calendar: Self.utc)

        await model.load()

        #expect(model.state.mileage == .unknown)
        #expect(model.state.mileageRecency == nil)
    }

    @Test("REQ-BOARD-027: a reading saved in the editor is dated today")
    func savedReadingIsToday() async {
        let store = FakeCarMemoryStore()
        let model = CarBoardViewModel(store: store, now: { now }, calendar: Self.utc)
        await model.load()

        #expect(await model.saveCar(name: "", odometerText: "47560"))

        #expect(model.state.mileageRecency == .today)
    }

    @Test("ADR-0007: an unchanged editor executes no command")
    func unchangedEditorSavesNothing() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.carBoard(store, now: now)
        await model.load()

        #expect(await model.saveCar(name: ProvisionalCarContext.defaultName, odometerText: ""))
        #expect(await store.executed.isEmpty)
    }

    @Test(
        "REQ-BOARD-004: mileage text is parsed without inventing a value",
        arguments: [
            ("", WholeNumberInput.absent),
            ("   ", .absent),
            ("84 200", .value(84200)),
            ("84,200", .value(84200)),
            ("84\u{00A0}200", .value(84200)),
            ("0", .value(0)),
            ("5000000", .value(5_000_000)),
            ("5000001", .invalid),
            ("-5", .invalid),
            ("+5", .invalid),
            ("-0", .invalid),
            ("84200.5", .invalid),
            ("1.5", .invalid),
            ("84,2", .invalid),
            ("1.084.200", .value(1_084_200)),
            ("1,084.200", .invalid),
            ("1 084,200", .invalid),
            ("84\u{202F}200", .value(84200)),
            ("٨٤٢٠٠", .invalid),
            ("12km", .invalid),
            ("99999999999999999999", .invalid)
        ]
    )
    func mileageParsing(text: String, expected: WholeNumberInput) {
        #expect(InputParsing.kilometers(from: text) == expected)
    }

    @Test("REQ-CAPTURE-009: a failed save is reported and the editor result is false")
    func failedSaveIsReported() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.carBoard(store, now: now)
        await model.load()
        await store.failEverything()

        let saved = await model.saveCar(name: "Kestrel", odometerText: "84200")

        #expect(!saved)
        #expect(model.state.failure == .saveFailed)
        #expect(model.state.car.name == ProvisionalCarContext.defaultName)
    }

    @Test("REQ-BOARD-001: a load failure keeps the first-launch state on screen instead of an error page")
    func loadFailureKeepsBoardUsable() async {
        let store = FakeCarMemoryStore()
        await store.failEverything()
        let model = TestViewModels.carBoard(store, persistence: .temporary, now: now)

        await model.load()

        #expect(model.state.car == .firstLaunch)
        #expect(model.state.isLoadFailed)
        #expect(model.state.isStorageTemporary)
    }

    @Test("ADR-0007: invalid input is rejected before any command is executed")
    func invalidInputExecutesNothing() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.carBoard(store, now: now)
        await model.load()

        #expect(await !model.saveCar(name: "Kestrel", odometerText: "abc"))
        #expect(model.state.failure == .invalidOdometer)
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-CAPTURE-009: when the name saves and the reading fails, the message does not claim nothing changed")
    func partialSaveIsReportedHonestly() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.carBoard(store, now: now)
        await model.load()
        await store.failReadingCommands()

        let saved = await model.saveCar(name: "Kestrel", odometerText: "84200")

        #expect(!saved)
        #expect(model.state.failure == .mileageNotSaved)
        #expect(model.state.car.name == "Kestrel")
        #expect(model.state.mileage == .unknown)
    }

    @Test("REQ-DOMAIN-001: a later, lower reading is a correction and becomes the shown mileage")
    func lowerReadingCorrectsMileage() async {
        let clock = TestClock()
        let store = FakeCarMemoryStore()
        let model = CarBoardViewModel(store: store, now: { clock.date })
        await model.load()

        #expect(await model.saveCar(name: ProvisionalCarContext.defaultName, odometerText: "84200"))
        clock.advance(by: 60)
        #expect(await model.saveCar(name: ProvisionalCarContext.defaultName, odometerText: "82400"))

        #expect(model.state.mileage == .kilometers(82400))
        #expect(await store.readings.count == 2)
    }

    @Test("REQ-BOARD-001: a failed load can be retried, clears its warning, and then allows saving")
    func loadFailureRecovers() async {
        let store = FakeCarMemoryStore()
        await store.failEverything()
        let model = TestViewModels.carBoard(store, now: now)
        await model.load()
        #expect(model.state.isLoadFailed)
        #expect(await !model.saveCar(name: "Kestrel", odometerText: ""))
        model.dismissFailure()
        // Dismissing the save alert must not remove the retry row.
        #expect(model.state.isLoadFailed)

        await store.recover()
        #expect(await model.saveCar(name: "Kestrel", odometerText: ""))

        #expect(model.state.failure == nil)
        #expect(!model.state.isLoadFailed)
        #expect(model.state.car.name == "Kestrel")
    }

    @Test("REQ-BOARD-002: a blank name over stale first-launch state never overwrites the stored name")
    func blankNameKeepsStoredName() async {
        let store = FakeCarMemoryStore(vehicle: Vehicle(id: Vehicle.provisionalID, name: "Kestrel"))
        await store.failEverything()
        let model = TestViewModels.carBoard(store, now: now)
        await model.load()
        #expect(model.state.car.name == ProvisionalCarContext.defaultName)
        await store.recover()

        #expect(await model.saveCar(name: "", odometerText: "84200"))

        #expect(model.state.car.name == "Kestrel")
        #expect(await store.vehicle.name == "Kestrel")
        #expect(model.state.mileage == .kilometers(84200))
    }
}
