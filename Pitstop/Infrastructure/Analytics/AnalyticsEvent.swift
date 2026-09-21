import Foundation

/// Event names from the taxonomy in `docs/operations/analytics.md`. Feature code refers to a case,
/// never to the string (ADR 0002, ADR 0021).
enum AnalyticsEventName: String, Hashable, Sendable, CaseIterable {
    case inputInterpretationCompleted = "input_interpretation_completed"
    case draftSaved = "draft_saved"
    case draftCancelled = "draft_cancelled"
    case noteCreated = "note_created"
    case noteContextOpened = "note_context_opened"
    case noteArchived = "note_archived"
    case odometerUpdated = "odometer_updated"
}

/// Parameter names from the same taxonomy.
enum AnalyticsProperty: String, Hashable, Sendable, CaseIterable {
    case intent
    case availability
    case result
    case latencyBucket = "latency_bucket"
    case interpreterVersion = "interpreter_version"
    case edited
    case stage
    case inputSource = "input_source"
    case contextCountBucket = "context_count_bucket"
    case hasCanonicalContext = "has_canonical_context"
    case context
    case activeNoteCountBucket = "active_note_count_bucket"
    case sourceContext = "source_context"
    case ageBucket = "age_bucket"
    case source
    case anomalyConfirmation = "anomaly_confirmation"
}

/// A closed set of values: every value an event can carry is a declared case, so the cardinality of a
/// property is known before anything is sent and user input has no way in (ADR 0021).
protocol AnalyticsCategory: CaseIterable, RawRepresentable, Sendable where RawValue == String {}

/// One property value. It can only be built from a `Bool` or an `AnalyticsCategory` case; there is no
/// initializer that takes a string, a number, or a date.
struct AnalyticsValue: Hashable, Sendable {
    let encoded: String

    init(_ flag: Bool) {
        encoded = flag ? "true" : "false"
    }

    init(_ value: some AnalyticsCategory) {
        encoded = value.rawValue
    }
}

/// The provider-neutral encoded event an `AnalyticsClient` receives.
struct AnalyticsEvent: Hashable, Sendable {
    let name: AnalyticsEventName
    let properties: [AnalyticsProperty: AnalyticsValue]
}

/// A feature-owned typed event that knows its encoded form.
protocol AnalyticsEncodable: Sendable {
    var analyticsEvent: AnalyticsEvent { get }
}

// MARK: - Shared buckets

enum CountBucket: String, AnalyticsCategory {
    case zero = "0"
    case one = "1"
    case twoToThree = "2_3"
    case fourToNine = "4_9"
    case tenOrMore = "10_plus"

    init(_ count: Int) {
        switch count {
        case ..<1: self = .zero
        case 1: self = .one
        case 2 ... 3: self = .twoToThree
        case 4 ... 9: self = .fourToNine
        default: self = .tenOrMore
        }
    }
}

enum LatencyBucket: String, AnalyticsCategory {
    case under250ms = "lt_250ms"
    case under1s = "lt_1s"
    case under3s = "lt_3s"
    case under10s = "lt_10s"
    case tenSecondsOrMore = "gte_10s"

    init(_ duration: Duration) {
        switch duration {
        case ..<(.milliseconds(250)): self = .under250ms
        case ..<(.seconds(1)): self = .under1s
        case ..<(.seconds(3)): self = .under3s
        case ..<(.seconds(10)): self = .under10s
        default: self = .tenSecondsOrMore
        }
    }
}

enum AgeBucket: String, AnalyticsCategory {
    case underOneDay = "lt_1d"
    case underOneWeek = "lt_7d"
    case underOneMonth = "lt_30d"
    case underThreeMonths = "lt_90d"
    case threeMonthsOrMore = "gte_90d"

    init(_ age: TimeInterval) {
        let day: TimeInterval = 86400
        switch age {
        case ..<day: self = .underOneDay
        case ..<(7 * day): self = .underOneWeek
        case ..<(30 * day): self = .underOneMonth
        case ..<(90 * day): self = .underThreeMonths
        default: self = .threeMonthsOrMore
        }
    }
}
