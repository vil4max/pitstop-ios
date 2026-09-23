import SwiftUI

struct HistoryView: View {
    let viewModel: HistoryViewModel
    let carName: String

    @State private var editor: HistoryEditorTarget?
    @Environment(\.calendar) private var calendar
    @Environment(\.timeZone) private var timeZone

    var body: some View {
        FeatureScaffold(carName: carName, title: String(localized: "tile.history.title")) {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                if viewModel.state.isLoadFailed {
                    LoadFailureBanner(message: "history.load.failed") { await viewModel.load() }
                }
                if let sparse = viewModel.state.sparseState {
                    EmptyState(sparse) { action in
                        switch action {
                        case .add: Button("history.add") { editor = .new }
                        }
                    }
                } else {
                    let dates = HistoryDateStyle(calendar: calendar, timeZone: timeZone)
                    ForEach(viewModel.state.timeline.months(calendar: calendar, timeZone: timeZone)) { month in
                        HistoryMonthSection(month: month, dates: dates) { editor = .existing($0) }
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

/// How History writes its dates: in the calendar and time zone the months were grouped in, so a row's day never
/// contradicts its month header.
struct HistoryDateStyle {
    let calendar: Calendar
    let timeZone: TimeZone

    var month: Date.FormatStyle {
        Date.FormatStyle(calendar: calendar, timeZone: timeZone, capitalizationContext: .beginningOfSentence)
            .month(.wide).year()
    }

    var day: Date.FormatStyle {
        Date.FormatStyle(calendar: calendar, timeZone: timeZone).day().month(.wide).year()
    }
}

/// One month of History as one grouped list with a rail through its rows (mockup #history). Recorded events open
/// their editor; confirmed completions do not, because they are corrected on Service.
struct HistoryMonthSection: View {
    let month: HistoryMonth
    let dates: HistoryDateStyle
    let onEdit: (HistoryEvent) -> Void

    var body: some View {
        GroupedSection(title: Text(month.start, format: dates.month)) {
            ForEach(Array(month.entries.enumerated()), id: \.element.id) { index, entry in
                let row = HistoryRow(
                    entry: entry,
                    dayStyle: dates.day,
                    showsSeparator: index > 0,
                    rail: .joining(index: index, count: month.entries.count)
                )
                if let event = entry.editableEvent {
                    Button {
                        onEdit(event)
                    } label: {
                        row
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("history.row.editHint")
                } else {
                    row
                }
            }
        }
    }
}

/// One entry on its month's rail. A recorded event has the accent dot and a chevron; a confirmed completion has the
/// up-to-date dot, no chevron, and a seal line saying where it is corrected. The dot is the plain rail dot, never a
/// state glyph: "due" on Service is a filled glyph in the same column (REQ-DESIGN-001).
struct HistoryRow: View {
    let entry: HistoryEntry
    let dayStyle: Date.FormatStyle
    var showsSeparator = false
    var rail: GlyphColumnRail = []

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isEditable: Bool {
        entry.editableEvent != nil
    }

    var body: some View {
        GlyphColumnRow(
            mark: .railDot,
            color: isEditable ? PitColor.accentPrimary : PitColor.statusUpToDate,
            showsSeparator: showsSeparator,
            rail: rail
        ) {
            details
                .frame(maxWidth: .infinity, alignment: .leading)
        } accessory: {
            // As the row's accessory the chevron moves under the text at accessibility sizes, so the text keeps
            // the width and a sighted user still sees the row opens.
            if isEditable {
                Image(systemName: "chevron.right")
                    .font(PitTypography.supportingSmall.weight(.semibold))
                    .foregroundStyle(PitColor.contentTertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            entry.titleText
                .font(PitTypography.headline)
                .foregroundStyle(PitColor.contentPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            Text(entry.date, format: dayStyle)
                .font(PitTypography.supporting)
                .foregroundStyle(PitColor.contentSecondary)
            facts
                .font(PitTypography.supportingSmall)
                .monospacedDigit()
                .foregroundStyle(PitColor.contentSecondary)
            if case let .event(event) = entry, let note = event.note {
                Text(note)
                    .font(PitTypography.supportingSmall)
                    .foregroundStyle(PitColor.contentSecondary)
            }
            if !isEditable {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .accessibilityHidden(true)
                    Text("history.completion.correctedOnService")
                }
                .font(PitTypography.supportingSmall.weight(.semibold))
                .foregroundStyle(PitColor.statusUpToDate)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Missing facts are stated, not guessed and not silently omitted (charter, "Looking back").
    private var facts: Text {
        let mileage = entry.odometerKm.map(FeatureFormat.mileage) ?? Text("history.mileage.unknown")
        guard case let .event(event) = entry, let amount = event.amount else { return mileage }
        return Text("history.facts.mileageAndAmount \(mileage) \(Text(amount, format: FeatureFormat.amountStyle))")
    }
}

extension HistoryEntry {
    var titleText: Text {
        switch self {
        case let .event(event): Text(event.kind.title)
        case let .completion(completion): completion.operationID.titleText
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

#if DEBUG
    #Preview("History months") {
        let vehicle = VehicleID()
        let now = Date.now
        let visitDay = now.addingTimeInterval(-80 * 86400)
        let timeline = HistoryTimeline(
            events: [
                HistoryEvent(vehicleID: vehicle, kind: .carWash, date: now, amount: 18, note: "Underbody wash"),
                HistoryEvent(vehicleID: vehicle, kind: .service, date: visitDay, odometerKm: 42500, amount: 240),
            ],
            completions: [
                MaintenanceCompletion(
                    vehicleID: vehicle, operationID: .engineOilService,
                    performedAt: visitDay.addingTimeInterval(60), odometerKm: 42500
                ),
            ]
        )
        PreviewMatrix {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                ForEach(timeline.months(calendar: .current, timeZone: .current)) { month in
                    HistoryMonthSection(
                        month: month, dates: HistoryDateStyle(calendar: .current, timeZone: .current)
                    ) { _ in }
                }
            }
        }
    }
#endif
