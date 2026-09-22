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
        // Kept on Service only by a reading that newer work superseded: there is no rule left to count by.
        if policy == nil, countingReport == nil {
            return Text("service.progress.readingSuperseded")
        }
        guard hasBaseline else { return Text("service.progress.noBaseline") }
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
        case .completionMissing: Text("service.progress.completionMissing")
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

extension MaintenanceOperationState {
    /// What the car itself said, as it said it: "Car says 3,200 km / 45 days · Sep 20". The age is
    /// always shown, and after 180 days the line says the reading is old; it never disappears on its
    /// own (ADR 0035). Nil when there is no reading or a newer completion superseded it.
    func reportText(now: Date) -> Text? {
        guard let report = countingReport else { return nil }
        let values = VehicleServiceReport.carSaysTexts(
            distance: report.remainingDistance, unit: report.distanceUnit, days: report.remainingDays
        )
        guard let first = values.first else { return nil }
        let said = values.count == 2 ? Text("service.report.pair \(first) \(values[1])") : first
        let date = Text(report.reportedAt, format: .dateTime.month(.abbreviated).day())
        return report.isOld(now: now)
            ? Text("service.report.line.old \(said) \(date)")
            : Text("service.report.line \(said) \(date)")
    }
}

extension VehicleServiceReport {
    var distanceText: Text? {
        remainingDistance.map { Self.distanceText($0, unit: distanceUnit) }
    }

    /// The values the car showed, distance first, as the Service line and the Pit confirmation say them.
    static func carSaysTexts(distance: Double?, unit: DistanceUnit, days: Int?) -> [Text] {
        [distance.map { distanceText($0, unit: unit) }, days.map(daysText)].compactMap(\.self)
    }

    var daysText: Text? {
        remainingDays.map(Self.daysText)
    }

    /// In the unit the car showed; never converted for display (REQ-MAINT-037). Overdue says so in
    /// words, not with a minus sign.
    static func distanceText(_ remaining: Double, unit: DistanceUnit) -> Text {
        let value = Int(abs(remaining).rounded())
        switch (unit, remaining < 0) {
        case (.kilometers, false): return Text("service.report.km \(value)")
        case (.kilometers, true): return Text("service.report.overKm \(value)")
        case (.miles, false): return Text("service.report.mi \(value)")
        case (.miles, true): return Text("service.report.overMi \(value)")
        }
    }

    static func daysText(_ remaining: Int) -> Text {
        remaining < 0 ? Text("service.report.overDays \(abs(remaining))") : Text("service.report.days \(remaining)")
    }
}

extension DistanceUnit {
    var title: LocalizedStringKey {
        switch self {
        case .kilometers: "service.unit.km"
        case .miles: "service.unit.mi"
        }
    }
}
