import SwiftUI

struct HistoryView: View {
    let viewModel: HistoryViewModel
    let carName: String

    @State private var editor: HistoryEditorTarget?

    var body: some View {
        FeatureScaffold(carName: carName, title: String(localized: "tile.history.title")) {
            VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
                if viewModel.state.isLoadFailed {
                    LoadFailureBanner(message: "history.load.failed") { await viewModel.load() }
                }
                if viewModel.state.timeline.entries.isEmpty {
                    ContentUnavailableView {
                        Label("tile.history.empty.headline", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("tile.history.empty.detail")
                    } actions: {
                        Button("history.add") { editor = .new }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                } else {
                    ForEach(viewModel.state.timeline.entries) { entry in
                        if case let .event(event) = entry {
                            Button {
                                editor = .existing(event)
                            } label: {
                                HistoryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("history.row.editHint")
                        } else {
                            // Completions are corrected where they were confirmed (Service), not here.
                            HistoryRow(entry: entry)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("history.add", systemImage: "plus") { editor = .new }
                    .accessibilityIdentifier("history.add")
            }
        }
        .task { await viewModel.load() }
        .pitActivity(.modalTask, while: editor != nil)
        .sheet(item: $editor) { target in
            HistoryEventEditorView(
                draft: target.event.map(viewModel.draft(for:)) ?? viewModel.newDraft(),
                isNew: target == .new
            ) { draft in
                await viewModel.save(draft, replacing: target.event)
            }
            .alert(failureTitle, isPresented: failureBinding) {
                Button("common.ok") { viewModel.dismissFailure() }
            }
        }
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
        case .invalidOdometer: "carEditor.failure.odometer"
        case .invalidAmount: "history.failure.amount"
        case .futureDate: "history.failure.future"
        case .notSaved, .none: "history.failure.notSaved"
        }
    }
}

enum HistoryEditorTarget: Identifiable, Equatable {
    case new
    case existing(HistoryEvent)

    var id: String {
        event?.id.uuidString ?? "new"
    }

    var event: HistoryEvent? {
        if case let .existing(event) = self {
            event
        } else {
            nil
        }
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        TileCard(minHeight: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: entry.systemImage)
                    .font(.title3)
                    .foregroundStyle(PitColor.accentPrimary)
                    .frame(width: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    entry.titleText
                        .font(.headline)
                        .foregroundStyle(PitColor.contentPrimary)
                    Text(entry.date, format: .dateTime.day().month(.wide).year())
                        .font(.subheadline)
                        .foregroundStyle(PitColor.contentSecondary)
                    facts
                    if case let .event(event) = entry, let note = event.note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(PitColor.contentSecondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Missing facts are stated, not guessed and not silently omitted (charter, "Looking back").
    private var facts: some View {
        HStack(spacing: 10) {
            if let kilometers = entry.odometerKm {
                Text("carBoard.mileage.km \(kilometers)")
            } else {
                Text("history.mileage.unknown")
            }
            if case let .event(event) = entry, let amount = event.amount {
                Text(amount, format: .number.precision(.fractionLength(0 ... 2)))
            }
        }
        .font(.footnote)
        .foregroundStyle(PitColor.contentSecondary)
    }
}

extension HistoryEntry {
    var titleText: Text {
        switch self {
        case let .event(event): Text(event.kind.title)
        case let .completion(completion): completion.operationID.titleText
        }
    }

    /// Events carry a day, not a moment, so recency is counted in whole days ("today", "3 days ago").
    func recencyText(now: Date = Date(), calendar: Calendar = .current) -> Text {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return Text(verbatim: formatter.localizedString(for: day, relativeTo: today))
    }

    var systemImage: String {
        switch self {
        case let .event(event): event.kind.systemImage
        case .completion: "checkmark.seal"
        }
    }
}

extension HistoryEventKind {
    var title: LocalizedStringKey {
        switch self {
        case .service: "history.kind.service"
        case .carWash: "history.kind.carWash"
        case .odometer: "history.kind.odometer"
        case .insurance: "history.kind.insurance"
        case .purchase: "history.kind.purchase"
        case .other: "history.kind.other"
        }
    }

    var systemImage: String {
        switch self {
        case .service: "wrench.and.screwdriver"
        case .carWash: "drop"
        case .odometer: "gauge.with.needle"
        case .insurance: "shield"
        case .purchase: "bag"
        case .other: "circle.dashed"
        }
    }

    /// Kinds a person records by hand. Odometer readings have their own command and place.
    static let userSelectable: [HistoryEventKind] = [.service, .carWash, .insurance, .purchase, .other]
}

extension MaintenanceOperationID {
    /// Localized titles are presentation only; the ID stays the domain identity. An ID without a
    /// known title is shown verbatim so it is neither looked up nor parsed as a format string.
    var titleText: Text {
        titleResource.map { Text($0) } ?? Text(verbatim: rawValue)
    }

    /// The same title as plain text, for announcements and other string-only APIs.
    var localizedTitle: String {
        titleResource.map { String(localized: $0) } ?? rawValue
    }

    private var titleResource: LocalizedStringResource? {
        switch self {
        case .engineOilService: "operation.engineOilService"
        case .dsgService: "operation.dsgService"
        case .awdCouplingService: "operation.awdCouplingService"
        case .brakeFluid: "operation.brakeFluid"
        case .cabinFilter: "operation.cabinFilter"
        case .airFilter: "operation.airFilter"
        case .sparkPlugs: "operation.sparkPlugs"
        default: nil
        }
    }
}
