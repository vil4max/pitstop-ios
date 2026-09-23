import SwiftUI

/// Pit's head beside the title that names the sheet's one moment (pit-behavior-and-motion.md, "Capture").
struct PitMomentHeader: View {
    let title: PitMomentTitle
    let eyes: PitState
    var life: PitEyeLife = .still

    var body: some View {
        HStack(spacing: 12) {
            // Fixed size at every text size, like the utility circle.
            PitHead(state: eyes, life: life, size: DesignTokens.pitHeaderHeadSize)
            Text(title.key)
                .font(.title2.bold())
                .foregroundStyle(title == .saved ? PitColor.statusUpToDate : PitColor.contentPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// The user's own words, quoted quietly before anything PitStop made of them (REQ-CAPTURE-016).
struct PitQuotedWords: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(PitTypography.supporting)
            .foregroundStyle(PitColor.contentSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 13)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(PitColor.contentTertiary)
                    .frame(width: 3)
                    .accessibilityHidden(true)
            }
    }
}

/// The sheet's calm card for Pit's question and for a confirmation: the secondary surface on the sheet's
/// primary one.
struct PitSheetCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PitColor.surfaceSecondary, in: shape)
        .overlay(shape.strokeBorder(PitColor.separator.opacity(0.35), lineWidth: DesignTokens.hairline))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
    }
}

/// Plain choices for the capture's one clarification, as full-width rows of one grouped list; nothing becomes
/// icon-only at large text sizes.
struct PitChoiceList: View {
    let choices: [PitChoice]
    let onChoose: (ClarificationAnswer) -> Void

    var body: some View {
        GroupedSection {
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                Button {
                    onChoose(choice.answer)
                } label: {
                    choice.label
                        .font(PitTypography.body)
                        .foregroundStyle(PitColor.contentPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.vertical, 4)
                        .padding(.horizontal, DesignTokens.groupedRowPadding)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .groupedRowSeparator(index > 0)
            }
        }
    }
}

struct PitChoice {
    let label: Text
    let answer: ClarificationAnswer
}

/// A full-width action label. The prominent one uses `contentOnAccent`, which stays legible on the pale dark-mode
/// accent; a disabled button keeps the style's own dimmed label on its grey fill. A compact label is for a pair of
/// small side-by-side actions, such as the question card's decline buttons.
struct PitActionLabel: View {
    let title: LocalizedStringKey
    var prominent = false
    var compact = false

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Group {
            if prominent, isEnabled {
                Text(title).foregroundStyle(PitColor.contentOnAccent)
            } else {
                Text(title)
            }
        }
        .font(compact ? PitTypography.supporting.weight(.semibold) : PitTypography.headline)
        .frame(maxWidth: .infinity)
    }
}

/// Children side by side at equal widths. Its ideal width is the widest child's ideal width times the count, so a
/// `ViewThatFits` moves on to a stacked layout before any label would have to wrap inside its equal share.
struct PitEqualWidthRow: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let width = Self.width(
            proposed: proposal.width,
            idealWidths: subviews.map { $0.sizeThatFits(.unspecified).width },
            spacing: spacing
        )
        let share = ProposedViewSize(width: Self.share(of: width, count: subviews.count, spacing: spacing), height: nil)
        let height = subviews.map { $0.sizeThatFits(share).height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        guard !subviews.isEmpty else { return }
        let share = Self.share(of: bounds.width, count: subviews.count, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + CGFloat(index) * (share + spacing), y: bounds.minY),
                proposal: ProposedViewSize(width: share, height: bounds.height)
            )
        }
    }

    /// The widest child's ideal width times the count, plus the gaps: the narrowest row in which no child is squeezed
    /// below its ideal width.
    static func idealWidth(of idealWidths: [CGFloat], spacing: CGFloat) -> CGFloat {
        guard let widest = idealWidths.max() else { return 0 }
        return widest * CGFloat(idealWidths.count) + spacing * CGFloat(idealWidths.count - 1)
    }

    /// A finite proposal is taken as given; no proposal or an infinite one gets the ideal width, so the row never
    /// reports an infinite size.
    static func width(proposed: CGFloat?, idealWidths: [CGFloat], spacing: CGFloat) -> CGFloat {
        if let proposed, proposed.isFinite {
            return max(0, proposed)
        }
        return idealWidth(of: idealWidths, spacing: spacing)
    }

    /// Each child's equal share, never negative when the row is narrower than its gaps.
    static func share(of width: CGFloat, count: Int, spacing: CGFloat) -> CGFloat {
        guard count > 0 else { return 0 }
        return max(0, (width - spacing * CGFloat(count - 1)) / CGFloat(count))
    }
}

extension View {
    /// The moment's one prominent action as a filled capsule (mockup #pit), wherever it sits: for example Remember
    /// while the user writes, the question card's Save, or the confirmation's "Yes, save it".
    func pitPrimaryAction() -> some View {
        buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(PitColor.accentPrimary)
    }

    /// Any other action in the sheet: the same capsule on a quiet fill; `.regular` for a compact pair.
    func pitSecondaryAction(size: ControlSize = .large) -> some View {
        buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(size)
            .tint(PitColor.accentPrimary)
    }
}

#if DEBUG
    #Preview("Pit sheet parts") {
        PreviewMatrix {
            VStack(alignment: .leading, spacing: 16) {
                PitMomentHeader(title: .remember, eyes: .fixedGaze)
                PitMomentHeader(title: .isThisRight, eyes: .sideGaze)
                PitMomentHeader(title: .oneThing, eyes: .knock)
                PitMomentHeader(title: .saved, eyes: .closedEyes)
                PitSheetCard {
                    PitQuotedWords(text: "changed the oil today at 47 560, 240 at the dealer")
                    Text(verbatim: "Service done: Engine oil service").font(PitTypography.headline)
                    Text(verbatim: "At 47 560 km")
                        .font(PitTypography.supporting)
                        .foregroundStyle(PitColor.contentSecondary)
                }
                PitChoiceList(
                    choices: [
                        PitChoice(label: Text(verbatim: "Cabin filter"), answer: .unknown),
                        PitChoice(label: Text(verbatim: "Air filter"), answer: .unknown),
                    ],
                    onChoose: { _ in }
                )
                Button {} label: { PitActionLabel(title: "pit.save", prominent: true) }
                    .pitPrimaryAction()
                Button {} label: { PitActionLabel(title: "pit.save", prominent: true) }
                    .pitPrimaryAction()
                    .disabled(true)
                Button {} label: { PitActionLabel(title: "pit.confirm.asNote") }
                    .pitSecondaryAction()
            }
        }
    }
#endif
