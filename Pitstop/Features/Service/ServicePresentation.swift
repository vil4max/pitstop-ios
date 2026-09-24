import SwiftUI

extension MaintenanceOperationState {
    /// The shared status word (`statusWord`), said in the app's words.
    var statusLabel: LocalizedStringKey {
        switch statusWord {
        case .unknown: "service.status.unknown"
        case .upToDate: "service.status.upToDate"
        case .upToDateByDate: "service.status.upToDate.byDate"
        case .approaching: "service.status.approaching"
        case .approachingByDate: "service.status.approaching.byDate"
        case .due: "service.status.due"
        }
    }

    /// One honest line about where this operation stands; `progressFact` decides what it says, here and
    /// in the widget (ADR 0036).
    var progressText: Text {
        switch progressFact {
        case .readingSuperseded:
            return Text("service.progress.readingSuperseded")
        case .noBaseline:
            return Text("service.progress.noBaseline")
        case let .progress(measure, block):
            let measured = measure.map(ProgressText.text(for:))
            let blocked = block.map(ProgressText.blocked)
            switch (measured, blocked) {
            case let (measured?, blocked?): return Text("\(measured) \(blocked)")
            case let (measured?, nil): return measured
            case let (nil, blocked?): return blocked
            case (nil, nil): return ProgressText.blocked(.mileageUnknown)
            }
        }
    }
}

extension MaintenanceOperationState {
    /// The used share the row's remaining-share track draws, or nil when it draws none (ADR 0038; redesign
    /// proposal §4 decision 2 and §6). Stale facts must not produce a confident-looking share, so the track needs
    /// a last completion, a mileage observation newer than 90 days and a known status. It shows the dimension
    /// that decided the status, and only when the policy sets an interval in that dimension: a reading the owner
    /// set no interval for is measured against the car's own countdown, which is not the owner's interval. Past
    /// 100 % the bar is full; the status word says overdue.
    func drawnUsedShare(mileage: MileageKnowledge) -> Double? {
        guard mileage == .known, lastCompletion != nil, status != .unknown,
              let remainingFraction, let decidedBy, policy?.interval(in: decidedBy) != nil
        else { return nil }
        return RemainingShareTrack.clamped(1 - remainingFraction)
    }
}

private extension MaintenancePolicy {
    func interval(in dimension: MaintenanceDimension) -> Int? {
        switch dimension {
        case .distance: distanceIntervalKm
        case .time: timeIntervalMonths
        }
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

/// What an empty Service offers: the two entrances of the toolbar menu, the single one first (mockup `#empty`).
enum ServiceEmptyAction: Hashable {
    case track
    case trackSeveral
}

extension ServiceViewState {
    /// Service's sparse state (REQ-GRAMMAR-004). Nil before the first load, when an empty list is only what was
    /// not read and "Nothing tracked" would claim a fact the screen does not have (core C2).
    var sparseState: EmptyStateContent<ServiceEmptyAction>? {
        guard hasLoaded, operations.isEmpty else {
            return nil
        }
        return EmptyStateContent(
            systemImage: "wrench.and.screwdriver",
            headline: "tile.service.empty.headline",
            sentence: "service.empty.detail",
            actions: [.track, .trackSeveral]
        )
    }
}

extension MarkDoneConflict {
    /// The prompt, shown in the sheet and spoken to VoiceOver: it names every entry of Pit's that Replace would
    /// revoke, since each may be dated a day away from the owner's or carry another odometer (REQ-MAINT-040).
    var message: String {
        guard pitEntries.count > 1 else {
            guard let pitEntry = pitEntries.first else { return "" }
            let date = pitEntry.performedAt.formatted(date: .long, time: .omitted)
            if let odometerKm = pitEntry.odometerKm {
                return String(localized: "service.done.conflict.odometer \(date) \(odometerKm)")
            }
            return String(localized: "service.done.conflict \(date)")
        }
        let entries = pitEntries.map { entry in
            let date = entry.performedAt.formatted(date: .long, time: .omitted)
            guard let odometerKm = entry.odometerKm else { return date }
            return String(localized: "service.done.conflict.entry \(date) \(odometerKm)")
        }
        return String(localized: "service.done.conflict.many \(entries.formatted(.list(type: .and)))")
    }

    var keepTitle: LocalizedStringKey {
        pitEntries.count > 1 ? "service.done.keepPits.many" : "service.done.keepPits"
    }
}
