import CoreGraphics
import CoreImage
import Vision

/// The lift through Vision's foreground instance mask, on device and off the main actor. Every detected
/// instance is kept, since a car photo's subject can come back as more than one piece. Nothing here logs or
/// reports the photo or the outcome (ADR 0040 "Privacy").
struct VisionSubjectLifter: SubjectLifter {
    @concurrent
    func lift(_ image: CGImage) async -> CGImage? {
        let handler = ImageRequestHandler(image)
        do {
            guard let observation = try await handler.perform(GenerateForegroundInstanceMaskRequest()),
                  !observation.allInstances.isEmpty
            else { return nil }
            let masked = try observation.generateMaskedImage(
                for: observation.allInstances,
                imageFrom: handler,
                croppedToInstancesExtent: true
            )
            return Self.image(from: masked)
        } catch {
            // An error is the same as no subject: the photo is shown whole and nothing is said (REQ-BOARD-031).
            return nil
        }
    }

    /// The masked buffer as an sRGB image that keeps its transparency.
    private static func image(from buffer: CVPixelBuffer) -> CGImage? {
        let masked = CIImage(cvPixelBuffer: buffer)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CIContext().createCGImage(masked, from: masked.extent, format: .RGBA8, colorSpace: space)
    }
}
