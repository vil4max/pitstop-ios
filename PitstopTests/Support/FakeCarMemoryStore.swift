import Foundation
@testable import Pitstop

/// In-memory double. It repeats the real store's command validation, vehicle check, and
/// duplicate-reading check; SwiftData behaviour itself is covered by the store's own tests.
actor FakeCarMemoryStore: CarMemoryStore {
    private(set) var vehicle: Vehicle
    private(set) var readings: [OdometerReading] = []
    private(set) var storedNotes: [Note] = []
    private(set) var events: [HistoryEvent] = []
    private(set) var policies: [MaintenancePolicy] = []
    private(set) var completions: [MaintenanceCompletion] = []
    private(set) var planned: [PlannedDatedEvent] = []
    private(set) var reports: [VehicleServiceReport] = []
    private(set) var executed: [DomainCommand] = []
    private var failure: CarMemoryStoreError?
    private var failsReadings = false
    private var failsCommands = false
    private var failingPolicyOperations: Set<MaintenanceOperationID> = []

    init(vehicle: Vehicle = .provisional()) {
        self.vehicle = vehicle
    }

    func failEverything(with error: CarMemoryStoreError = .storageFailure) {
        failure = error
    }

    func recover() {
        failure = nil
        failsReadings = false
        failsCommands = false
        failingPolicyOperations = []
    }

    /// Reads keep working; only writes fail, as when the disk is full.
    func failCommands() {
        failsCommands = true
    }

    /// Only policy writes for these operations fail, so a multi-item save can fail part way.
    func failPolicies(for operations: Set<MaintenanceOperationID>) {
        failingPolicyOperations = operations
    }

    func failReadingCommands() {
        failsReadings = true
    }

    func currentVehicle() throws(CarMemoryStoreError) -> Vehicle {
        try check()
        return vehicle
    }

    func odometerReadings() throws(CarMemoryStoreError) -> [OdometerReading] {
        try check()
        return readings.sorted { $0.recordedAt > $1.recordedAt }
    }

    func notes() throws(CarMemoryStoreError) -> [Note] {
        try check()
        return storedNotes.sorted { $0.createdAt > $1.createdAt }
    }

    func historyEvents() throws(CarMemoryStoreError) -> [HistoryEvent] {
        try check()
        return events.sorted { $0.date > $1.date }
    }

    func maintenancePolicies() throws(CarMemoryStoreError) -> [MaintenancePolicy] {
        try check()
        return policies
    }

    func maintenanceCompletions() throws(CarMemoryStoreError) -> [MaintenanceCompletion] {
        try check()
        return completions
    }

    func plannedEvents() throws(CarMemoryStoreError) -> [PlannedDatedEvent] {
        try check()
        return planned.sorted { ($0.date, $0.createdAt) < ($1.date, $1.createdAt) }
    }

    func vehicleServiceReports() throws(CarMemoryStoreError) -> [VehicleServiceReport] {
        try check()
        return reports.newestFirst
    }

    /// Seeds a reading without going through a command, for engine and surface fixtures. Like the real
    /// store it keeps older readings; only the newest per operation is read.
    func seed(_ report: VehicleServiceReport) {
        reports.append(report)
    }

    func execute(_ command: DomainCommand, now: Date) throws(CarMemoryStoreError) -> CommandResult {
        try check()
        guard !failsCommands else { throw .storageFailure }
        do {
            try command.validate(now: now)
        } catch {
            throw .invalidCommand(error)
        }
        defer {
            if !failsReadings || !command.isReading {
                executed.append(command)
            }
        }
        switch command {
        case let .createNote(create):
            let note = Note(
                vehicleID: create.vehicleID,
                rawText: create.rawText,
                createdAt: create.createdAt ?? now,
                canonicalContexts: create.canonicalContexts
            )
            storedNotes.append(note)
            return .noteCreated(note)
        case let .updateNote(update):
            guard let index = storedNotes.firstIndex(where: { $0.id == update.noteID }) else { throw .unknownNote }
            let old = storedNotes[index]
            let note = Note(
                id: old.id,
                vehicleID: old.vehicleID,
                rawText: update.rawText ?? old.rawText,
                createdAt: old.createdAt,
                status: update.status ?? old.status,
                canonicalContexts: old.canonicalContexts
            )
            storedNotes[index] = note
            return .noteUpdated(note)
        case let .recordOdometerReading(record):
            guard !failsReadings else { throw .storageFailure }
            guard record.reading.vehicleID == vehicle.id else { throw .unknownVehicle }
            guard !readings.contains(where: { $0.id == record.reading.id }) else { throw .duplicateRecord }
            readings.append(record.reading)
            return .readingRecorded(record.reading)
        default:
            return try applyToCar(command, now: now)
        }
    }

    /// The rest of the same switch. Split only to stay under the complexity the project lints for.
    private func applyToCar(_ command: DomainCommand, now: Date) throws(CarMemoryStoreError) -> CommandResult {
        switch command {
        case let .recordVehicleFact(record):
            guard record.vehicleID == vehicle.id else { throw .unknownVehicle }
            vehicle = vehicle.applying(record.fact)
            return .vehicleUpdated(vehicle)
        case let .confirmMaintenanceCompletion(confirm):
            // A known record ID is rejected, exactly as the real store rejects it.
            guard !completions.contains(where: { $0.id == confirm.completion.id }) else { throw .duplicateRecord }
            completions.append(confirm.completion)
            return .completionConfirmed(confirm.completion)
        case let .revokeMaintenanceCompletion(revoke):
            guard let index = completions.firstIndex(where: { $0.id == revoke.completionID }) else {
                throw .unknownCompletion
            }
            return .completionRevoked(completions.remove(at: index))
        case let .replaceMaintenanceCompletion(replace):
            return try applyReplace(replace)
        case let .setMaintenancePolicy(set):
            guard !failingPolicyOperations.contains(set.policy.operationID) else { throw .storageFailure }
            policies.removeAll { $0.operationID == set.policy.operationID && $0.source == set.policy.source }
            policies.append(set.policy)
            return .policySet(set.policy)
        case let .stopTrackingOperation(stop):
            guard stop.vehicleID == vehicle.id else { throw .unknownVehicle }
            let isOwned = { (policy: MaintenancePolicy) in
                policy.operationID == stop.operationID && policy.source == .userCustom
            }
            guard let removed = policies.first(where: isOwned) else { throw .unknownPolicy }
            policies.removeAll(where: isOwned)
            return .trackingStopped(removed)
        case let .recordVehicleEvent(record):
            return try insertEvent(record.event)
        case let .correctVehicleEvent(correct):
            guard let index = events.firstIndex(where: { $0.id == correct.event.id }),
                  events[index].vehicleID == correct.event.vehicleID
            else { throw .unknownEvent }
            events[index] = correct.event
            return .eventCorrected(correct.event)
        case let .recordExpense(record):
            return try insertEvent(record.event)
        default:
            return try applyPlanned(command, now: now)
        }
    }

    /// Planned dates, with the real store's vehicle, duplicate, and one-insurance checks (ADR 0032).
    private func applyPlanned(_ command: DomainCommand, now: Date) throws(CarMemoryStoreError) -> CommandResult {
        switch command {
        case let .addPlannedEvent(add):
            guard add.event.vehicleID == vehicle.id else { throw .unknownVehicle }
            guard !planned.contains(where: { $0.id == add.event.id }) else { throw .duplicateRecord }
            try requireNoOtherInsurance(for: add.event, now: now)
            planned.append(add.event)
            return .plannedEventAdded(add.event)
        case let .updatePlannedEvent(update):
            guard update.event.vehicleID == vehicle.id else { throw .unknownVehicle }
            guard let index = planned.firstIndex(where: { $0.id == update.event.id }) else {
                throw .unknownPlannedEvent
            }
            try requireNoOtherInsurance(for: update.event, now: now)
            let old = planned[index]
            planned[index] = PlannedDatedEvent(
                id: old.id, vehicleID: old.vehicleID, kind: update.event.kind, date: update.event.date,
                createdAt: old.createdAt
            )
            return .plannedEventUpdated(planned[index])
        case let .removePlannedEvent(remove):
            guard let index = planned.firstIndex(where: { $0.id == remove.eventID }) else {
                throw .unknownPlannedEvent
            }
            return .plannedEventRemoved(planned.remove(at: index))
        default:
            return try applyReport(command)
        }
    }

    /// All or nothing, as the real store saves it once: every check runs before anything changes.
    private func applyReplace(
        _ replace: ReplaceMaintenanceCompletionCommand
    ) throws(CarMemoryStoreError) -> CommandResult {
        let completion = replace.completion
        guard completion.vehicleID == vehicle.id else { throw .unknownVehicle }
        guard !completions.contains(where: { $0.id == completion.id }) else { throw .duplicateRecord }
        let replaced = completions.filter { replace.replacedIDs.contains($0.id) }
        let isSameWork = replaced.allSatisfy {
            $0.vehicleID == completion.vehicleID && $0.operationID == completion.operationID
        }
        guard replaced.count == replace.replacedIDs.count, isSameWork else { throw .unknownCompletion }
        completions.removeAll { replace.replacedIDs.contains($0.id) }
        completions.append(completion)
        return .completionConfirmed(completion)
    }

    /// Dashboard readings, with the real store's vehicle check and one-row-per-operation rule.
    private func applyReport(_ command: DomainCommand) throws(CarMemoryStoreError) -> CommandResult {
        switch command {
        case let .recordVehicleServiceReport(record):
            guard record.report.vehicleID == vehicle.id else { throw .unknownVehicle }
            guard !reports.contains(where: { $0.id == record.report.id }) else { throw .duplicateRecord }
            let entered = record.report.entered(after: completions)
            seed(entered)
            return .vehicleServiceReportRecorded(entered)
        case let .removeVehicleServiceReport(remove):
            guard remove.vehicleID == vehicle.id else { throw .unknownVehicle }
            let matches = { (report: VehicleServiceReport) in report.operationID == remove.operationID }
            guard let removed = reports.filter(matches).newestPerOperation[remove.operationID] else {
                throw .unknownVehicleServiceReport
            }
            reports.removeAll(where: matches)
            return .vehicleServiceReportRemoved(removed)
        default:
            throw .storageFailure
        }
    }

    private func requireNoOtherInsurance(for event: PlannedDatedEvent, now: Date) throws(CarMemoryStoreError) {
        guard event.isInsuranceExpiry else { return }
        let conflict = planned.contains {
            $0.id != event.id && $0.vehicleID == event.vehicleID && $0.isInsuranceExpiry && $0.isOnRoad(now: now)
        }
        guard !conflict else { throw .insuranceExpiryAlreadyPlanned }
    }

    private func insertEvent(_ event: HistoryEvent) throws(CarMemoryStoreError) -> CommandResult {
        guard !events.contains(where: { $0.id == event.id }) else { throw .duplicateRecord }
        events.append(event)
        return .eventRecorded(event)
    }

    private func check() throws(CarMemoryStoreError) {
        if let failure {
            throw failure
        }
    }
}

private extension DomainCommand {
    var isReading: Bool {
        if case .recordOdometerReading = self {
            true
        } else {
            false
        }
    }
}
