import SwiftUI

/// Chips left to right, starting a new line when the next chip would not fit, so a set of choices keeps every
/// label at accessibility sizes instead of truncating or scrolling off screen (REQ-GRAMMAR-003).
struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    /// Line breaks for chips of given widths, and the width of the widest line.
    struct Arrangement: Equatable {
        var lines: [[Int]] = []
        var width: CGFloat = 0
    }

    /// How far a line may exceed the width it is broken for. The parent may hand the measured width back
    /// rounded to the pixel grid; without this a chip could drop to a line the measured height does not include.
    static let overhangTolerance: CGFloat = 0.5

    /// The one line-breaking routine for measuring and placing. The reported width is the running line width
    /// the breaks were decided with, summed in the same order, so breaking again at that width gives the same
    /// lines. A chip wider than the line gets a line of its own.
    static func arrange(widths: [CGFloat], maxWidth: CGFloat, spacing: CGFloat) -> Arrangement {
        var arrangement = Arrangement()
        var current: [Int] = []
        var lineWidth: CGFloat = 0
        for (index, width) in widths.enumerated() {
            if current.isEmpty {
                lineWidth = width
            } else {
                let extended = lineWidth + spacing + width
                if extended > maxWidth + overhangTolerance {
                    arrangement.lines.append(current)
                    arrangement.width = max(arrangement.width, lineWidth)
                    current = []
                    lineWidth = width
                } else {
                    lineWidth = extended
                }
            }
            current.append(index)
        }
        if !current.isEmpty {
            arrangement.lines.append(current)
            arrangement.width = max(arrangement.width, lineWidth)
        }
        return arrangement
    }

    /// Each chip's ideal size, measured once per layout pass.
    func makeCache(subviews: Subviews) -> [CGSize] {
        subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let sizes = Self.sizes(of: subviews, ideal: cache, maxWidth: maxWidth)
        let arrangement = Self.arrange(widths: sizes.map(\.width), maxWidth: maxWidth, spacing: spacing)
        var height: CGFloat = 0
        for line in arrangement.lines {
            height += line.reduce(0) { max($0, sizes[$1].height) }
        }
        height += lineSpacing * CGFloat(max(arrangement.lines.count - 1, 0))
        return CGSize(width: arrangement.width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]) {
        let sizes = Self.sizes(of: subviews, ideal: cache, maxWidth: bounds.width)
        let arrangement = Self.arrange(widths: sizes.map(\.width), maxWidth: bounds.width, spacing: spacing)
        var y = bounds.minY
        for line in arrangement.lines {
            let height: CGFloat = line.reduce(0) { max($0, sizes[$1].height) }
            var x = bounds.minX
            for index in line {
                let size = sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += height + lineSpacing
        }
    }

    /// A chip wider than the line is offered the line's width, so its label wraps instead of running off.
    private static func sizes(of subviews: Subviews, ideal: [CGSize], maxWidth: CGFloat) -> [CGSize] {
        zip(subviews, ideal).map { subview, size in
            guard size.width > maxWidth else { return size }
            return subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
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
