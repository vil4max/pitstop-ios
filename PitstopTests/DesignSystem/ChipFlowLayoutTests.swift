import CoreGraphics
@testable import Pitstop
import Testing

@Suite("Wrapping chip layout")
struct ChipFlowLayoutTests {
    private func lines(_ widths: [CGFloat], maxWidth: CGFloat) -> [[Int]] {
        ChipFlowLayout.arrange(widths: widths, maxWidth: maxWidth, spacing: 8).lines
    }

    @Test("REQ-GRAMMAR-003: chips share a line while they fit; the chip that would overflow starts the next line")
    func breaksBeforeOverflow() {
        // 50 + 8 + 50 + 8 + 50 = 166.
        #expect(lines([50, 50, 50], maxWidth: 166) == [[0, 1, 2]])
        #expect(lines([50, 50, 50], maxWidth: 165) == [[0, 1], [2]])
        #expect(lines([50, 50, 50, 50], maxWidth: 110) == [[0, 1], [2, 3]])
        #expect(ChipFlowLayout.arrange(widths: [50, 50, 50, 50], maxWidth: 110, spacing: 8).width == 108)
    }

    @Test("REQ-GRAMMAR-003: a chip wider than the line gets a line of its own and is never dropped")
    func overWideChip() {
        #expect(lines([30, 200, 30], maxWidth: 100) == [[0], [1], [2]])
        #expect(lines([], maxWidth: 100).isEmpty)
    }

    /// Chip widths in thirds of a point, as on a 3x screen. The parent may place the chips at exactly the
    /// measured width, or at that width rounded down to the pixel grid; both must give the measured lines, or a
    /// chip lands on a line the measured height does not include.
    @Test("REQ-GRAMMAR-003: placing at the measured width breaks lines exactly as measuring did")
    func placingMatchesMeasuring() {
        var mismatches: [[CGFloat]] = []
        let thirds = stride(from: 61, through: 301, by: 7).map { CGFloat($0) / 3 }
        for first in thirds {
            for second in thirds {
                for third in thirds {
                    let widths = [first, second, third]
                    for proposed in [CGFloat.infinity, 200] {
                        let measured = ChipFlowLayout.arrange(widths: widths, maxWidth: proposed, spacing: 8)
                        let pixelRounded = (measured.width * 3).rounded(.down) / 3
                        if lines(widths, maxWidth: measured.width) != measured.lines
                            || lines(widths, maxWidth: pixelRounded) != measured.lines
                        {
                            mismatches.append(widths)
                        }
                    }
                }
            }
        }
        #expect(
            mismatches.isEmpty,
            "\(mismatches.count) chip sets re-broke at the measured width, e.g. \(mismatches.prefix(3))"
        )
    }
}
