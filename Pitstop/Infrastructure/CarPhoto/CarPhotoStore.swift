import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum CarPhotoStoreError: Error, Hashable, Sendable {
    /// The picked data does not decode as an image.
    case unreadableImage
    case writeFailed
}

/// Where one saved photo's files are. `lifted` is `nil` when the subject could not be lifted, and the
/// car is then drawn from the whole original (REQ-BOARD-031).
struct CarPhotoFiles: Hashable, Sendable {
    let original: URL
    let lifted: URL?
}

/// The car photo as plain files, so the store keeps only an id and a widget can later read the files
/// without a timeline entry (ADR 0040, REQ-BOARD-029).
protocol CarPhotoStoring: Sendable {
    /// Saves a new photo under a new id and returns it; the caller then points the car at that id.
    func save(original: Data, lifted: CGImage?) throws(CarPhotoStoreError) -> CarPhotoID
    /// `nil` when the id has no original on disk.
    func files(for id: CarPhotoID) -> CarPhotoFiles?
    /// Removes every file of the id; an id with no files is already deleted (REQ-BOARD-033).
    func delete(_ id: CarPhotoID) throws(CarPhotoStoreError)
}

/// Files live in `<directory>/CarPhotos/`, named `<id>.jpg` and `<id>-lifted.png`. Nothing here logs,
/// uploads or reports the photo, its id or its path (ADR 0040 "Privacy").
struct CarPhotoStore: CarPhotoStoring {
    static let folderName = "CarPhotos"
    static let maxLongSide = 2048
    private static let jpegQuality = 0.85

    private let folder: URL

    /// `directory` is the App Group's `Library/Application Support` in the app, a temporary one in tests.
    init(directory: URL) {
        folder = directory.appending(path: Self.folderName, directoryHint: .isDirectory)
    }

    /// The directory beside the car memory store, so both share the App Group container (ADR 0036).
    static func directory(inGroupContainer container: URL) -> URL {
        StoreLocation.groupStoreURL(in: container).deletingLastPathComponent()
    }

    func save(original: Data, lifted: CGImage?) throws(CarPhotoStoreError) -> CarPhotoID {
        let jpeg = try Self.reencodedJPEG(original)
        var png: Data?
        if let lifted {
            png = try Self.encoded(lifted, as: .png)
        }
        let id = CarPhotoID()
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try jpeg.write(to: originalURL(for: id), options: .atomic)
            if let png {
                try png.write(to: liftedURL(for: id), options: .atomic)
            }
        } catch {
            // Half a photo is never left behind: without both writes the id's files are removed.
            try? delete(id)
            throw .writeFailed
        }
        return id
    }

    func files(for id: CarPhotoID) -> CarPhotoFiles? {
        let fileManager = FileManager.default
        let original = originalURL(for: id)
        guard fileManager.fileExists(atPath: original.path) else { return nil }
        let lifted = liftedURL(for: id)
        return CarPhotoFiles(original: original, lifted: fileManager.fileExists(atPath: lifted.path) ? lifted : nil)
    }

    func delete(_ id: CarPhotoID) throws(CarPhotoStoreError) {
        let fileManager = FileManager.default
        let prefix = id.rawValue.uuidString
        let names: [String]
        do {
            names = try fileManager.contentsOfDirectory(atPath: folder.path)
        } catch {
            // No folder yet means no photo was ever saved here.
            guard fileManager.fileExists(atPath: folder.path) else { return }
            throw .writeFailed
        }
        // By prefix, not by the two known names, so a file a later version adds for the id goes too.
        do {
            for name in names where name.hasPrefix(prefix) {
                try fileManager.removeItem(at: folder.appending(path: name))
            }
        } catch {
            throw .writeFailed
        }
    }

    private func originalURL(for id: CarPhotoID) -> URL {
        folder.appending(path: "\(id.rawValue.uuidString).jpg")
    }

    private func liftedURL(for id: CarPhotoID) -> URL {
        folder.appending(path: "\(id.rawValue.uuidString)-lifted.png")
    }

    /// Decodes and draws the photo afresh, so no source metadata (EXIF, GPS, TIFF, XMP) is carried over;
    /// the orientation is applied to the pixels first, since its tag is dropped with the rest.
    private static func reencodedJPEG(_ data: Data) throws(CarPhotoStoreError) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { throw .unreadableImage }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            // Never enlarged: a photo within the limit keeps its own size.
            kCGImageSourceThumbnailMaxPixelSize: min(maxLongSide, max(width, height)),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw .unreadableImage
        }
        return try withoutMetadataSegments(encoded(image, as: .jpeg))
    }

    /// ImageIO adds its own APP1 Exif (colour space, pixel size) and APP13 Photoshop segments to every JPEG
    /// it writes. They hold nothing personal, but the stored photo carries no EXIF at all (ADR 0040), so
    /// both are cut from the header; the image data after the start-of-scan marker is copied untouched.
    private static func withoutMetadataSegments(_ jpeg: Data) throws(CarPhotoStoreError) -> Data {
        let bytes = [UInt8](jpeg)
        let app1: UInt8 = 0xE1
        let app13: UInt8 = 0xED
        let startOfScan: UInt8 = 0xDA
        guard bytes.count > 4, bytes[0] == 0xFF, bytes[1] == 0xD8 else { throw .writeFailed }
        var kept = [UInt8](bytes[0 ..< 2])
        var index = 2
        while index + 4 <= bytes.count, bytes[index] == 0xFF {
            let marker = bytes[index + 1]
            if marker == startOfScan {
                kept.append(contentsOf: bytes[index...])
                return Data(kept)
            }
            let end = index + 2 + (Int(bytes[index + 2]) << 8 | Int(bytes[index + 3]))
            guard end <= bytes.count else { break }
            if marker != app1, marker != app13 {
                kept.append(contentsOf: bytes[index ..< end])
            }
            index = end
        }
        // A header this code cannot walk is not stored: it might still hold the segments.
        throw .writeFailed
    }

    private static func encoded(_ image: CGImage, as type: UTType) throws(CarPhotoStoreError) -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            throw .writeFailed
        }
        let properties: [CFString: Any] = type == .jpeg ? [kCGImageDestinationLossyCompressionQuality: jpegQuality] :
            [:]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw .writeFailed }
        return data as Data
    }
}
