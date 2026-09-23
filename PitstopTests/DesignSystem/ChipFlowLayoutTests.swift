import CoreGraphics
@testable import Pitstop
import SwiftUI
import Testing

/// Drives the two functions `ChipFlowLayout.sizeThatFits` and `placeSubviews` call, the way SwiftUI does:
/// measure for a proposal, then place with the same proposal into bounds the parent has snapped to the nearest
/// pixel (a third of a point on a 3x screen), which can be narrower than measured.
@Suite("Wrapping chip layout")
struct ChipFlowLayoutTests {
    private static let chipHeight: CGFloat = 30
    private static let pixel: CGFloat = 1.0 / 3

    /// A test chip at its ideal size. Offered less than its width, its label wraps to twice the height, but it
    /// never gets narrower than `minWidth` (a word that cannot break).
    private struct Chip {
        var width: CGFloat
        var height: CGFloat = chipHeight
        var minWidth: CGFloat = 0
    }

    private struct Rendering {
        var chips: [Chip]
        var measured: CGSize
        var bounds: CGRect
        var frames: [CGRect]

        /// Chip indices per line in placement order: a chip back at the leading edge starts a new line, whatever
        /// the chips' heights.
        var lines: [[Int]] {
            var lines: [[Int]] = []
            for index in frames.indices {
                if index == 0 || frames[index].minX <= frames[index - 1].minX {
                    lines.append([index])
                } else {
                    lines[lines.count - 1].append(index)
                }
            }
            return lines
        }

        /// Why this rendering breaks the layout contract, or nil.
        func violation(proposal: ProposedViewSize) -> String? {
            let everyChipFits = chips.allSatisfy { $0.minWidth <= (proposal.width ?? .infinity) }
            if let width = proposal.width, everyChipFits, measured.width > width {
                return "measured \(measured.width) wider than the proposed \(width)"
            }
            for frame in frames {
                if frame.minX < bounds.minX || frame.minY < bounds.minY
                    || frame.maxX > bounds.maxX + pixel || frame.maxY > bounds.maxY + pixel
                {
                    return "chip \(frame) outside the bounds \(bounds)"
                }
            }
            return nil
        }
    }

    private func render(_ chips: [Chip], proposal: ProposedViewSize) -> Rendering {
        let layout = ChipFlowLayout()
        let stub = ChipFlowLayout.Chips(idealSizes: chips.map { CGSize(width: $0.width, height: $0.height) }) {
            index, width in
            CGSize(width: max(width, chips[index].minWidth), height: chips[index].height * 2)
        }
        let measured = layout.measuredSize(proposal: proposal, chips: stub)
        let snapped = CGSize(
            width: (measured.width * 3).rounded() / 3,
            height: (measured.height * 3).rounded() / 3
        )
        let bounds = CGRect(origin: CGPoint(x: 16, y: 40), size: snapped)
        return Rendering(
            chips: chips,
            measured: measured,
            bounds: bounds,
            frames: layout.placements(in: bounds, proposal: proposal, chips: stub)
        )
    }

    private func render(_ widths: [CGFloat], proposal width: CGFloat?) -> Rendering {
        render(widths.map { Chip(width: $0) }, proposal: proposal(width))
    }

    private func proposal(_ width: CGFloat?) -> ProposedViewSize {
        ProposedViewSize(width: width, height: nil)
    }

    @Test("REQ-GRAMMAR-003: chips share a line while they fit; the chip that would overflow starts the next line")
    func breaksBeforeOverflow() {
        // 50 + 8 + 50 + 8 + 50 = 166.
        #expect(render([50, 50, 50], proposal: 166).lines == [[0, 1, 2]])
        #expect(render([50, 50, 50], proposal: 165).lines == [[0, 1], [2]])
        let twoLines = render([50, 50, 50, 50], proposal: 110)
        #expect(twoLines.lines == [[0, 1], [2, 3]])
        #expect(twoLines.measured == CGSize(width: 108, height: 68))
        #expect(render([50, 50, 50], proposal: nil).lines == [[0, 1, 2]])
        #expect(render([50, 50, 50], proposal: .infinity).lines == [[0, 1, 2]])
    }

