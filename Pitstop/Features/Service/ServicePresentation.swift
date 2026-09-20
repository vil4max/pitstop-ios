import SwiftUI

extension MaintenanceStatus {
    /// Status is always said in words; colour only supports it (non-colour status meaning).
    var label: LocalizedStringKey {
        switch self {
        case .unknown: "service.status.unknown"
        case .upToDate: "service.status.upToDate"
        case .approaching: "service.status.approaching"
        case .due: "service.status.due"
        }
    }

    var color: Color {
        switch self {
        case .unknown: PitColor.contentTertiary
        case .upToDate: PitColor.statusUpToDate
        case .approaching: PitColor.statusApproaching
        // Due is attention, not danger.
        case .due: PitColor.statusDue
        }
    }

    var systemImage: String {
        switch self {
        case .unknown: "questionmark.circle"
        case .upToDate: "checkmark.circle"
        case .approaching: "clock.badge.exclamationmark"
        case .due: "exclamationmark.circle"
        }
    }
}

extension MaintenanceOperationState {
    /// "Up to date" that rests on the date rule alone says so, instead of implying the distance is fine.
    var statusLabel: LocalizedStringKey {
        guard isPartial else { return status.label }
        return status == .approaching ? "service.status.approaching.byDate" : "service.status.upToDate.byDate"
    }

    /// One honest line about where this operation stands, in the dimension that decided it. Words
    /// follow the status, so text and status can never disagree near the anchor.
    var progressText: Text {
        guard lastCompletion != nil else { return Text("service.progress.noBaseline") }
        var decided: Text?
        if decidedBy == .distance, let kilometers = remainingKm {
            decided = Self.text(
                remaining: kilometers,
                isDue: status == .due,
                ahead: { Text("service.progress.inKm \($0)") },
                past: { Text("service.progress.overKm \($0)") }
            )
        } else if decidedBy == .time, let days = remainingDays {
            decided = Self.text(
                remaining: days,
                isDue: status == .due,
                ahead: { Text("service.progress.daysLeft \($0)") },
                past: { Text("service.progress.daysPast \($0)") }
            )
        }
        guard let blockText else { return decided ?? Text("service.progress.mileageUnknown") }
        guard let decided else { return blockText }
        return Text("\(decided) \(blockText)")
    }

    private var blockText: Text? {
        switch distanceBlock {
        case .mileageStale: Text("service.progress.mileageStale")
        case .mileageUnknown: Text("service.progress.mileageUnknown")
        case .completionMileageMissing: Text("service.progress.completionMileageMissing")
        case .none: nil
        }
    }

    private static func text(
        remaining: Int,
        isDue: Bool,
        ahead: (Int) -> Text,
        past: (Int) -> Text
    ) -> Text {
        if isDue {
            return remaining == 0 ? Text("service.progress.reached") : past(abs(remaining))
        }
        return remaining == 0 ? Text("service.progress.almost") : ahead(remaining)
    }
}
