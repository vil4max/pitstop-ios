import SwiftUI

/// "Track several" (ADR 0033): choose operations, enter each interval, confirm one summary, see what was saved.
struct TrackSeveralView: View {
    @State private var model: TrackSeveralViewModel
    @Environment(\.dismiss) private var dismiss

    init(makeModel: @escaping () -> TrackSeveralViewModel) {
        _model = State(initialValue: makeModel())
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    Section {
                        StepStrip(steps: stepNames, current: model.step.stripIndex)
                            .listRowBackground(Color.clear)
                    }
                    switch model.step {
                    case .choose: chooseContent
                    case .intervals: intervalsContent
                    case .review: reviewContent
                    case .results: resultsContent
                    }
                }
                // The step strip sits just under the title, as the form's first line, not below a section gap.
                .contentMargins(.top, 8, for: .scrollContent)
                // The failing section may be off screen: bring it into view and say which items need a fix,
                // as the single Track sheet does with its alert.
                .onChange(of: model.validationFailures) {
                    guard let first = model.firstInvalid else { return }
                    withAnimation { proxy.scrollTo(first, anchor: .top) }
                    let names = model.invalidInListOrder.map(\.localizedTitle).formatted(.list(type: .and))
                    AccessibilityNotification.Announcement(
                        String(localized: "trackSeveral.invalid.announcement \(names)")
                    ).post()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        // Typed intervals are lost on dismissal, so only the explicit Cancel closes the sheet mid-way.
        .interactiveDismissDisabled(model.step == .intervals || model.step == .review || model.isSaving)
    }

    private func cancel() {
        model.cancel()
        dismiss()
    }

    private var title: LocalizedStringKey {
        switch model.step {
        case .choose, .intervals: "trackSeveral.title"
        case .review: "trackSeveral.review.title"
        case .results: "trackSeveral.results.title"
        }
    }