    @Test("REQ-GRAMMAR-003: a chip wider than the line wraps its label on a line of its own and is never dropped")
    func overWideChip() {
        let rendering = render([30, 200, 30], proposal: 100)
        #expect(rendering.lines == [[0], [1], [2]])
        #expect(rendering.frames[1].size == CGSize(width: 100, height: 60))
        #expect(rendering.violation(proposal: proposal(100)) == nil)
        #expect(render([CGFloat](), proposal: 100).frames.isEmpty)
    }

    @Test("REQ-GRAMMAR-003: chips of different heights share a line, centred on it, and the next line starts below")
    func mixedHeightsShareALine() {
        let rendering = render(
            [Chip(width: 40), Chip(width: 40, height: 60), Chip(width: 80)],
            proposal: proposal(100)
        )
        #expect(rendering.lines == [[0, 1], [2]])
        #expect(rendering.frames[0].midY == rendering.frames[1].midY)
        #expect(rendering.frames[2].minY == rendering.frames[1].maxY + 8)
        #expect(rendering.violation(proposal: proposal(100)) == nil)
    }

    @Test("REQ-GRAMMAR-003: a chip that cannot shrink to the line is measured at the width it is placed at")
    func chipWiderThanItsOffer() {
        let rendering = render([Chip(width: 150, minWidth: 120)], proposal: proposal(100))
        #expect(rendering.frames.map(\.size) == [CGSize(width: 120, height: 60)])
        #expect(rendering.measured == CGSize(width: 120, height: 60))
        #expect(rendering.violation(proposal: proposal(100)) == nil)
    }

    @Test(
        "REQ-GRAMMAR-003: placement stays inside the measured size, which never exceeds the proposal",
        arguments: [
            // Found by review: measuring broke [[0], [1, 2]] at 200.333; placing there joined [0, 1].
            ([277.0 / 3, 301.0 / 3, 92], 200),
            // Found by review: a lone 187.4 pt chip placed at 187.333 was measured again, narrower and taller.
            // 187.4 snaps to 187.333 on a 3x screen.
            ([187.4], 300),
            ([187.4], nil),
        ] as [([CGFloat], CGFloat?)]
    )
    func reviewedCases(widths: [CGFloat], width: CGFloat?) {
        #expect(render(widths, proposal: width).violation(proposal: proposal(width)) == nil)
    }

    /// Widths within a point of the line-break boundaries, in thirds of a point, where rounding decides whether a
    /// chip joins a line.
    @Test("REQ-GRAMMAR-003: chip sets at the line-break boundaries keep the layout contract")
    func boundarySweep() {
        let line: CGFloat = 200
        let spacing: CGFloat = 8
        let nearBoundary = (-3 ... 3).map { CGFloat($0) / 3 }
        var violations: [String] = []
        func check(_ widths: [CGFloat], _ width: CGFloat?) {
            if let violation = render(widths, proposal: width).violation(proposal: proposal(width)) {
                violations.append("\(widths) at \(width.map { "\($0)" } ?? "nil"): \(violation)")
            }
        }
        // Pairs and triples whose neighbouring chips sum to within a point of the line: the first pair decides
        // one break, the second pair the next.
        for first in stride(from: CGFloat(80), through: 120, by: 1.0 / 3) {
            for offset in nearBoundary {
                let second = line - spacing - first + offset
                check([first, second], line)
                for nextOffset in nearBoundary {
                    check([first, second, line - spacing - second + nextOffset], line)
                }
            }
        }
        // Lone chips of any tenth of a point near a line width: a pixel-snapped bounds narrower than the chip
        // must not re-measure it.
        for tenth in 1870 ... 1890 {
            check([CGFloat(tenth) / 10], 300)
            check([CGFloat(tenth) / 10], nil)
        }
        #expect(violations.isEmpty, "\(violations.count) violations, e.g. \(violations.prefix(3))")
    }
}
