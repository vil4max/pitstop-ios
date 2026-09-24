@testable import Pitstop
import SwiftUI
import Testing
import UIKit

/// A locked device redacts the next-service widget's privacy-sensitive content (REQ-WIDGET-008). SwiftUI replaces
/// text and SF Symbols with placeholders but draws shapes as they are, so the status glyph and chip must hide the
/// state themselves. Rendered as the widget nests them: privacy-sensitive content under a privacy redaction.
@MainActor
@Suite("Status redaction")
struct StatusRedactionTests {
    private static let statuses: [MaintenanceStatus] = [.unknown, .upToDate, .approaching, .due]

    private func pixels(_ view: some View, redacted: Bool) throws -> Data {
        let renderer = ImageRenderer(content: view
            .privacySensitive()
            .redacted(reason: redacted ? .privacy : [])
            .padding(4)
            .background(PitColor.surfaceSecondary)
            .environment(\.colorScheme, .light))
        renderer.scale = 2
        let image = try #require(renderer.cgImage, "the view did not render")
        let bytesPerRow = image.width * 4
        var data = Data(count: bytesPerRow * image.height)
        try data.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return data
    }

    private func glyph(_ glyph: StatusGlyph) -> some View {
        StatusGlyphView(glyph: glyph, size: 18)
            .foregroundStyle(PitColor.statusDue)
    }

    private func chip(_ status: MaintenanceStatus) -> some View {
        // One word for every status, so only the glyph and the colour could tell the states apart.
        StatusChip(Text(verbatim: "Status"), glyph: status.glyph, color: status.color)
    }

    @Test("REQ-WIDGET-008: a redacted status glyph is the same placeholder for every state")
    func redactedGlyphHidesTheState() throws {
        let shown = try StatusGlyph.allCases.map { try pixels(glyph($0), redacted: false) }
        #expect(Set(shown).count == StatusGlyph.allCases.count, "the glyphs should differ when not redacted")
        let redacted = try StatusGlyph.allCases.map { try pixels(glyph($0), redacted: true) }
        #expect(Set(redacted).count == 1, "a redacted glyph still tells the state by its shape")
    }

    @Test("REQ-WIDGET-008: a redacted status chip shows neither the state's glyph nor its colour")
    func redactedChipHidesTheState() throws {
        let shown = try Self.statuses.map { try pixels(chip($0), redacted: false) }
        #expect(Set(shown).count == Self.statuses.count, "the chips should differ when not redacted")
        let redacted = try Self.statuses.map { try pixels(chip($0), redacted: true) }
        #expect(Set(redacted).count == 1, "a redacted chip still tells the state by its glyph or colour")
    }
}
