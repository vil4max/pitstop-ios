import CoreGraphics
import Foundation
import ImageIO
@testable import Pitstop
import Testing
import UniformTypeIdentifiers

/// Synthetic pictures only: blocks and shapes of colour, never a real car or place.
private enum Synthetic {
    static func context(width: Int, height: Int) throws -> CGContext {
        try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
    }

    /// One flat colour: nothing stands out from a background.
    static func flat(width: Int = 512, height: Int = 384) throws -> CGImage {
        let context = try context(width: width, height: height)
        context.setFillColor(CGColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    /// A dark round shape on a pale ground: the clearest subject a picture can have.
    static func subject(width: Int = 512, height: Int = 384) throws -> CGImage {
        let context = try context(width: width, height: height)
        context.setFillColor(CGColor(red: 0.95, green: 0.95, blue: 0.93, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.55, green: 0.1, blue: 0.1, alpha: 1))
        context.fillEllipse(in: CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
        return try #require(context.makeImage())
    }

    static func jpeg(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        return data as Data
    }
}

private struct PhotoDirectory {
    let root = URL.temporaryDirectory.appending(path: "pitstop-lift-\(UUID().uuidString)")

    var store: CarPhotoStore {
        CarPhotoStore(directory: root)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

/// Alpha of the pixel at the top-left corner, read from a copy drawn into a known layout.
private func cornerAlpha(of image: CGImage) throws -> UInt8 {
    var pixel = [UInt8](repeating: 0, count: 4)
    let context = try #require(CGContext(
        data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    // Only the image's top-left pixel lands on the 1×1 canvas.
    context.draw(image, in: CGRect(x: 0, y: 1 - image.height, width: image.width, height: image.height))
    return pixel[3]
}

@Suite("Subject lift")
struct SubjectLifterTests {
    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
            true
        #else
            false
        #endif
    }

    // MARK: Vision

    @Test("REQ-BOARD-031: a picture with no subject lifts to nothing, without an error")
    func noSubjectLiftsToNothing() async throws {
        #expect(try await VisionSubjectLifter().lift(Synthetic.flat()) == nil)
    }

    @Test("REQ-BOARD-031: a picture too small to hold a subject lifts to nothing, without an error")
    func tinyPictureLiftsToNothing() async throws {
        #expect(try await VisionSubjectLifter().lift(Synthetic.flat(width: 1, height: 1)) == nil)
    }

    /// On the simulator Vision cannot create an inference context for this request (it offers only the
    /// simulator GPU, and the request fails with an internal error), so the test runs on a device only; there
    /// the no-subject tests above also take the no-instance path instead of the error path.
    @Test(
        "REQ-BOARD-031: a lifted subject is a transparent cut-out, cropped to it and never larger than the photo",
        .disabled(if: Self.isSimulator, "Vision's foreground mask does not run on the simulator; a device check")
    )
    func liftedSubjectIsACutOut() async throws {
        let photo = try Synthetic.subject()
        let cutOut = try #require(await VisionSubjectLifter().lift(photo))

        #expect(cutOut.width <= photo.width && cutOut.height <= photo.height)
        #expect(![.none, .noneSkipLast, .noneSkipFirst].contains(cutOut.alphaInfo), "the cut-out has no alpha")
        // Cropped to a round subject, the corner of its bounding box is background, so transparent.
        #expect(try cornerAlpha(of: cutOut) < 32)
    }

    // MARK: With the photo store

    @Test("REQ-BOARD-031: when no subject is found the photo is saved without a cut-out and drawn whole")
    func noSubjectIsSavedAndDrawnWhole() async throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let lifter = FakeSubjectLifter(cutOut: nil)
        let photo = try Synthetic.subject()

        let cutOut = await lifter.lift(photo)
        let id = try directory.store.save(original: Synthetic.jpeg(photo), lifted: cutOut)
        let files = try #require(directory.store.files(for: id))

        #expect(files.lifted == nil)
        guard case .whole = CarPicture.resolve(body: .sedan, photo: files, decode: CarPhotoDecoder.decode) else {
            Issue.record("a photo without a cut-out is drawn whole")
            return
        }
        #expect(lifter.liftedSizes == [CGSize(width: 512, height: 384)])
    }

    @Test("REQ-BOARD-031: a found subject is saved as the cut-out and drawn lifted")
    func foundSubjectIsSavedAndDrawnLifted() async throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let lifter = try FakeSubjectLifter(cutOut: Synthetic.subject(width: 200, height: 100))
        let photo = try Synthetic.subject()

        let cutOut = await lifter.lift(photo)
        let id = try directory.store.save(original: Synthetic.jpeg(photo), lifted: cutOut)
        let files = try #require(directory.store.files(for: id))

        #expect(files.lifted != nil)
        guard case let .lifted(image) = CarPicture.resolve(
            body: .suv,
            photo: files,
            decode: CarPhotoDecoder.decode
        ) else {
            Issue.record("a saved cut-out is drawn lifted")
            return
        }
        #expect(image.width == 200 && image.height == 100)
    }
}
