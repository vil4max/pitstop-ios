import CoreGraphics
import Foundation
import ImageIO
@testable import Pitstop
import SwiftUI
import Testing
import UIKit
import UniformTypeIdentifiers

/// A plain fictional picture: one block of colour, no real car and no real place.
private func block(red: CGFloat, green: CGFloat, blue: CGFloat, width: Int = 80, height: Int = 60) throws -> CGImage {
    let context = try #require(CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return try #require(context.makeImage())
}

/// One photo's files in a temporary folder, as `CarPhotoStore` lays them out, removed after the test.
private struct PhotoFolder {
    let root = URL.temporaryDirectory.appending(path: "pitstop-car-avatar-\(UUID().uuidString)")

    func write(_ image: CGImage, named name: String) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appending(path: name)
        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        return url
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

@MainActor
@Suite("Car avatar")
struct CarAvatarTests {
    private static let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent() // DesignSystem
        .deletingLastPathComponent() // PitstopTests
        .deletingLastPathComponent()

    /// The avatar rendered at 1x on transparency at its own size, with no frame imposed from outside.
    private static func render(_ view: some View, dark: Bool = false) throws -> CGImage {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, dark ? .dark : .light))
        renderer.scale = 1
        renderer.isOpaque = false
        return try #require(renderer.cgImage)
    }

    private static func pixels(_ image: CGImage) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }

    // MARK: Size and shape

    @Test("REQ-BOARD-034: the avatar is 28 pt in a header and 44 pt in Pit, at every text size")
    func sizes() throws {
        #expect(CarAvatar.Size.header.diameter == 28)
        #expect(CarAvatar.Size.pit.diameter == 44)
        for size in [CarAvatar.Size.header, .pit] {
            for textSize in [DynamicTypeSize.xSmall, .large, .accessibility5] {
                let image = try Self.render(
                    CarAvatar(source: CarAvatarSource(body: .suv, photo: nil), size: size)
                        .environment(\.dynamicTypeSize, textSize)
                )
                #expect(
                    image.width == Int(size.diameter) && image.height == Int(size.diameter),
                    "\(size) at \(textSize)"
                )
            }
        }
    }

    @Test("REQ-BOARD-034: the avatar is round, on the stage's strong tint")
    func round() throws {
        let diameter = Int(CarAvatar.Size.pit.diameter)
        let image = try Self.render(CarAvatar(source: CarAvatarSource(body: .suv, photo: nil), size: .pit))
        let pixels = Self.pixels(image)
        func alpha(_ x: Int, _ y: Int) -> UInt8 {
            pixels[(y * diameter + x) * 4 + 3]
        }
        for (x, y) in [(0, 0), (diameter - 1, 0), (0, diameter - 1), (diameter - 1, diameter - 1)] {
            #expect(alpha(x, y) == 0, "corner \(x),\(y) is drawn, so the avatar is not round")
        }
        for (x, y) in [(diameter / 2, 1), (1, diameter / 2), (diameter / 2, diameter - 2)] {
            #expect(alpha(x, y) > 0, "edge \(x),\(y) is empty")
        }
        for dark in [false, true] {
            let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
            #expect(UIColor(CarAvatar.backgroundColor).resolvedColor(with: traits)
                .isEqual(UIColor(PitColor.surfaceTintStrong).resolvedColor(with: traits)))
        }
    }

    // MARK: Picture

    @Test("REQ-BOARD-034: without a photo the avatar shows the placeholder for the chosen body")
    func placeholderForTheBody() throws {
        for size in [CarAvatar.Size.header, .pit] {
            let suv = try Self.render(CarAvatar(source: CarAvatarSource(body: .suv, photo: nil), size: size))
            let sedan = try Self.render(CarAvatar(source: CarAvatarSource(body: .sedan, photo: nil), size: size))
            let drawnSUV = try Self.render(CarAvatarPicture(picture: .placeholder(.suv), size: size))
            #expect(Self.pixels(suv) != Self.pixels(sedan), "the avatar does not change with the body at \(size)")
            #expect(Self.pixels(suv) == Self.pixels(drawnSUV), "the avatar is not the SUV placeholder at \(size)")
        }
    }

    @Test("REQ-BOARD-034: a photo that was not lifted fills the round avatar")
    func wholePhotoFillsTheAvatar() async throws {
        let folder = PhotoFolder()
        defer { folder.remove() }
        let photo = try CarPhotoFiles(
            original: folder.write(block(red: 0.9, green: 0.1, blue: 0.1), named: "a.png"),
            lifted: nil
        )
        // The avatar reads the files through the car visual's decoder and its shared cache.
        _ = await CarPhotoDecoder.load(body: .suv, photo: photo)

        let diameter = Int(CarAvatar.Size.pit.diameter)
        let image = try Self.render(CarAvatar(source: CarAvatarSource(body: .suv, photo: photo), size: .pit))
        let pixels = Self.pixels(image)
        for (x, y) in [(diameter / 2, diameter / 2), (diameter / 2, 3), (3, diameter / 2)] {
            let offset = (y * diameter + x) * 4
            #expect(pixels[offset] > 200 && pixels[offset + 1] < 60 && pixels[offset + 3] > 250, "\(x),\(y)")
        }
        #expect(pixels[3] == 0, "the photo is not cropped to the circle")
    }

    @Test("REQ-BOARD-034: a lifted photo stands on the tint, as the car visual resolves it")
    func liftedPhotoOnTheTint() async throws {
        let folder = PhotoFolder()
        defer { folder.remove() }
        let cutOut = try block(red: 0.1, green: 0.1, blue: 0.9, width: 60, height: 30)
        let photo = try CarPhotoFiles(
            original: folder.write(block(red: 0.9, green: 0.1, blue: 0.1), named: "b.png"),
            lifted: folder.write(cutOut, named: "b-lifted.png")
        )
        let picture = await CarPhotoDecoder.load(body: .suv, photo: photo)
        guard case .lifted = picture else {
            Issue.record("expected the lifted cut-out, got \(picture)")
            return
        }

        let avatar = try Self.render(CarAvatar(source: CarAvatarSource(body: .suv, photo: photo), size: .pit))
        let drawn = try Self.render(CarAvatarPicture(picture: picture, size: .pit))
        #expect(Self.pixels(avatar) == Self.pixels(drawn))
        let diameter = Int(CarAvatar.Size.pit.diameter)
        let centre = (diameter / 2 * diameter + diameter / 2) * 4
        #expect(Self.pixels(avatar)[centre + 2] > 200, "the cut-out is not drawn in the centre")
        let top = (3 * diameter + diameter / 2) * 4
        #expect(Self.pixels(avatar)[top + 2] < 200, "the cut-out fills the circle instead of standing on the tint")
    }

    // MARK: Accessibility and environment

    @Test("REQ-BOARD-034: the avatar is hidden from VoiceOver")
    func hiddenFromVoiceOver() throws {
        let text = try String(
            contentsOf: Self.repositoryRoot.appending(path: "Pitstop/DesignSystem/Components/CarAvatar.swift"),
            encoding: .utf8
        )
        let start = try #require(text.range(of: "struct CarAvatar: View"))
        let rest = text[start.upperBound...]
        let declaration = rest[..<(rest.range(of: "\n}\n")?.upperBound ?? rest.endIndex)]
        #expect(declaration.contains(".accessibilityHidden(true)"))
        #expect(!declaration.contains("accessibilityLabel"))
    }

    @Test("REQ-BOARD-034: the car's body and photo files travel as one environment value, absent outside the root")
    func environmentValue() throws {
        #expect(EnvironmentValues().carAvatar == nil)
        let photo = CarPhotoFiles(original: URL(filePath: "/tmp/a.jpg"), lifted: nil)
        var values = EnvironmentValues()
        values.carAvatar = CarAvatarSource(body: .sedan, photo: photo)
        let source = try #require(values.carAvatar)
        #expect(source.body == .sedan && source.photo == photo)
        #expect(source != CarAvatarSource(body: .suv, photo: photo))
        #expect(source != CarAvatarSource(body: .sedan, photo: nil))
    }
}
