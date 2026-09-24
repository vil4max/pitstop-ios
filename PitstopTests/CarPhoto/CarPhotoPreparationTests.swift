import CoreGraphics
import Foundation
import ImageIO
@testable import Pitstop
import Synchronization
import Testing
import UniformTypeIdentifiers

/// A temporary stand-in for the App Group's `Library/Application Support`, removed after the test.
private struct PhotoDirectory {
    let root = URL.temporaryDirectory.appending(path: "pitstop-prepare-\(UUID().uuidString)")

    var store: CarPhotoStore {
        CarPhotoStore(directory: root)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

/// A fictional picture as JPEG bytes: two blocks of colour, no real car and no real place.
private func syntheticJPEG(width: Int, height: Int) throws -> Data {
    let context = try #require(CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ))
    context.setFillColor(CGColor(red: 0.3, green: 0.4, blue: 0.5, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
    let image = try #require(context.makeImage())
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    try #require(CGImageDestinationFinalize(destination))
    return data as Data
}

/// A one-pixel cut-out, enough for the store to write a lifted file.
private func cutOut() throws -> CGImage {
    let context = try #require(CGContext(
        data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    return try #require(context.makeImage())
}

/// Records whether each lift ran on the main thread and finds no subject.
private final class ThreadRecordingLifter: SubjectLifter {
    private let onMain = Mutex<[Bool]>([])

    var liftsOnMainThread: [Bool] {
        onMain.withLock { $0 }
    }

    func lift(_: CGImage) async -> CGImage? {
        record()
        return nil
    }

    /// Synchronous, so the thread check reads where the lift itself runs.
    private func record() {
        let isMain = Thread.isMainThread
        onMain.withLock { $0.append(isMain) }
    }
}

@Suite("Preparing a picked car photo")
struct CarPhotoPreparationTests {
    @Test("REQ-BOARD-029: a picked photo is bounded to 2048 px on its long side before anything else sees it")
    func pickedPhotoIsBounded() throws {
        let wide = try #require(CarPhotoPreparation.boundedImage(from: syntheticJPEG(width: 4096, height: 1024)))
        #expect(wide.width == CarPhotoStore.maxLongSide)
        #expect(wide.height == 512)

        let tall = try #require(CarPhotoPreparation.boundedImage(from: syntheticJPEG(width: 600, height: 3000)))
        #expect(tall.height == CarPhotoStore.maxLongSide)

        let small = try #require(CarPhotoPreparation.boundedImage(from: syntheticJPEG(width: 64, height: 32)))
        #expect(small.width == 64 && small.height == 32, "a photo within the bound is never enlarged")
    }

    @Test("REQ-BOARD-029: data that is not an image is not a photo")
    func unreadableDataIsRejected() {
        #expect(CarPhotoPreparation.boundedImage(from: Data("not a picture".utf8)) == nil)
        #expect(CarPhotoPreparation.boundedImage(from: Data()) == nil)
    }

    @Test("REQ-BOARD-029: the lift gets the bounded image, never the picked full-resolution data")
    func liftGetsTheBoundedImage() async throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let lifter = try FakeSubjectLifter(cutOut: cutOut())
        let preparation = CarPhotoPreparation(photos: directory.store, lifter: lifter)

        let id = try await preparation.store(picked: syntheticJPEG(width: 4096, height: 2048))

        #expect(lifter.liftedSizes == [CGSize(width: 2048, height: 1024)])
        let files = try #require(directory.store.files(for: id))
        #expect(files.lifted != nil, "the cut-out was not stored beside the original")
    }

    @Test("REQ-BOARD-029: the photo is bounded, lifted and stored off the main actor")
    @MainActor
    func photoWorkRunsOffTheMainActor() async throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let lifter = ThreadRecordingLifter()
        let preparation = CarPhotoPreparation(photos: directory.store, lifter: lifter)

        let id = try await preparation.store(picked: syntheticJPEG(width: 640, height: 320))

        #expect(lifter.liftsOnMainThread == [false])
        #expect(directory.store.files(for: id)?.lifted == nil, "no subject keeps the original only")
    }

    @Test("REQ-BOARD-029: without a lifter the original alone is stored")
    func noLifterStoresTheOriginal() async throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let preparation = CarPhotoPreparation(photos: directory.store, lifter: nil)

        let id = try await preparation.store(picked: syntheticJPEG(width: 64, height: 32))

        let files = try #require(directory.store.files(for: id))
        #expect(files.lifted == nil)
    }

    @Test("REQ-BOARD-029: an unreadable pick stores no file")
    func unreadablePickStoresNothing() async {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let preparation = CarPhotoPreparation(photos: directory.store, lifter: nil)

        await #expect(throws: CarPhotoStoreError.unreadableImage) {
            try await preparation.store(picked: Data("not a picture".utf8))
        }
        let folder = directory.root.appending(path: CarPhotoStore.folderName)
        #expect(((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).isEmpty)
    }
}
