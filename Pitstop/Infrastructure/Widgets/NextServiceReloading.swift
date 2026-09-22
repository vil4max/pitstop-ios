import Foundation
import WidgetKit

/// Asks the system to rebuild the next-service widget's timeline (ADR 0036). A protocol so tests can
/// count requests without WidgetKit.
protocol NextServiceReloading: Sendable {
    func reloadNextService()
}

struct WidgetCenterNextServiceReloader: NextServiceReloading {
    /// Requests made while the app is in the foreground do not count against the widget's daily budget
    /// (WidgetKit, "Keeping a widget up to date"). "Remember in PitStop" may save while the app runs in the
    /// background, and that reload does count; a fresh widget is worth more than the budget it spends.
    func reloadNextService() {
        WidgetCenter.shared.reloadTimelines(ofKind: NextServiceWidgetKind.kind)
    }
}

/// The durable car memory as the app uses it: every command goes to `base`, and only a command that was
/// saved asks the widget to reload. A rejected or failed command changed nothing, so it asks for nothing.
/// Reads pass through untouched.
struct WidgetReloadingCarMemoryStore: CarMemoryStore {
    let base: any CarMemoryStore
    let reloader: any NextServiceReloading

    func currentVehicle() async throws(CarMemoryStoreError) -> Vehicle {
        try await base.currentVehicle()
    }

    func odometerReadings() async throws(CarMemoryStoreError) -> [OdometerReading] {
        try await base.odometerReadings()
    }

    func notes() async throws(CarMemoryStoreError) -> [Note] {
        try await base.notes()
    }

    func historyEvents() async throws(CarMemoryStoreError) -> [HistoryEvent] {
        try await base.historyEvents()
    }

    func maintenancePolicies() async throws(CarMemoryStoreError) -> [MaintenancePolicy] {
        try await base.maintenancePolicies()
    }

    func maintenanceCompletions() async throws(CarMemoryStoreError) -> [MaintenanceCompletion] {
        try await base.maintenanceCompletions()
    }

    func plannedEvents() async throws(CarMemoryStoreError) -> [PlannedDatedEvent] {
        try await base.plannedEvents()
    }

    func vehicleServiceReports() async throws(CarMemoryStoreError) -> [VehicleServiceReport] {
        try await base.vehicleServiceReports()
    }

    @discardableResult
    func execute(_ command: DomainCommand, now: Date) async throws(CarMemoryStoreError) -> CommandResult {
        let result = try await base.execute(command, now: now)
        reloader.reloadNextService()
        return result
    }
}
