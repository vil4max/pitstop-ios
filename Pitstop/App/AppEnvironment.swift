import Foundation

/// Composition root: the only place that knows which concrete store backs the app.
struct AppEnvironment: Sendable {
    enum Persistence: Equatable, Sendable {
        case durable
        /// The on-disk store could not be opened; this session keeps data in memory only.
        case temporary
    }

    static let inMemoryArgument = "-pitstop-in-memory"

    let store: any CarMemoryStore
    let persistence: Persistence

    static func live(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment {
        let log = AppLog.logger(category: "app.persistence")
        if arguments.contains(inMemoryArgument) {
            // Never fall through to the user's real store from a test or preview launch.
            guard let store = makeStore(url: nil) else {
                return AppEnvironment(store: UnavailableCarMemoryStore(), persistence: .temporary)
            }
            return AppEnvironment(store: store, persistence: .temporary)
        }
        if let store = makeStore(url: PersistenceContainer.defaultStoreURL) {
            return AppEnvironment(store: store, persistence: .durable)
        }
        // Core P2: the app must still open. The user is told that nothing will be kept.
        log.error("Persistent store unavailable; falling back to memory")
        guard let fallback = makeStore(url: nil) else {
            return AppEnvironment(store: UnavailableCarMemoryStore(), persistence: .temporary)
        }
        return AppEnvironment(store: fallback, persistence: .temporary)
    }

    private static func makeStore(url: URL?) -> SwiftDataCarMemoryStore? {
        do {
            return try SwiftDataCarMemoryStore(modelContainer: PersistenceContainer.make(storeURL: url))
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
