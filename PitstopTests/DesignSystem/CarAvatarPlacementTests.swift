import CoreGraphics
import Foundation
@testable import Pitstop
import SwiftUI
import Testing
import UIKit

/// Where the car avatar appears (REQ-BOARD-034): detail screen headers at 28 pt, the Pit sheet's saved state and
/// question card at 44 pt, and nowhere else.
@MainActor
@Suite("Car avatar placement")
struct CarAvatarPlacementTests {
    private static let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent() // DesignSystem
        .deletingLastPathComponent() // PitstopTests
        .deletingLastPathComponent()

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repositoryRoot.appending(path: path), encoding: .utf8)
    }

    /// The source of one declaration, from its first line to the next top-level closing brace.
    private static func declaration(_ name: String, in path: String) throws -> Substring {
        let text = try source(path)
        let start = try #require(text.range(of: name), "\(name) not found in \(path)")
        let rest = text[start.upperBound...]
        let end = rest.range(of: "\n}\n")?.upperBound ?? rest.endIndex
        return rest[..<end]
    }

    /// Swift sources under a folder, as paths relative to the repository root.
    private static func swiftFiles(under folder: String) throws -> [String] {
        let root = repositoryRoot.appending(path: folder)
        let enumerator = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        return enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .map { String($0.path(percentEncoded: false).dropFirst(repositoryRoot.path(percentEncoded: false).count)) }
            .sorted()
    }

    private static func render(_ view: some View, width: CGFloat) throws -> [UInt8] {
        let renderer = ImageRenderer(content: view
            .frame(width: width)
            .environment(\.colorScheme, .light)
            .environment(\.dynamicTypeSize, .large))
        renderer.scale = 1
        renderer.isOpaque = false
        let image = try #require(renderer.cgImage)
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

    private static let sedan = CarAvatarSource(body: .sedan, photo: nil)

    // MARK: Root

    @Test("REQ-BOARD-034: the root gives every screen and sheet the car's body and photo from the car board state")
    func rootSetsTheValue() throws {
        let content = try Self.declaration("private var content: some View", in: "Pitstop/App/RootView.swift")
        #expect(content.contains(
            ".environment(\\.carAvatar, CarAvatarSource(body: carBoard.state.carBody, photo: carBoard.state.carPhoto))"
        ))
    }

    // MARK: Headers

    @Test("REQ-BOARD-034: a detail header shows the 28 pt avatar before the eyebrow")
    func headerShowsTheAvatar() throws {
        let width: CGFloat = 320
        let plain = try Self.render(ScreenHeader(eyebrow: "Kestrel", title: "Service"), width: width)
        let withAvatar = try Self.render(
            ScreenHeader(eyebrow: "Kestrel", title: "Service", avatar: Self.sedan),
            width: width
        )
        #expect(plain != withAvatar, "the header draws no avatar")

        // The avatar's circle is the first thing on the eyebrow line: its tint fills the header's leading corner
        // area, where the plain header's first letter leaves a gap at the top.
        let diameter = Int(CarAvatar.Size.header.diameter)
        let alpha = withAvatar[((diameter / 2) * Int(width) + 1) * 4 + 3]
        #expect(alpha > 0, "no avatar at the start of the eyebrow line")
    }

    @Test("REQ-BOARD-034: the header stays one VoiceOver heading, without the avatar")
    func headerKeepsItsAccessibility() throws {
        let header = try Self.declaration(
            "struct ScreenHeader: View",
            in: "Pitstop/DesignSystem/Components/ScreenHeader.swift"
        )
        #expect(header.contains(".accessibilityElement(children: .combine)"))
        #expect(header.contains(".accessibilityAddTraits(.isHeader)"))
        #expect(header.contains("CarAvatar(source: avatar, size: .header)"))
        let avatar = try Self.declaration(
            "struct CarAvatar: View",
            in: "Pitstop/DesignSystem/Components/CarAvatar.swift"
        )
        #expect(avatar.contains(".accessibilityHidden(true)"))
    }

    @Test("REQ-BOARD-034: Road, Notes, History and Service headers take the avatar from the environment")
    func detailScreensShowTheAvatar() throws {
        let scaffold = try Self.declaration(
            "struct FeatureScaffold",
            in: "Pitstop/Features/Shared/FeatureScaffold.swift"
        )
        #expect(scaffold.contains("@Environment(\\.carAvatar) private var carAvatar"))
        #expect(scaffold.contains("ScreenHeader(eyebrow: carName, title: title, avatar: carAvatar)"))
        for path in [
            "Pitstop/Features/Road/RoadView.swift",
            "Pitstop/Features/Notes/NotesView.swift",
            "Pitstop/Features/History/HistoryView.swift",
            "Pitstop/Features/Service/ServiceView.swift",
        ] {
            #expect(try Self.source(path).contains("FeatureScaffold(carName:"), "\(path) has no detail header")
        }
    }

    @Test("REQ-BOARD-034: Car Board's own header shows no avatar; the hero shows the car")
    func carBoardHeaderHasNone() throws {
        let board = try Self.source("Pitstop/Features/CarBoard/CarBoardView.swift")
        let call = try #require(board.range(of: "ScreenHeader("))
        let line = board[call.lowerBound...].prefix { $0 != "\n" }
        #expect(!line.contains("avatar"), "Car Board's header passes an avatar: \(line)")
    }

    // MARK: Pit

    @Test("REQ-BOARD-034: the Pit sheet's saved state shows the 44 pt avatar; other moments show none")
    func savedStateShowsTheAvatar() throws {
        let width: CGFloat = 320
        func header(_ title: PitMomentTitle, eyes: PitState, avatar: CarAvatarSource?) throws -> [UInt8] {
            try Self.render(
                PitMomentHeader(title: title, eyes: eyes).environment(\.carAvatar, avatar),
                width: width
            )
        }
        let savedWith = try header(.saved, eyes: .closedEyes, avatar: Self.sedan)
        let savedWithout = try header(.saved, eyes: .closedEyes, avatar: nil)
        #expect(savedWith != savedWithout, "the saved state draws no avatar")
        for title in [PitMomentTitle.remember, .isThisRight, .oneThing] {
            #expect(
                try header(title, eyes: .fixedGaze, avatar: Self.sedan)
                    == header(title, eyes: .fixedGaze, avatar: nil),
                "\(title) draws an avatar"
            )
        }
        let parts = try Self.declaration("struct PitMomentHeader", in: "Pitstop/Features/Pit/PitSheetParts.swift")
        #expect(parts.contains("CarAvatar(source: avatar, size: .pit)"))
    }

    @Test("REQ-BOARD-034: Pit's question card shows the 44 pt avatar of the car it asks about")
    func questionCardShowsTheAvatar() throws {
        let card = try Self.declaration("struct PitQuestionCard", in: "Pitstop/Features/Pit/PitQuestionCard.swift")
        #expect(card.contains("@Environment(\\.carAvatar) private var carAvatar"))
        #expect(card.contains("CarAvatar(source: carAvatar, size: .pit)"))
    }

    // MARK: Nowhere else

    @Test("REQ-BOARD-034: Settings, forms, list rows and widgets show no avatar")
    func nowhereElse() throws {
        let files = try ["Pitstop", "Shared", "PitstopWidgets"].flatMap(Self.swiftFiles(under:))
        #expect(files.count > 50, "the sources were not found; the rule would pass vacuously")
        let drawing = try files.filter { try Self.source($0).contains("CarAvatar(source:") }
        #expect(drawing == [
            "Pitstop/DesignSystem/Components/CarAvatar.swift",
            "Pitstop/DesignSystem/Components/ScreenHeader.swift",
            "Pitstop/Features/Pit/PitQuestionCard.swift",
            "Pitstop/Features/Pit/PitSheetParts.swift",
        ])
        let reading = try files.filter { try Self.source($0).contains("\\.carAvatar") }
        #expect(reading == [
            "Pitstop/App/RootView.swift",
            "Pitstop/Features/Pit/PitQuestionCard.swift",
            "Pitstop/Features/Pit/PitSheetParts.swift",
            "Pitstop/Features/Shared/FeatureScaffold.swift",
        ])
    }
}
