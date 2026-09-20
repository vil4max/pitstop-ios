import Foundation

public enum MaintenanceRules {
    /// An operation is "approaching" once this share of its interval (or less) remains.
    public static let approachFraction = 0.15
    /// A reading older than this no longer describes where the car is now (ADR 0008).
    public static let mileageStaleAfter: TimeInterval = 90 * 24 * 60 * 60
    /// Planner grouping window around the visit anchor. 2,000 km reproduces the contract's own
    /// example: DSG due at 62,000 is "due nearby" for a visit at 60,000 (maintenance-engine.md).
    public static let groupingDistanceKm = 2000
    public static let groupingDays = 45
}

public enum MaintenanceDimension: String, Hashable, Sendable {
    case distance
    case time
}

public enum MileageKnowledge: String, Hashable, Sendable {
    case known
    case stale
    case unknown
}

/// Why a distance rule could not be evaluated. The reason is shown to the user as it is.
public enum DistanceBlock: String, Hashable, Sendable {
    case mileageUnknown
    case mileageStale
    /// The car's mileage is known, but the completion was recorded without one.
    case completionMileageMissing
}

/// Where the car is now, as far as recorded facts say. A completion recorded with its mileage is a
/// mileage observation too: marking oil done at 70,000 km says the car has reached 70,000 km.
public struct MaintenanceContext: Hashable, Sendable {
    public let now: Date
    public let observedKm: Double?
    public let observedAt: Date?

    public init(
        now: Date,
        latestReading: OdometerReading?,
        completions: some Sequence<MaintenanceCompletion> = [MaintenanceCompletion]()
    ) {
        self.now = now
        var observations = completions.compactMap { completion in
            completion.odometerKm.map { (date: completion.performedAt, km: Double($0)) }
        }
        if let latestReading {
            observations.append((latestReading.recordedAt, latestReading.valueInKilometers))
        }
        let latest = observations.filter { $0.date <= now.addingTimeInterval(DomainCommandLimits.futureTolerance) }
            .max { ($0.date, $0.km) < ($1.date, $1.km) }
        observedKm = latest?.km
        observedAt = latest?.date
    }

    public var mileage: MileageKnowledge {
        guard let observedAt else { return .unknown }
        return now.timeIntervalSince(observedAt) > MaintenanceRules.mileageStaleAfter ? .stale : .known
    }

    /// Only a current observation feeds arithmetic; a stale or missing one never does (REQ-BOARD-006).
    var currentKm: Double? {
        mileage == .known ? observedKm : nil
    }
}

/// Progress of one operation under its effective policy. Every number is derived from a confirmed
/// completion; with no completion there are no numbers at all (REQ-MAINT-016).
public struct MaintenanceOperationState: Hashable, Identifiable, Sendable {
    public let policy: MaintenancePolicy
    public let lastCompletion: MaintenanceCompletion?
    public let status: MaintenanceStatus
    public let anchorKm: Int?
    public let anchorDate: Date?
    public let remainingKm: Int?
    public let remainingDays: Int?
    /// Smallest remaining share across the known dimensions; `nil` when nothing is known.
    public let remainingFraction: Double?
    /// The dimension that produced `remainingFraction`; labels show this one, never a conversion.
    public let decidedBy: MaintenanceDimension?
    /// The policy has a distance rule that could not be evaluated. When a time rule still decided the
    /// status, the status is only half the picture and the surface must say so (core C2).
    public let distanceBlock: DistanceBlock?

    public var id: MaintenanceOperationID {
        policy.operationID
    }

    /// A calm or approaching status that rests on the time rule alone.
    public var isPartial: Bool {
        distanceBlock != nil && decidedBy != nil && status != .due
    }
}

public struct MaintenanceEngine: Sendable {
    public init() {}