    /// Short names for the step strip; the toolbar title still names the step in full for VoiceOver.
    private var stepNames: [Text] {
        TrackSeveralStep.stripOrder.map { step in
            switch step {
            case .choose: Text("trackSeveral.step.choose")
            case .intervals: Text("trackSeveral.step.intervals")
            case .review: Text("trackSeveral.step.confirm")
            case .results: Text("trackSeveral.results.title")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        switch model.step {
        case .choose:
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel", role: .cancel) { cancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("trackSeveral.next") { model.continueToIntervals() }
                    .disabled(model.selected.isEmpty)
                    .accessibilityIdentifier("trackSeveral.next")
            }
        case .intervals:
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel", role: .cancel) { cancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("trackSeveral.next") { model.continueToReview() }
                    .accessibilityIdentifier("trackSeveral.next")
            }
        case .review:
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel", role: .cancel) { cancel() }
                    .disabled(model.isSaving)
            }
        case .results:
            ToolbarItem(placement: .confirmationAction) {
                Button("common.done") { dismiss() }
                    .disabled(model.isSaving)
                    .accessibilityIdentifier("trackSeveral.done")
            }
        }
    }

    // MARK: Choose

    @ViewBuilder
    private var chooseContent: some View {
        Section {
            Picker("trackSeveral.gearbox", selection: $model.gearbox) {
                ForEach(GearboxAnswer.allCases, id: \.self) { answer in
                    Text(answer.label).tag(answer)
                }
            }
            Picker("trackSeveral.drive", selection: $model.drive) {
                ForEach(DriveAnswer.allCases, id: \.self) { answer in
                    Text(answer.label).tag(answer)
                }
            }
        } header: {
            Text("trackSeveral.car.header")
        } footer: {
            Text("trackSeveral.car.footer")
        }
        Section {
            ForEach(model.operations, id: \.self) { operation in
                let isSelected = model.isSelected(operation)
                Button {
                    model.toggle(operation)
                } label: {
                    HStack {
                        operation.titleText.foregroundStyle(PitColor.contentPrimary)
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? PitColor.accentPrimary : PitColor.contentTertiary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("trackSeveral.operation.\(operation.rawValue)")
            }
        } header: {
            Text("trackSeveral.operations.header")
        } footer: {
            Text("trackSeveral.operations.footer")
        }
    }

    // MARK: Intervals

    @ViewBuilder
    private var intervalsContent: some View {
        Section {
            Text("trackSeveral.intervals.footer")
                .font(.footnote)
                .foregroundStyle(PitColor.contentSecondary)
                .listRowBackground(Color.clear)
        }
        ForEach(model.selected, id: \.self) { operation in
            IntervalSection(model: model, operation: operation)
                .id(operation)
        }
        StackedActions {
            BackButton { model.back() }
        }
    }

    // MARK: Review

    @ViewBuilder
    private var reviewContent: some View {
        Section {
            ForEach(model.reviewPolicies, id: \.operationID) { policy in
                VStack(alignment: .leading, spacing: 4) {
                    policy.operationID.titleText.font(.body.weight(.medium))
                    IntervalSummary(policy: policy)
                        .font(.footnote)
                        .foregroundStyle(PitColor.contentSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("trackSeveral.review.header")
        } footer: {
            Text("trackSeveral.review.footer")
        }
        StackedActions {
            // The one confirmation: nothing is saved before this (ADR 0006, ADR 0033).
            Button {
                Task { await model.apply() }
            } label: {
                ProminentLabel(Text("trackSeveral.confirm \(model.reviewPolicies.count)"))
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isSaving)
            .accessibilityIdentifier("trackSeveral.confirm")
            BackButton { model.back() }
                .disabled(model.isSaving)
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultsContent: some View {
        Section {
            ForEach(model.selected, id: \.self) { operation in
                let saved = model.results[operation] == .saved
                ViewThatFits(in: .horizontal) {
                    HStack {
                        operation.titleText
                        Spacer()
                        resultChip(saved: saved)
                    }
                    // At accessibility sizes the chip moves under the name instead of squeezing it.
                    VStack(alignment: .leading, spacing: 6) {
                        operation.titleText
                        resultChip(saved: saved)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        } footer: {
            if !model.failedOperations.isEmpty {
                Text("trackSeveral.results.failedFooter")
            }
        }
        if !model.failedOperations.isEmpty {
            StackedActions {
                Button {
                    Task { await model.apply() }
                } label: {
                    Label("trackSeveral.retry \(model.failedOperations.count)", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.isSaving)
                .accessibilityIdentifier("trackSeveral.retry")
            }
        }
    }

    private func resultChip(saved: Bool) -> StatusChip {
        saved
            ? StatusChip("trackSeveral.result.saved", glyph: .ring, color: PitColor.statusUpToDate)
            : StatusChip("trackSeveral.result.failed", glyph: .filled, color: PitColor.statusDue)
    }
}

/// Full-width buttons stacked under the form, outside any grouped row: the step's actions, not its content.
private struct StackedActions<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Section {
            VStack(spacing: 10) {
                content
            }
            .font(PitTypography.headline)
            .controlSize(.large)
            .tint(PitColor.accentPrimary)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
}

/// A full-width prominent button's label in `contentOnAccent`, which stays legible on the pale dark-mode accent.
/// A disabled button keeps the style's own dimmed label, since on-accent text would sit on its grey fill.
private struct ProminentLabel: View {
    let text: Text
    @Environment(\.isEnabled) private var isEnabled

    init(_ text: Text) {
        self.text = text
    }

    var body: some View {
        Group {
            if isEnabled {
                text.foregroundStyle(PitColor.contentOnAccent)
            } else {
                text
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The secondary action that returns to the previous step with everything typed kept.
private struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("trackSeveral.back", systemImage: "chevron.backward")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

/// One operation's interval fields with the quick picks under each.
private struct IntervalSection: View {
    let model: TrackSeveralViewModel
    let operation: MaintenanceOperationID

    var body: some View {
        Section {
            TextField("service.track.km", text: kilometers)
                .keyboardType(.numberPad)
                .pitReportsEditing()
                .accessibilityIdentifier("trackSeveral.km.\(operation.rawValue)")
            QuickPickRow(values: IntervalQuickPicks.kilometers, current: model.entry(for: operation).kilometers) {
                Text("trackSeveral.pick.km \($0.formatted())")
            } onPick: { model.pickKilometers($0, for: operation) }
            TextField("service.track.months", text: months)
                .keyboardType(.numberPad)
                .pitReportsEditing()
                .accessibilityIdentifier("trackSeveral.months.\(operation.rawValue)")
            QuickPickRow(values: IntervalQuickPicks.months, current: model.entry(for: operation).months) {
                Text("trackSeveral.pick.months \($0)")
            } onPick: { model.pickMonths($0, for: operation) }
        } header: {
            operation.titleText
        } footer: {
            if model.invalid.contains(operation) {
                Label("service.failure.interval", systemImage: "exclamationmark.circle")
                    .foregroundStyle(PitColor.statusDue)
            }
        }
    }

    private var kilometers: Binding<String> {
        Binding(
            get: { model.entry(for: operation).kilometers },
            set: { model.setKilometers($0, for: operation) }
        )
    }

    private var months: Binding<String> {
        Binding(
            get: { model.entry(for: operation).months },
            set: { model.setMonths($0, for: operation) }
        )
    }
}

/// Tappable common values as tinted chips that wrap. None is selected until the field holds exactly that number.
private struct QuickPickRow: View {
    let values: [Int]
    let current: String
    let label: (Int) -> Text
    let onPick: (Int) -> Void

    var body: some View {
        ChipFlowLayout(spacing: 8, lineSpacing: 6) {
            ForEach(values, id: \.self) { value in
                let isSelected = IntervalQuickPicks.isSelected(value, fieldText: current)
                Button {
                    onPick(value)
                } label: {
                    label(value)
                }
                .buttonStyle(QuickPickChipStyle(isSelected: isSelected))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHint(Text("trackSeveral.pick.hint"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A quick pick in the tint colour; filled with the accent while its field holds this value.
private struct QuickPickChipStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PitTypography.supportingSmall.weight(.medium))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(isSelected ? PitColor.contentOnAccent : PitColor.accentPrimary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(isSelected ? PitColor.accentPrimary : PitColor.surfaceTint, in: .capsule)
            .opacity(configuration.isPressed ? 0.6 : 1)
            // The chip looks about 30 pt tall; the target keeps the 44 pt minimum (REQ-GRAMMAR-003).
            .frame(minHeight: 44)
            .contentShape(.rect)
    }
}

/// "Every 10 000 km · Every 12 mo." in the owner's own numbers.
private struct IntervalSummary: View {
    let policy: MaintenancePolicy

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let kilometers = policy.distanceIntervalKm {
                Text("trackSeveral.summary.km \(kilometers.formatted())")
            }
            if let months = policy.timeIntervalMonths {
                Text("trackSeveral.summary.months \(months)")
            }
            if policy.distanceIntervalKm != nil, policy.timeIntervalMonths != nil {
                Text("trackSeveral.summary.whicheverFirst")
            }
        }
    }
}

extension GearboxAnswer {
    var label: LocalizedStringKey {
        switch self {
        case .notAnswered: "trackSeveral.answer.notAnswered"
        case .dualClutch: "trackSeveral.gearbox.dualClutch"
        case .otherAutomatic: "trackSeveral.gearbox.otherAutomatic"
        case .manual: "trackSeveral.gearbox.manual"
        }
    }
}

extension DriveAnswer {
    var label: LocalizedStringKey {
        switch self {
        case .notAnswered: "trackSeveral.answer.notAnswered"
        case .allWheel: "trackSeveral.drive.allWheel"
        case .twoWheel: "trackSeveral.drive.twoWheel"
        }
    }
}

#if DEBUG
    #Preview("Track several parts") {
        PreviewMatrix {
            VStack(alignment: .leading, spacing: 16) {
                StepStrip(
                    steps: [
                        Text("trackSeveral.step.choose"), Text("trackSeveral.step.intervals"),
                        Text("trackSeveral.step.confirm"), Text("trackSeveral.results.title"),
                    ],
                    current: 1
                )
                QuickPickRow(values: IntervalQuickPicks.kilometers, current: "10000") {
                    Text("trackSeveral.pick.km \($0.formatted())")
                } onPick: { _ in }
                QuickPickRow(values: IntervalQuickPicks.months, current: "") {
                    Text("trackSeveral.pick.months \($0)")
                } onPick: { _ in }
                StackedActions {
                    Button {} label: {
                        ProminentLabel(Text("trackSeveral.confirm \(3)"))
                    }
                    .buttonStyle(.borderedProminent)
                    Button {} label: {
                        ProminentLabel(Text("trackSeveral.confirm \(3)"))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                    BackButton {}
                }
            }
        }
    }
#endif
