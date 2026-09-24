import SwiftUI

struct ServiceView: View {
    let viewModel: ServiceViewModel
    let carName: String

    @State private var sheet: ServiceSheet?
    @State private var undoCandidate: MaintenanceOperationState?

    var body: some View {
        FeatureScaffold(carName: carName, title: String(localized: "tile.service.title")) {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                if viewModel.state.isLoadFailed {
                    LoadFailureBanner(message: "service.load.failed") { await viewModel.load() }
                }
                if let sparse = viewModel.state.sparseState {
                    emptyState(sparse)
                } else if !viewModel.state.operations.isEmpty {
                    if !viewModel.state.scope.isEmpty {
                        nextVisit
                    }
                    tracked
                }
            }
        }
        .toolbar { toolbarItems }
        .task { await viewModel.load() }
        .alert(failureTitle(viewModel.state.listFailure), isPresented: listFailureBinding) {
            Button("common.ok") { viewModel.dismissFailure() }
        }
        .pitActivity(
            .modalTask,
            while: sheet != nil || undoCandidate != nil || viewModel.state.stopTrackingCandidate != nil
                || viewModel.state.deleteReportCandidate != nil || listFailureBinding.wrappedValue
        )
        // Undo deletes a recorded fact, so it asks first and names what will be removed.
        .confirmationDialog(
            "service.undoDone.title",
            isPresented: undoBinding,
            titleVisibility: .visible,
            presenting: undoCandidate
        ) { operation in
            Button("service.undoDone", role: .destructive) {
                Task { _ = await viewModel.undoLastCompletion(of: operation) }
            }
            Button("common.cancel", role: .cancel) {}
        } message: { operation in
            if let completion = operation.lastCompletion {
                Text("service.undoDone.message \(completion.performedAt.formatted(date: .long, time: .omitted))")
            }
        }
        .stopTrackingConfirmation(viewModel)
        .deleteReportConfirmation(viewModel)
        .pitSheet(item: sheetBinding) { sheet in
            sheetContent(sheet)
                .alert(failureTitle(viewModel.state.failure), isPresented: failureBinding) {
                    Button("common.ok") { viewModel.dismissFailure() }
                }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        // One menu, not a glass group: "Track several" waits for the first load, and a half-disabled group reads
        // badly (redesign proposal §4, decision 4). Each item keeps its delivered rule.
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("service.track", systemImage: "plus") { sheet = .track }
                    .disabled(!viewModel.state.canTrackOne)
                    .accessibilityIdentifier("service.track")
                Button("service.trackSeveral", systemImage: "checklist") { sheet = .trackSeveral }
                    .disabled(!viewModel.state.canTrackSeveral)
                    .accessibilityIdentifier("service.trackSeveral")
            } label: {
                // The word stays beside the glyph: "+" alone would not say what is added (mockup #service). A
                // toolbar draws a `Label` icon-only whatever its style, so the label is built from its parts.
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .accessibilityHidden(true)
                    Text("service.trackMenu")
                }
            }
            .tint(PitColor.accentPrimary)
            .disabled(!viewModel.state.isTrackMenuEnabled)
            .accessibilityIdentifier("service.trackMenu")
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: ServiceSheet) -> some View {
        switch sheet {
        case .track:
            TrackOperationView(operations: viewModel.state.untrackedOperations) { operation, kilometers, months in
                await viewModel.track(operation, kilometersText: kilometers, monthsText: months)
            }
        case .trackSeveral:
            TrackSeveralView(makeModel: viewModel.makeTrackSeveral)
        case let .interval(operation):
            TrackOperationView(
                operations: [operation],
                existing: viewModel.state.operations.first { $0.id == operation }.flatMap(\.policy)
            ) { operation, kilometers, months in
                await viewModel.track(operation, kilometersText: kilometers, monthsText: months)
            }
        case let .done(operation):
            MarkDoneView(
                operation: operation,
                conflict: viewModel.state.markDoneConflict,
                conflictNotices: viewModel.state.markDoneConflictNotices,
                onEdit: viewModel.markDoneInputChanged,
                onKeepPits: viewModel.keepPitsEntry
            ) { date, odometer, replacingPits in
                await viewModel.confirmDone(operation, on: date, odometerText: odometer, replacingPits: replacingPits)
            }
        case let .report(operation):
            DashboardReadingView(
                operation: operation,
                defaultUnit: viewModel.state.defaultReportUnit,
                odometerPrefill: viewModel.state.sameDayOdometerKm
            ) { entry in
                await viewModel.enterReport(
                    operation, distanceText: entry.distance, unit: entry.unit,
                    daysText: entry.days, odometerText: entry.odometer
                )
            }
        }
    }

    private func emptyState(_ sparse: EmptyStateContent<ServiceEmptyAction>) -> some View {
        EmptyState(sparse) { action in
            switch action {
            case .track:
                Button("service.track") { sheet = .track }
            case .trackSeveral:
                Button("service.trackSeveral") { sheet = .trackSeveral }
                    .disabled(!viewModel.state.canTrackSeveral)
                    .accessibilityIdentifier("service.empty.trackSeveral")
            }
        }
    }

    /// A suggestion only: nothing here is a plan or a record until the user marks work as done.
    private var nextVisit: some View {
        let scope = viewModel.state.scope
        let lines = scope.due.map { NextVisitLine(operation: $0, note: nil) }
            + scope.dueNearby.map { NextVisitLine(operation: $0, note: "service.nextVisit.nearby") }
        return GroupedSection(title: "service.nextVisit", footer: "service.nextVisit.footer") {
            ForEach(Array(lines.enumerated()), id: \.element.operation.id) { index, line in
                NextVisitRow(line: line, showsSeparator: index > 0)
            }
        }
    }

    private var tracked: some View {
        GroupedSection(title: "service.tracked") {
            ForEach(Array(viewModel.state.operations.enumerated()), id: \.element.id) { index, operation in
                OperationRow(
                    operation: operation,
                    usedShare: operation.drawnUsedShare(mileage: viewModel.state.mileage),
                    showsSeparator: index > 0
                ) {
                    // The sheet opens once what is stored is known (REQ-PIT-026). A sheet that opened during the read,
                    // this one included, is not replaced, and a read that loses is simply dropped: only the read that
                    // opens the sheet becomes its snapshot.
                    Task {
                        let opening = await viewModel.readMarkDoneOpening(operation.id)
                        guard sheet == nil, viewModel.openMarkDone(opening) else { return }
                        sheet = .done(operation.id)
                    }
                } onChangeInterval: {
                    sheet = .interval(operation.id)
                } onUndo: {
                    undoCandidate = operation
                } onStopTracking: {
                    viewModel.requestStopTracking(operation)
                } onEnterReport: {
                    sheet = .report(operation.id)
                } onDeleteReport: {
                    viewModel.requestDeleteReport(operation)
                }
            }
        }
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

    private var undoBinding: Binding<Bool> {
        Binding(
            get: { undoCandidate != nil },
            set: { isPresented in
                if !isPresented {
                    undoCandidate = nil
                }
            }
        )
    }

    /// Every way a sheet closes (Cancel, a swipe, its own save) goes through this setter, before any other sheet can
    /// open, so a Mark as done save still running from a closed sheet reports on the list (REQ-NEW-10).
    private var sheetBinding: Binding<ServiceSheet?> {
        Binding(
            get: { sheet },
            set: { newValue in
                if case .done = sheet, newValue != sheet {
                    viewModel.markDoneClosed()
                }
                sheet = newValue
            }
        )
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

    private func failureTitle(_ failure: ServiceFailure?) -> LocalizedStringKey {
        switch failure {
        case .invalidInterval: "service.failure.interval"
        case .invalidOdometer: "carEditor.failure.odometer"
        case .futureDate: "service.failure.future"
        case .invalidReport: "service.failure.report"
        case .reportOdometerMissing: "service.failure.reportOdometer"
        case .pitAlreadyRecorded: "service.failure.pitEntryKept"
        case .notSaved, .none: "service.failure.notSaved"
        }
    }
}

enum ServiceSheet: Identifiable, Equatable {
    case track
    case trackSeveral
    case interval(MaintenanceOperationID)
    case done(MaintenanceOperationID)
    case report(MaintenanceOperationID)

    var id: String {
        switch self {
        case .track: "track"
        case .trackSeveral: "trackSeveral"
        case let .interval(operation): "interval-\(operation.rawValue)"
        case let .done(operation): "done-\(operation.rawValue)"
        case let .report(operation): "report-\(operation.rawValue)"
        }
    }
}

struct TrackOperationView: View {
    let operations: [MaintenanceOperationID]
    /// Set when changing an interval: both current values are shown, so clearing one is a visible choice.
    var existing: MaintenancePolicy?
    let onSave: (MaintenanceOperationID, String, String) async -> Bool

    @State private var operation: MaintenanceOperationID?
    @State private var kilometers = ""
    @State private var months = ""

    var body: some View {
        SaveSheetScaffold(
            title: existing == nil ? "service.track" : "service.changeInterval",
            saveIdentifier: "service.track.save",
            canSave: operation != nil
        ) {
            Form {
                Section {
                    Picker("service.track.operation", selection: $operation) {
                        ForEach(operations, id: \.self) { operation in
                            operation.titleText.tag(Optional(operation))
                        }
                    }
                }
                Section {
                    TextField("service.track.km", text: $kilometers)
                        .keyboardType(.numberPad)
                        .pitReportsEditing()
                        .accessibilityIdentifier("service.track.km")
                    TextField("service.track.months", text: $months)
                        .keyboardType(.numberPad)
                        .pitReportsEditing()
                        .accessibilityIdentifier("service.track.months")
                } header: {
                    Text("service.track.interval")
                } footer: {
                    Text("service.track.footer")
                }
            }
            .onAppear {
                guard operation == nil else { return }
                operation = operations.first
                if let existing {
                    kilometers = existing.distanceIntervalKm.map(String.init) ?? ""
                    months = existing.timeIntervalMonths.map(String.init) ?? ""
                }
            }
        } save: {
            guard let operation else { return false }
            return await onSave(operation, kilometers, months)
        }
    }
}

#if DEBUG
    #Preview("Service empty") {
        PreviewMatrix {
            if let sparse = ServiceViewState(hasLoaded: true).sparseState {
                EmptyState(sparse) { action in
                    switch action {
                    case .track: Button("service.track") {}
                    case .trackSeveral: Button("service.trackSeveral") {}
                    }
                }
            }
        }
    }
#endif
