import Foundation

/// The widget's kind, shared so the app can ask WidgetKit to reload exactly this widget (ADR 0036).
enum NextServiceWidgetKind {
    static let kind = "dev.vil4max.pitstop.widgets.nextService"
}

/// The word a status is said with, decided once for Service, Car Board and the widget. "Up to date" that
/// rests on the date rule alone says so, instead of implying the distance is fine.
enum MaintenanceStatusWord: Hashable, Sendable {
    case unknown
    case upToDate
    case upToDateByDate
    case approaching
    case approachingByDate
    case due
}

/// The measured part of an operation's progress line, in the dimension that decided it.
enum ProgressMeasure: Hashable, Sendable {
    case kilometersAhead(Int)
    case kilometersPast(Int)
    case daysLeft(Int)
    case daysPast(Int)
    /// Due exactly at the anchor.
    case reached
    /// Approaching or up to date with nothing left to count down.
    case almost
}

/// What one honest line about an operation says. Service and the widget word it differently; they never
/// decide it differently.
enum ProgressFact: Hashable, Sendable {
    /// Kept on Service only by a reading that newer work superseded: there is no rule left to count by.
    case readingSuperseded
    /// Nothing to measure from.
    case noBaseline
    /// A measure, a reason the distance is not counted, or both (core C2).
    case progress(ProgressMeasure?, block: DistanceBlock?)
}

extension MaintenanceOperationState {
    var statusWord: MaintenanceStatusWord {
        switch status {
        case .unknown: .unknown
        case .due: .due
        case .approaching: isPartial ? .approachingByDate : .approaching
        case .upToDate: isPartial ? .upToDateByDate : .upToDate
        }
    }

    /// Words follow the status, so text and status can never disagree near the anchor.
    var progressFact: ProgressFact {
        if policy == nil, countingReport == nil {
            return .readingSuperseded
        }
        guard hasBaseline else { return .noBaseline }
        var measure: ProgressMeasure?
        if decidedBy == .distance, let kilometers = remainingKm {
            measure = Self.measure(remaining: kilometers, isDue: status == .due, ahead: ProgressMeasure.kilometersAhead,
                                   past: ProgressMeasure.kilometersPast)
        } else if decidedBy == .time, let days = remainingDays {
            measure = Self.measure(remaining: days, isDue: status == .due, ahead: ProgressMeasure.daysLeft,
                                   past: ProgressMeasure.daysPast)
        }
        if measure == nil, distanceBlock == nil {
            return .progress(nil, block: .mileageUnknown)
        }
        return .progress(measure, block: distanceBlock)
    }

    private static func measure(
        remaining: Int,
        isDue: Bool,
        ahead: (Int) -> ProgressMeasure,
        past: (Int) -> ProgressMeasure
    ) -> ProgressMeasure {
        if isDue {
            return remaining == 0 ? .reached : past(abs(remaining))
        }
        return remaining == 0 ? .almost : ahead(remaining)
    }
}

/// The recorded facts the next-service widget needs: exactly the inputs Service gives the engine.
struct NextServiceFacts: Hashable, Sendable {
    var hasVehicle: Bool
    var policies: [MaintenancePolicy]
    var completions: [MaintenanceCompletion]
    var reports: [VehicleServiceReport]
    var latestReading: OdometerReading?

    static let noCar = NextServiceFacts(hasVehicle: false, policies: [], completions: [], reports: [])
}

/// The one operation the widget talks about: its name, status word and fact. No note text, no amount,
/// no car name (ADR 0036).
struct NextServiceSummary: Hashable, Sendable {
    let operation: MaintenanceOperationID
    let status: MaintenanceStatus
    let word: MaintenanceStatusWord
    let fact: ProgressFact

    init(_ state: MaintenanceOperationState) {
        self.init(operation: state.id, status: state.status, word: state.statusWord, fact: state.progressFact)
    }

