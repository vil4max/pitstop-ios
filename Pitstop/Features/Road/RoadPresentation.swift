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

    /// The shared state glyph (REQ-DESIGN-001), on the lane's signs and in the list's rows.
    var glyph: StatusGlyph {
        switch self {
        case .upcoming: .ring
        case .approaching: .half
        case .due: .filled
        case .overdue: .filledRing
        }
    }
}

extension RoadMilestone {
    /// The glyph to draw. A milestone waiting for mileage is dashed whatever its state: the projector files
    /// it as `.upcoming`, and a ring would claim it is ahead.
    var glyph: StatusGlyph {
        isWaitingForMileage ? .dashed : state.glyph
    }

    /// The colour of its glyph and state word. Waiting for mileage is secondary, as an unknown state is:
    /// the ahead accent would claim a place on the road it does not have.
    var color: Color {
        isWaitingForMileage ? PitColor.contentSecondary : state.color
    }

    private var isWaitingForMileage: Bool {
        if case .blocked = distanceLabel {
            return true
        }
        return false
    }
}

/// What the lane draws for one slot: its lead milestone on one roadside sign, with the count of the others
/// that share its place, so labels never overlap (REQ-ROAD-013).
struct RoadSign: Equatable {
    let milestone: RoadMilestone
    let alsoHere: Int
}

extension RoadSlot {
    var sign: RoadSign? {
        lead.map { RoadSign(milestone: $0, alsoHere: milestones.count - 1) }
    }
}

/// The milestone list under the lane (REQ-ROAD-027). "Ahead" holds the lane's milestones slot by slot in
/// lane order, clustered ones included, so each sign's lead starts its own run of rows; "Waiting for mileage"
/// holds the ones the lane cannot place. It adds, removes and reorders nothing (REQ-ROAD-004).
struct RoadMilestoneList: Equatable {
    let ahead: [RoadMilestone]
    let waiting: [RoadMilestone]

    init(_ projection: RoadProjection) {
        ahead = projection.slots.flatMap(\.milestones)
        waiting = projection.waitingForMileage
    }
}

/// What an empty Road offers: the toolbar's "Add a date", once more where the eye lands.
enum RoadEmptyAction: Hashable {
    case addDate
}

extension RoadProjection {
    /// Road's sparse state (REQ-GRAMMAR-004), only when nothing at all is known (REQ-ROAD-009). A road with
    /// something tracked but nothing placeable is not empty: its summary sentence says why.
    var sparseState: EmptyStateContent<RoadEmptyAction>? {
        guard isCompletelyEmpty else {
            return nil
        }
        return EmptyStateContent(
            systemImage: "road.lanes",
            headline: "tile.road.empty.headline",
            sentence: "tile.road.empty.detail",
            actions: [.addDate]
        )
    }
}

/// The lane's return to the car (INV-ROAD-004): shown only once the lane has left the car (REQ-ROAD-028),
/// and without animation under Reduce Motion (REQ-ROAD-014).
enum RoadBackToNow {
    static func isShown(scrollPosition: String?) -> Bool {
        scrollPosition != RoadLaneView.carID
    }

    static func animation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .snappy
    }
}

extension RoadMilestone {
    var titleText: Text {
        switch subject {
        case let .maintenance(operation): operation.titleText
        case .planned(.insuranceExpiry, _): Text("road.planned.insurance")
        case .planned(.plannedVisit, _): Text("road.planned.visit")
        case .planned(.other, _): plannedLabel.map { Text(verbatim: $0) } ?? Text("road.planned.other")
        }
    }

    /// Distance in kilometres or time in days, in the dimension that placed the milestone. A blocked
    /// milestone says why it has no number instead of showing one. When the car's own dashboard reading
    /// decided, the fact names that source; it adds no dimension and converts nothing (REQ-ROAD-026).
    var distanceText: Text {
        guard isFromDashboard else { return factText }
        return Text("road.fromDashboard \(factText)")
    }

    private var factText: Text {
        switch distanceLabel {
        case let .inKm(kilometers): ProgressText.kilometersAhead(kilometers)
        case let .pastKm(kilometers): ProgressText.kilometersPast(kilometers)
        case let .daysLeft(days): ProgressText.daysLeft(days)
        case let .daysPast(days): ProgressText.daysPast(days)
        case .reached: ProgressText.reached
        case .almost: ProgressText.almost
        case let .blocked(block): ProgressText.blocked(block)
        }
    }
}

