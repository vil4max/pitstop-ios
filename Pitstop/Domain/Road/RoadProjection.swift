import Foundation

/// Constants decided in ADR 0008. They are product hypotheses kept in one place.
public enum RoadRules {
    public static let horizonKm = 5000
    public static let horizonDays = 183
    public static let initialSlotLimit = 4
    public static let clusterKm = 1500
    public static let clusterDays = 21
    /// Past the anchor by this share of the interval or more, "due" becomes "overdue".
    public static let overdueShare = -0.10
    /// A planned date that has passed stays on the road as due for this long, then leaves it.
    public static let plannedGraceDays = 14
}

public enum RoadMilestoneState: String, Hashable, Sendable {
    case upcoming
    case approaching
    case due
    /// Attention, not danger (REQ-ROAD-012).
    case overdue
}

/// A future vehicle event the owner stated explicitly, such as an insurance expiry. Notes,
/// reminders, car washes, and model suggestions are never planned events (REQ-ROAD-002).
public struct PlannedVehicleEvent: Hashable, Identifiable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case insuranceExpiry
        case plannedVisit
        case other
    }

    public let id: UUID
    public let kind: Kind
    public let date: Date
    /// The owner's own short name for an `other` event (ADR 0032); nil for every other kind.
    public let label: String?

    public init(id: UUID = UUID(), kind: Kind, date: Date, label: String? = nil) {
        self.id = id
        self.kind = kind
        self.date = date
        self.label = label
    }
}

public struct RoadMilestone: Hashable, Identifiable, Sendable {
    public enum Subject: Hashable, Sendable {
        case maintenance(MaintenanceOperationID)
        case planned(PlannedVehicleEvent.Kind, id: UUID)
    }

    public let subject: Subject
    public let state: RoadMilestoneState
    /// The dimension this milestone is placed and labelled by. Never converted (REQ-ROAD-007).
    public let dimension: MaintenanceDimension
    public let remainingKm: Int?
    public let remainingDays: Int?
    public let anchorKm: Int?
    public let anchorDate: Date?
    /// A distance rule of this milestone could not be evaluated (REQ-ROAD-006).
    public let mileageDependency: DistanceBlock?
    /// The owner's label of a planned event, shown verbatim instead of the generic title (ADR 0032).
    public let plannedLabel: String?
    /// Ordering key in horizon units: remaining km / 5,000 or remaining days / 183. It orders the one
    /// lane and is never shown; `.infinity` for a milestone that cannot be placed.
    let proximity: Double

    /// True when the milestone falls inside six months / 5,000 km. Due and overdue always do. Nearness
    /// alone decides: an "approaching" transmission service 8,000 km away is still 8,000 km away.
    public var isInsideHorizon: Bool {
        proximity <= 1
    }

    /// Work whose moment has come. It is never folded into a cluster of calmer milestones.
    public var isDueNow: Bool {
        state == .due || state == .overdue
    }

    public var id: String {
        switch subject {
        case let .maintenance(operation): "maintenance-\(operation.rawValue)"
        case let .planned(_, id): "planned-\(id.uuidString)"
        }
    }

    /// `proximity` is derived from the fields below, so it stays out of equality and hashing.
    public static func == (lhs: RoadMilestone, rhs: RoadMilestone) -> Bool {
        lhs.subject == rhs.subject && lhs.state == rhs.state && lhs.dimension == rhs.dimension
            && lhs.remainingKm == rhs.remainingKm && lhs.remainingDays == rhs.remainingDays
            && lhs.anchorKm == rhs.anchorKm && lhs.anchorDate == rhs.anchorDate
            && lhs.mileageDependency == rhs.mileageDependency && lhs.plannedLabel == rhs.plannedLabel
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(subject)
        hasher.combine(state)
        hasher.combine(remainingKm)
        hasher.combine(remainingDays)
    }
}

/// How far a milestone is, as the surface should say it. At zero the wording follows the state, so
/// "approaching" never reads "reached" because a fraction of a day was truncated.
public enum RoadDistanceLabel: Hashable, Sendable {
    case inKm(Int)
    case pastKm(Int)
    case daysLeft(Int)
    case daysPast(Int)
    case reached
    case almost
    case blocked(DistanceBlock)
}

public extension RoadMilestone {
    var distanceLabel: RoadDistanceLabel {
        guard let remaining = remainingKm ?? remainingDays else {
            return .blocked(mileageDependency ?? .mileageUnknown)
        }
        if remaining == 0 {
            return isDueNow ? .reached : .almost
        }
        let isDistance = remainingKm != nil
        if remaining > 0 {
            return isDistance ? .inKm(remaining) : .daysLeft(remaining)
        }
        return isDistance ? .pastKm(-remaining) : .daysPast(-remaining)
    }
}

public extension RoadProjection {
    /// Nothing is known at all: no milestone, nothing waiting, and nothing tracked without a baseline.
    var isCompletelyEmpty: Bool {
        semanticSummary == .noKnownMilestones(trackedWithoutBaseline: 0)
    }
}

/// One position on the road: a single milestone or a cluster of close ones (REQ-ROAD-013).
public struct RoadSlot: Hashable, Identifiable, Sendable {
    public let milestones: [RoadMilestone]

    public var id: String {
        milestones.first?.id ?? "empty"
    }

    public var lead: RoadMilestone? {
        milestones.first
    }
}

public enum RoadHorizon: Hashable, Sendable {
    /// Something falls inside six months or 5,000 km.
    case standard
    /// Nothing is that close, so the road reaches to the nearest known milestone (REQ-ROAD-008).
    case extendedToNearest
    /// Milestones are known but none can be placed until mileage is known again.
    case waitingForMileage
    case noKnownMilestones
}

public struct RoadPastSummary: Hashable, Sendable {
    public let count: Int
    public let latestDate: Date
}

/// A description of the road that needs no drawing or animation (REQ-ROAD-015). The surface
/// localizes it; the facts are decided here.
public enum RoadSemanticSummary: Hashable, Sendable {
    case noKnownMilestones(trackedWithoutBaseline: Int)
    case nearest(RoadMilestone, alsoAhead: Int, waitingForMileage: Int)
}

public struct RoadContext: Hashable, Sendable {
    public let now: Date
    public let maintenanceStates: [MaintenanceOperationState]
    public let plannedEvents: [PlannedVehicleEvent]
    public let history: HistoryTimeline

    public init(
        now: Date,
        maintenanceStates: [MaintenanceOperationState],
        plannedEvents: [PlannedVehicleEvent] = [],
        history: HistoryTimeline = .empty
    ) {
        self.now = now
        self.maintenanceStates = maintenanceStates
        self.plannedEvents = plannedEvents
        self.history = history
    }
}

public struct RoadProjection: Hashable, Sendable {
    /// Every placed slot, nearest first. The first `initialSlotCount` form the default viewport.
    public let slots: [RoadSlot]
    public let initialSlotCount: Int
    /// Mileage-only milestones that cannot be placed until mileage is known again.
    public let waitingForMileage: [RoadMilestone]
    public let past: RoadPastSummary?
    public let horizon: RoadHorizon
    public let semanticSummary: RoadSemanticSummary

    public var initialSlots: ArraySlice<RoadSlot> {
        slots.prefix(initialSlotCount)
    }
}
