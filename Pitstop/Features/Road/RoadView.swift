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
                    LoadFailureBanner(message: "road.load.failed") { await viewModel.load() }
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
            FeatureEmptyState(title: "tile.road.empty.headline", systemImage: "road.lanes", topPadding: 0) {
                Text("tile.road.empty.detail")
            } actions: {
                Button("road.addDate") { editor = .new }
                    .buttonStyle(.borderedProminent)
            }
        } else if !projection.slots.isEmpty {
            lane(projection)
        }
        let list = RoadMilestoneList(projection)
        if !list.ahead.isEmpty {
            milestoneSection("road.ahead.title", list.ahead)
        }
        if !list.waiting.isEmpty {
            milestoneSection("road.waiting.title", list.waiting)
        }
        if let past = projection.past {
            // The compact history marker (REQ-ROAD-010): one entry that points to History, never a list.
            Label {
                Text("road.past \(past.count) \(past.latestDate.formatted(date: .abbreviated, time: .omitted))")
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .font(PitTypography.supportingSmall)
            .foregroundStyle(PitColor.contentSecondary)
        }
    }

    /// The stage tier (ADR 0038): the car and its road on the tint, with "Back to now" as a glass pill inside
    /// it once the lane has left the car (REQ-ROAD-028).
    private func lane(_ projection: RoadProjection) -> some View {
        StageSurface {
            VStack(alignment: .trailing, spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    RoadLaneView(slots: projection.slots)
                        // Labels keep growing to the first accessibility size and then wrap in their slot;
                        // past it one slot would outgrow the screen. The list below keeps every size.
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .padding(.vertical, 4)
                }
                .scrollPosition(id: $position, anchor: .leading)
                // The lane scrolls to the stage's rounded edge instead of stopping at its padding.
                .scrollClipDisabled()
                .pitReportsScrolling()
                // The drawing is decoration for VoiceOver; the summary and the list carry the meaning.
                .accessibilityHidden(true)

                if RoadBackToNow.isShown(scrollPosition: position) {
                    GlassPill(title: Text("road.backToNow"), systemImage: "arrow.uturn.backward") {
                        withAnimation(RoadBackToNow.animation(reduceMotion: reduceMotion)) {
                            position = RoadLaneView.carID
                        }
                    }
                    .accessibilityIdentifier("road.backToNow")
                }
            }
        }
    }

    /// The same milestones as text, in the same order: meaning never depends on the drawing (REQ-ROAD-027).
    private func milestoneSection(_ title: LocalizedStringKey, _ milestones: [RoadMilestone]) -> some View {
        RoadListSection(title: title) {
            ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                if index > 0 {
                    RoadListSeparator()
                }
                MilestoneRow(
                    milestone: milestone,
                    planned: plannedEvent(for: milestone),
                    onEdit: { editor = .existing($0) },
                    onDelete: { viewModel.requestDelete($0) }
                )
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

/// One inset-grouped container per section (ADR 0038): a heading, then rows separated by hairlines on one
/// calm surface, not a card per row.
private struct RoadListSection<Rows: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(PitTypography.title)
                .foregroundStyle(PitColor.contentPrimary)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) {
                rows
            }
            .background(PitColor.surfaceSecondary, in: shape)
            .overlay(shape.strokeBorder(PitColor.separator.opacity(0.35), lineWidth: DesignTokens.hairline))
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: RoadListMetrics.cornerRadius, style: .continuous)
    }
}

private enum RoadListMetrics {
    static let cornerRadius: CGFloat = 20
    static let rowPadding: CGFloat = 16
    static let glyphColumn: CGFloat = 20
    static let glyphSpacing: CGFloat = 12
}

/// Starts under the row text, past the glyph column, as a native inset list separator does.
private struct RoadListSeparator: View {
    var body: some View {
        Rectangle()
            .fill(PitColor.separator)
            .frame(height: DesignTokens.hairline)
            .padding(.leading, RoadListMetrics.rowPadding + RoadListMetrics.glyphColumn + RoadListMetrics.glyphSpacing)
            .accessibilityHidden(true)
    }
}

