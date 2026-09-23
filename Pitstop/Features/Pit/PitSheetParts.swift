import SwiftUI

/// Pit's eyes beside the title that names the sheet's one moment (pit-behavior-and-motion.md, "Capture"). The eyes
/// stay `PitEyesGlyph` until the round head replaces them (RD-011).
struct PitMomentHeader: View {
    let title: PitMomentTitle
    let eyes: PitState
    var life: PitEyeLife = .still

    /// The mockup draws the eyes at 2.2 times the utility-layer mark, in a 44 pt slot like the head that follows.
    private static let eyeScale: CGFloat = 2.2
    private static let eyeSlot = CGSize(width: 52, height: 44)

    var body: some View {
        HStack(spacing: 12) {
            PitEyesGlyph(state: eyes, life: life)
                .scaleEffect(Self.eyeScale)
                .frame(width: Self.eyeSlot.width, height: Self.eyeSlot.height)
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
        let gaps = spacing * CGFloat(subviews.count - 1)
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let width = proposal.width ?? widest * CGFloat(subviews.count) + gaps
        let share = ProposedViewSize(width: (width - gaps) / CGFloat(subviews.count), height: nil)
        let height = subviews.map { $0.sizeThatFits(share).height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        guard !subviews.isEmpty else { return }
        let gaps = spacing * CGFloat(subviews.count - 1)
        let share = (bounds.width - gaps) / CGFloat(subviews.count)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + CGFloat(index) * (share + spacing), y: bounds.minY),
                proposal: ProposedViewSize(width: share, height: bounds.height)
            )
        }
    }
}

extension View {
    /// The moment's one prominent action: a filled capsule at the bottom of the sheet (mockup #pit).
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
