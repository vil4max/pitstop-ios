import Foundation

/// Composition root: the only place that knows which concrete store backs the app.
struct AppEnvironment: Sendable {
    enum Persistence: Equatable, Sendable {
        case durable
        /// The on-disk store could not be opened; this session keeps data in memory only.
        case temporary
    }

    static let inMemoryArgument = "-pitstop-in-memory"
    /// DEBUG only: product events go to the local log instead of nowhere, as if the user had opted in.
    static let analyticsLogArgument = "-pitstop-analytics-log"

    let store: any CarMemoryStore
    /// Shares the car memory's container, so both live in one file under one migration plan (ADR 0016).
    let questions: any PitQuestionStateStore
    let registry: PitQuestionRegistry
    let persistence: Persistence
    /// Already consent-gated; the only analytics client feature trackers are built from (ADR 0021).
    let analytics: any AnalyticsClient
    /// The Settings switch for that gate, and the flush on leaving the app (ADR 0022).
    let analyticsSharing: AnalyticsSharing
    /// Runs once before the first load. Only the DEBUG demo launch uses it.
    var prepare: (@Sendable () async -> Void)?

    static func live(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment {
        let log = AppLog.logger(category: "app.persistence")
        let registry = productRegistry()
        let analytics = makeAnalytics(
            arguments: arguments,
            info: Bundle.main.infoDictionary,
            preferences: UserDefaultsAnalyticsPreferences(defaults: .standard)
        )
        #if DEBUG
            if arguments.contains(DemoData.argument) {
                // Demo facts never reach the user's store, even when the in-memory store cannot be built.
                guard let stores = makeStores(url: nil, registry: registry) else {
                    return .unavailable(registry: registry, analytics: analytics)
                }
                let staleMileage = arguments.contains(DemoData.staleMileageArgument)
                return AppEnvironment(stores, registry: registry, persistence: .temporary, analytics: analytics) {
                    await DemoData.seed(stores.car, staleMileage: staleMileage)
                }
            }
        #endif
        if arguments.contains(inMemoryArgument) {
            // Never fall through to the user's real store from a test or preview launch.
            guard let stores = makeStores(url: nil, registry: registry) else {
                return .unavailable(registry: registry, analytics: analytics)
            }
            return AppEnvironment(stores, registry: registry, persistence: .temporary, analytics: analytics)
        }
        if let stores = makeStores(url: PersistenceContainer.defaultStoreURL, registry: registry) {
            return AppEnvironment(stores, registry: registry, persistence: .durable, analytics: analytics)
        }
        // Core P2: the app must still open. The user is told that nothing will be kept.
        log.error("Persistent store unavailable; falling back to memory")
        guard let fallback = makeStores(url: nil, registry: registry) else {
            return .unavailable(registry: registry, analytics: analytics)
        }
        return AppEnvironment(fallback, registry: registry, persistence: .temporary, analytics: analytics)
    }

    struct Analytics: Sendable {
        let client: any AnalyticsClient
        let sharing: AnalyticsSharing
    }

    /// The PostHog adapter exists only when the build carries a project key and host (ADR 0022); otherwise
    /// the gated no-op stays and nothing can leave the device. Either way the stored consent gates events.
    static func makeAnalytics(
        arguments: [String],
        info: [String: Any]?,
        preferences: any AnalyticsPreferenceStorage
    ) -> Analytics {
        let consent = AnalyticsConsentStore(storage: preferences)
        #if DEBUG
            if arguments.contains(analyticsLogArgument) {
                return Analytics(
                    client: ConsentGatedAnalyticsClient(
                        client: LoggingAnalyticsClient(),
                        consent: FixedAnalyticsConsent(consent: .granted)
                    ),
                    sharing: AnalyticsSharing(consent: consent, pipeline: NoAnalyticsPipeline())
                )
            }
        #endif
        guard let configuration = PostHogConfiguration(info: info) else {
            return Analytics(
                client: ConsentGatedAnalyticsClient(client: NoAnalyticsClient(), consent: consent),
                sharing: AnalyticsSharing(consent: consent, pipeline: NoAnalyticsPipeline())
            )
        }
        let posthog = PostHogAnalyticsClient(
            configuration: configuration,
            transport: URLSessionAnalyticsTransport(),
            identity: consent
        )
        return Analytics(
            client: ConsentGatedAnalyticsClient(client: posthog, consent: consent),
            sharing: AnalyticsSharing(consent: consent, pipeline: posthog)
        )
    }

    private typealias Stores = (car: SwiftDataCarMemoryStore, questions: SwiftDataPitQuestionStore)

    private init(
        _ stores: Stores,
        registry: PitQuestionRegistry,
        persistence: Persistence,
        analytics: Analytics,
        prepare: (@Sendable () async -> Void)? = nil
    ) {
        self.init(
            store: stores.car,
            questions: stores.questions,
            registry: registry,
            persistence: persistence,
            analytics: analytics.client,
            analyticsSharing: analytics.sharing,
            prepare: prepare
        )
    }

    init(
        store: any CarMemoryStore,
        questions: any PitQuestionStateStore,
        registry: PitQuestionRegistry,
        persistence: Persistence,
        analytics: any AnalyticsClient = NoAnalyticsClient(),
        analyticsSharing: AnalyticsSharing = .inMemory(),
        prepare: (@Sendable () async -> Void)? = nil
    ) {
        self.store = store
        self.questions = questions
        self.registry = registry
        self.persistence = persistence
        self.analytics = analytics
        self.analyticsSharing = analyticsSharing
        self.prepare = prepare
    }

    private static func unavailable(registry: PitQuestionRegistry, analytics: Analytics) -> AppEnvironment {
        AppEnvironment(
            store: UnavailableCarMemoryStore(),
            questions: UnavailablePitQuestionStore(),
            registry: registry,
            persistence: .temporary,
            analytics: analytics.client,
            analyticsSharing: analytics.sharing
        )
    }

    /// A test builds the same list, so this fails only if the gate was skipped; Pit then asks nothing.
    private static func productRegistry() -> PitQuestionRegistry {
        do {
            return try PitQuestionRegistry.product()
        } catch {
            AppLog.logger(category: "app.pit").error("Question registry rejected: \(String(describing: error))")
            return .empty
        }
    }

    private static func makeStores(url: URL?, registry: PitQuestionRegistry) -> Stores? {
        do {
            let container = try PersistenceContainer.make(storeURL: url)
            return (
                SwiftDataCarMemoryStore(modelContainer: container),
                SwiftDataPitQuestionStore(modelContainer: container, registry: registry)
            )
        } catch {
            let kind = url == nil ? "in-memory" : "on-disk"
            AppLog.logger(category: "app.persistence").error("Cannot open \(kind) store: \(error)")
            return nil
        }
    }
}

/// Last resort when even an in-memory container cannot be built: every call fails visibly.
struct UnavailableCarMemoryStore: CarMemoryStore {
    func currentVehicle() async throws(CarMemoryStoreError) -> Vehicle {
        throw .storageFailure
    }

    func odometerReadings() async throws(CarMemoryStoreError) -> [OdometerReading] {
        throw .storageFailure
    }

    func notes() async throws(CarMemoryStoreError) -> [Note] {
        throw .storageFailure
    }

    func historyEvents() async throws(CarMemoryStoreError) -> [HistoryEvent] {
        throw .storageFailure
    }

    func maintenancePolicies() async throws(CarMemoryStoreError) -> [MaintenancePolicy] {
        throw .storageFailure
    }

    func maintenanceCompletions() async throws(CarMemoryStoreError) -> [MaintenanceCompletion] {
        throw .storageFailure
    }

    func execute(_: DomainCommand, now _: Date) async throws(CarMemoryStoreError) -> CommandResult {
        throw .storageFailure
    }
}

/// Question state cannot be read or written, so Pit asks nothing: `evaluate` records the ask first.
struct UnavailablePitQuestionStore: PitQuestionStateStore {
    func questionStates() async throws(PitQuestionStoreError) -> [PitQuestionState] {
        throw .storageFailure
    }

    func execute(_: PitQuestionCommand, now _: Date) async throws(PitQuestionStoreError) -> PitQuestionState {
        throw .storageFailure
    }
}
