import Foundation

/// Who reports an activity to Pit. Each reporting view instance gets its own source, so two editors or
/// two scroll views of the same kind never clear each other's report (ADR 0019).
public struct PitActivitySource: Hashable, Sendable {
    private let id: String

    /// The Settings and Pit sheets presented by the root view.
    public static let utilitySheet = PitActivitySource(id: "utility.sheet")

    public static func unique() -> PitActivitySource {
        PitActivitySource(id: UUID().uuidString)
    }
}

/// The interface activity as the union of what every source reports now (REQ-PIT-005, 006).
///
/// A source always reports its whole current activity, so a report replaces the previous one from that
/// source and an empty report withdraws it. Nothing is counted: a source that reports twice is still one
/// source, and one withdrawal clears it, which is what keeps activity from getting stuck.
public struct PitActivitySources: Hashable, Sendable {
    private var reports: [PitActivitySource: PitActivity] = [:]

    public init() {}

    public var activity: PitActivity {
        reports.values.reduce(into: PitActivity.idle) { $0.formUnion($1) }
    }

    public var isEmpty: Bool {
        reports.isEmpty
    }

    /// The union of every report except `source`'s.
    public func activity(excluding source: PitActivitySource) -> PitActivity {
        reports.filter { $0.key != source }.values.reduce(into: PitActivity.idle) { $0.formUnion($1) }
    }

    public mutating func report(_ activity: PitActivity, from source: PitActivitySource) {
        reports[source] = activity.isEmpty ? nil : activity
    }

    public mutating func withdraw(_ source: PitActivitySource) {
        reports[source] = nil
    }
}
