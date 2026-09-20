import SwiftUI

extension RoadMilestoneState {
    var label: LocalizedStringKey {
        switch self {
        case .upcoming: "road.state.upcoming"
        case .approaching: "road.state.approaching"
        case .due: "road.state.due"
        case .overdue: "road.state.overdue"
        }
    }

    /// Overdue is attention, never danger (REQ-ROAD-012). Shape differs too, so colour is not the only cue.
    var color: Color {
        switch self {
        case .upcoming: PitColor.accentPrimary
        case .approaching: PitColor.statusApproaching
        case .due, .overdue: PitColor.statusDue
        }
    }

    var systemImage: String {
        switch self {
        case .upcoming: "circle"
        case .approaching: "circle.lefthalf.filled"
        case .due: "circle.fill"
        case .overdue: "exclamationmark.circle.fill"
        }
    }
}

extension RoadMilestone {
    var titleText: Text {
        switch subject {
        case let .maintenance(operation): operation.titleText
        case .planned(.insuranceExpiry, _): Text("road.planned.insurance")
        case .planned(.plannedVisit, _): Text("road.planned.visit")
        case .planned(.other, _): Text("road.planned.other")
        }
    }

    /// Distance in kilometres or time in days, in the dimension that placed the milestone. A blocked
    /// milestone says why it has no number instead of showing one.
    var distanceText: Text {
        switch distanceLabel {
        case let .inKm(kilometers): Text("service.progress.inKm \(kilometers)")
        case let .pastKm(kilometers): Text("service.progress.overKm \(kilometers)")
        case let .daysLeft(days): Text("service.progress.daysLeft \(days)")
        case let .daysPast(days): Text("service.progress.daysPast \(days)")
        case .reached: Text("service.progress.reached")
        case .almost: Text("service.progress.almost")
        case .blocked(.mileageStale): Text("service.progress.mileageStale")
        case .blocked(.completionMileageMissing): Text("service.progress.completionMileageMissing")
        case .blocked(.mileageUnknown): Text("service.progress.mileageUnknown")
        }
    }
}

extension RoadProjection {
    /// The non-visual description of the road (REQ-ROAD-015, REQ-BOARD-023).
    var summaryText: Text {
        switch semanticSummary {
        case let .noKnownMilestones(tracked):
            return tracked > 0 ? Text("road.summary.noBaseline") : Text("tile.road.empty.headline")
        case let .nearest(milestone, alsoAhead, _):
            // A blocked milestone has no state to report; its reason already says why (REQ-ROAD-011).
            guard milestone.remainingKm != nil || milestone.remainingDays != nil else {
                return Text("road.summary.blocked \(milestone.titleText) \(milestone.distanceText)")
            }
            // The state word is part of the sentence: VoiceOver never sees the marker symbols.
            let state = Text(milestone.state.label)
            return alsoAhead > 0
                ?
                Text(
                    "road.summary.nearestAndMore \(milestone.titleText) \(state) \(milestone.distanceText) \(alsoAhead)"
                )
                : Text("road.summary.nearest \(milestone.titleText) \(state) \(milestone.distanceText)")
        }
    }
}
