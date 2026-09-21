import Foundation

/// A future date the owner stated for the car, such as an insurance expiry (ADR 0032). Only the date
/// is kept, plus a short label the owner typed for `other`: never an insurer, a policy number, or a
/// date derived from law, locale, or mileage (core C2). It is a plan, not a History event, and it
/// resets nothing (core C5).
public struct PlannedDatedEvent: Hashable, Identifiable, Sendable {
    public enum Kind: Hashable, Sendable {
        case insuranceExpiry
        /// The label is the owner's own words; without one, Road says "Planned event".
        case other(label: String?)
    }

    public let id: UUID
    public let vehicleID: VehicleID
    public let kind: Kind
    public let date: Date
    public let createdAt: Date

    public init(id: UUID = UUID(), vehicleID: VehicleID, kind: Kind, date: Date, createdAt: Date) {
        self.id = id
        self.vehicleID = vehicleID
        self.kind = kind
        self.date = date
        self.createdAt = createdAt
    }

    public var isInsuranceExpiry: Bool {
        kind == .insuranceExpiry
    }

    public var label: String? {
        if case let .other(label) = kind {
            label
        } else {
            nil
        }
    }

    /// Still on Road at `now`: the date has not passed by more than the grace period (ADR 0008).
    public func isOnRoad(now: Date) -> Bool {
        date >= PlannedEventLimits.earliestDate(now: now)
    }

    /// The projection input. Road decides placement; this adds nothing to the stated date.
    public var roadEvent: PlannedVehicleEvent {
        switch kind {
        case .insuranceExpiry: PlannedVehicleEvent(id: id, kind: .insuranceExpiry, date: date)
        case let .other(label): PlannedVehicleEvent(id: id, kind: .other, date: date, label: label)
        }
    }
}

public enum PlannedEventLimits {
    /// Long enough for "Winter tyres" or "Warranty ends" in any shipped language; Road shows it in a
    /// two-line slot, so it is a short name, not a note.
    public static let maximumLabelLength = 40
    /// Ten years covers the longest owner-stated dates seen (warranty end); anything later is a typo.
    public static let maximumDaysAhead = 3650

    /// An earlier date would never reach Road, so saving it could only hide the owner's input.
    public static func earliestDate(now: Date) -> Date {
        now.addingTimeInterval(-Double(RoadRules.plannedGraceDays) * 86400)
    }

    public static func latestDate(now: Date) -> Date {
        now.addingTimeInterval(Double(maximumDaysAhead) * 86400)
    }

    public static func isPlausibleDate(_ date: Date, now: Date) -> Bool {
        (earliestDate(now: now) ... latestDate(now: now)).contains(date)
    }

    /// A label is one line of visible text within the limit. Trimming is the caller's job, so a
    /// command never stores something other than what was validated.
    public static func isValidLabel(_ label: String) -> Bool {
        !label.isBlank && !label.contains(where: \.isNewline) && label == label.trimmed
    }

    public static func isLabelWithinLimit(_ label: String) -> Bool {
        label.count <= maximumLabelLength
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
