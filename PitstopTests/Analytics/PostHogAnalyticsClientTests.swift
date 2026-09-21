import Foundation
@testable import Pitstop
import Testing

private let apiKey = "phc_fictional_test_key"
private let info: [String: String] = [
    PostHogConfiguration.apiKeyInfoKey: apiKey,
    PostHogConfiguration.hostInfoKey: "eu.i.posthog.com",
]
private let events = analyticsEventCatalog.map(\.analyticsEvent)

private func grantedConsent() -> AnalyticsConsentStore {
    let consent = AnalyticsConsentStore(storage: InMemoryAnalyticsPreferences())
    consent.grant()
    return consent
}

private func makeClient(
    transport: FakeAnalyticsTransport = FakeAnalyticsTransport(),
    identity: any AnalyticsIdentityReading,
    policy: PostHogAnalyticsClient.Policy = PostHogAnalyticsClient.Policy(flushInterval: nil),
    sleeper: RecordingSleeper = RecordingSleeper()
) throws -> PostHogAnalyticsClient {
    try PostHogAnalyticsClient(
        configuration: #require(PostHogConfiguration(info: info)),
        transport: transport,
        identity: identity,
        policy: policy,
        sleep: { try await sleeper.sleep($0) }
    )
}

@Suite("PostHog HTTP adapter", .timeLimit(.minutes(1)))
struct PostHogAnalyticsClientTests {

    // MARK: Payload

