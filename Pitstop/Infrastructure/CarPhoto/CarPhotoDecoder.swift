import CoreGraphics
import Foundation
import ImageIO
import Synchronization

/// Reads the car photo's files at display size. Files never change under one name (a new photo gets a new id,
/// so new names), which makes the URL a safe cache key; the stage, the tiles and the lane share one decode
/// through `shared`, and a test reads through an instance of its own.
final class CarPhotoDecoder: CarPhotoDecoding {
    /// The one decoder every view reads through unless the environment supplies another.
    static let shared = CarPhotoDecoder()

    /// Enough for the widest use, the stage at 3x; the stored original can be up to 2048 px.
    static let maxPixelSize = 1200

    /// One car has at most a few files alive at once; the cache starts over rather than tracking age.
    private let cache: Mutex<Cache>

    init(limit: Int = 8) {
        cache = Mutex(Cache(limit: limit))
    }

    /// The decoded files by URL. A value of its own, so its rules are tested on an instance and not through a
    /// decoder.
    struct Cache {
        let limit: Int
        /// `nil` inside records a file that was tried and did not decode, so a broken file is not read again.
        private var entries: [URL: CGImage?] = [:]

        init(limit: Int) {
            self.limit = limit
        }

        /// `.some(nil)` for a file read before that did not decode; `nil` for a file not read yet.
        func entry(for url: URL) -> CGImage?? {
            entries[url]
        }

        mutating func store(_ image: CGImage?, for url: URL) {
            if entries.count >= limit {
                entries.removeAll()
            }
            entries[url] = .some(image)
        }

        /// The picture from files already decoded, or `nil` while a file it needs has not been read yet.
        func picture(body: CarBody, photo: CarPhotoFiles) -> CarPicture? {
            var isComplete = true
            let picture = CarPicture.resolve(body: body, photo: photo) { url in
                guard let entry = entries[url] else {
                    isComplete = false
                    return nil
                }
                return entry
            }
            return isComplete ? picture : nil
        }
    }

    /// The image at `url`, bounded to `maxPixelSize` on its long side and never enlarged; `nil` when the file is
    /// missing or is not an image.
    static func decode(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        guard max(width, height) > maxPixelSize else {
            return CGImageSourceCreateImageAtIndex(
                source,
                0,
                [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            )
        }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    func cachedPicture(body: CarBody, photo: CarPhotoFiles) -> CarPicture? {
        cache.withLock { $0 }.picture(body: body, photo: photo)
    }

    /// Reads the files the picture needs off the main actor, through this decoder's cache.
    @concurrent
    func load(body: CarBody, photo: CarPhotoFiles) async -> CarPicture {
        CarPicture.resolve(body: body, photo: photo) { url in
            if let entry = cache.withLock({ $0.entry(for: url) }) {
                return entry
            }
            // Decoded outside the lock: one slow file must not hold up a view reading the cache.
            let image = Self.decode(url)
            cache.withLock { $0.store(image, for: url) }
            return image
        }
    }
}
