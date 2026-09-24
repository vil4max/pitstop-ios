import CoreGraphics
import Foundation
import ImageIO
@testable import Pitstop
import Testing
import UniformTypeIdentifiers

/// A temporary stand-in for the App Group's `Library/Application Support`, removed after the test.
private struct PhotoDirectory {
    let root = URL.temporaryDirectory.appending(path: "pitstop-photos-\(UUID().uuidString)")

    var photos: URL {
        root.appending(path: "CarPhotos")
    }

    var store: CarPhotoStore {
        CarPhotoStore(directory: root)
    }

    func fileNames() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: photos.path)) ?? []).sorted()
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

/// A plain fictional picture: no real car, no real place.
private func image(width: Int, height: Int, alpha: Bool = false) throws -> CGImage {
    let info = alpha ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast
    let context = try #require(CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: info.rawValue
    ))
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
    return try #require(context.makeImage())
}

/// A camera-style JPEG carrying the metadata a real photo would: a fictional location, capture date,
/// camera make and an orientation.
private func cameraJPEG(width: Int, height: Int, orientation: Int = 1) throws -> Data {
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
    let properties: [CFString: Any] = [
        kCGImagePropertyOrientation: orientation,
        kCGImagePropertyGPSDictionary: [
            kCGImagePropertyGPSLatitude: 12.5, kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 45.25, kCGImagePropertyGPSLongitudeRef: "E",
        ],
        kCGImagePropertyExifDictionary: [
            kCGImagePropertyExifDateTimeOriginal: "2026:01:02 03:04:05",
            kCGImagePropertyExifUserComment: "fictional comment",
        ],
        kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "FictionalCam"],
    ]
    try CGImageDestinationAddImage(destination, image(width: width, height: height), properties as CFDictionary)
    try #require(CGImageDestinationFinalize(destination))
    return data as Data
}

private struct Decoded {
    let type: String
    let width: Int
    let height: Int
    let properties: [CFString: Any]
    let hasAlpha: Bool
}

private func decode(_ url: URL) throws -> Decoded {
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    let opaque: [CGImageAlphaInfo] = [.none, .noneSkipLast, .noneSkipFirst]
    return try Decoded(
        type: #require(CGImageSourceGetType(source) as String?),
        width: image.width,
        height: image.height,
        properties: properties,
        hasAlpha: !opaque.contains(image.alphaInfo)
    )
}

@Suite("Car photo files")
struct CarPhotoStoreTests {
    @Test("REQ-BOARD-029: the original is re-encoded as JPEG at most 2048 px long, without EXIF or location")
    func originalIsReencodedWithoutMetadata() throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let id = try directory.store.save(original: cameraJPEG(width: 4000, height: 3000), lifted: nil)
        let files = try #require(directory.store.files(for: id))

