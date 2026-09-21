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
    private(set) var executed: [DomainCommand] = []
    private var failure: CarMemoryStoreError?
    private var failsReadings = false
    private var failsCommands = false

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
    }

    /// Reads keep working; only writes fail, as when the disk is full.
    func failCommands() {
        failsCommands = true
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
            return try applyToCar(command)
        }
    }

    /// The rest of the same switch. Split only to stay under the complexity the project lints for.
    private func applyToCar(_ command: DomainCommand) throws(CarMemoryStoreError) -> CommandResult {
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
        case let .setMaintenancePolicy(set):
            policies.removeAll { $0.operationID == set.policy.operationID && $0.source == set.policy.source }
            policies.append(set.policy)
            return .policySet(set.policy)
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
            throw .storageFailure
        }
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
