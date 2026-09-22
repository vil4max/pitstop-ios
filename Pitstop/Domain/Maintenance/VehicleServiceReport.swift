import Foundation

/// What the car itself said was left before an operation, read off the dashboard at one moment
/// (ADR 0035). It is an observation, not a rule: it carries no interval and never resets a cycle
/// (core C5). Due points are derived from it on read and are never stored.
public struct VehicleServiceReport: Identifiable, Hashable, Codable, Sendable {
    public enum Source: String, Codable, Sendable {
        case manualEntry
        case pitCapture
    }

    public let id: UUID
    public let vehicleID: VehicleID
    public let operationID: MaintenanceOperationID
    /// The moment the owner read the dashboard, which is also this observation's mileage date.
    public let reportedAt: Date
    /// Required whenever a remaining distance is given: without it the distance anchor has no baseline.
    public let odometerKm: Int?
    /// The value as the car showed it, in `distanceUnit`. Negative means the car reports it overdue.
    public let remainingDistance: Double?
    /// Kept beside the value, as `OdometerReading` does, so a reading in miles is never re-read as km.
    public let distanceUnit: DistanceUnit
    /// A date shown by the car, stored as whole days. Negative means overdue.
    public let remainingDays: Int?
    public let source: Source
    /// Every completion of this operation already saved when this reading was saved; set by the store,
    /// never by the caller. It orders a reading and a completion of the same day by when each was saved:
    /// a same-day completion not in this set was saved after the reading. A set, not the newest one
    /// alone, so undoing the newest leaves an earlier same-day completion known as earlier (ADR 0035).
    public let completionIDsAtEntry: Set<UUID>

    public init(
        id: UUID = UUID(),
        vehicleID: VehicleID,
        operationID: MaintenanceOperationID,
        reportedAt: Date = Date(),
        odometerKm: Int? = nil,
        remainingDistance: Double? = nil,
        distanceUnit: DistanceUnit = .kilometers,
        remainingDays: Int? = nil,
        source: Source = .manualEntry,
        completionIDsAtEntry: Set<UUID> = []
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.operationID = operationID
        self.reportedAt = reportedAt
        self.odometerKm = odometerKm
        self.remainingDistance = remainingDistance
        self.distanceUnit = distanceUnit
        self.remainingDays = remainingDays
        self.source = source
        self.completionIDsAtEntry = completionIDsAtEntry
    }

    /// The same reading as the store saves it: stamped with the operation's completions saved by then.
    public func entered(after completions: some Sequence<MaintenanceCompletion>) -> VehicleServiceReport {
        VehicleServiceReport(
            id: id, vehicleID: vehicleID, operationID: operationID, reportedAt: reportedAt,
            odometerKm: odometerKm, remainingDistance: remainingDistance, distanceUnit: distanceUnit,
            remainingDays: remainingDays, source: source,
            completionIDsAtEntry: Set(completions.filter { $0.operationID == operationID }.map(\.id))
        )
    }
}

public enum VehicleServiceReportLimits {
    /// Cars show overdue countdowns too, so the lower bound is negative on purpose.
    public static let minimumRemainingKm = -50000.0
    public static let maximumRemainingKm = 100_000.0
    public static let minimumRemainingDays = -365
    public static let maximumRemainingDays = 1095
    /// Past this the surface calls the reading old. It still counts: a hidden expiry would move due
    /// work back to unknown (ADR 0035).
    public static let oldAfter: TimeInterval = 180 * 24 * 60 * 60

    public static func isPlausibleRemainingKm(_ kilometers: Double) -> Bool {
        kilometers.isFinite && (minimumRemainingKm ... maximumRemainingKm).contains(kilometers)
    }

    public static func isPlausibleRemainingDays(_ days: Int) -> Bool {
        (minimumRemainingDays ... maximumRemainingDays).contains(days)
    }
}

public extension VehicleServiceReport {
    /// The reported distance in kilometres. The unit is converted only here, for arithmetic; the
    /// stored value and unit stay exactly as the owner entered them (REQ-MAINT-037).
    var remainingDistanceKm: Double? {
        guard let remainingDistance else { return nil }
        switch distanceUnit {
        case .kilometers: return remainingDistance
        case .miles: return remainingDistance * 1.609344
        }
    }

    /// Odometer plus what is left, derived on read (ADR 0035). Nil without both parts.
    var anchorKm: Int? {
        guard let odometerKm, let remainingDistanceKm else { return nil }
        return odometerKm + Int(remainingDistanceKm.rounded())
    }

    func anchorDate(calendar: Calendar = Calendar(identifier: .gregorian)) -> Date? {
        guard let remainingDays else { return nil }
        return calendar.date(byAdding: .day, value: remainingDays, to: reportedAt)
    }

    /// The reading is still the newest thing the car said, but old enough that the surface says so.
    func isOld(now: Date) -> Bool {
        now.timeIntervalSince(reportedAt) > VehicleServiceReportLimits.oldAfter
    }

    /// A completion confirmed after the reading resets the car's own countdown too, so the reading
    /// stops deciding anything (core C5, ADR 0035). On different days the calendar day decides. On the
    /// same day the order in which the two were saved decides, never the times they carry: "Mark done"
    /// keeps the time its sheet was opened. A same-day completion that was not already saved when the
    /// reading was saved came after it, so "300 km overdue" in the morning and "Mark done" in the
    /// afternoon supersede the reading.
    func isSuperseded(
        by completion: MaintenanceCompletion?,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Bool {
        guard let completion else { return false }
        let reportDay = calendar.startOfDay(for: reportedAt)
        let completionDay = calendar.startOfDay(for: completion.performedAt)
        guard completionDay == reportDay else { return completionDay > reportDay }
        return !completionIDsAtEntry.contains(completion.id)
    }
}

public extension Sequence<VehicleServiceReport> {
    /// Newest first, the ID deciding a tie, so every store returns the same order.
    var newestFirst: [VehicleServiceReport] {
        sorted { ($0.reportedAt, $0.id.uuidString) > ($1.reportedAt, $1.id.uuidString) }
    }

    /// The one reading per operation that counts: the newest by report time, the newest entry
    /// deciding an exact tie (REQ-MAINT-031).
    var newestPerOperation: [MaintenanceOperationID: VehicleServiceReport] {
        Dictionary(grouping: self, by: \.operationID).compactMapValues { reports in
            reports.max { ($0.reportedAt, $0.id.uuidString) < ($1.reportedAt, $1.id.uuidString) }
        }
    }
}
