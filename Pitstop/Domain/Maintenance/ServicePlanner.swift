import Foundation

/// A derived proposal for the next practical visit. It is not a plan and not history: nothing here
/// is persisted, and reading it never changes an operation's anchor (REQ-DOMAIN-008, REQ-MAINT-007).
public struct SuggestedServiceScope: Hashable, Sendable {
    public let due: [MaintenanceOperationState]
    public let dueNearby: [MaintenanceOperationState]

    public var isEmpty: Bool {
        due.isEmpty && dueNearby.isEmpty
    }

    public static let empty = SuggestedServiceScope(due: [], dueNearby: [])
}

public struct ServicePlanner: Sendable {
    public init() {}

    /// Deterministic grouping around the visit: everything due, plus operations whose own anchor
    /// falls inside the grouping window of the visit point. No model is consulted.
    ///
    /// When something is due the visit is now, at the car's current mileage, so "nearby" is measured
    /// from where the car is, not from how overdue the worst item is. When nothing is due, the visit
    /// is planned for the most urgent approaching operation's anchor.
    public func suggestedScope(
        for states: some Sequence<MaintenanceOperationState>,
        context: MaintenanceContext
    ) -> SuggestedServiceScope {
        let ordered = states.byUrgency
        let due = ordered.filter { $0.status == .due }
        let visitKm: Double?
        let visitDate: Date?
        let core: [MaintenanceOperationState]
        if !due.isEmpty {
            core = due
            visitKm = context.currentKm ?? due.compactMap(\.anchorKm).max().map(Double.init)
            visitDate = context.now
        } else if let approaching = ordered.first(where: { $0.status == .approaching }) {
            core = [approaching]
            // Only the dimension that made it approaching says when the visit is; its other anchor may
            // be a year away and must not pull unrelated work into this visit.
            visitKm = approaching.decidedBy == .distance ? approaching.anchorKm.map(Double.init) : nil
            visitDate = approaching.decidedBy == .time ? approaching.anchorDate : nil
        } else {
            return .empty
        }

        let coreIDs = Set(core.map(\.id))
        let nearby = ordered.filter { candidate in
            guard !coreIDs.contains(candidate.id), candidate.status != .unknown else { return false }
            if let candidateKm = candidate.anchorKm, let visitKm,
               abs(Double(candidateKm) - visitKm) <= Double(MaintenanceRules.groupingDistanceKm)
            {
                return true
            }
            if let candidateDate = candidate.anchorDate, let visitDate,
               abs(candidateDate.timeIntervalSince(visitDate)) <= Double(MaintenanceRules.groupingDays) * 86400
            {
                return true
            }
            return false
        }
        return SuggestedServiceScope(due: core, dueNearby: nearby)
    }
}
