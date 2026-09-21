import Foundation

/// `odometer_updated` from `docs/operations/analytics.md` (AQ-002). The reading itself is never sent.
enum OdometerAnalyticsEvent: AnalyticsEncodable, Hashable {
    case odometerUpdated(source: OdometerSource, anomalyConfirmation: AnomalyConfirmation)

    var analyticsEvent: AnalyticsEvent {
        switch self {
        case let .odometerUpdated(source, anomalyConfirmation):
            AnalyticsEvent(name: .odometerUpdated, properties: [
                .source: AnalyticsValue(source),
                .anomalyConfirmation: AnalyticsValue(anomalyConfirmation),
            ])
        }
    }
}

enum OdometerSource: String, AnalyticsCategory {
    case explicit
    case natural
    case siri
    case document

    init(_ source: CaptureSource) {
        switch source {
        case .pitText, .pitVoice, .widget: self = .natural
        case .directApp: self = .explicit
        case .siri, .shortcut: self = .siri
        }
    }
}

enum AnomalyConfirmation: String, AnalyticsCategory {
    case noAnomaly = "none"
    case accepted
    case corrected
}
