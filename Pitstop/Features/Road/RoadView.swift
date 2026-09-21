import SwiftUI

struct RoadView: View {
    let viewModel: RoadViewModel
    let carName: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: String? = RoadLaneView.carID

    var body: some View {
        FeatureScaffold(carName: carName, title: String(localized: "tile.road.title")) {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                if viewModel.state.isLoadFailed {
                    HStack {
                        Label("road.load.failed", systemImage: "exclamationmark.arrow.circlepath")
                            .font(.footnote)
                            .foregroundStyle(PitColor.contentSecondary)
                        Spacer()
                        Button("carBoard.load.retry") {
                            Task { await viewModel.load() }
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }
                if let projection = viewModel.state.projection {
                    content(projection)
                }
            }
        }
        .task {
            // Every visit starts at the car (ADR 0008, INV-ROAD-004); reset before loading so a slow load
            // never pulls the lane back from under the user's finger.
            position = RoadLaneView.carID
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func content(_ projection: RoadProjection) -> some View {
        if !projection.isCompletelyEmpty {
            projection.summaryText
                .font(.body)
                .foregroundStyle(PitColor.contentSecondary)
        }

        if projection.isCompletelyEmpty {
            ContentUnavailableView {
                Label("tile.road.empty.headline", systemImage: "road.lanes")
            } description: {
                Text("tile.road.empty.detail")
            }
            .frame(maxWidth: .infinity)
        } else if !projection.slots.isEmpty {
            lane(projection)
            milestoneList(projection)
        }
        if !projection.waitingForMileage.isEmpty {
            waiting(projection.waitingForMileage)
        }
        if let past = projection.past {
            Label {
                Text("road.past \(past.count) \(past.latestDate.formatted(date: .abbreviated, time: .omitted))")
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .font(.footnote)
            .foregroundStyle(PitColor.contentSecondary)
        }
    }

    private func lane(_ projection: RoadProjection) -> some View {
        TileCard(minHeight: 0) {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    RoadLaneView(slots: projection.slots, isScrollTarget: true)
                        .padding(.vertical, 4)
                }
                .scrollPosition(id: $position, anchor: .leading)
                .pitReportsScrolling()
                // The drawing is decoration for VoiceOver; the summary and the list carry the meaning.
                .accessibilityHidden(true)

                if position != RoadLaneView.carID {
                    Button("road.backToNow", systemImage: "arrow.uturn.left") {
                        if reduceMotion {
                            position = RoadLaneView.carID
                        } else {
                            withAnimation(.snappy) { position = RoadLaneView.carID }
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .accessibilityIdentifier("road.backToNow")
                }
            }
        }
    }

    /// The same milestones as text, in the same order: meaning never depends on the drawing.
    private func milestoneList(_ projection: RoadProjection) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
            ForEach(projection.slots) { slot in
                ForEach(slot.milestones) { milestone in
                    MilestoneRow(milestone: milestone)
                }
            }
        }
    }

    private func waiting(_ milestones: [RoadMilestone]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
            Text("road.waiting.title")
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            ForEach(milestones) { MilestoneRow(milestone: $0) }
        }
    }
}

private struct MilestoneRow: View {
    let milestone: RoadMilestone

    var body: some View {
        TileCard(minHeight: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: milestone.state.systemImage)
                    .foregroundStyle(milestone.state.color)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    milestone.titleText
                        .font(.headline)
                        .foregroundStyle(PitColor.contentPrimary)
                    if milestone.remainingKm != nil || milestone.remainingDays != nil {
                        Text(milestone.state.label)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(milestone.state.color)
                    }
                    milestone.distanceText
                        .font(.footnote)
                        .foregroundStyle(PitColor.contentSecondary)
                    if milestone.mileageDependency != nil, milestone.remainingDays != nil {
                        Text("road.milestone.byDateOnly")
                            .font(.footnote)
                            .foregroundStyle(PitColor.contentSecondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
