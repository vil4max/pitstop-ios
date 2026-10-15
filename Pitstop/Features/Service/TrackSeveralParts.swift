import SwiftUI

/// A full-width prominent button's label in `contentOnAccent`, which stays legible on the pale dark-mode accent.
/// A disabled button keeps the style's own dimmed label, since on-accent text would sit on its grey fill.
struct ProminentLabel: View {
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

/// One operation's interval fields with the quick picks under each.
struct IntervalSection: View {
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
            } onPick: {
                model.pickKilometers($0, for: operation)
            }
            TextField("service.track.months", text: months)
                .keyboardType(.numberPad)
                .pitReportsEditing()
                .accessibilityIdentifier("trackSeveral.months.\(operation.rawValue)")
            QuickPickRow(values: IntervalQuickPicks.months, current: model.entry(for: operation).months) {
                Text("trackSeveral.pick.months \($0)")
            } onPick: {
                model.pickMonths($0, for: operation)
            }
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
struct QuickPickRow: View {
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
struct IntervalSummary: View {
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
