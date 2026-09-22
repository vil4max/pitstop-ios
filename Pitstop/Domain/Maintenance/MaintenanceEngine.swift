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
    /// The owner's distance rule has no completion to count from; only the car's reading of days
    /// decided the status, and the surface must say the distance is not counted (core C2, ADR 0035).
    case completionMissing
}

/// Where the car is now, as far as recorded facts say. A completion recorded with its mileage is a
/// mileage observation too: marking oil done at 70,000 km says the car has reached 70,000 km. A
/// dashboard reading entered with its odometer is the same kind of fact (ADR 0035).
public struct MaintenanceContext: Hashable, Sendable {
    public let now: Date
    public let observedKm: Double?
    public let observedAt: Date?

    public init(
        now: Date,
        latestReading: OdometerReading?,
        completions: some Sequence<MaintenanceCompletion> = [MaintenanceCompletion](),
        reports: [VehicleServiceReport] = []
    ) {
        self.now = now
        var observations = completions.compactMap { completion in
            completion.odometerKm.map { (date: completion.performedAt, km: Double($0)) }
        }
        observations += reports.compactMap { report in
            report.odometerKm.map { (date: report.reportedAt, km: Double($0)) }
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

/// Progress of one operation under its effective policy and the car's own reading. Every number is
/// derived from a confirmed completion or from what the owner read off the dashboard; nothing is
/// invented, and with neither there are no numbers at all (REQ-MAINT-016).
public struct MaintenanceOperationState: Hashable, Identifiable, Sendable {
    public let operationID: MaintenanceOperationID
    /// The rule the owner (or a recommendation) set. Nil when only a dashboard reading keeps this
    /// operation on Service (REQ-MAINT-036).
    public let policy: MaintenancePolicy?
    public let lastCompletion: MaintenanceCompletion?
    /// The newest stored dashboard reading of this operation, if any (ADR 0035). It keeps the
    /// operation on Service until the owner deletes it, even once a newer completion superseded it.
    public let report: VehicleServiceReport?
    /// A completion confirmed after the reading: it no longer decides anything (REQ-MAINT-031).
    public let isReportSuperseded: Bool
    public let status: MaintenanceStatus
    public let anchorKm: Int?
    public let anchorDate: Date?
    public let remainingKm: Int?
    public let remainingDays: Int?
    /// Smallest remaining share across the known dimensions; `nil` when nothing is known.
    public let remainingFraction: Double?
    /// The dimension that produced `remainingFraction`; labels show this one, never a conversion.
    public let decidedBy: MaintenanceDimension?
    /// True when the deciding anchor came from the car's own reading rather than the owner's
    /// interval. Surfaces name the source so an ignored-looking interval is explained (ADR 0035).
    public let isDecidedByReport: Bool
    /// The policy has a distance rule that could not be evaluated. When a time rule still decided the
    /// status, the status is only half the picture and the surface must say so (core C2).
    public let distanceBlock: DistanceBlock?

    public init(
        operationID: MaintenanceOperationID,
        policy: MaintenancePolicy?,
        lastCompletion: MaintenanceCompletion?,
        report: VehicleServiceReport? = nil,
        isReportSuperseded: Bool = false,
        status: MaintenanceStatus,
        anchorKm: Int?,
        anchorDate: Date?,
        remainingKm: Int?,
        remainingDays: Int?,
        remainingFraction: Double?,
        decidedBy: MaintenanceDimension?,
        isDecidedByReport: Bool = false,
        distanceBlock: DistanceBlock?
    ) {
        self.operationID = operationID
        self.policy = policy
        self.lastCompletion = lastCompletion
        self.report = report
        self.isReportSuperseded = isReportSuperseded
        self.status = status
        self.anchorKm = anchorKm
        self.anchorDate = anchorDate
        self.remainingKm = remainingKm
        self.remainingDays = remainingDays
        self.remainingFraction = remainingFraction
        self.decidedBy = decidedBy
        self.isDecidedByReport = isDecidedByReport
        self.distanceBlock = distanceBlock
    }

    public var id: MaintenanceOperationID {
        operationID
    }

    /// The dashboard reading that still decides anchors, if any.
    public var countingReport: VehicleServiceReport? {
        isReportSuperseded ? nil : report
    }

    /// Something to measure from: a confirmed completion or the car's own reading that still counts.
    public var hasBaseline: Bool {
        lastCompletion != nil || countingReport != nil
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
        reports: [VehicleServiceReport] = [],
        context: MaintenanceContext,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [MaintenanceOperationState] {
        let latestByOperation = Dictionary(grouping: completions, by: \.operationID)
            .compactMapValues { $0.max { ($0.performedAt, $0.id.uuidString) < ($1.performedAt, $1.id.uuidString) } }
        let newest = reports.newestPerOperation
        let effective = policies.effective
        // A stored reading keeps its operation on Service until the owner deletes it, like a tracked
        // one (REQ-MAINT-036).
        let operations = Set(effective.map(\.operationID)).union(newest.keys).sorted { $0.rawValue < $1.rawValue }
        let policyByOperation = Dictionary(uniqueKeysWithValues: effective.map { ($0.operationID, $0) })
        return operations.map { operation in
            state(
                for: Facts(
                    operation: operation,
                    policy: policyByOperation[operation],
                    last: latestByOperation[operation],
                    report: newest[operation]
                ),
                context: context,
                calendar: calendar
            )
        }
    }

    /// One anchor candidate in one dimension: where it falls, what it is measured from, and the
    /// interval its remaining share is a share of.
    private struct Candidate<Point: Comparable> {
        let anchor: Point
        let baseline: Double
        let denominator: Double
        let fromReport: Bool
    }

    /// What is recorded about one operation.
    private struct Facts {
        let operation: MaintenanceOperationID
        let policy: MaintenancePolicy?
        let last: MaintenanceCompletion?
        let report: VehicleServiceReport?
    }

    private func state(for facts: Facts, context: MaintenanceContext, calendar: Calendar)
        -> MaintenanceOperationState
    {
        let (operation, policy, last) = (facts.operation, facts.policy, facts.last)
        // Only the newest reading counts, and only while no confirmed completion of the operation is
        // newer: marking the work done resets the car's own countdown too (REQ-MAINT-031).
        let stored = facts.report
        let isSuperseded = stored?.isSuperseded(by: last, calendar: calendar) ?? false
        let report = isSuperseded ? nil : stored
        guard last != nil || report != nil else {
            return MaintenanceOperationState(
                operationID: operation, policy: policy, lastCompletion: nil, report: stored,
                isReportSuperseded: isSuperseded, status: .unknown,
                anchorKm: nil, anchorDate: nil, remainingKm: nil, remainingDays: nil, remainingFraction: nil,
                decidedBy: nil, distanceBlock: nil
            )
        }

        var shares: [(share: Double, dimension: MaintenanceDimension, fromReport: Bool)] = []
        var anchorKm: Int?
        var remainingKm: Int?
        var block: DistanceBlock?
        if let winner = distanceAnchor(policy: policy, last: last, report: report) {
            anchorKm = winner.anchor
            if let observedKm = context.currentKm {
                // The car cannot be behind the mileage the anchor was measured from.
                let remaining = Double(winner.anchor) - max(observedKm, winner.baseline)
                remainingKm = Int(remaining.rounded(.towardZero))
                shares.append((remaining / winner.denominator, .distance, winner.fromReport))
            } else {
                block = context.mileage == .stale ? .mileageStale : .mileageUnknown
            }
        } else if policy?.distanceIntervalKm != nil {
            block = last == nil ? .completionMissing : .completionMileageMissing
        }

        var anchorDate: Date?
        var remainingDays: Int?
        if let winner = timeAnchor(policy: policy, last: last, report: report, calendar: calendar) {
            anchorDate = winner.anchor
            let remaining = winner.anchor.timeIntervalSince(context.now)
            // Toward zero, so half a day either side of the anchor reads as "now", not as a day past.
            remainingDays = Int((remaining / 86400).rounded(.towardZero))
            if winner.denominator > 0 {
                shares.append((remaining / winner.denominator, .time, winner.fromReport))
            }
        }

        // Distance wins an exact tie so the result does not depend on evaluation order.
        let deciding = shares.min { ($0.share, $0.dimension.rawValue) < ($1.share, $1.dimension.rawValue) }
        return MaintenanceOperationState(
            operationID: operation,
            policy: policy,
            lastCompletion: last,
            report: stored,
            isReportSuperseded: isSuperseded,
            status: Self.status(for: deciding?.share),
            anchorKm: anchorKm,
            anchorDate: anchorDate,
            remainingKm: remainingKm,
            remainingDays: remainingDays,
            remainingFraction: deciding?.share,
            decidedBy: deciding?.dimension,
            isDecidedByReport: deciding?.fromReport ?? false,
            distanceBlock: block
        )
    }

    /// The earlier of the owner's anchor and the car's own, per dimension (REQ-MAINT-032). An exact
    /// tie goes to the owner's interval: the reading then adds nothing and naming it would mislead.
    private func distanceAnchor(
        policy: MaintenancePolicy?,
        last: MaintenanceCompletion?,
        report: VehicleServiceReport?
    ) -> Candidate<Int>? {
        var candidates: [Candidate<Int>] = []
        if let interval = policy?.distanceIntervalKm, let completionKm = last?.odometerKm {
            // The next anchor derives from the actual completion, early or late (REQ-MAINT-003, 018).
            candidates.append(Candidate(
                anchor: completionKm + interval, baseline: Double(completionKm),
                denominator: Double(interval), fromReport: false
            ))
        }
        if let report, let anchor = report.anchorKm, let odometerKm = report.odometerKm,
           let remaining = report.remainingDistanceKm
        {
            candidates.append(Candidate(
                anchor: anchor, baseline: Double(odometerKm),
                denominator: Self.denominator(ownerInterval: policy?.distanceIntervalKm.map(Double.init),
                                              reported: remaining),
                fromReport: true
            ))
        }
        return candidates.min { ($0.anchor, $0.fromReport ? 1 : 0) < ($1.anchor, $1.fromReport ? 1 : 0) }
    }

    private func timeAnchor(
        policy: MaintenancePolicy?,
        last: MaintenanceCompletion?,
        report: VehicleServiceReport?,
        calendar: Calendar
    ) -> Candidate<Date>? {
        var candidates: [Candidate<Date>] = []
        if let months = policy?.timeIntervalMonths, let last,
           let anchor = calendar.date(byAdding: .month, value: months, to: last.performedAt)
        {
            candidates.append(Candidate(
                anchor: anchor, baseline: last.performedAt.timeIntervalSinceReferenceDate,
                denominator: anchor.timeIntervalSince(last.performedAt), fromReport: false
            ))
        }
        if let report, let anchor = report.anchorDate(calendar: calendar), let days = report.remainingDays {
            // With an owner interval the share is measured against it, in the length that interval has
            // from the day of the reading; otherwise against what the car itself reported.
            let ownerLength = policy?.timeIntervalMonths
                .flatMap { calendar.date(byAdding: .month, value: $0, to: report.reportedAt) }
                .map { $0.timeIntervalSince(report.reportedAt) }
            candidates.append(Candidate(
                anchor: anchor, baseline: report.reportedAt.timeIntervalSinceReferenceDate,
                denominator: Self.denominator(ownerInterval: ownerLength, reported: Double(days) * 86400),
                fromReport: true
            ))
        }
        return candidates.min { ($0.anchor, $0.fromReport ? 1 : 0) < ($1.anchor, $1.fromReport ? 1 : 0) }
    }

    /// The owner's interval when there is one, otherwise the value the car reported (ADR 0035). An
    /// already-overdue reading has no cycle length to measure against, so its magnitude is the only
    /// scale available; the sign of the share still comes from what is left.
    private static func denominator(ownerInterval: Double?, reported: Double) -> Double {
        if let ownerInterval, ownerInterval > 0 {
            return ownerInterval
        }
        return max(abs(reported), 1)
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
