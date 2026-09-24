import CoreGraphics
import Foundation
import ImageIO
@testable import Pitstop
import SwiftUI
import Testing
import UIKit
import UniformTypeIdentifiers

private let now = DomainFixtures.Odometers.baseDate

/// A temporary stand-in for the App Group's `Library/Application Support`, removed after the test.
private struct PhotoDirectory {
    let root = URL.temporaryDirectory.appending(path: "pitstop-board-photo-\(UUID().uuidString)")

    var store: CarPhotoStore {
        CarPhotoStore(directory: root)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

/// A fictional picture as JPEG bytes: a block of colour, no real car and no real place.
private func syntheticJPEG() throws -> Data {
    let context = try #require(CGContext(
        data: nil, width: 64, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ))
    context.setFillColor(CGColor(red: 0.3, green: 0.4, blue: 0.5, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 64, height: 32))
    let image = try #require(context.makeImage())
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    try #require(CGImageDestinationFinalize(destination))
    return data as Data
}

/// Opaque pixels of a view rendered at 1x on transparency, top row first.
@MainActor
private func render(_ view: some View, width: CGFloat, height: CGFloat) throws -> Bitmap {
    let renderer = ImageRenderer(content: view.frame(width: width, height: height))
    renderer.scale = 1
    renderer.isOpaque = false
    return try Bitmap(#require(renderer.cgImage))
}

private struct Bitmap: Equatable {
    let width: Int
    let height: Int
    let rgba: [UInt8]

    init(_ image: CGImage) throws {
        width = image.width
        height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        rgba = pixels
    }

    func alpha(x: Int, y: Int) -> UInt8 {
        rgba[(y * width + x) * 4 + 3]
    }

    /// The smallest rectangle holding every pixel at least half opaque.
    var opaqueBounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        var bounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)?
        for y in 0 ..< height {
            for x in 0 ..< width where alpha(x: x, y: y) > 128 {
                let current = bounds ?? (x, y, x, y)
                bounds = (min(current.minX, x), min(current.minY, y), max(current.maxX, x), max(current.maxY, y))
            }
        }
        return bounds
    }
}

@MainActor
@Suite("The car on Car Board and Road")
struct CarBoardCarPictureTests {

    // MARK: Loaded into the board

    @Test("REQ-BOARD-030: a loaded car's chosen body reaches the Car Board state")
    func chosenBodyReachesTheBoard() async {
        let car = Vehicle(id: Vehicle.provisionalID, name: "Kestrel", chosenBody: .sedan)
        let model = CarBoardViewModel(store: FakeCarMemoryStore(vehicle: car), now: { now })
        await model.load()

        #expect(model.state.carBody == .sedan)
        #expect(model.state.carPhoto == nil)
    }

    @Test("REQ-BOARD-030: a car with no chosen body is an SUV on the board, whatever its name or make says")
    func unchosenBodyIsSUVOnTheBoard() async {
        let car = Vehicle(id: Vehicle.provisionalID, name: "Sedan", make: "Fictional", model: "Saloon")
        let model = CarBoardViewModel(store: FakeCarMemoryStore(vehicle: car), now: { now })
        #expect(model.state.carBody == .suv, "first launch draws the SUV before any load (REQ-BOARD-032)")
        await model.load()

        #expect(model.state.carBody == .suv)
    }

    @Test("REQ-BOARD-029: a saved photo's files reach the Car Board state, so the stage shows the photo")
    func savedPhotoReachesTheBoard() async throws {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let id = try directory.store.save(original: syntheticJPEG(), lifted: nil)
        let car = Vehicle(id: Vehicle.provisionalID, name: "Kestrel", chosenBody: .sedan, photoID: id)
        let model = CarBoardViewModel(store: FakeCarMemoryStore(vehicle: car), photos: directory.store, now: { now })
        await model.load()

        let files = try #require(model.state.carPhoto)
        #expect(files == directory.store.files(for: id))
        #expect(model.state.carBody == .sedan)
    }

    @Test("REQ-DESIGN-005: a photo id with no files on disk shows the placeholder for the chosen body")
    func missingPhotoFilesShowThePlaceholder() async {
        let directory = PhotoDirectory()
        defer { directory.remove() }
        let car = Vehicle(id: Vehicle.provisionalID, name: "Kestrel", chosenBody: .sedan, photoID: CarPhotoID())
        let model = CarBoardViewModel(store: FakeCarMemoryStore(vehicle: car), photos: directory.store, now: { now })
        await model.load()

        #expect(model.state.carPhoto == nil)
        #expect(model.state.carBody == .sedan)
    }

    // MARK: Drawn

    /// The placeholder is drawn synchronously, so the render shows exactly what the stage shows.
    @Test("REQ-BOARD-017: the Car Board hero draws the car visual for the car's body")
    func heroDrawsTheCarVisual() throws {
        func hero(_ body: CarBody) -> some View {
            CarHeroView(car: .firstLaunch, carBody: body, carPhoto: nil, mileage: .unknown, recency: nil, onEdit: {})
                .environment(\.colorScheme, .light)
        }
        let suv = try render(hero(.suv), width: 360, height: 200)
        let sedan = try render(hero(.sedan), width: 360, height: 200)
        let again = try render(hero(.suv), width: 360, height: 200)

        #expect(suv != sedan, "the hero does not change with the body")
        #expect(suv == again, "the hero render is not stable, so the comparison proves nothing")
    }

    @Test("REQ-DESIGN-005: the placeholder is drawn in its colour role, as a side view standing on the frame's bottom")
    func placeholderIsDrawnInItsRole() throws {
        let width: CGFloat = 288
        let height = (width / CarVisual.aspectRatio).rounded()
        let expected = UIColor(CarVisual.placeholderColor)
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        expected.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        for body in CarBody.allCases {
            let visual = CarVisual(body: body, photo: nil).environment(\.colorScheme, .light)
            let bitmap = try render(visual, width: width, height: height)
            let bounds = try #require(bitmap.opaqueBounds, "\(body) drew nothing")

            // Wheels on the frame's bottom edge: a road line drawn there carries the car (REQ-ROAD-029).
            #expect(bounds.maxY >= bitmap.height - 2, "\(body) floats above the frame's bottom")
            #expect(bounds.maxX - bounds.minX > (bounds.maxY - bounds.minY) * 2, "\(body) is not a side view")

            // A pixel inside the body carries the role's colour and alpha, not a colour of its own.
            let centre = ((bounds.minY + bounds.maxY) / 2 * bitmap.width + (bounds.minX + bounds.maxX) / 2) * 4
            let pixel = bitmap.rgba[centre ..< centre + 4].map { CGFloat($0) / 255 }
            #expect(abs(pixel[3] - alpha) < 0.02, "\(body) alpha \(pixel[3]) is not the role's \(alpha)")
            #expect(abs(pixel[0] - red * alpha) < 0.03 && abs(pixel[1] - green * alpha) < 0.03
                && abs(pixel[2] - blue * alpha) < 0.03, "\(body) is not drawn in the role's colour")
        }
    }
}
