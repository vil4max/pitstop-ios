import CoreGraphics
import Foundation
import ImageIO
@testable import Pitstop
import SwiftUI
import Testing
import UIKit
import UniformTypeIdentifiers

/// A plain fictional picture: a block of colour, no real car and no real place.
private func picture(width: Int = 64, height: Int = 32) throws -> CGImage {
    let context = try #require(CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(CGColor(red: 0.3, green: 0.5, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
    return try #require(context.makeImage())
}

/// A temporary folder holding one photo's files as `CarPhotoStore` lays them out, removed after the test.
private struct PhotoFolder {
    let root = URL.temporaryDirectory.appending(path: "pitstop-car-visual-\(UUID().uuidString)")

    func write(_ image: CGImage, named name: String, as type: UTType) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appending(path: name)
        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL,
            type.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        return url
    }

    func writeGarbage(named name: String) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appending(path: name)
        try Data("not an image".utf8).write(to: url)
        return url
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private func resolved(_ color: Color, dark: Bool) -> UIColor {
    UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
}

@Suite("Car visual")
struct CarVisualTests {

    // MARK: Placeholder

    @Test("REQ-DESIGN-005: with no photo the car is the placeholder for the chosen body", arguments: CarBody.allCases)
    func noPhotoDrawsTheChosenBody(body: CarBody) {
        let picture = CarPicture.resolve(body: body, photo: nil) { _ in
            Issue.record("nothing is decoded when there is no photo")
            return nil
        }
        #expect(picture == .placeholder(body))
    }

    @Test("REQ-BOARD-030: a car without a chosen body is drawn as the SUV placeholder")
    func unchosenBodyIsSUV() {
        let car = Vehicle(name: "Kestrel", make: "Fictional", model: "Sedan GT")
        #expect(CarPicture.resolve(body: car.body, photo: nil) { _ in nil } == .placeholder(.suv))
    }

    @Test("REQ-DESIGN-005: each body has its own placeholder image in the asset catalog")
    func eachBodyHasItsOwnImage() throws {
        let names = CarBody.allCases.map(CarVisual.placeholderAssetName)
        #expect(Set(names).count == CarBody.allCases.count)
        for name in names {
            let image = try #require(UIImage(named: name, in: .main, with: nil), "missing asset \(name)")
            #expect(image.size.width > image.size.height * 2, "a side view is wide: \(name)")
        }
    }

