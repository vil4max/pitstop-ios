import Foundation

/// The maintenance facts as Service, Road, Car Board and Pit's questions read them, assembled one way: the stored
/// facts, the car's mileage context from them, and the engine's states under that context. Every surface that
/// reads it at the same moment sees the same mileage and the same states (REQ-BOARD-026, ADR 0010). The widget
/// reads its own through `NextServiceStoreReader`, since it opens the store read-only.
struct MaintenanceSnapshot: Sendable {
    let completions: [MaintenanceCompletion]
    let reports: [VehicleServiceReport]
    let readings: [OdometerReading]
    let policies: [MaintenancePolicy]
    let context: MaintenanceContext
    /// In the engine's order; surfaces sort them as they show them.
    let states: [MaintenanceOperationState]

    static func read(from store: any CarMemoryStore, now: Date) async throws(CarMemoryStoreError)
        -> MaintenanceSnapshot
    {
        let completions = try await store.maintenanceCompletions()
        let reports = try await store.vehicleServiceReports()
        let readings = try await store.odometerReadings()
        let policies = try await store.maintenancePolicies()
        let context = MaintenanceContext(
            now: now, latestReading: readings.latest, completions: completions, reports: reports
        )
        let states = MaintenanceEngine().states(
            policies: policies, completions: completions, reports: reports, context: context
        )
        return MaintenanceSnapshot(
            completions: completions, reports: reports, readings: readings, policies: policies,
            context: context, states: states
        )
    }

    /// Road from these facts: Road owns no data, so the Road screen and the Car Board tile project the same lane
    /// from the same snapshot, history and planned dates.
    func road(history: HistoryTimeline, planned: [PlannedDatedEvent], calendar: Calendar) -> RoadProjection {
        RoadProjector().project(
            RoadContext(
                now: context.now,
                maintenanceStates: states,
                plannedEvents: planned.map(\.roadEvent),
                history: history,
                mileageObservations: MileageObservation.history(
                    readings: readings, completions: completions, reports: reports
                ),
                calendar: calendar
            ))
    }
}
