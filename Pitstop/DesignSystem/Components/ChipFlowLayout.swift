import SwiftUI

/// Chips left to right, starting a new line when the next chip would not fit, so a set of choices keeps every
/// label at accessibility sizes instead of truncating or scrolling off screen (REQ-GRAMMAR-003).
///
/// Both layout passes decide from the same input, the proposed width: SwiftUI hands `placeSubviews` the proposal
/// it measured with, while `bounds` may be that size rounded to the pixel grid. Identical inputs give identical
/// lines and chip sizes, so placement never adds a line or a taller chip the measured size does not include.
struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    /// The chips as the layout sees them: each one's ideal size, and its size when offered a narrower width.
    struct Chips {
        var idealSizes: [CGSize]
        var sizeAtWidth: (_ index: Int, _ width: CGFloat) -> CGSize
    }

    /// Each chip's ideal size, measured once per layout pass.
    func makeCache(subviews: Subviews) -> [CGSize] {
        subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]) -> CGSize {
        measuredSize(proposal: proposal, chips: chips(subviews, cache))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]) {
        for (index, frame) in placements(in: bounds, proposal: proposal, chips: chips(subviews, cache)).enumerated() {
            subviews[index].place(at: frame.origin, proposal: ProposedViewSize(frame.size))
        }
    }

    /// What `sizeThatFits` reports. Never wider than a finite proposal.
    func measuredSize(proposal: ProposedViewSize, chips: Chips) -> CGSize {
        plan(proposedWidth: proposal.width, chips: chips).size
    }

    /// Where `placeSubviews` puts each chip: the plan for the same proposal, offset to the bounds' origin. The
    /// bounds' size takes no part in the decision.
    func placements(in bounds: CGRect, proposal: ProposedViewSize, chips: Chips) -> [CGRect] {
        plan(proposedWidth: proposal.width, chips: chips).frames.map { $0.offsetBy(dx: bounds.minX, dy: bounds.minY) }
    }

    /// Chip frames from the top-leading corner and the size they cover. A missing or infinite width is one
    /// unbounded line. A chip wider than a finite line is measured at the line's width, so its label wraps, and
    /// gets a line of its own.
    private func plan(proposedWidth: CGFloat?, chips: Chips) -> (frames: [CGRect], size: CGSize) {
        let maxWidth = proposedWidth ?? .infinity
        let sizes = chips.idealSizes.indices.map { index in
            let ideal = chips.idealSizes[index]
            return ideal.width > maxWidth ? chips.sizeAtWidth(index, maxWidth) : ideal
        }

        var lines: [[Int]] = []
        var current: [Int] = []
        var lineWidth: CGFloat = 0
        for (index, size) in sizes.enumerated() {
            if !current.isEmpty, lineWidth + spacing + size.width > maxWidth {
                lines.append(current)
                current = []
            }
            lineWidth = current.isEmpty ? size.width : lineWidth + spacing + size.width
            current.append(index)
        }
        if !current.isEmpty {
            lines.append(current)
        }

        var frames = Array(repeating: CGRect.zero, count: sizes.count)
        var width: CGFloat = 0
        var y: CGFloat = 0
        for (lineIndex, line) in lines.enumerated() {
            let height: CGFloat = line.reduce(0) { max($0, sizes[$1].height) }
            var x: CGFloat = 0
            for index in line {
                let size = sizes[index]
                frames[index] = CGRect(origin: CGPoint(x: x, y: y + (height - size.height) / 2), size: size)
                width = max(width, x + size.width)
                x += size.width + spacing
            }
            y += height
            if lineIndex < lines.count - 1 {
                y += lineSpacing
            }
        }
        return (frames, CGSize(width: min(width, maxWidth), height: y))
    }

    private func chips(_ subviews: Subviews, _ idealSizes: [CGSize]) -> Chips {
        Chips(idealSizes: idealSizes) { index, width in
            subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
        }
    }
}

#if DEBUG
    #Preview("Chip flow layout") {
        PreviewMatrix {
            ChipFlowLayout {
                ForEach(["5 000 km", "7 500 km", "10 000 km", "15 000 km"], id: \.self) { label in
                    Text(verbatim: label)
                        .font(PitTypography.supportingSmall)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(PitColor.surfaceTint, in: .capsule)
                }
            }
        }
    }
#endif
