import CoreGraphics
import Foundation
import ImageIO
@testable import Pitstop
import Testing
import UniformTypeIdentifiers

private let now = DomainFixtures.Odometers.baseDate

/// A temporary stand-in for the App Group's `Library/Application Support`, removed after the test.
private struct PhotoDirectory {
    let root = URL.temporaryDirectory.appending(path: "pitstop-save-photo-\(UUID().uuidString)")

    var store: CarPhotoStore {
        CarPhotoStore(directory: root)
    }

    func fileNames() -> [String] {
        let folder = root.appending(path: CarPhotoStore.folderName)
        return ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

/// A fictional picture as JPEG bytes: two blocks of colour, no real car and no real place.
private func syntheticJPEG(width: Int = 64, height: Int = 32) throws -> Data {
    let context = try #require(CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ))
    context.setFillColor(CGColor(red: 0.6, green: 0.3, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
    let image = try #require(context.makeImage())
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    try #require(CGImageDestinationFinalize(destination))
    return data as Data
}

private func cutOut() throws -> CGImage {
    let context = try #require(CGContext(
        data: nil, width: 2, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    return try #require(context.makeImage())
}

/// The in-memory store, except that the chosen profile commands fail, as a full disk would part way
/// through a save.
private actor ProfileFailingStore: CarMemoryStore {
    enum Failing: Sendable {
        case photo
        case body
    }

    let base: FakeCarMemoryStore
    private var failing: Set<Failing> = []

    init(base: FakeCarMemoryStore) {
        self.base = base
    }

    func fail(_ commands: Set<Failing>) {
        failing = commands
    }

    func currentVehicle() async throws(CarMemoryStoreError) -> Vehicle {
        try await base.currentVehicle()
    }

    func odometerReadings() async throws(CarMemoryStoreError) -> [OdometerReading] {
        try await base.odometerReadings()
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
        switch command {
        case .setCarPhoto where failing.contains(.photo), .setCarBody where failing.contains(.body):
            throw .storageFailure
        default:
            return try await base.execute(command, now: now)
        }
    }
}

@MainActor
@Suite("Saving the car's photo and body")
struct CarPhotoSaveTests {
    private static let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent() // CarBoard
        .deletingLastPathComponent() // PitstopTests
        .deletingLastPathComponent()

    private func model(
        _ store: any CarMemoryStore,
        photos: CarPhotoStore,
        lifter: (any SubjectLifter)? = nil,
        analytics: RecordingAnalyticsClient = RecordingAnalyticsClient()
    ) -> CarBoardViewModel {
        CarBoardViewModel(
            store: store,
            photos: photos,
            lifter: lifter,
            analytics: AnalyticsTracker<OdometerAnalyticsEvent>(client: analytics),
            now: { now }
        )
    }

    // MARK: Picking and storing

    @Test("REQ-BOARD-029: a picked photo is stored as files, the car points at them and the stage shows them")
    func pickedPhotoIsStoredAndShown() async throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let store = FakeCarMemoryStore()
        let lifter = try FakeSubjectLifter(cutOut: cutOut())
        let board = model(store, photos: directory.store, lifter: lifter)
        await board.load()

        let saved = try await board.saveCar(
            name: "", odometerText: "", body: nil, photo: .replace(syntheticJPEG(width: 3000, height: 1500))
        )

        #expect(saved)
        let id = try #require(await store.vehicle.photoID)
        let files = try #require(directory.store.files(for: id))
        #expect(files.lifted != nil, "the lift's cut-out was not stored")
        #expect(board.state.carPhoto == files)
        #expect(lifter.liftedSizes == [CGSize(width: 2048, height: 1024)], "the lift did not get the bounded image")
        #expect(board.state.failure == nil)
    }

    @Test("REQ-BOARD-029: a pick that is not an image saves nothing and says nothing was changed")
    func unreadablePickSavesNothing() async {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let store = FakeCarMemoryStore()
        let board = model(store, photos: directory.store)
        await board.load()

        let saved = await board.saveCar(
            name: "Kestrel", odometerText: "", body: .sedan, photo: .replace(Data("not a picture".utf8))
        )

        #expect(!saved)
        #expect(board.state.failure == .saveFailed)
        #expect(await store.executed.isEmpty)
        #expect(directory.fileNames().isEmpty)
    }

    @Test("REQ-BOARD-029: saving a photo and a body sends no analytics event and no event carries the photo")
    func photoSaveSendsNoAnalytics() async throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let store = FakeCarMemoryStore()
        let analytics = RecordingAnalyticsClient()
        let board = model(store, photos: directory.store, analytics: analytics)
        await board.load()

        #expect(try await board.saveCar(name: "", odometerText: "", body: .sedan, photo: .replace(syntheticJPEG())))
        #expect(analytics.events.isEmpty, "a photo or body save sent \(analytics.names)")

        // A mileage saved with the photo sends its own event, which still carries nothing of the photo.
        #expect(try await board.saveCar(name: "", odometerText: "47560", body: nil, photo: .replace(syntheticJPEG())))
        #expect(analytics.names == [.odometerUpdated])
        let id = try #require(await store.vehicle.photoID)
        let files = try #require(directory.store.files(for: id))
        let sent = analytics.events.flatMap { $0.properties.values.map(\.encoded) }
        for value in sent {
            #expect(!value.contains(id.rawValue.uuidString), "an event carries the photo id")
            #expect(!value.contains(files.original.lastPathComponent), "an event carries the photo's file name")
            #expect(!value.contains(CarPhotoStore.folderName), "an event carries the photo's path")
        }
    }

    @Test("REQ-BOARD-029: the analytics catalog has no event or parameter for the photo or the body")
    func analyticsCatalogHasNoPhotoOrBody() {
        let names = AnalyticsEventName.allCases.map(\.rawValue) + AnalyticsProperty.allCases.map(\.rawValue)
        for name in names {
            for word in ["photo", "image", "picture", "body", "file", "lift"] {
                #expect(!name.contains(word), "analytics name \(name) is about the photo or the body")
            }
        }
    }

    @Test("REQ-BOARD-029: the photo's save path writes no log line")
    func photoPathWritesNoLog() throws {
        let paths = [
            "Pitstop/Features/CarBoard/CarBoardViewModel.swift",
            "Pitstop/Features/CarBoard/CarEditorView.swift",
            "Pitstop/Infrastructure/CarPhoto/CarPhotoPreparation.swift",
            "Pitstop/Infrastructure/CarPhoto/CarPhotoStore.swift",
            "Pitstop/Infrastructure/SubjectLift/SubjectLifter.swift",
            "Pitstop/Infrastructure/SubjectLift/VisionSubjectLifter.swift",
        ]
        for path in paths {
            let code = try String(contentsOf: Self.repositoryRoot.appending(path: path), encoding: .utf8)
            for call in ["AppLog", "Logger", "os_log", "NSLog", "print(", "debugPrint(", "dump("] {
                #expect(!code.contains(call), "\(path) calls \(call)")
            }
        }
    }

    // MARK: Body

    @Test("REQ-BOARD-030: a chosen body is saved and the board draws it")
    func chosenBodyIsSaved() async {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let store = FakeCarMemoryStore()
        let board = model(store, photos: directory.store)
        await board.load()

        #expect(await board.saveCar(name: "", odometerText: "", body: .sedan, photo: .unchanged))

        #expect(await store.vehicle.chosenBody == .sedan)
        #expect(board.state.carBody == .sedan)
        #expect(await store.executed.count == 1)
    }

    @Test("REQ-BOARD-030: the body already shown executes no command, so SUV is never written for the owner")
    func unchangedBodySavesNothing() async {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let store = FakeCarMemoryStore()
        let board = model(store, photos: directory.store)
        await board.load()

        #expect(await board.saveCar(name: "", odometerText: "", body: .suv, photo: .unchanged))

        #expect(await store.executed.isEmpty)
        #expect(await store.vehicle.chosenBody == nil)
    }

    // MARK: Replacing and removing

    @Test("REQ-BOARD-033: replacing the photo deletes every file of the old one once the car points at the new")
    func replacingDeletesTheOldFiles() async throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let old = try directory.store.save(original: syntheticJPEG(), lifted: cutOut())
        let store = FakeCarMemoryStore(vehicle: Vehicle(id: Vehicle.provisionalID, name: "Kestrel", photoID: old))
        let board = model(store, photos: directory.store)
        await board.load()

        #expect(try await board.saveCar(name: "", odometerText: "", body: nil, photo: .replace(syntheticJPEG())))

        let new = try #require(await store.vehicle.photoID)
        #expect(new != old)
        #expect(directory.store.files(for: old) == nil)
        #expect(directory.fileNames() == ["\(new.rawValue.uuidString).jpg"])
    }

    @Test("REQ-BOARD-033: when the photo command fails the new files are deleted and the old photo stays")
    func failedCommandDeletesTheNewFiles() async throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let old = try directory.store.save(original: syntheticJPEG(), lifted: nil)
        let base = FakeCarMemoryStore(vehicle: Vehicle(id: Vehicle.provisionalID, name: "Kestrel", photoID: old))
        let store = ProfileFailingStore(base: base)
        await store.fail([.photo])
        let board = try model(store, photos: directory.store, lifter: FakeSubjectLifter(cutOut: cutOut()))
        await board.load()

        let saved = try await board.saveCar(name: "", odometerText: "", body: nil, photo: .replace(syntheticJPEG()))

        #expect(!saved)
        #expect(board.state.failure == .saveFailed, "nothing was saved, so nothing may be claimed")
        #expect(await base.vehicle.photoID == old)
        #expect(directory.fileNames() == ["\(old.rawValue.uuidString).jpg"])
        #expect(board.state.carPhoto == directory.store.files(for: old))
    }