        let saved = try decode(files.original)
        #expect(saved.type == UTType.jpeg.identifier)
        #expect(saved.width == 2048 && saved.height == 1536)
        #expect(saved.properties[kCGImagePropertyGPSDictionary] == nil)
        #expect(saved.properties[kCGImagePropertyExifDictionary] == nil)
        #expect(saved.properties[kCGImagePropertyIPTCDictionary] == nil)
        let tiff = saved.properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(tiff?[kCGImagePropertyTIFFMake] == nil)
        let exif = saved.properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(exif?[kCGImagePropertyExifDateTimeOriginal] == nil)
        #expect(exif?[kCGImagePropertyExifUserComment] == nil)
        // No APP1 Exif segment at all, whatever ImageIO would synthesise when reading.
        let bytes = try Data(contentsOf: files.original)
        #expect(bytes.range(of: Data("Exif\0\0".utf8)) == nil)
    }

    @Test("REQ-BOARD-029: a turned camera photo is saved upright, since its orientation tag is dropped")
    func orientationIsApplied() throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        // Orientation 6: stored landscape, shown rotated 90° clockwise.
        let id = try directory.store.save(original: cameraJPEG(width: 4000, height: 3000, orientation: 6), lifted: nil)
        let saved = try decode(#require(directory.store.files(for: id)).original)
        #expect(saved.width == 1536 && saved.height == 2048)
        #expect((saved.properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
    }

    @Test("REQ-BOARD-029: a photo already within 2048 px keeps its size")
    func smallPhotoIsNotEnlarged() throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let id = try directory.store.save(original: cameraJPEG(width: 1200, height: 800), lifted: nil)
        let saved = try decode(#require(directory.store.files(for: id)).original)
        #expect(saved.width == 1200 && saved.height == 800)
    }

    @Test("REQ-BOARD-029: the files live under CarPhotos in the given container directory, named by the id")
    func filesLiveUnderCarPhotos() throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let lifted = try image(width: 600, height: 400, alpha: true)
        let id = try directory.store.save(original: cameraJPEG(width: 1200, height: 800), lifted: lifted)
        let files = try #require(directory.store.files(for: id))

        #expect(files.original.deletingLastPathComponent().standardizedFileURL == directory.photos.standardizedFileURL)
        #expect(files.original.lastPathComponent.hasPrefix(id.rawValue.uuidString))
        let cutOut = try #require(files.lifted)
        #expect(cutOut.deletingLastPathComponent().standardizedFileURL == directory.photos.standardizedFileURL)
        let decoded = try decode(cutOut)
        #expect(decoded.type == UTType.png.identifier && decoded.hasAlpha)
        #expect(decoded.width == 600 && decoded.height == 400)
        #expect(directory.fileNames().count == 2)
    }

    @Test("REQ-BOARD-029: without a lift only the original is stored")
    func noLiftStoresOriginalOnly() throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let id = try directory.store.save(original: cameraJPEG(width: 1200, height: 800), lifted: nil)
        #expect(try #require(directory.store.files(for: id)).lifted == nil)
        #expect(directory.fileNames().count == 1)
    }

    @Test("REQ-BOARD-029: data that is not an image is rejected and leaves no file")
    func unreadableDataLeavesNothing() throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        #expect(throws: CarPhotoStoreError.unreadableImage) {
            try directory.store.save(original: Data("not an image".utf8), lifted: nil)
        }
        #expect(directory.fileNames().isEmpty)
    }

    @Test("REQ-BOARD-033: deleting a photo removes every file of its id and no other photo's")
    func deleteRemovesEveryFileOfTheID() throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let lifted = try image(width: 600, height: 400, alpha: true)
        let removed = try directory.store.save(original: cameraJPEG(width: 1200, height: 800), lifted: lifted)
        let kept = try directory.store.save(original: cameraJPEG(width: 1200, height: 800), lifted: nil)
        // A file of the same id this version did not write, as a later version might, goes too.
        let stray = directory.photos.appending(path: "\(removed.rawValue.uuidString)-thumbnail.heic")
        try Data([0]).write(to: stray)

        try directory.store.delete(removed)
        #expect(directory.store.files(for: removed) == nil)
        #expect(directory.fileNames().allSatisfy { $0.hasPrefix(kept.rawValue.uuidString) })
        #expect(directory.fileNames().count == 1)
        #expect(directory.store.files(for: kept) != nil)
    }

    @Test("REQ-BOARD-033: deleting a photo that has no files is not an error")
    func deletingMissingPhotoSucceeds() throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        try directory.store.delete(CarPhotoID())
        #expect(directory.store.files(for: CarPhotoID()) == nil)
    }

    @Test("REQ-BOARD-029: the production directory is next to the store in the App Group container")
    func productionDirectoryIsNextToTheStore() {
        let container = URL(fileURLWithPath: "/tmp/group")
        #expect(CarPhotoStore.directory(inGroupContainer: container)
            == StoreLocation.groupStoreURL(in: container).deletingLastPathComponent())
    }
}
