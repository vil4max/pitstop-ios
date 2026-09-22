import Foundation

public enum CommandResult: Hashable, Sendable {
    case noteCreated(Note)
    case noteUpdated(Note)
    case readingRecorded(OdometerReading)
    case vehicleUpdated(Vehicle)
    case completionConfirmed(MaintenanceCompletion)
    case completionRevoked(MaintenanceCompletion)
    case policySet(MaintenancePolicy)
    /// The owner's policy that was removed; the operation's completions are untouched.
    case trackingStopped(MaintenancePolicy)
    case eventRecorded(HistoryEvent)
    case eventCorrected(HistoryEvent)
    case plannedEventAdded(PlannedDatedEvent)
    case plannedEventUpdated(PlannedDatedEvent)
    case plannedEventRemoved(PlannedDatedEvent)
    /// The car's own reading for one operation; it replaced any earlier reading of that operation.
    case vehicleServiceReportRecorded(VehicleServiceReport)
    case vehicleServiceReportRemoved(VehicleServiceReport)
}

public enum CarMemoryStoreError: Error, Hashable, Sendable {
    case invalidCommand(DomainCommandError)
    case unknownVehicle
    case unknownNote
    case unknownEvent
    case unknownCompletion
    /// The vehicle has no owner-set policy for the operation, so there is nothing to stop tracking.
    case unknownPolicy
    /// A record with this ID already exists; history is never rewritten by a repeated command.
    case duplicateRecord
    case unknownPlannedEvent
    /// The vehicle has no dashboard reading for that operation, so there is nothing to delete.
    case unknownVehicleServiceReport
    /// The vehicle already has an insurance expiry on Road; the owner changes that one instead (ADR 0032).
    case insuranceExpiryAlreadyPlanned
    case storageFailure
}

/// The car's persisted memory. Reads return domain values; the only write path is a
/// `DomainCommand`, so no caller (UI, intent, or model adapter) can store ad-hoc records.
public protocol CarMemoryStore: Sendable {
    /// Returns the single car context (core C1), creating the provisional one on first use.
    func currentVehicle() async throws(CarMemoryStoreError) -> Vehicle
    func odometerReadings() async throws(CarMemoryStoreError) -> [OdometerReading]
    func notes() async throws(CarMemoryStoreError) -> [Note]
    func historyEvents() async throws(CarMemoryStoreError) -> [HistoryEvent]
    /// Every stored rule, including a recommendation shadowed by a custom policy; use `.effective`.
    func maintenancePolicies() async throws(CarMemoryStoreError) -> [MaintenancePolicy]
    func maintenanceCompletions() async throws(CarMemoryStoreError) -> [MaintenanceCompletion]
    /// Every stored planned date, earliest first, including ones Road no longer shows (ADR 0032).
    func plannedEvents() async throws(CarMemoryStoreError) -> [PlannedDatedEvent]
    /// Every stored dashboard reading, newest first. Older readings of an operation are mileage
    /// observations; the engine counts only the newest per operation (ADR 0035).
    func vehicleServiceReports() async throws(CarMemoryStoreError) -> [VehicleServiceReport]

    /// Validates the command, then persists it. A thrown error means nothing was saved.
    @discardableResult
    func execute(_ command: DomainCommand, now: Date) async throws(CarMemoryStoreError) -> CommandResult
}
