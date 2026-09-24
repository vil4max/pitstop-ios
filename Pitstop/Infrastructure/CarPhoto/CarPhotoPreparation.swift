import CoreGraphics
import Foundation
import ImageIO

/// Turns the data picked in the car editor into a stored photo: bound it, lift it, store the files
/// (ADR 0040 "Picking", "Lift", "Storage"). Every step runs off the main actor, since a picked photo can be
/// tens of megapixels. Nothing here logs or reports the photo, its id or its files (ADR 0040 "Privacy").
struct CarPhotoPreparation: Sendable {
    let photos: any CarPhotoStoring
    /// `nil` stores the original alone, as when no subject is found (REQ-BOARD-031).
    let lifter: (any SubjectLifter)?

    /// Saves the picked photo under a new id and returns it. The lift sees the bounded image, never the
    /// picked full-resolution data, so its cut-out stays within the same bound as the stored original.
    @concurrent
    func store(picked data: Data) async throws(CarPhotoStoreError) -> CarPhotoID {
        guard let bounded = Self.boundedImage(from: data) else { throw .unreadableImage }
        let lifted = await lifter?.lift(bounded)
        return try photos.save(original: data, lifted: lifted)
    }

    /// Deletes every file of the id. A failure leaves unreferenced files, which nothing shows; the save that
    /// asked for it has already succeeded or already failed, so there is nothing more to tell the owner.
    @concurrent
    func discard(_ id: CarPhotoID) async {
        try? photos.delete(id)
    }

    /// The picked image upright and scaled so its long side is at most `maxLongSide`, never enlarged; `nil`
    /// when the data is not an image. `CarPhotoStore` bounds the original the same way when it re-encodes
    /// it, but does not return the result, so the lift's input is made here.
    static func boundedImage(from data: Data, maxLongSide: Int = CarPhotoStore.maxLongSide) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maxLongSide, max(width, height)),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
