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

    private struct Rendering {
        var measured: CGSize
        var bounds: CGRect
        var frames: [CGRect]

        /// Chip indices per line, top to bottom.
        var lines: [[Int]] {
            Dictionary(grouping: frames.indices) { frames[$0].minY }
                .sorted { $0.key < $1.key }
                .map { $0.value.sorted() }
        }

        /// Why this rendering breaks the layout contract, or nil.
        func violation(proposal: ProposedViewSize) -> String? {
            if let width = proposal.width, measured.width > width {
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

    /// Chips of the given widths, one line of text tall. A chip offered less than its ideal width wraps its label
    /// to two lines, as a Text does.
    private func render(_ widths: [CGFloat], proposal: ProposedViewSize) -> Rendering {
        let layout = ChipFlowLayout()
        let chips = ChipFlowLayout
            .Chips(idealSizes: widths.map { CGSize(width: $0, height: Self.chipHeight) }) { _, width in
                CGSize(width: width, height: Self.chipHeight * 2)
            }
        let measured = layout.measuredSize(proposal: proposal, chips: chips)
        let snapped = CGSize(
            width: (measured.width * 3).rounded() / 3,
            height: (measured.height * 3).rounded() / 3
        )
        let bounds = CGRect(origin: CGPoint(x: 16, y: 40), size: snapped)
        return Rendering(
            measured: measured,
            bounds: bounds,
            frames: layout.placements(in: bounds, proposal: proposal, chips: chips)
        )
    }

    private func proposal(_ width: CGFloat?) -> ProposedViewSize {
        ProposedViewSize(width: width, height: nil)
    }

    @Test("REQ-GRAMMAR-003: chips share a line while they fit; the chip that would overflow starts the next line")
    func breaksBeforeOverflow() {
        // 50 + 8 + 50 + 8 + 50 = 166.
        #expect(render([50, 50, 50], proposal: proposal(166)).lines == [[0, 1, 2]])
        #expect(render([50, 50, 50], proposal: proposal(165)).lines == [[0, 1], [2]])
        let twoLines = render([50, 50, 50, 50], proposal: proposal(110))
        #expect(twoLines.lines == [[0, 1], [2, 3]])
        #expect(twoLines.measured == CGSize(width: 108, height: 68))
        #expect(render([50, 50, 50], proposal: proposal(nil)).lines == [[0, 1, 2]])
        #expect(render([50, 50, 50], proposal: proposal(.infinity)).lines == [[0, 1, 2]])
    }

    @Test("REQ-GRAMMAR-003: a chip wider than the line wraps its label on a line of its own and is never dropped")
    func overWideChip() {
        let rendering = render([30, 200, 30], proposal: proposal(100))
        #expect(rendering.lines == [[0], [1], [2]])
        #expect(rendering.frames[1].size == CGSize(width: 100, height: 60))
        #expect(rendering.violation(proposal: proposal(100)) == nil)
        #expect(render([], proposal: proposal(100)).frames.isEmpty)
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
        let rendering = render(widths, proposal: proposal(width))
        #expect(rendering.violation(proposal: proposal(width)) == nil)
    }

    @Test("REQ-GRAMMAR-003: every chip set in thirds of a point keeps the layout contract")
    func sweepInThirds() {
        var violations: [String] = []
        func check(_ widths: [CGFloat], _ width: CGFloat?) {
            if let violation = render(widths, proposal: proposal(width)).violation(proposal: proposal(width)) {
                violations.append("\(widths) at \(width.map { "\($0)" } ?? "nil"): \(violation)")
            }
        }
        // Every pair around a 200 pt line, one third apart.
        let pairThirds = (150 ... 450).map { CGFloat($0) / 3 }
        for first in pairThirds {
            for second in pairThirds {
                check([first, second], 200)
            }
        }
        // Every triple near the reviewed case, one third apart.
        let nearThirds = (270 ... 310).map { CGFloat($0) / 3 }
        for first in nearThirds {
            for second in nearThirds {
                for third in nearThirds {
                    check([first, second, third], 200)
                }
            }
        }
        // A wider spread of triples and lone chips, unbounded and bounded.
        let spread = stride(from: 61, through: 601, by: 7).map { CGFloat($0) / 3 }
        for first in spread {
            check([first], 150)
            for second in spread {
                for third in spread where third < 120 {
                    check([first, second, third], nil)
                    check([first, second, third], 200)
                }
            }
        }
        #expect(violations.isEmpty, "\(violations.count) violations, e.g. \(violations.prefix(3))")
    }
}