private struct MilestoneRow: View {
    let milestone: RoadMilestone
    /// Set for a planned date the owner stated; only those can be edited or deleted here (ADR 0032).
    var planned: PlannedDatedEvent?
    var onEdit: (PlannedDatedEvent) -> Void = { _ in }
    var onDelete: (PlannedDatedEvent) -> Void = { _ in }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var glyphSize: CGFloat = 13
    /// Half the headline's cap height: it centres the glyph on the title's first line.
    @ScaledMetric(relativeTo: .headline) private var glyphLift: CGFloat = 6

    var body: some View {
        // At accessibility sizes the more menu moves under the text, so the text keeps the row's width.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        layout {
            details
            if let planned {
                moreMenu(planned)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, RoadListMetrics.rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The text reads as one element; for a planned date the same actions are offered to VoiceOver on it.
    private var details: some View {
        // Read on the main actor: the alignment closure below is Sendable.
        let lift = glyphLift
        return HStack(alignment: .firstTextBaseline, spacing: RoadListMetrics.glyphSpacing) {
            StatusGlyphView(glyph: milestone.glyph, size: glyphSize)
                .foregroundStyle(milestone.color)
                .frame(width: max(RoadListMetrics.glyphColumn, glyphSize))
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + lift }
            VStack(alignment: .leading, spacing: 3) {
                milestone.titleText
                    .font(PitTypography.headline)
                    .foregroundStyle(PitColor.contentPrimary)
                // The state word is the chip pattern's word: the colour and the glyph beside it say the same.
                if milestone.remainingKm != nil || milestone.remainingDays != nil {
                    Text(milestone.state.label)
                        .font(PitTypography.supporting.weight(.semibold))
                        .foregroundStyle(milestone.color)
                }
                milestone.distanceText
                    .font(PitTypography.supportingSmall)
                    .foregroundStyle(PitColor.contentSecondary)
                if let estimate = milestone.estimate {
                    RoadEstimateLine(range: estimate)
                }
                if milestone.mileageDependency != nil, milestone.remainingDays != nil {
                    Text("road.milestone.byDateOnly")
                        .font(PitTypography.supportingSmall)
                        .foregroundStyle(PitColor.contentSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            if let planned {
                Button("common.edit") { onEdit(planned) }
                Button("road.planned.delete") { onDelete(planned) }
            }
        }
    }

    private func moreMenu(_ planned: PlannedDatedEvent) -> some View {
        Menu {
            Button("common.edit", systemImage: "pencil") { onEdit(planned) }
                .accessibilityIdentifier("road.planned.edit")
            Button("road.planned.delete", systemImage: "trash", role: .destructive) {
                onDelete(planned)
            }
            .accessibilityIdentifier("road.planned.delete")
        } label: {
            Label("service.more", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .font(PitTypography.headline)
                .foregroundStyle(PitColor.accentPrimary)
                // The glyph is small; the target keeps the 44 pt minimum (REQ-GRAMMAR-003).
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        // Beside the text the target overhangs into the row padding, so the glyph lines up with the title.
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 0 : -10)
    }
}

#if DEBUG
    #Preview("Road milestone list") {
        let now = Date.now
        let road = RoadProjector().project(RoadContext(
            now: now,
            maintenanceStates: [],
            plannedEvents: [
                PlannedVehicleEvent(kind: .insuranceExpiry, date: now.addingTimeInterval(-3 * 86400)),
                PlannedVehicleEvent(kind: .other, date: now.addingTimeInterval(38 * 86400), label: "Winter tyres"),
                PlannedVehicleEvent(kind: .other, date: now.addingTimeInterval(121 * 86400)),
            ]
        ))
        let list = RoadMilestoneList(road)
        PreviewMatrix {
            RoadListSection(title: "road.ahead.title") {
                ForEach(Array(list.ahead.enumerated()), id: \.element.id) { index, milestone in
                    if index > 0 {
                        RoadListSeparator()
                    }
                    MilestoneRow(milestone: milestone)
                }
            }
        }
    }
#endif
