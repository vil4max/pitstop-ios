import Foundation
import Synchronization

/// Where analytics preferences live. The app uses `UserDefaults`; tests and previews keep them in memory.
protocol AnalyticsPreferenceStorage: Sendable {
    func string(forKey key: String) -> String?
    func setString(_ value: String?, forKey key: String)
}

struct UserDefaultsAnalyticsPreferences: AnalyticsPreferenceStorage {
    /// Apple documents `UserDefaults` as thread-safe; the SDK does not mark it `Sendable`.
    nonisolated(unsafe) let defaults: UserDefaults

    func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func setString(_ value: String?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

final class InMemoryAnalyticsPreferences: AnalyticsPreferenceStorage {
    private let values = Mutex<[String: String]>([:])

    func string(forKey key: String) -> String? {
        values.withLock { $0[key] }
    }

    func setString(_ value: String?, forKey key: String) {
        values.withLock { $0[key] = value }
    }
}

/// The identity events are sent under. `nil` means nothing may be sent.
protocol AnalyticsIdentityReading: Sendable {
    var anonymousID: String? { get }
}

protocol AnalyticsConsentStoring: AnalyticsConsentReading, AnalyticsIdentityReading {
    func grant()
    func withdraw()
}

/// The user's analytics choice and the anonymous ID that exists only while it is `granted` (ADR 0022).
/// The ID is a random UUID made on opt-in, never derived from the device, and deleted on withdrawal,
/// so a later opt-in starts a new, unlinkable identity.
struct AnalyticsConsentStore: AnalyticsConsentStoring {
    static let consentKey = "analytics.consent"
    static let anonymousIDKey = "analytics.anonymousID"

    let storage: any AnalyticsPreferenceStorage
    var makeID: @Sendable () -> String = { UUID().uuidString.lowercased() }

    var consent: AnalyticsConsent {
        storage.string(forKey: Self.consentKey).flatMap(AnalyticsConsent.init(rawValue:)) ?? .notAsked
    }

    var anonymousID: String? {
        guard consent == .granted else { return nil }
        return storage.string(forKey: Self.anonymousIDKey)
    }

    /// The ID is written before the consent and removed after it, so no reader sees `granted` without an ID.
    func grant() {
        if storage.string(forKey: Self.anonymousIDKey) == nil {
            storage.setString(makeID(), forKey: Self.anonymousIDKey)
        }
        storage.setString(AnalyticsConsent.granted.rawValue, forKey: Self.consentKey)
    }

    func withdraw() {
        storage.setString(AnalyticsConsent.declined.rawValue, forKey: Self.consentKey)
        storage.setString(nil, forKey: Self.anonymousIDKey)
    }
}

/// What a provider adapter holds in memory between events and a request.
protocol AnalyticsPipelineControlling: Sendable {
    func flush() async
    func discardPending()
}

struct NoAnalyticsPipeline: AnalyticsPipelineControlling {
    func flush() async {}
    func discardPending() {}
}

/// The one place consent changes. Settings flips it; a withdrawal also drops every event not yet sent.
struct AnalyticsSharing: Sendable {
    let consent: any AnalyticsConsentStoring
    let pipeline: any AnalyticsPipelineControlling

    var isEnabled: Bool {
        consent.consent == .granted
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            consent.grant()
        } else {
            consent.withdraw()
            pipeline.discardPending()
        }
    }

    func flush() async {
        await pipeline.flush()
    }

    static func inMemory() -> AnalyticsSharing {
        AnalyticsSharing(
            consent: AnalyticsConsentStore(storage: InMemoryAnalyticsPreferences()),
            pipeline: NoAnalyticsPipeline()
        )
    }
}
