import CoreGraphics

/// Cuts the subject of the owner's car photo out of its background, once, when the photo is saved
/// (ADR 0040 "Lift"). Behind a protocol so tests and previews never need Vision.
protocol SubjectLifter: Sendable {
    /// The subject on transparency, cropped to it, or `nil` when no subject is found or the lift fails: the
    /// photo is then kept whole and nothing is reported (REQ-BOARD-031).
    ///
    /// `image` is the stored original, already bounded to `CarPhotoStore.maxLongSide`, never the picked
    /// full-resolution data, so the cut-out stays within the same bound.
    func lift(_ image: CGImage) async -> CGImage?
}
