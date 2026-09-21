import Foundation
import os

/// The provider boundary (ADR 0002). A provider adapter implements this and nothing in feature code
/// imports the provider. `send` must not block the caller.
protocol AnalyticsClient: Sendable {
    func send(_ event: AnalyticsEvent)
}

/// The production default until a provider adapter is approved (ADR 0021).
struct NoAnalyticsClient: AnalyticsClient {
    func send(_: AnalyticsEvent) {}
}

enum AnalyticsConsent: Sendable {
    case notAsked
    case granted
    case declined
}

protocol AnalyticsConsentReading: Sendable {
    var consent: AnalyticsConsent { get }
}

struct FixedAnalyticsConsent: AnalyticsConsentReading {
    let consent: AnalyticsConsent
}

/// Only an explicit opt-in lets an event through; `notAsked` counts as no (ADR 0021). Consent is read
/// on every event, so a later change applies without rebuilding the trackers.
struct ConsentGatedAnalyticsClient: AnalyticsClient {
    let client: any AnalyticsClient
    let consent: any AnalyticsConsentReading

    func send(_ event: AnalyticsEvent) {
        guard consent.consent == .granted else { return }
        client.send(event)
    }
}

/// DEBUG-only local view of what would be sent (ADR 0003): nothing is persisted or transmitted.
/// Every value is a closed category, so the whole event can be public in the log.
struct LoggingAnalyticsClient: AnalyticsClient {
    #if DEBUG
        private static let logger = AppLog.logger(category: "analytics")
    #endif

    func send(_ event: AnalyticsEvent) {
        #if DEBUG
            let properties = event.properties
                .map { "\($0.key.rawValue)=\($0.value.encoded)" }
                .sorted()
                .joined(separator: " ")
            Self.logger.debug("\(event.name.rawValue, privacy: .public) \(properties, privacy: .public)")
        #endif
    }
}

// MARK: - Feature-facing tracking

/// What feature code depends on: typed events of one feature, no provider and no event-name strings.
protocol AnalyticsTracking<Event>: Sendable {
    associatedtype Event: Sendable
    func track(_ event: Event)
}

struct AnalyticsTracker<Event: AnalyticsEncodable>: AnalyticsTracking {
    let client: any AnalyticsClient

    func track(_ event: Event) {
        client.send(event.analyticsEvent)
    }
}

struct NoAnalyticsTracker<Event: Sendable>: AnalyticsTracking {
    func track(_: Event) {}
}