    @Test("ADR-0022: every event maps to a batch entry with closed values, the anonymous ID, and privacy flags")
    func payloadMapsEveryEvent() throws {
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let pending = events.map { PostHogPendingEvent(event: $0, distinctID: "anon-1", timestamp: timestamp) }

        let batch = try DecodedBatch(PostHogPayload.batch(pending, apiKey: apiKey))

        #expect(Set(batch.root.keys) == ["api_key", "historical_migration", "batch"])
        #expect(batch.root["api_key"] as? String == apiKey)
        #expect(batch.root["historical_migration"] as? Bool == false)
        #expect(batch.events.count == events.count)
        for (entry, source) in zip(batch.events, events) {
            #expect(Set(entry.keys) == ["event", "distinct_id", "timestamp", "properties"])
            #expect(entry["event"] as? String == source.name.rawValue)
            #expect(entry["distinct_id"] as? String == "anon-1")
            #expect(entry["timestamp"] as? String == "2027-01-15T08:00:00.000Z")
            let properties = try #require(entry["properties"] as? [String: Any])
            #expect(properties["$process_person_profile"] as? Bool == false)
            #expect(properties["$geoip_disable"] as? Bool == true)
            let reserved = Set(properties.keys.filter { $0.hasPrefix("$") })
            #expect(reserved == Set(PostHogPayload.privacyProperties.keys), "\(source.name.rawValue): \(reserved)")
            let closed = properties.filter { !$0.key.hasPrefix("$") }
            #expect(Set(closed.keys).isSubset(of: analyticsTaxonomy[source.name] ?? []))
            #expect(closed.mapValues { $0 as? String } == Dictionary(
                uniqueKeysWithValues: source.properties.map { ($0.key.rawValue, $0.value.encoded) }
            ))
        }
    }

    @Test("ADR-0022: the batch carries no IP, device, person, or set properties")
    func payloadHasNoIdentifyingKeys() throws {
        let pending = events.map { PostHogPendingEvent(event: $0, distinctID: "anon-1", timestamp: .now) }
        let text = try #require(String(bytes: PostHogPayload.batch(pending, apiKey: apiKey), encoding: .utf8))

        for forbidden in ["\"$ip\"", "$set", "$device", "$os", "$app", "$lib", "$anon_distinct_id", "idfa", "$groups"] {
            #expect(!text.contains(forbidden), "payload contains \(forbidden)")
        }
    }

    // MARK: Consent and identity

    @Test(
        "ADR-0021: without an opt-in the adapter makes no request",
        arguments: [AnalyticsConsent.notAsked, .declined]
    )
    func noConsentNoRequest(consent: AnalyticsConsent) async throws {
        let preferences = InMemoryAnalyticsPreferences()
        preferences.setString(consent.rawValue, forKey: AnalyticsConsentStore.consentKey)
        let store = AnalyticsConsentStore(storage: preferences)
        let transport = FakeAnalyticsTransport()
        let posthog = try makeClient(transport: transport, identity: store)
        let gated = ConsentGatedAnalyticsClient(client: posthog, consent: store)

        events.forEach(gated.send)
        await posthog.flush()

        #expect(transport.bodies.isEmpty)
        #expect(posthog.pendingCount == 0)
        #expect(store.anonymousID == nil)
    }

    @Test("ADR-0022: the toggle is off by default and an opt-in creates a random anonymous ID")
    func optInCreatesAnonymousID() throws {
        let sharing = AnalyticsSharing(
            consent: AnalyticsConsentStore(storage: InMemoryAnalyticsPreferences()),
            pipeline: NoAnalyticsPipeline()
        )
        #expect(!sharing.isEnabled)
        #expect(sharing.consent.consent == .notAsked)
        #expect(sharing.consent.anonymousID == nil)

        sharing.setEnabled(true)

        #expect(sharing.isEnabled)
        let id = try #require(sharing.consent.anonymousID)
        #expect(UUID(uuidString: id) != nil)
    }

    @Test("ADR-0022: withdrawing consent clears the queue and the anonymous ID; a new opt-in gets a new ID")
    func withdrawalClearsQueueAndID() async throws {
        let preferences = InMemoryAnalyticsPreferences()
        let store = AnalyticsConsentStore(storage: preferences)
        let transport = FakeAnalyticsTransport()
        let posthog = try makeClient(transport: transport, identity: store)
        let sharing = AnalyticsSharing(consent: store, pipeline: posthog)
        let gated = ConsentGatedAnalyticsClient(client: posthog, consent: store)
        sharing.setEnabled(true)
        let firstID = try #require(store.anonymousID)
        events.prefix(3).forEach(gated.send)
        #expect(posthog.pendingCount == 3)

        sharing.setEnabled(false)
        #expect(posthog.pendingCount == 0)
        await posthog.flush()

        #expect(transport.bodies.isEmpty)
        #expect(store.consent == .declined)
        #expect(store.anonymousID == nil)
        #expect(preferences.string(forKey: AnalyticsConsentStore.anonymousIDKey) == nil)

        sharing.setEnabled(true)
        #expect(try #require(store.anonymousID) != firstID)
    }

    @Test("ADR-0022: an event queued under an earlier identity is never sent under a later one")
    func staleIdentityIsDropped() async throws {
        let store = grantedConsent()
        let transport = FakeAnalyticsTransport()
        let posthog = try makeClient(transport: transport, identity: store)
        events.prefix(2).forEach(posthog.send)

        store.withdraw()
        store.grant()
        await posthog.flush()

        #expect(transport.bodies.isEmpty)
        #expect(posthog.pendingCount == 0)
    }

    // MARK: Batching

    @Test("ADR-0022: nothing is sent below the batch size; a full batch is sent in one request")
    func fullBatchFlushes() async throws {
        let store = grantedConsent()
        let transport = FakeAnalyticsTransport()
        let posthog = try makeClient(
            transport: transport,
            identity: store,
            policy: .init(batchSize: 3, flushInterval: nil)
        )
        var requests = transport.requests.makeAsyncIterator()

        events.prefix(2).forEach(posthog.send)
        #expect(transport.bodies.isEmpty)
        #expect(posthog.pendingCount == 2)
        posthog.send(events[2])

        let body = try #require(await requests.next())
        let batch = try DecodedBatch(body)
        #expect(batch.eventNames == events.prefix(3).map(\.name.rawValue))
        #expect(batch.distinctIDs == [store.anonymousID])
        #expect(transport.urls.first?.absoluteString == "https://eu.i.posthog.com/batch/")
    }

    @Test("ADR-0022: a partial batch is sent once the flush interval passes")
    func intervalFlushes() async throws {
        let store = grantedConsent()
        let transport = FakeAnalyticsTransport()
        let sleeper = RecordingSleeper()
        let posthog = try makeClient(
            transport: transport,
            identity: store,
            policy: .init(batchSize: 20, flushInterval: .seconds(30)),
            sleeper: sleeper
        )
        var requests = transport.requests.makeAsyncIterator()

        posthog.send(events[0])

        let body = try #require(await requests.next())
        #expect(try DecodedBatch(body).eventNames == [events[0].name.rawValue])
        #expect(sleeper.durations == [.seconds(30)])
    }

    @Test("ADR-0022: a full queue drops its oldest events")
    func boundedQueueDropsOldest() async throws {
        let store = grantedConsent()
        let transport = FakeAnalyticsTransport()
        let posthog = try makeClient(
            transport: transport,
            identity: store,
            policy: .init(batchSize: 100, capacity: 5, flushInterval: nil)
        )

        events.prefix(8).forEach(posthog.send)
        #expect(posthog.pendingCount == 5)
        await posthog.flush()

        let batch = try DecodedBatch(#require(transport.bodies.first))
        #expect(batch.eventNames == events[3 ..< 8].map(\.name.rawValue))
    }

    // MARK: Delivery

    @Test("ADR-0022: transient failures are retried with doubling backoff")
    func transientFailureRetries() async throws {
        let transport = FakeAnalyticsTransport(replies: [.status(503), .failure, .status(200)])
        let sleeper = RecordingSleeper()
        let posthog = try makeClient(transport: transport, identity: grantedConsent(), sleeper: sleeper)
        posthog.send(events[0])

        await posthog.flush()

        #expect(transport.bodies.count == 3)
        #expect(sleeper.durations == [.seconds(2), .seconds(4)])
        #expect(posthog.pendingCount == 0)
    }

    @Test("ADR-0022: a batch that keeps failing stays in memory for the next flush")
    func exhaustedRetriesKeepBatch() async throws {
        let transport = FakeAnalyticsTransport(fallback: .status(503))
        let sleeper = RecordingSleeper()
        let posthog = try makeClient(transport: transport, identity: grantedConsent(), sleeper: sleeper)
        events.prefix(2).forEach(posthog.send)

        await posthog.flush()

        #expect(transport.bodies.count == 3)
        #expect(sleeper.durations == [.seconds(2), .seconds(4)])
        #expect(posthog.pendingCount == 2)
    }

    @Test("ADR-0022: after a flush gives up, a full batch waits instead of retrying at once")
    func givingUpPausesSizeFlushes() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let transport = FakeAnalyticsTransport(replies: [.status(503), .status(503), .status(503)])
        let posthog = try PostHogAnalyticsClient(
            configuration: #require(PostHogConfiguration(info: info)),
            transport: transport,
            identity: grantedConsent(),
            policy: .init(batchSize: 2, flushInterval: nil),
            now: { now },
            sleep: { _ in }
        )
        posthog.send(events[0])
        await posthog.flush()
        #expect(transport.bodies.count == 3)
        #expect(posthog.retryAfter == now.addingTimeInterval(60))

        posthog.send(events[1])

        // The batch is full, but the size trigger waits: both events stay in memory without a new request.
        #expect(posthog.pendingCount == 2)
        await posthog.flush()
        #expect(transport.bodies.count == 4)
        #expect(posthog.retryAfter == nil)
    }

    @Test("ADR-0022: a refused batch is dropped without retry", arguments: [400, 401, 413])
    func rejectedBatchIsDropped(status: Int) async throws {
        let transport = FakeAnalyticsTransport(replies: [.status(status)])
        let sleeper = RecordingSleeper()
        let posthog = try makeClient(transport: transport, identity: grantedConsent(), sleeper: sleeper)
        posthog.send(events[0])

        await posthog.flush()

        #expect(transport.bodies.count == 1)
        #expect(sleeper.durations.isEmpty)
        #expect(posthog.pendingCount == 0)
    }

    @Test("ADR-0022: backoff doubles up to its cap")
    func backoffIsCapped() {
        let policy = PostHogAnalyticsClient.Policy()
        #expect([1, 2, 3, 5, 6, 30].map(policy.backoff(afterAttempt:)) == [
            .seconds(2), .seconds(4), .seconds(8), .seconds(32), .seconds(60), .seconds(60),
        ])
    }

    @Test("ADR-0022: a network failure never reaches the feature that tracked the event")
    func transportFailureStaysInside() async throws {
        let store = grantedConsent()
        let transport = FakeAnalyticsTransport(fallback: .failure)
        let posthog = try makeClient(transport: transport, identity: store)
        let tracker = AnalyticsTracker<NotesAnalyticsEvent>(
            client: ConsentGatedAnalyticsClient(client: posthog, consent: store)
        )

        // `track` is synchronous and cannot throw; it returns before any request is made.
        tracker.track(.noteArchived(sourceContext: .service, age: .underOneDay))
        #expect(transport.bodies.isEmpty)
        await posthog.flush()

        #expect(transport.bodies.count == 3)
        #expect(posthog.pendingCount == 1)
    }

    // MARK: Configuration

    @Test(
        "ADR-0022: an empty, unexpanded, or insecure configuration creates no client",
        arguments: [
            [:],
            [PostHogConfiguration.apiKeyInfoKey: "", PostHogConfiguration.hostInfoKey: ""],
            [PostHogConfiguration.apiKeyInfoKey: apiKey, PostHogConfiguration.hostInfoKey: ""],
            [PostHogConfiguration.apiKeyInfoKey: "", PostHogConfiguration.hostInfoKey: "eu.i.posthog.com"],
            [
                PostHogConfiguration.apiKeyInfoKey: "$(POSTHOG_PROJECT_API_KEY)",
                PostHogConfiguration.hostInfoKey: "$(POSTHOG_HOST)",
            ],
            [PostHogConfiguration.apiKeyInfoKey: apiKey, PostHogConfiguration.hostInfoKey: "http://eu.i.posthog.com"],
            [PostHogConfiguration.apiKeyInfoKey: "phc key", PostHogConfiguration.hostInfoKey: "eu.i.posthog.com"],
        ] as [[String: String]]
    )
    func invalidConfigurationIsNil(values: [String: String]) {
        #expect(PostHogConfiguration(info: values) == nil)
    }

    @Test(
        "ADR-0022: the host may be bare or https",
        arguments: [
            ("eu.i.posthog.com", "https://eu.i.posthog.com/batch/"),
            ("https://us.i.posthog.com", "https://us.i.posthog.com/batch/"),
            (" https://us.i.posthog.com/ ", "https://us.i.posthog.com/batch/"),
        ]
    )
    func hostBecomesBatchURL(host: String, expected: String) {
        let configuration = PostHogConfiguration(info: [
            PostHogConfiguration.apiKeyInfoKey: apiKey,
            PostHogConfiguration.hostInfoKey: host,
        ])
        #expect(configuration?.batchURL.absoluteString == expected)
    }

    @Test("ADR-0022: without a configured project the app composes the gated no-op")
    func emptyConfigurationComposesNoClient() {
        let analytics = AppEnvironment.makeAnalytics(
            arguments: [],
            info: [PostHogConfiguration.apiKeyInfoKey: "", PostHogConfiguration.hostInfoKey: ""],
            preferences: InMemoryAnalyticsPreferences()
        )

        let gated = analytics.client as? ConsentGatedAnalyticsClient
        #expect(gated?.client is NoAnalyticsClient)
        #expect(analytics.sharing.pipeline is NoAnalyticsPipeline)
    }

    @Test("ADR-0022: a configured project composes the gated PostHog adapter")
    func configurationComposesAdapter() {
        let analytics = AppEnvironment.makeAnalytics(
            arguments: [],
            info: info,
            preferences: InMemoryAnalyticsPreferences()
        )

        let gated = analytics.client as? ConsentGatedAnalyticsClient
        #expect(gated?.client is PostHogAnalyticsClient)
        #expect(analytics.sharing.pipeline is PostHogAnalyticsClient)
        #expect(!analytics.sharing.isEnabled)
    }
}
