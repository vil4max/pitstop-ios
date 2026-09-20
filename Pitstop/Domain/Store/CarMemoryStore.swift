import Foundation

public enum CommandResult: Hashable, Sendable {
    case noteCreated(Note)
    case noteUpdated(Note)
    case readingRecorded(OdometerReading)
    case vehicleUpdated(Vehicle)
    case completionConfirmed(MaintenanceCompletion)
    case completionRevoked(MaintenanceCompletion)
    case policySet(MaintenancePolicy)
    case eventRecorded(HistoryEvent)
    case eventCorrected(HistoryEvent)
}

public enum CarMemoryStoreError: Error, Hashable, Sendable {
    case invalidCommand(DomainCommandError)
    case unknownVehicle
    case unknownNote
    case unknownEvent
    case unknownCompletion
    /// A record with this ID already exists; history is never rewritten by a repeated command.
    case duplicateRecord
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

    /// Validates the command, then persists it. A thrown error means nothing was saved.
    @discardableResult
    func execute(_ command: DomainCommand, now: Date) async throws(CarMemoryStoreError) -> CommandResult
}
