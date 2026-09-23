import SwiftUI

/// Chips left to right, starting a new line when the next chip would not fit, so a set of choices keeps every
/// label at accessibility sizes instead of truncating or scrolling off screen (REQ-GRAMMAR-003).
struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let sizes = Self.sizes(of: subviews, maxWidth: maxWidth)
        let lines = Self.lines(widths: sizes.map(\.width), maxWidth: maxWidth, spacing: spacing)
        var width: CGFloat = 0
        var height: CGFloat = 0
        for line in lines {
            let chipsWidth: CGFloat = line.reduce(0) { $0 + sizes[$1].width }
            let lineWidth = chipsWidth + spacing * CGFloat(line.count - 1)
            let lineHeight: CGFloat = line.reduce(0) { max($0, sizes[$1].height) }
            width = max(width, lineWidth)
            height += lineHeight
        }
        height += lineSpacing * CGFloat(max(lines.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let sizes = Self.sizes(of: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for line in Self.lines(widths: sizes.map(\.width), maxWidth: bounds.width, spacing: spacing) {
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

    /// Subview indices per line, in order. A chip wider than the line gets a line of its own.
    static func lines(widths: [CGFloat], maxWidth: CGFloat, spacing: CGFloat) -> [[Int]] {
        var lines: [[Int]] = []
        var current: [Int] = []
        var lineWidth: CGFloat = 0
        for (index, width) in widths.enumerated() {
            if !current.isEmpty, lineWidth + spacing + width > maxWidth {
                lines.append(current)
                current = []
                lineWidth = 0
            }
            lineWidth += current.isEmpty ? width : spacing + width
            current.append(index)
        }
        if !current.isEmpty {
            lines.append(current)
        }
        return lines
    }

    /// A chip wider than the line is offered the line's width, so its label wraps instead of running off.
    private static func sizes(of subviews: Subviews, maxWidth: CGFloat) -> [CGSize] {
        subviews.map { subview in
            let ideal = subview.sizeThatFits(.unspecified)
            guard ideal.width > maxWidth else { return ideal }
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
