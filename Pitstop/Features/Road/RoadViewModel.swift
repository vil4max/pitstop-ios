import Foundation
import Observation

struct RoadViewState: Equatable {
    var projection: RoadProjection?
    var isLoadFailed = false
}

@MainActor
@Observable
final class RoadViewModel {
    private(set) var state = RoadViewState()

    private let store: any CarMemoryStore
    private let now: @Sendable () -> Date

    init(store: any CarMemoryStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.now = now
    }

    func load() async {
        do {
            state.projection = try await Self.projection(from: store, now: now())
            state.isLoadFailed = false
        } catch {
            state.isLoadFailed = true
        }
    }

    /// Road owns no data: it is recomputed from the same facts Service and History read.
    static func projection(from store: any CarMemoryStore,
                           now: Date) async throws(CarMemoryStoreError) -> RoadProjection
    {
        let completions = try await store.maintenanceCompletions()
        let context = try await MaintenanceContext(
            now: now,
            latestReading: store.odometerReadings().latest,
            completions: completions
        )
        let states = try await MaintenanceEngine().states(
            policies: store.maintenancePolicies(),
            completions: completions,
            context: context
        )
        let history = try await HistoryTimeline(events: store.historyEvents(), completions: completions)
        return RoadProjector().project(RoadContext(now: now, maintenanceStates: states, history: history))
    }
}
