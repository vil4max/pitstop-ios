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
                    HStack {
                        Label("service.load.failed", systemImage: "exclamationmark.arrow.circlepath")
                            .font(.footnote)
                            .foregroundStyle(PitColor.contentSecondary)
                        Spacer()
                        Button("carBoard.load.retry") {
                            Task { await viewModel.load() }
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }
                if viewModel.state.operations.isEmpty {
                    emptyState
                } else {
                    if !viewModel.state.scope.isEmpty {
                        nextVisit
                    }
                    tracked
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("service.track", systemImage: "plus") { sheet = .track }
                    .disabled(viewModel.state.untrackedOperations.isEmpty)
                    .accessibilityIdentifier("service.track")
            }
        }
        .task { await viewModel.load() }
        .alert("service.failure.notSaved", isPresented: listFailureBinding) {
            Button("common.ok") { viewModel.dismissFailure() }
        }
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
        .sheet(item: $sheet) { sheet in
            Group {
                switch sheet {
                case .track:
                    TrackOperationView(operations: viewModel.state
                        .untrackedOperations)
                    { operation, kilometers, months in
                        await viewModel.track(operation, kilometersText: kilometers, monthsText: months)
                    }
                case let .interval(operation):
                    TrackOperationView(
                        operations: [operation],
                        existing: viewModel.state.operations.first { $0.id == operation }?.policy
                    ) { operation, kilometers, months in
                        await viewModel.track(operation, kilometersText: kilometers, monthsText: months)
                    }
                case let .done(operation):
                    MarkDoneView(operation: operation) { date, odometer in
                        await viewModel.confirmDone(operation, on: date, odometerText: odometer)
                    }
                }
            }
            .alert(failureTitle, isPresented: failureBinding) {
                Button("common.ok") { viewModel.dismissFailure() }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("tile.service.empty.headline", systemImage: "wrench.and.screwdriver")
        } description: {
            Text("service.empty.detail")
        } actions: {
            Button("service.track") { sheet = .track }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    /// A suggestion only: nothing here is a plan or a record until the user marks work as done.
    private var nextVisit: some View {
        VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
            sectionTitle("service.nextVisit")
            TileCard(minHeight: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.state.scope.due) { scopeLine($0, note: nil) }
                    ForEach(viewModel.state.scope.dueNearby) { scopeLine($0, note: "service.nextVisit.nearby") }
                    Text("service.nextVisit.footer")
                        .font(.footnote)
                        .foregroundStyle(PitColor.contentSecondary)
                }
            }
        }
    }

    private func scopeLine(_ operation: MaintenanceOperationState, note: LocalizedStringKey?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: operation.status.systemImage)
                .foregroundStyle(operation.status.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                operation.id.titleText.font(.body.weight(.medium))
                (note.map { Text($0) } ?? operation.progressText)
                    .font(.footnote)
                    .foregroundStyle(PitColor.contentSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var tracked: some View {
        VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
            sectionTitle("service.tracked")
            ForEach(viewModel.state.operations) { operation in
                OperationRow(operation: operation) {
                    sheet = .done(operation.id)
                } onChangeInterval: {
                    sheet = .interval(operation.id)
                } onUndo: {
                    undoCandidate = operation
                }
            }
        }
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.title3.weight(.semibold))
            .foregroundStyle(PitColor.contentPrimary)
            .accessibilityAddTraits(.isHeader)
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

    private var failureTitle: LocalizedStringKey {
        switch viewModel.state.failure {
        case .invalidInterval: "service.failure.interval"
        case .invalidOdometer: "carEditor.failure.odometer"
        case .futureDate: "service.failure.future"
        case .notSaved, .none: "service.failure.notSaved"
        }
    }
}

enum ServiceSheet: Identifiable, Equatable {
    case track
    case interval(MaintenanceOperationID)
    case done(MaintenanceOperationID)

    var id: String {
        switch self {
        case .track: "track"
        case let .interval(operation): "interval-\(operation.rawValue)"
        case let .done(operation): "done-\(operation.rawValue)"
        }
    }
}

private struct OperationRow: View {
    let operation: MaintenanceOperationState
    let onMarkDone: () -> Void
    let onChangeInterval: () -> Void
    let onUndo: () -> Void

    var body: some View {
        TileCard(minHeight: 0) {
            VStack(alignment: .leading, spacing: 8) {
                operation.id.titleText
                    .font(.headline)
                    .foregroundStyle(PitColor.contentPrimary)
                Label(operation.statusLabel, systemImage: operation.status.systemImage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(operation.status.color)
                operation.progressText
                    .font(.footnote)
                    .foregroundStyle(PitColor.contentSecondary)
                HStack {
                    Button("service.markDone", systemImage: "checkmark", action: onMarkDone)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("service.markDone.\(operation.id.rawValue)")
                    Spacer()
                    // Stored facts stay correctable: the interval, and a confirmation made by mistake.
                    Menu("service.more", systemImage: "ellipsis.circle") {
                        Button("service.changeInterval", systemImage: "slider.horizontal.3", action: onChangeInterval)
                        if operation.lastCompletion != nil {
                            Button(
                                "service.undoDone",
                                systemImage: "arrow.uturn.backward",
                                role: .destructive,
                                action: onUndo
                            )
                        }
                    }
                    .labelStyle(.iconOnly)
                }
                .font(.subheadline)
            }
        }
    }
}

struct TrackOperationView: View {
    let operations: [MaintenanceOperationID]
    /// Set when changing an interval: both current values are shown, so clearing one is a visible choice.
    var existing: MaintenancePolicy?
    let onSave: (MaintenanceOperationID, String, String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var operation: MaintenanceOperationID?
    @State private var kilometers = ""
    @State private var months = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
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
                        .accessibilityIdentifier("service.track.km")
                    TextField("service.track.months", text: $months)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("service.track.months")
                } header: {
                    Text("service.track.interval")
                } footer: {
                    Text("service.track.footer")
                }
            }
            .navigationTitle(existing == nil ? "service.track" : "service.changeInterval")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        guard let operation else { return }
                        Task {
                            isSaving = true
                            let saved = await onSave(operation, kilometers, months)
                            isSaving = false
                            if saved {
                                dismiss()
                            }
                        }
                    }
                    .disabled(isSaving || operation == nil)
                    .accessibilityIdentifier("service.track.save")
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
        }
    }
}

struct MarkDoneView: View {
    let operation: MaintenanceOperationID
    let onConfirm: (Date, String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var odometer = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("service.done.date", selection: $date, in: ...Date(), displayedComponents: .date)
                    TextField("carEditor.odometer.placeholder", text: $odometer)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("service.done.odometer")
                } header: {
                    operation.titleText
                } footer: {
                    Text("service.done.footer")
                }
                Section {
                    // The explicit confirmation: only performed work resets a cycle (core C5).
                    Button("service.done.confirm") {
                        Task {
                            isSaving = true
                            let saved = await onConfirm(date, odometer)
                            isSaving = false
                            if saved {
                                dismiss()
                            }
                        }
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier("service.done.confirm")
                }
            }
            .navigationTitle("service.markDone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }
}
