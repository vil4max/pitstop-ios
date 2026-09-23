import CoreGraphics
@testable import Pitstop
import Testing

@Suite("Wrapping chip layout")
struct ChipFlowLayoutTests {
    @Test("REQ-GRAMMAR-003: chips share a line while they fit; the chip that would overflow starts the next line")
    func breaksBeforeOverflow() {
        // 50 + 8 + 50 + 8 + 50 = 166.
        #expect(ChipFlowLayout.lines(widths: [50, 50, 50], maxWidth: 166, spacing: 8) == [[0, 1, 2]])
        #expect(ChipFlowLayout.lines(widths: [50, 50, 50], maxWidth: 165, spacing: 8) == [[0, 1], [2]])
        #expect(ChipFlowLayout.lines(widths: [50, 50, 50, 50], maxWidth: 110, spacing: 8) == [[0, 1], [2, 3]])
    }

    @Test("REQ-GRAMMAR-003: a chip wider than the line gets a line of its own and is never dropped")
    func overWideChip() {
        #expect(ChipFlowLayout.lines(widths: [30, 200, 30], maxWidth: 100, spacing: 8) == [[0], [1], [2]])
        #expect(ChipFlowLayout.lines(widths: [], maxWidth: 100, spacing: 8).isEmpty)
    }
}
