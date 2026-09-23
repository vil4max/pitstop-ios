import SwiftUI

/// The named steps of a multi-step sheet. Labels wrap to a column rather than truncate.
struct StepStrip: View {
    let steps: [Text]
    let current: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { stepViews(wrapping: false) }
            // In the column a label wider than the sheet wraps instead of running off the edge.
            VStack(alignment: .leading, spacing: 6) { stepViews(wrapping: true) }
        }
        .accessibilityElement(children: .contain)
    }

    private func stepViews(wrapping: Bool) -> some View {
        ForEach(steps.indices, id: \.self) { index in
            let isCurrent = index == current
            steps[index]
                .font(PitTypography.captionSmall.weight(.semibold))
                .lineLimit(wrapping ? nil : 1)
                .fixedSize(horizontal: !wrapping, vertical: true)
                .foregroundStyle(isCurrent ? PitColor.contentOnAccent : PitColor.contentSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(isCurrent ? PitColor.accentPrimary : PitColor.surfaceElevated, in: .capsule)
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
        }
    }
}

#if DEBUG
    #Preview("Step strip") {
        PreviewMatrix {
            StepStrip(
                steps: ["Choose", "Intervals", "Confirm", "Result"].map { Text(verbatim: $0) },
                current: 1
            )
        }
    }
#endif
