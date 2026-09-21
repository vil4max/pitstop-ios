import Foundation

/// The PostHog project the app sends to, read from Info.plist keys that build settings fill in
/// (`Config/Analytics.xcconfig`, ADR 0022). The repository leaves both empty.
struct PostHogConfiguration: Equatable, Sendable {
    static let apiKeyInfoKey = "PostHogProjectAPIKey"
    static let hostInfoKey = "PostHogHost"

    /// A project API key is write-only: it can capture events but read nothing back.
    let projectAPIKey: String
    let batchURL: URL

    /// `nil` when a value is missing, empty, an unexpanded build setting, or not an HTTPS host; the app then
    /// creates no provider client at all.
    init?(info: [String: Any]?) {
        let key = (info?[Self.apiKeyInfoKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let host = (info?[Self.hostInfoKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty, !key.contains("$("), !key.contains(where: \.isWhitespace),
              let url = Self.batchURL(host: host)
        else { return nil }
        projectAPIKey = key
        batchURL = url
    }

    /// The host may be given bare (`eu.i.posthog.com`, as an xcconfig needs) or with `https://`.
    private static func batchURL(host: String) -> URL? {
        guard !host.isEmpty, !host.contains("$(") else { return nil }
        let base = host.contains("://") ? host : "https://" + host
        guard var components = URLComponents(string: base),
              components.scheme == "https",
              let name = components.host, !name.isEmpty
        else { return nil }
        components.path = "/batch/"
        components.query = nil
        components.fragment = nil
        return components.url
    }
}

/// One event waiting for a request, stamped when it was sent to the client.
struct PostHogPendingEvent: Hashable, Sendable {
    let event: AnalyticsEvent
    let distinctID: String
    let timestamp: Date
}

/// Builds the body of `POST /batch/` (https://posthog.com/docs/api/capture). Only the event name, its closed
/// properties, the anonymous ID, the time, and the two privacy flags below are sent: no device, OS, app,
/// locale, or network property is added, and `$ip` is never set by the app.
enum PostHogPayload {
    /// `$process_person_profile: false` captures the event as anonymous, without a person profile;
    /// `$geoip_disable: true` asks ingestion not to derive a location from the request's IP address.
    static let privacyProperties: [String: Bool] = [
        "$process_person_profile": false,
        "$geoip_disable": true,
    ]

    /// UTC, with milliseconds, as the capture API's ISO 8601 `timestamp`.
    private static let timestampStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    static func batch(_ events: [PostHogPendingEvent], apiKey: String) throws -> Data {
        let body: [String: Any] = [
            "api_key": apiKey,
            "historical_migration": false,
            "batch": events.map(encode),
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    private static func encode(_ pending: PostHogPendingEvent) -> [String: Any] {
        var properties: [String: Any] = privacyProperties
        for (key, value) in pending.event.properties {
            properties[key.rawValue] = value.encoded
        }
        return [
            "event": pending.event.name.rawValue,
            "distinct_id": pending.distinctID,
            "timestamp": pending.timestamp.formatted(timestampStyle),
            "properties": properties,
        ]
    }
}
