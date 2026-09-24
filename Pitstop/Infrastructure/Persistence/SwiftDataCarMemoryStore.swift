import Foundation
import SwiftData

private typealias Schema1 = PitstopSchemaV1
private typealias PlannedRecord = PitstopSchemaV3.PlannedVehicleEventRecord
private typealias ReportRecord = PitstopSchemaV4.VehicleServiceReportRecord

@ModelActor
actor SwiftDataCarMemoryStore: CarMemoryStore {
    #if DEBUG
        private var failsNextSave = false

        /// Test seam: the save-failure path cannot be provoked through SwiftData itself.
        func failNextSave() {
            failsNextSave = true
        }
    #endif

    func currentVehicle() throws(CarMemoryStoreError) -> Vehicle {
        try storage { try vehicleRecord().domain }
    }

    func odometerReadings() throws(CarMemoryStoreError) -> [OdometerReading] {
        try storage {
            let sort = SortDescriptor(\Schema1.OdometerReadingRecord.recordedAt, order: .reverse)
            return try modelContext.fetch(FetchDescriptor(sortBy: [sort])).compactMap(\.domain)
        }
    }

    func notes() throws(CarMemoryStoreError) -> [Note] {
        try storage {
            let sort = SortDescriptor(\Schema1.NoteRecord.createdAt, order: .reverse)
            return try modelContext.fetch(FetchDescriptor(sortBy: [sort])).map(\.domain)
        }
    }

    func historyEvents() throws(CarMemoryStoreError) -> [HistoryEvent] {
        try storage {
            let sort = SortDescriptor(\Schema1.HistoryEventRecord.date, order: .reverse)
            return try modelContext.fetch(FetchDescriptor(sortBy: [sort])).map(\.domain)
        }
    }

    func maintenancePolicies() throws(CarMemoryStoreError) -> [MaintenancePolicy] {
        try storage {
            let sort = SortDescriptor(\Schema1.MaintenancePolicyRecord.operationID)
            return try modelContext.fetch(FetchDescriptor(sortBy: [sort])).map(\.domain)
        }
    }

    func maintenanceCompletions() throws(CarMemoryStoreError) -> [MaintenanceCompletion] {
        try storage {
            let sort = SortDescriptor(\Schema1.MaintenanceCompletionRecord.performedAt, order: .reverse)
            return try modelContext.fetch(FetchDescriptor(sortBy: [sort])).map(\.domain)
        }
    }

    func plannedEvents() throws(CarMemoryStoreError) -> [PlannedDatedEvent] {
        try storage {
            let sort = [SortDescriptor(\PlannedRecord.date), SortDescriptor(\PlannedRecord.createdAt)]
            return try modelContext.fetch(FetchDescriptor(sortBy: sort)).map(\.domain)
        }
    }

    func vehicleServiceReports() throws(CarMemoryStoreError) -> [VehicleServiceReport] {
        try storage {
            // Every stored reading: older ones are still mileage observations and let a replayed
            // confirmation be recognised; the engine counts only the newest per operation (ADR 0035).
            try modelContext.fetch(FetchDescriptor<ReportRecord>()).map(\.domain).newestFirst
        }
    }

    @discardableResult
    func execute(_ command: DomainCommand, now: Date) throws(CarMemoryStoreError) -> CommandResult {
        do {
            try command.validate(now: now)
        } catch {
            throw .invalidCommand(error)
        }
        do {
            let result = try apply(command, now: now)
            try save()
            return result
        } catch {
            // Drop the pending change so a failed save can never surface later as a success.
            modelContext.rollback()
            throw (error as? CarMemoryStoreError) ?? .storageFailure
        }
    }

    // MARK: - Private

    private func apply(_ command: DomainCommand, now: Date) throws -> CommandResult {
        switch command {
        case let .createNote(create):
            if let vehicleID = create.vehicleID {
                try requireVehicle(vehicleID)
            }
            let note = Note(
                vehicleID: create.vehicleID,
                rawText: create.rawText,
                createdAt: create.createdAt ?? now,
                canonicalContexts: create.canonicalContexts
            )
            modelContext.insert(Schema1.NoteRecord(note))
            return .noteCreated(note)
        case let .updateNote(update):
            let id = update.noteID
            let matches = try modelContext
                .fetch(FetchDescriptor<Schema1.NoteRecord>(predicate: #Predicate { $0.id == id }))
            guard let record = matches.first else { throw CarMemoryStoreError.unknownNote }
            if let text = update.rawText {
                record.rawText = text
            }
            if let status = update.status {
                record.status = status.rawValue
            }
            return .noteUpdated(record.domain)
        case let .recordOdometerReading(record):
            try requireVehicle(record.reading.vehicleID)
            try requireNew(Schema1.OdometerReadingRecord.self, id: record.reading.id)
            modelContext.insert(Schema1.OdometerReadingRecord(record.reading))
            return .readingRecorded(record.reading)
        case let .recordVehicleFact(record):
            let vehicle = try requireVehicle(record.vehicleID)
            let updated = vehicle.domain.applying(record.fact)
            vehicle.update(from: updated)
            return .vehicleUpdated(updated)
        case let .confirmMaintenanceCompletion(confirm):
            try requireVehicle(confirm.completion.vehicleID)
            try requireNew(Schema1.MaintenanceCompletionRecord.self, id: confirm.completion.id)
            modelContext.insert(Schema1.MaintenanceCompletionRecord(confirm.completion))
            return .completionConfirmed(confirm.completion)
        case let .revokeMaintenanceCompletion(revoke):
            let matches = try modelContext.fetch(
                FetchDescriptor(predicate: Schema1.MaintenanceCompletionRecord.matching(revoke.completionID))
            )
            guard let record = matches.first else { throw CarMemoryStoreError.unknownCompletion }
            let revoked = record.domain
            modelContext.delete(record)
            return .completionRevoked(revoked)
        case let .replaceMaintenanceCompletion(replace):
            return try applyReplace(replace)
        case let .setMaintenancePolicy(set):
            try requireVehicle(set.vehicleID)
            try upsert(set.policy, vehicleID: set.vehicleID)
            return .policySet(set.policy)
        case let .stopTrackingOperation(stop):
            try requireVehicle(stop.vehicleID)
            return try .trackingStopped(removeOwnerPolicy(stop.operationID, vehicleID: stop.vehicleID))
        case let .recordVehicleEvent(record):
            return try insert(record.event)
        case let .correctVehicleEvent(correct):
            return try update(correct.event)
        case let .recordExpense(record):
            return try insert(record.event)
        case let .addPlannedEvent(add):
            return try insertPlanned(add.event, now: now)
        case let .updatePlannedEvent(update):
            return try updatePlanned(update.event, now: now)
        case let .removePlannedEvent(remove):
            let matches = try modelContext.fetch(FetchDescriptor(predicate: PlannedRecord.matching(remove.eventID)))
            guard let record = matches.first else { throw CarMemoryStoreError.unknownPlannedEvent }
            let removed = record.domain
            modelContext.delete(record)
            return .plannedEventRemoved(removed)
        case .recordVehicleServiceReport, .removeVehicleServiceReport:
            return try applyReport(command)
        }
    }

    private func completions(
        of operationID: MaintenanceOperationID,
        vehicleID: VehicleID
    ) throws -> [MaintenanceCompletion] {
        let vehicle = vehicleID.rawValue
        let operation = operationID.rawValue
        return try modelContext.fetch(FetchDescriptor<Schema1.MaintenanceCompletionRecord>(
            predicate: #Predicate { $0.vehicleID == vehicle && $0.operationID == operation }
        )).map(\.domain)
    }

    private func reportRecords(
        _ operationID: MaintenanceOperationID,
        vehicleID: VehicleID
    ) throws -> [ReportRecord] {
        let vehicle = vehicleID.rawValue
        let operation = operationID.rawValue
        return try modelContext.fetch(FetchDescriptor<ReportRecord>(
            predicate: #Predicate { $0.vehicleID == vehicle && $0.operationID == operation }
        ))
    }

    private func insertPlanned(_ event: PlannedDatedEvent, now: Date) throws -> CommandResult {
        try requireVehicle(event.vehicleID)
        try requireNew(PlannedRecord.self, id: event.id)
        try requireNoOtherInsurance(for: event, now: now)
        modelContext.insert(PlannedRecord(event))
        return .plannedEventAdded(event)
    }

    private func updatePlanned(_ event: PlannedDatedEvent, now: Date) throws -> CommandResult {
        try requireVehicle(event.vehicleID)
        let matches = try modelContext.fetch(FetchDescriptor(predicate: PlannedRecord.matching(event.id)))
        // A correction changes the date of the same plan; it can never move it to another vehicle.
        guard let record = matches.first, record.vehicleID == event.vehicleID.rawValue else {
            throw CarMemoryStoreError.unknownPlannedEvent
        }
        try requireNoOtherInsurance(for: event, now: now)
        record.update(from: event)
        return .plannedEventUpdated(record.domain)
    }

    /// One insurance expiry on Road per vehicle, so two unnamed "Insurance ends" rows cannot compete; a
    /// second policy is an `other` date with its own label (ADR 0032). One that has left Road does not count.
    private func requireNoOtherInsurance(for event: PlannedDatedEvent, now: Date) throws {
        guard event.isInsuranceExpiry else { return }
        let vehicle = event.vehicleID.rawValue
        let id = event.id
        let kind = PlannedRecord.insuranceExpiryKind
        let earliest = PlannedEventLimits.earliestDate(now: now)
        let others = try modelContext.fetchCount(FetchDescriptor<PlannedRecord>(predicate: #Predicate {
            $0.vehicleID == vehicle && $0.id != id && $0.kind == kind && $0.date >= earliest
        }))
        guard others == 0 else { throw CarMemoryStoreError.insuranceExpiryAlreadyPlanned }
    }

    private func insert(_ event: HistoryEvent) throws -> CommandResult {
        try requireVehicle(event.vehicleID)
        try requireNew(Schema1.HistoryEventRecord.self, id: event.id)
        modelContext.insert(Schema1.HistoryEventRecord(event))
        return .eventRecorded(event)
    }

    private func update(_ event: HistoryEvent) throws -> CommandResult {
        try requireVehicle(event.vehicleID)
        let matches = try modelContext.fetch(FetchDescriptor(predicate: Schema1.HistoryEventRecord.matching(event.id)))
        // A correction edits facts of the same event; it can never move it to another vehicle.
        guard let record = matches.first, record.vehicleID == event.vehicleID.rawValue else {
            throw CarMemoryStoreError.unknownEvent
        }
        record.kind = event.kind.rawValue
        record.date = event.date
        record.odometerKm = event.odometerKm
        record.amount = event.amount
        record.note = event.note
        return .eventCorrected(event)
    }

    private func upsert(_ policy: MaintenancePolicy, vehicleID: VehicleID) throws {
        let vehicle = vehicleID.rawValue
        let operation = policy.operationID.rawValue
        let source = policy.source.rawValue
        // Keyed by source too: a custom policy must leave the recommendation row intact (REQ-DOMAIN-006).
        let existing = try modelContext.fetch(FetchDescriptor<Schema1.MaintenancePolicyRecord>(
            predicate: #Predicate { $0.vehicleID == vehicle && $0.operationID == operation && $0.source == source }
        ))
        existing.forEach(modelContext.delete)
        modelContext.insert(Schema1.MaintenancePolicyRecord(policy, vehicleID: vehicleID))
    }

    /// Deletes only the `userCustom` row: a recommendation stays (REQ-DOMAIN-006), and completion and
    /// History records are never touched, so re-tracking resumes from the same facts (ADR 0031).
    private func removeOwnerPolicy(_ operationID: MaintenanceOperationID, vehicleID: VehicleID) throws
        -> MaintenancePolicy
    {
        let vehicle = vehicleID.rawValue
        let operation = operationID.rawValue
        let source = PolicySource.userCustom.rawValue
        let matches = try modelContext.fetch(FetchDescriptor<Schema1.MaintenancePolicyRecord>(
            predicate: #Predicate { $0.vehicleID == vehicle && $0.operationID == operation && $0.source == source }
        ))
        guard let removed = matches.first?.domain else { throw CarMemoryStoreError.unknownPolicy }
        matches.forEach(modelContext.delete)
        return removed
    }

    /// First launch has no record yet; the provisional car is created on demand so the app
    /// needs no setup step before first value (core P2).
    private func vehicleRecord() throws -> Schema1.VehicleRecord {
        if let existing = try existingVehicleRecord() {
            return existing
        }
        let provisional = Vehicle.provisional()
        let record = Schema1.VehicleRecord(
            id: provisional.id.rawValue,
            name: provisional.name,
            isProvisional: true,
            createdAt: .now
        )
        modelContext.insert(record)
        try modelContext.save()
        return record
    }

    private func existingVehicleRecord() throws -> Schema1.VehicleRecord? {
        let sort = SortDescriptor(\Schema1.VehicleRecord.createdAt)
        return try modelContext.fetch(FetchDescriptor(sortBy: [sort])).first
    }

    /// Never creates the car: a command must not leave a side effect behind when it is rejected.
    @discardableResult
    private func requireVehicle(_ id: VehicleID) throws -> Schema1.VehicleRecord {
        guard let record = try existingVehicleRecord(), record.id == id.rawValue else {
            throw CarMemoryStoreError.unknownVehicle
        }
        return record
    }

    /// IDs are unique attributes, so inserting a known ID would silently overwrite that record.
    private func requireNew<Record: PersistentModel & Identified>(_: Record.Type, id: UUID) throws {
        let count = try modelContext.fetchCount(FetchDescriptor<Record>(predicate: Record.matching(id)))
        guard count == 0 else { throw CarMemoryStoreError.duplicateRecord }
    }

    private func save() throws {
        #if DEBUG
            if failsNextSave {
                failsNextSave = false
                throw CarMemoryStoreError.storageFailure
            }
        #endif
        try modelContext.save()
    }

    private func storage<T>(_ body: () throws -> T) throws(CarMemoryStoreError) -> T {
        do {
            return try body()
        } catch {
            throw (error as? CarMemoryStoreError) ?? .storageFailure
        }
    }
}

/// Command handlers kept outside the actor body, which the project's type-length lint caps.
extension SwiftDataCarMemoryStore {
    /// Deletes the replaced completions and inserts the owner's in the same pending change, which `execute` saves once
    /// or rolls back whole (REQ-MAINT-043). A replaced completion that is gone, or is not this vehicle's same
    /// operation,
    /// fails the whole command.
    private func applyReplace(_ replace: ReplaceMaintenanceCompletionCommand) throws -> CommandResult {
        let completion = replace.completion
        try requireVehicle(completion.vehicleID)
        try requireNew(Schema1.MaintenanceCompletionRecord.self, id: completion.id)
        for id in replace.replacedIDs {
            let matches = try modelContext.fetch(
                FetchDescriptor(predicate: Schema1.MaintenanceCompletionRecord.matching(id))
            )
            guard let record = matches.first,
                  record.domain.vehicleID == completion.vehicleID,
                  record.domain.operationID == completion.operationID
            else { throw CarMemoryStoreError.unknownCompletion }
            modelContext.delete(record)
        }
        modelContext.insert(Schema1.MaintenanceCompletionRecord(completion))
        return .completionConfirmed(completion)
    }

    private func applyReport(_ command: DomainCommand) throws -> CommandResult {
        switch command {
        case let .recordVehicleServiceReport(record):
            try requireVehicle(record.report.vehicleID)
            // A new reading replaces the older one for every reader, but the older row stays so that a
            // replayed confirmation of it is a duplicate, never an overwrite of the newer reading.
            try requireNew(ReportRecord.self, id: record.report.id)
            let entered = try record.report.entered(after: completions(
                of: record.report.operationID, vehicleID: record.report.vehicleID
            ))
            modelContext.insert(ReportRecord(entered))
            return .vehicleServiceReportRecorded(entered)
        case let .removeVehicleServiceReport(remove):
            try requireVehicle(remove.vehicleID)
            let matches = try reportRecords(remove.operationID, vehicleID: remove.vehicleID)
            guard let removed = matches.map(\.domain).newestPerOperation[remove.operationID] else {
                throw CarMemoryStoreError.unknownVehicleServiceReport
            }
            matches.forEach(modelContext.delete)
            return .vehicleServiceReportRemoved(removed)
        default:
            throw CarMemoryStoreError.storageFailure
        }
    }
}
