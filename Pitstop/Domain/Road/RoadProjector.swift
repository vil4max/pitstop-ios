import Foundation

/// Pure projection of known plans and deterministic maintenance state onto the road (ADR 0008).
/// The surface renders the slots in order and decides nothing (REQ-ROAD-004).
public struct RoadProjector: Sendable {
    public init() {}

    public func project(_ context: RoadContext) -> RoadProjection {
        // The rate is read once per projection: every milestone of this car is estimated from the
        // same history, and a car with no usable history simply has no estimates (REQ-ROAD-023).
        let rate = MileageRateEstimator.rate(
            from: context.mileageObservations, now: context.now, calendar: context.calendar
        )
        let candidates = context.maintenanceStates.compactMap(Self.milestone(from:))
            .map { Self.annotated($0, rate: rate, now: context.now, calendar: context.calendar) }
            + context.plannedEvents.compactMap { Self.milestone(from: $0, now: context.now) }
        let placed = candidates.filter(\.proximity.isFinite).sorted(by: Self.isAhead)
        let waiting = candidates.filter { !$0.proximity.isFinite }.sorted { $0.id < $1.id }

        let slots = Self.cluster(placed)
        let inHorizon = slots.count { $0.lead?.isInsideHorizon ?? false }
        let horizon: RoadHorizon
        let initialCount: Int
        if slots.isEmpty {
            horizon = waiting.isEmpty ? .noKnownMilestones : .waitingForMileage
            initialCount = 0
        } else if inHorizon == 0 {
            horizon = .extendedToNearest
            initialCount = 1
        } else {
            horizon = .standard
            initialCount = min(inHorizon, RoadRules.initialSlotLimit)
        }

        let summary: RoadSemanticSummary = if let nearest = slots.first?.lead {
            .nearest(nearest, alsoAhead: placed.count - 1, waitingForMileage: waiting.count)
        } else if let blocked = waiting.first {
            .nearest(blocked, alsoAhead: 0, waitingForMileage: waiting.count - 1)
        } else {
            .noKnownMilestones(trackedWithoutBaseline: context.maintenanceStates.count { $0.lastCompletion == nil })
        }

        return RoadProjection(
            slots: slots,
            initialSlotCount: initialCount,
            waitingForMileage: waiting,
            past: context.history.latest
                .map { RoadPastSummary(count: context.history.entries.count, latestDate: $0.date) },
            horizon: horizon,
            semanticSummary: summary
        )
    }

    /// The date estimate is attached to a milestone that is already complete, and only to a distance
    /// milestone with kilometres left. Nothing below this line reads it, so placement, ordering and
    /// clustering are the same with and without it (REQ-ROAD-007, REQ-ROAD-022, ADR 0008).
    private static func annotated(
        _ milestone: RoadMilestone, rate: MileageRate?, now: Date, calendar: Calendar
    ) -> RoadMilestone {
        guard milestone.dimension == .distance, let remainingKm = milestone.remainingKm, let rate,
              let range = MileageRateEstimator.dateRange(
                  remainingKm: remainingKm, rate: rate, timeAnchor: milestone.anchorDate,
                  now: now, calendar: calendar
              )
        else { return milestone }
        return milestone.annotated(with: range)
    }

    /// One lane, nearest first in horizon units. Due and overdue have a non-positive key, so they
    /// lead; on an exact tie the more urgent state wins before the stable ID decides.
    private static func isAhead(_ lhs: RoadMilestone, _ rhs: RoadMilestone) -> Bool {
        (lhs.proximity, urgencyRank(lhs.state), lhs.id) < (rhs.proximity, urgencyRank(rhs.state), rhs.id)
    }

    private static func urgencyRank(_ state: RoadMilestoneState) -> Int {
        switch state {
        case .overdue: 0
        case .due: 1
        case .approaching: 2
        case .upcoming: 3
        }
    }