    @Test("REQ-BOARD-033: removing the photo clears the reference, deletes its files and shows the chosen body")
    func removingDeletesEverything() async throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let old = try directory.store.save(original: syntheticJPEG(), lifted: cutOut())
        let car = Vehicle(id: Vehicle.provisionalID, name: "Kestrel", chosenBody: .sedan, photoID: old)
        let store = FakeCarMemoryStore(vehicle: car)
        let board = model(store, photos: directory.store)
        await board.load()
        #expect(board.state.carPhoto != nil)

        #expect(await board.saveCar(name: "", odometerText: "", body: nil, photo: .remove))

        #expect(await store.vehicle.photoID == nil)
        #expect(directory.fileNames().isEmpty)
        #expect(board.state.carPhoto == nil)
        #expect(board.state.carBody == .sedan)
    }

    @Test("REQ-BOARD-033: a remove that fails keeps the reference and every file")
    func failedRemoveKeepsThePhoto() async throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let old = try directory.store.save(original: syntheticJPEG(), lifted: cutOut())
        let base = FakeCarMemoryStore(vehicle: Vehicle(id: Vehicle.provisionalID, name: "Kestrel", photoID: old))
        let store = ProfileFailingStore(base: base)
        await store.fail([.photo])
        let board = model(store, photos: directory.store)
        await board.load()

        #expect(await !board.saveCar(name: "", odometerText: "", body: nil, photo: .remove))

        #expect(await base.vehicle.photoID == old)
        #expect(directory.fileNames().count == 2)
        #expect(board.state.carPhoto == directory.store.files(for: old))
    }

    @Test("REQ-BOARD-033: removing when there is no photo executes no command")
    func removingNothingSavesNothing() async {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let store = FakeCarMemoryStore()
        let board = model(store, photos: directory.store)
        await board.load()

        #expect(await board.saveCar(name: "", odometerText: "", body: nil, photo: .remove))
        #expect(await store.executed.isEmpty)
    }

    // MARK: Honest failures

    @Test("REQ-CAPTURE-009: when the name saves and the photo does not, the message does not claim nothing changed")
    func partialProfileSaveIsReportedHonestly() async throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let base = FakeCarMemoryStore()
        let store = ProfileFailingStore(base: base)
        await store.fail([.photo])
        let board = model(store, photos: directory.store)
        await board.load()

        let saved = try await board.saveCar(
            name: "Kestrel",
            odometerText: "",
            body: nil,
            photo: .replace(syntheticJPEG())
        )

        #expect(!saved)
        #expect(board.state.failure == .profileNotSaved)
        #expect(board.state.car.name == "Kestrel")
        #expect(directory.fileNames().isEmpty, "the unreferenced new files were left behind")
    }

    @Test("REQ-CAPTURE-009: a body that fails after nothing else saved says nothing was changed, and no file stays")
    func failedBodyAloneSavesNothing() async throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let base = FakeCarMemoryStore()
        let store = ProfileFailingStore(base: base)
        await store.fail([.body])
        let board = model(store, photos: directory.store)
        await board.load()

        let saved = try await board.saveCar(name: "", odometerText: "", body: .sedan, photo: .replace(syntheticJPEG()))

        #expect(!saved)
        #expect(board.state.failure == .saveFailed)
        #expect(await base.vehicle.photoID == nil)
        #expect(directory.fileNames().isEmpty)
    }
}