    /// The placeholder carries no colour of its own: the catalog marks it as a template, so the colour role the
    /// view applies is the only colour it has (REQ-DESIGN-004).
    @Test("REQ-DESIGN-005: the placeholder is drawn through a colour role, not its own colour")
    func placeholderTakesTheRole() throws {
        for body in CarBody.allCases {
            let image = try #require(UIImage(named: CarVisual.placeholderAssetName(body), in: .main, with: nil))
            #expect(image.renderingMode == .alwaysTemplate, "\(body) is not a template image")
        }
        for dark in [false, true] {
            #expect(resolved(CarVisual.placeholderColor, dark: dark)
                .isEqual(resolved(PitColor.contentSecondary, dark: dark)))
        }
    }

    /// A side view facing right has its hood, the low end, on the right: the top third of the silhouette holds
    /// more of its mass on the left, where the cabin and the tail rise. A mirrored image fails this.
    @Test("REQ-DESIGN-005: both placeholders face right")
    func placeholdersFaceRight() throws {
        for body in CarBody.allCases {
            let image = try #require(UIImage(named: CarVisual.placeholderAssetName(body), in: .main, with: nil)?
                .cgImage)
            let (left, right) = try Self.opaqueMassInTopThird(of: image)
            #expect(left > right, "\(body) does not face right: left \(left), right \(right)")
        }
    }

    // MARK: Photo

    @Test("REQ-BOARD-031: a lifted photo is drawn as the cut-out")
    func liftedPhotoIsTheCutOut() throws {
        let folder = PhotoFolder()
        defer { folder.remove() }
        let cutOut = try picture(width: 40, height: 20)
        let files = try CarPhotoFiles(
            original: folder.write(picture(), named: "a.jpg", as: .jpeg),
            lifted: folder.write(cutOut, named: "a-lifted.png", as: .png)
        )

        let result = CarPicture.resolve(body: .sedan, photo: files, decode: CarPhotoDecoder.decode)
        guard case let .lifted(image) = result else {
            Issue.record("expected the lifted cut-out, got \(result)")
            return
        }
        #expect(image.width == 40 && image.height == 20)
    }

    @Test("REQ-BOARD-031: a photo whose subject was not lifted is drawn whole, with no error")
    func unliftedPhotoIsWhole() throws {
        let folder = PhotoFolder()
        defer { folder.remove() }
        let files = try CarPhotoFiles(original: folder.write(picture(), named: "a.jpg", as: .jpeg), lifted: nil)

        let result = CarPicture.resolve(body: .suv, photo: files, decode: CarPhotoDecoder.decode)
        guard case let .whole(image) = result else {
            Issue.record("expected the whole photo, got \(result)")
            return
        }
        #expect(image.width == 64 && image.height == 32)
    }

    @Test("REQ-BOARD-031: a cut-out that cannot be read falls back to the whole photo")
    func unreadableCutOutFallsBackToWhole() throws {
        let folder = PhotoFolder()
        defer { folder.remove() }
        let files = try CarPhotoFiles(
            original: folder.write(picture(), named: "a.jpg", as: .jpeg),
            lifted: folder.writeGarbage(named: "a-lifted.png")
        )

        let result = CarPicture.resolve(body: .suv, photo: files, decode: CarPhotoDecoder.decode)
        guard case .whole = result else {
            Issue.record("expected the whole photo, got \(result)")
            return
        }
    }

    @Test("REQ-DESIGN-005: a photo whose files are gone or unreadable falls back to the chosen body")
    func unreadablePhotoFallsBackToThePlaceholder() throws {
        let folder = PhotoFolder()
        defer { folder.remove() }
        let missing = CarPhotoFiles(original: folder.root.appending(path: "gone.jpg"), lifted: nil)
        let garbage = try CarPhotoFiles(original: folder.writeGarbage(named: "b.jpg"), lifted: nil)

        #expect(CarPicture
            .resolve(body: .sedan, photo: missing, decode: CarPhotoDecoder.decode) == .placeholder(.sedan))
        #expect(CarPicture.resolve(body: .suv, photo: garbage, decode: CarPhotoDecoder.decode) == .placeholder(.suv))
    }

    @Test("The decoder bounds a photo to the display size, never enlarging a small one")
    func decoderBoundsTheSize() throws {
        let folder = PhotoFolder()
        defer { folder.remove() }
        let large = try folder.write(picture(width: 2000, height: 1000), named: "large.png", as: .png)
        let small = try folder.write(picture(width: 64, height: 32), named: "small.png", as: .png)

        let bounded = try #require(CarPhotoDecoder.decode(large))
        #expect(max(bounded.width, bounded.height) == CarPhotoDecoder.maxPixelSize)
        let kept = try #require(CarPhotoDecoder.decode(small))
        #expect(kept.width == 64 && kept.height == 32)
    }

    private static func opaqueMassInTopThird(of image: CGImage) throws -> (left: Int, right: Int) {
        let width = image.width, height = image.height
        var alpha = [UInt8](repeating: 0, count: width * height)
        let context = try #require(CGContext(
            data: &alpha, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var left = 0, right = 0
        // The buffer's first row is the image's top row.
        for row in 0 ..< height / 3 {
            for column in 0 ..< width where alpha[row * width + column] > 128 {
                if column < width / 2 {
                    left += 1
                } else {
                    right += 1
                }
            }
        }
        return (left, right)
    }
}