    /// An operation with no completion has no anchor, so it is not a milestone: Road never fills
    /// space with something that is not known (REQ-ROAD-009).
    private static func milestone(from state: MaintenanceOperationState) -> RoadMilestone? {
        guard state.lastCompletion != nil else { return nil }
        guard let share = state.remainingFraction, let dimension = state.decidedBy else {
            // Known to exist but blocked, whatever the reason: kept and flagged, not placed (REQ-ROAD-006).
            guard state.distanceBlock != nil else { return nil }
            return RoadMilestone(
                subject: .maintenance(state.id), state: .upcoming, dimension: .distance,
                remainingKm: nil, remainingDays: nil, anchorKm: state.anchorKm, anchorDate: nil,
                mileageDependency: state.distanceBlock, plannedLabel: nil, estimate: nil,
                proximity: .infinity
            )
        }
        let remainingKm = dimension == .distance ? state.remainingKm : nil
        let remainingDays = dimension == .time ? state.remainingDays : nil
        return RoadMilestone(
            subject: .maintenance(state.id),
            state: roadState(share: share, status: state.status),
            dimension: dimension,
            remainingKm: remainingKm,
            remainingDays: remainingDays,
            anchorKm: state.anchorKm,
            anchorDate: state.anchorDate,
            mileageDependency: state.distanceBlock,
            plannedLabel: nil,
            estimate: nil,
            proximity: horizonUnits(km: remainingKm, days: remainingDays)
        )
    }

    private static func milestone(from event: PlannedVehicleEvent, now: Date) -> RoadMilestone? {
        let remaining = event.date.timeIntervalSince(now) / 86400
        // A passed date stays visible as due for a short grace period, then leaves the road.
        guard remaining >= -Double(RoadRules.plannedGraceDays) else { return nil }
        // A planned date is a day stored as its start, so an unfinished day still to come counts as a whole
        // one: at 10:00, tomorrow is "1 day left", not "almost" (ADR 0032). Passed days count whole days past.
        let days = Int(remaining > 0 ? remaining.rounded(.up) : remaining.rounded(.towardZero))
        let state: RoadMilestoneState = if remaining <= 0 {
            .due
        } else if remaining <= Double(RoadRules.horizonDays) * MaintenanceRules.approachFraction {
            .approaching
        } else {
            .upcoming
        }
        return RoadMilestone(
            subject: .planned(event.kind, id: event.id),
            state: state,
            dimension: .time,
            remainingKm: nil,
            remainingDays: days,
            anchorKm: nil,
            anchorDate: event.date,
            mileageDependency: nil,
            plannedLabel: event.label,
            estimate: nil,
            proximity: remaining / Double(RoadRules.horizonDays)
        )
    }

    private static func horizonUnits(km: Int?, days: Int?) -> Double {
        if let km {
            return Double(km) / Double(RoadRules.horizonKm)
        }
        if let days {
            return Double(days) / Double(RoadRules.horizonDays)
        }
        return .infinity
    }

    private static func roadState(share: Double, status: MaintenanceStatus) -> RoadMilestoneState {
        switch status {
        case .due: share <= RoadRules.overdueShare ? .overdue : .due
        case .approaching: .approaching
        case .upToDate, .unknown: .upcoming
        }
    }

    /// Clusters are built per dimension, so two close distance milestones share a slot even when a
    /// date milestone sorts between them. Within a dimension the pass runs nearest first and compares
    /// with the first (earliest) member of the open cluster, so a chain cannot grow without bound.
    /// Different dimensions never cluster: how far apart a date and a mileage are is not known.
    private static func cluster(_ placed: [RoadMilestone]) -> [RoadSlot] {
        var slots: [[RoadMilestone]] = []
        for dimension in [MaintenanceDimension.distance, .time] {
            var open: [RoadMilestone] = []
            for milestone in placed where milestone.dimension == dimension {
                if let first = open.first, isClose(milestone, to: first) {
                    open.append(milestone)
                } else {
                    if !open.isEmpty {
                        slots.append(open)
                    }
                    open = [milestone]
                }
            }
            if !open.isEmpty {
                slots.append(open)
            }
        }
        return slots
            .sorted { lhs, rhs in
                guard let left = lhs.first, let right = rhs.first else { return !lhs.isEmpty }
                return isAhead(left, right)
            }
            .map(RoadSlot.init)
    }

    private static func isClose(_ milestone: RoadMilestone, to first: RoadMilestone) -> Bool {
        // Work that is due now is never merged with milestones that are still ahead.
        guard milestone.isDueNow == first.isDueNow else { return false }
        switch milestone.dimension {
        case .distance:
            guard let lhs = milestone.remainingKm, let rhs = first.remainingKm else { return false }
            return abs(lhs - rhs) <= RoadRules.clusterKm
        case .time:
            guard let lhs = milestone.remainingDays, let rhs = first.remainingDays else { return false }
            return abs(lhs - rhs) <= RoadRules.clusterDays
        }
    }
}