extension PlannedDatedEvent {
    /// The same title Road shows for this date; the owner's label is their own words, never translated.
    var titleText: Text {
        switch kind {
        case .insuranceExpiry: Text("road.planned.insurance")
        case let .other(label): label.map { Text(verbatim: $0) } ?? Text("road.planned.other")
        }
    }
}

extension PlannedEventDraft.Kind {
    var title: LocalizedStringKey {
        switch self {
        case .insuranceExpiry: "road.planned.insurance"
        case .other: "road.planned.kind.other"
        }
    }

    var systemImage: String {
        switch self {
        case .insuranceExpiry: "checkmark.shield"
        case .other: "calendar"
        }
    }
}

extension RoadFailure {
    var title: LocalizedStringKey {
        switch self {
        case .notSaved: "road.failure.notSaved"
        case .dateOutOfRange: "road.failure.date"
        case .labelTooLong: "road.failure.label"
        case .insuranceAlreadyPlanned: "road.failure.insurance"
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

/// How a date estimate reads. A range that crosses more than 45 days is said in months: a day inside
/// it would claim a precision the rate does not have. A bound outside the current year carries its
/// year, so neither "April - August" two years out nor "November - November" can read as the months
/// just ahead.
struct RoadEstimateLabel: Equatable {
    enum Granularity: Equatable {
        case day
        case month
    }

    let granularity: Granularity
    /// The visible range, e.g. "Mar 2 – Mar 28".
    let text: String
    /// True when both bounds are the same day, so the label names one day and not a range.
    let isSingleDay: Bool
    /// The bounds spoken in full, so VoiceOver never reads an abbreviation letter by letter.
    let spokenEarliest: String
    let spokenLatest: String

    static let monthGranularityAfterDays = 45

    init(range: EstimatedDateRange, now: Date, calendar: Calendar, locale: Locale) {
        let span = calendar.dateComponents([.day], from: range.earliest, to: range.latest).day ?? 0
        granularity = span > Self.monthGranularityAfterDays ? .month : .day
        isSingleDay = calendar.isDate(range.earliest, inSameDayAs: range.latest)
        let base = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        // Each bound is formatted on its own: an interval style prints a year whenever the range
        // crosses one, even for a range of a few weeks, and never when it does not.
        var shown = granularity == .day ? base.month(.abbreviated).day() : base.month(.wide)
        var spoken = granularity == .day ? base.month(.wide).day() : base.month(.wide)
        // A month name alone means "this year". An estimate reaches two years ahead, so any bound
        // outside the current year says which year it is in.
        let thisYear = calendar.component(.year, from: now)
        let years = [range.earliest, range.latest].map { calendar.component(.year, from: $0) }
        if years.contains(where: { $0 != thisYear }) {
            shown = shown.year()
            spoken = spoken.year()
        }
        let earliest = range.earliest.formatted(shown)
        let latest = range.latest.formatted(shown)
        // Only one day means one label; two different days that print alike still need both bounds.
        text = isSingleDay ? earliest : "\(earliest) \u{2013} \(latest)"
        spokenEarliest = range.earliest.formatted(spoken)
        spokenLatest = range.latest.formatted(spoken)
    }
}

/// The estimate line under a milestone's fact. Secondary by style and by wording, never a state
/// colour: it is an annotation, not something the car told us (REQ-ROAD-022).
struct RoadEstimateLine: View {
    let range: EstimatedDateRange
    var font: Font = .footnote
    /// Only the wording depends on it: which bound needs its year spelled out.
    var now: Date = .now

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        let label = RoadEstimateLabel(range: range, now: now, calendar: calendar, locale: locale)
        Text("road.estimate \(label.text)")
            .font(font)
            .foregroundStyle(PitColor.contentTertiary)
            .accessibilityLabel(accessibilityLabel(label))
    }

    /// One day is spoken as one day: "between December 8 and December 8" is not a range.
    private func accessibilityLabel(_ label: RoadEstimateLabel) -> Text {
        label.isSingleDay
            ? Text("road.estimate.accessibility.oneDay \(label.spokenEarliest)")
            : Text("road.estimate.accessibility \(label.spokenEarliest) \(label.spokenLatest)")
    }
}
