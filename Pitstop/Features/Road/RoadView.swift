import SwiftUI

struct RoadView: View {
    let viewModel: RoadViewModel
    let carName: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: String? = RoadLaneView.carID
    @State private var editor: PlannedEditorTarget?
    /// The alert keeps its title while it animates out, after the view model has cleared the failure.
    @State private var shownFailure: RoadFailure?

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("road.addDate", systemImage: "calendar.badge.plus") { editor = .new }
                    .accessibilityIdentifier("road.addDate")
            }
        }
        .pitActivity(
            .modalTask,
            while: editor != nil || viewModel.state.deleteCandidate != nil || listFailureBinding.wrappedValue
        )
        .plannedEventDeleteConfirmation(viewModel)
        .alert("road.failure.notSaved", isPresented: listFailureBinding) {
            Button("common.ok") { viewModel.dismissFailure() }
        }
        .sheet(item: $editor) { target in
            PlannedEventEditorView(
                draft: target.event.map(viewModel.draft(for:)) ?? viewModel.newDraft(),
                isNew: target == .new,
                kinds: viewModel.canChooseInsurance(editing: target.event)
                    ? PlannedEventDraft.Kind.allCases : [.other],
                dateRange: viewModel.dateRange(editing: target.event)
            ) { draft in
                await viewModel.save(draft, replacing: target.event)
            }
            .alert(
                (viewModel.state.failure ?? shownFailure)?.title ?? "road.failure.notSaved",
                isPresented: failureBinding
            ) {
                Button("common.ok") { viewModel.dismissFailure() }
            }
        }
        .onChange(of: viewModel.state.failure) { _, failure in
            if let failure {
                shownFailure = failure
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
            } actions: {
                Button("road.addDate") { editor = .new }
                    .buttonStyle(.borderedProminent)
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
                    MilestoneRow(
                        milestone: milestone,
                        planned: plannedEvent(for: milestone),
                        onEdit: { editor = .existing($0) },
                        onDelete: { viewModel.requestDelete($0) }
                    )
                }
            }
        }
    }

    private func plannedEvent(for milestone: RoadMilestone) -> PlannedDatedEvent? {
        guard case let .planned(_, id) = milestone.subject else { return nil }
        return viewModel.state.plannedEvent(id: id)
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.failure != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissFailure()
                }
            }
        )
    }

    private var listFailureBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.listFailure != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissFailure()
                }
            }
        )
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

enum PlannedEditorTarget: Identifiable, Equatable {
    case new
    case existing(PlannedDatedEvent)

    var id: String {
        switch self {
        case .new: "new"
        case let .existing(event): event.id.uuidString
        }
    }

    var event: PlannedDatedEvent? {
        if case let .existing(event) = self {
            event
        } else {
            nil
        }
    }
}

private struct MilestoneRow: View {
    let milestone: RoadMilestone
    /// Set for a planned date the owner stated; only those can be edited or deleted here (ADR 0032).
    var planned: PlannedDatedEvent?
    var onEdit: (PlannedDatedEvent) -> Void = { _ in }
    var onDelete: (PlannedDatedEvent) -> Void = { _ in }

    var body: some View {
        TileCard(minHeight: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                details
                if let planned {
                    Spacer(minLength: 0)
                    Menu("service.more", systemImage: "ellipsis.circle") {
                        Button("common.edit", systemImage: "pencil") { onEdit(planned) }
                            .accessibilityIdentifier("road.planned.edit")
                        Button("road.planned.delete", systemImage: "trash", role: .destructive) {
                            onDelete(planned)
                        }
                        .accessibilityIdentifier("road.planned.delete")
                    }
                    .labelStyle(.iconOnly)
                    .font(.subheadline)
                }
            }
        }
    }

    /// The text reads as one element; for a planned date the same actions are offered to VoiceOver on it.
    private var details: some View {
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
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            if let planned {
                Button("common.edit") { onEdit(planned) }
                Button("road.planned.delete") { onDelete(planned) }
            }
        }
    }
}