    public func states(
        policies: some Sequence<MaintenancePolicy>,
        completions: some Sequence<MaintenanceCompletion>,
        context: MaintenanceContext,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [MaintenanceOperationState] {
        let latestByOperation = Dictionary(grouping: completions, by: \.operationID)
            .compactMapValues { $0.max { ($0.performedAt, $0.id.uuidString) < ($1.performedAt, $1.id.uuidString) } }
        return policies.effective.map { policy in
            state(for: policy, last: latestByOperation[policy.operationID], context: context, calendar: calendar)
        }
    }

    private func state(
        for policy: MaintenancePolicy,
        last: MaintenanceCompletion?,
        context: MaintenanceContext,
        calendar: Calendar
    ) -> MaintenanceOperationState {
        guard let last else {
            return MaintenanceOperationState(
                policy: policy, lastCompletion: nil, status: .unknown, anchorKm: nil, anchorDate: nil,
                remainingKm: nil, remainingDays: nil, remainingFraction: nil, decidedBy: nil, distanceBlock: nil
            )
        }

        var shares: [(share: Double, dimension: MaintenanceDimension)] = []
        var anchorKm: Int?
        var remainingKm: Int?
        var block: DistanceBlock?
        if let interval = policy.distanceIntervalKm {
            // The next anchor derives from the actual completion, early or late (REQ-MAINT-003, 018).
            anchorKm = last.odometerKm.map { $0 + interval }
            if let anchorKm, let completionKm = last.odometerKm, let observedKm = context.currentKm {
                // The car cannot be behind the mileage at which this very work was done.
                let remaining = Double(anchorKm) - max(observedKm, Double(completionKm))
                remainingKm = Int(remaining.rounded(.towardZero))
                shares.append((remaining / Double(interval), .distance))
            } else if last.odometerKm == nil {
                block = .completionMileageMissing
            } else {
                block = context.mileage == .stale ? .mileageStale : .mileageUnknown
            }
        }

        var anchorDate: Date?
        var remainingDays: Int?
        if let months = policy.timeIntervalMonths,
           let anchor = calendar.date(byAdding: .month, value: months, to: last.performedAt)
        {
            anchorDate = anchor
            let total = anchor.timeIntervalSince(last.performedAt)
            let remaining = anchor.timeIntervalSince(context.now)
            // Toward zero, so half a day either side of the anchor reads as "now", not as a day past.
            remainingDays = Int((remaining / 86400).rounded(.towardZero))
            if total > 0 {
                shares.append((remaining / total, .time))
            }
        }

        // Distance wins an exact tie so the result does not depend on evaluation order.
        let deciding = shares.min { ($0.share, $0.dimension.rawValue) < ($1.share, $1.dimension.rawValue) }
        return MaintenanceOperationState(
            policy: policy,
            lastCompletion: last,
            status: Self.status(for: deciding?.share),
            anchorKm: anchorKm,
            anchorDate: anchorDate,
            remainingKm: remainingKm,
            remainingDays: remainingDays,
            remainingFraction: deciding?.share,
            decidedBy: deciding?.dimension,
            distanceBlock: block
        )
    }

    /// First threshold reached wins (REQ-MAINT-002): the smallest remaining share decides.
    static func status(for remainingFraction: Double?) -> MaintenanceStatus {
        guard let remainingFraction else { return .unknown }
        if remainingFraction <= 0 {
            return .due
        }
        return remainingFraction <= MaintenanceRules.approachFraction ? .approaching : .upToDate
    }
}

public extension Sequence<MaintenanceOperationState> {
    /// Most urgent first: due, approaching, up to date by remaining share, then unknown. Stable by ID.
    var byUrgency: [MaintenanceOperationState] {
        sorted { lhs, rhs in
            let left = (lhs.remainingFraction ?? .infinity, lhs.id.rawValue)
            let right = (rhs.remainingFraction ?? .infinity, rhs.id.rawValue)
            return left < right
        }
    }
}

public extension Sequence<MaintenanceOperationState> {
    /// The operation a one-line summary should talk about: the most urgent one with a known status,
    /// or, when none is known, the first tracked one so the summary can say what is missing.
    var summarySubject: MaintenanceOperationState? {
        let ordered = byUrgency
        return ordered.first { $0.status != .unknown } ?? ordered.first
    }
}