    init(operation: MaintenanceOperationID, status: MaintenanceStatus, word: MaintenanceStatusWord,
         fact: ProgressFact)
    {
        self.operation = operation
        self.status = status
        self.word = word
        self.fact = fact
    }
}

enum NextServiceContent: Hashable, Sendable {
    /// No car yet, or nothing tracked: a calm invitation to open the app.
    case empty
    case operation(NextServiceSummary)
    /// The store could not be read (not moved yet, locked before first unlock, or another version).
    case unavailable

    /// Runs the same engine as Service on the same facts and takes Service's first row: `byUrgency`
    /// orders due, approaching and up to date by remaining share, then unknown.
    init(facts: NextServiceFacts, now: Date) {
        guard facts.hasVehicle else {
            self = .empty
            return
        }
        let context = MaintenanceContext(
            now: now, latestReading: facts.latestReading, completions: facts.completions, reports: facts.reports
        )
        let states = MaintenanceEngine().states(
            policies: facts.policies, completions: facts.completions, reports: facts.reports, context: context
        )
        guard let first = states.byUrgency.first else {
            self = .empty
            return
        }
        self = .operation(NextServiceSummary(first))
    }
}

/// When the widget must look again without any write: the first moment the shown content changes by time
/// alone, such as a date anchor turning an operation approaching or due, a day passing on a day count, or
/// the mileage going stale. Found by evaluating the same engine forward, so no rule is restated here.
enum NextServiceSchedule {
    static let horizon: TimeInterval = 400 * 86400
    /// WidgetKit wants entries at least about five minutes apart.
    static let minimumDelay: TimeInterval = 5 * 60
    private static let step: TimeInterval = 86400
    private static let precision: TimeInterval = 60

    /// `nil` when nothing changes within the horizon; a write in the app reloads the widget anyway.
    static func nextChange(facts: NextServiceFacts, after now: Date) -> Date? {
        let current = NextServiceContent(facts: facts, now: now)
        guard case .operation = current else { return nil }
        var earlier = now
        var offset = step
        while offset <= horizon {
            let later = now.addingTimeInterval(offset)
            if NextServiceContent(facts: facts, now: later) != current {
                let change = boundary(facts: facts, current: current, from: earlier, to: later)
                return max(change, now.addingTimeInterval(minimumDelay))
            }
            earlier = later
            offset += step
        }
        return nil
    }

    /// Narrows a one-day window to the first minute whose content differs.
    private static func boundary(facts: NextServiceFacts, current: NextServiceContent, from: Date, to: Date) -> Date {
        var low = from
        var high = to
        while high.timeIntervalSince(low) > precision {
            let middle = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if NextServiceContent(facts: facts, now: middle) == current {
                low = middle
            } else {
                high = middle
            }
        }
        return high
    }
}

/// One timeline request of the widget: what to show now and when to look again (ADR 0036).
struct NextServiceTimelinePlan: Hashable, Sendable {
    /// A store that cannot be read now (before the first unlock after a restart, or mid-upgrade) is
    /// tried again after this long rather than waiting for the next write.
    static let retryAfterUnavailable: TimeInterval = 30 * 60

    let content: NextServiceContent
    /// `nil` means no time-based change is coming; the app's reload after a write is enough.
    let refreshDate: Date?

    /// `read` returns `nil` while there is no finished store to read yet: the app has not launched
    /// since the upgrade, or has not saved anything. The app reloads the widget once it moves the store.
    init(now: Date, read: () throws -> NextServiceFacts?) {
        let facts: NextServiceFacts?
        do {
            facts = try read()
        } catch {
            content = .unavailable
            refreshDate = now.addingTimeInterval(Self.retryAfterUnavailable)
            return
        }
        guard let facts else {
            content = .empty
            refreshDate = nil
            return
        }
        content = NextServiceContent(facts: facts, now: now)
        refreshDate = NextServiceSchedule.nextChange(facts: facts, after: now)
    }
}
