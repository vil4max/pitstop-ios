import SwiftUI

/// The car on its stage, one mileage line and one edit action. The name is the screen header above it; no
/// technical specifications appear here (REQ-BOARD-017).
struct CarHeroView: View {
    let car: ProvisionalCarContext
    let mileage: CarBoardMileage
    /// Nil when no mileage observation exists: then there is no age to show (REQ-BOARD-027).
    let recency: MileageRecency?
    let onEdit: () -> Void

    var body: some View {
        StageSurface {
            VStack(alignment: .leading, spacing: 12) {
                stagedCar
                // Widest first; long translations and accessibility sizes fall through to the stacked forms.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 10) {
                        mileageLine(isStacked: false)
                        Spacer(minLength: 8)
                        editAction
                    }
                    HStack(alignment: .center, spacing: 10) {
                        mileageLine(isStacked: true)
                        Spacer(minLength: 8)
                        editAction
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        mileageLine(isStacked: true)
                        editAction
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("carBoard.hero")
    }

    /// The car standing on a dashed horizon, the stage's only drawing. Decorative: the screen title names the
    /// car (REQ-BOARD-024).
    private var stagedCar: some View {
        AbstractCarView()
            .frame(maxWidth: .infinity, maxHeight: DesignTokens.heroCarMaxHeight)
            .padding(.top, 4)
            .background(alignment: .bottom) {
                HorizonLine()
                    .stroke(
                        PitColor.contentTertiary,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 6])
                    )
                    .frame(height: 1.5)
                    // Behind the car and level with the bottom of its wheels, so they stand on it.
                    .padding(.bottom, 1)
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func mileageLine(isStacked: Bool) -> some View {
        switch mileage {
        case .unknown:
            // A label, never 0 km, and no age: there is nothing to date (REQ-BOARD-004, REQ-BOARD-027).
            Text("carBoard.mileage.unknown")
                .font(PitTypography.headline.weight(.medium))
                .foregroundStyle(PitColor.contentSecondary)
                .fixedSize(horizontal: false, vertical: isStacked)
                .lineLimit(isStacked ? nil : 1)
        case let .kilometers(value):
            let layout = isStacked
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
            layout {
                FeatureFormat.mileage(value)
                    .font(PitTypography.title)
                    .monospacedDigit()
                    .foregroundStyle(PitColor.contentPrimary)
                if let recency {
                    recency.text
                        .font(PitTypography.supportingSmall.weight(.medium))
                        .foregroundStyle(PitColor.contentSecondary)
                }
            }
            .lineLimit(isStacked ? nil : 1)
            .fixedSize(horizontal: false, vertical: isStacked)
            // One spoken line: "47 560 km, updated 9 days ago".
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var editAction: some View {
        if car.isProvisional {
            // One useful next action instead of a setup checklist (sparse data policy).
            Button(action: onEdit) {
                Label("carBoard.hero.name", systemImage: "pencil")
                    .font(PitTypography.supporting.weight(.semibold))
                    .foregroundStyle(PitColor.accentPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(PitColor.surfaceTint, in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityHint("carBoard.hero.editHint")
            .accessibilityIdentifier("carBoard.hero.edit")
        } else {
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(PitTypography.supporting.weight(.semibold))
                    .foregroundStyle(PitColor.contentPrimary)
                    .frame(width: 36, height: 36)
                    .pitGlass(in: .circle)
                    // The glass looks 36 pt; the target keeps the 44 pt minimum (REQ-GRAMMAR-003).
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            // A toolbar-sized glyph: it does not grow with text, as the utility circles do not.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityLabel("common.edit")
            .accessibilityHint("carBoard.hero.editHint")
            .accessibilityIdentifier("carBoard.hero.edit")
        }
    }
}

private struct HorizonLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

#if DEBUG
    #Preview("Car hero") {
        PreviewMatrix {
            VStack(spacing: 16) {
                CarHeroView(
                    car: ProvisionalCarContext(
                        vehicle: Vehicle(id: Vehicle.provisionalID, name: "Kestrel"),
                        observedKm: 47560
                    ),
                    mileage: .kilometers(47560),
                    recency: .days(9),
                    onEdit: {}
                )
                CarHeroView(car: .firstLaunch, mileage: .unknown, recency: nil, onEdit: {})
            }
        }
    }
#endif
