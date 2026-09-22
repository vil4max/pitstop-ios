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
                    switch model.step {
                    case .choose: chooseContent
                    case .intervals: intervalsContent
                    case .review: reviewContent
                    case .results: resultsContent
                    }
                }
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
                            .foregroundStyle(isSelected ? Color.accentColor : PitColor.contentTertiary)
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
        }
        ForEach(model.selected, id: \.self) { operation in
            IntervalSection(model: model, operation: operation)
                .id(operation)
        }
        Section {
            Button("trackSeveral.back", systemImage: "chevron.backward") { model.back() }
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
        Section {
            // The one confirmation: nothing is saved before this (ADR 0006, ADR 0033).
            Button {
                Task { await model.apply() }
            } label: {
                Text("trackSeveral.confirm \(model.reviewPolicies.count)")
            }
            .disabled(model.isSaving)
            .accessibilityIdentifier("trackSeveral.confirm")
            Button("trackSeveral.back", systemImage: "chevron.backward") { model.back() }
                .disabled(model.isSaving)
        }
    }

    // MARK: Results

    @ViewBuilder
    private var resultsContent: some View {
        Section {
            ForEach(model.selected, id: \.self) { operation in
                let saved = model.results[operation] == .saved
                HStack {
                    operation.titleText
                    Spacer()
                    Label(
                        saved ? "trackSeveral.result.saved" : "trackSeveral.result.failed",
                        systemImage: saved ? "checkmark.circle" : "exclamationmark.triangle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(saved ? PitColor.statusUpToDate : PitColor.statusDue)
                }
                .accessibilityElement(children: .combine)
            }
        } footer: {
            if !model.failedOperations.isEmpty {
                Text("trackSeveral.results.failedFooter")
            }
        }
        if !model.failedOperations.isEmpty {
            Section {
                Button("trackSeveral.retry \(model.failedOperations.count)", systemImage: "arrow.clockwise") {
                    Task { await model.apply() }
                }
                .disabled(model.isSaving)
                .accessibilityIdentifier("trackSeveral.retry")
            }
        }
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

/// Tappable common values. None is highlighted until the field holds exactly that number.
private struct QuickPickRow: View {
    let values: [Int]
    let current: String
    let label: (Int) -> Text
    let onPick: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    let isCurrent = WholeNumberInput.parse(current, upTo: Int.max).intValue == value
                    Button {
                        onPick(value)
                    } label: {
                        label(value)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(isCurrent ? Color.accentColor : PitColor.contentSecondary)
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                    .accessibilityHint(Text("trackSeveral.pick.hint"))
                }
            }
        }
        .scrollIndicators(.hidden)
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
