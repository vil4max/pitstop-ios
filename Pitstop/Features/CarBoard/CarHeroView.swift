import SwiftUI

/// Car visual and its one supporting line. The name is the screen header above it; no technical
/// specifications appear here (REQ-BOARD-017).
struct CarHeroView: View {
    let car: ProvisionalCarContext
    let mileage: CarBoardMileage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AbstractCarView()
                .frame(maxWidth: .infinity, maxHeight: DesignTokens.heroCarMaxHeight)
                .padding(.horizontal, 8)
                .padding(.top, 4)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    mileageLabel
                    Spacer(minLength: 8)
                    nameAction
                }
                VStack(alignment: .leading, spacing: 4) {
                    mileageLabel
                    nameAction
                }
            }
        }
    }

    private var mileageLabel: some View {
        mileageText
            .font(.subheadline)
            .foregroundStyle(PitColor.contentSecondary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var nameAction: some View {
        if car.isProvisional {
            // One useful next action instead of a setup checklist (sparse data policy).
            Label("carBoard.hero.name", systemImage: "pencil")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PitColor.accentPrimary)
                .lineLimit(1)
        }
    }

    private var mileageText: Text {
        switch mileage {
        case .unknown:
            Text("carBoard.mileage.unknown")
        case let .kilometers(value):
            Text("carBoard.mileage.km \(value)")
        }
    }
}
