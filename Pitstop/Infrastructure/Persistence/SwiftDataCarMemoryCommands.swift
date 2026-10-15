import Foundation
import SwiftData

private typealias Schema1 = PitstopSchemaV1
private typealias ReportRecord = PitstopSchemaV4.VehicleServiceReportRecord
private typealias CarRecord = PitstopSchemaV5.VehicleRecord

/// Command handlers kept outside the actor body, which the project's type-length lint caps.
extension SwiftDataCarMemoryStore {
    /// Deletes the replaced completions and inserts the owner's in the same pending change, which `execute` saves once
    /// or rolls back whole (REQ-MAINT-043). A replaced completion that is gone, or is not this vehicle's same
    /// operation, fails the whole command.
    func applyReplace(_ replace: ReplaceMaintenanceCompletionCommand) throws -> CommandResult {
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

    func applyReport(_ command: DomainCommand) throws -> CommandResult {
        switch command {
        case let .recordVehicleServiceReport(record):
            try requireVehicle(record.report.vehicleID)
            // A new reading replaces the older one for every reader, but the older row stays so that a
            // replayed confirmation of it is a duplicate, never an overwrite of the newer reading.
            try requireNew(ReportRecord.self, id: record.report.id)
            let entered = try record.report.entered(
                after: completions(
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

    /// The body and the photo id live on the V5 car record (ADR 0040). Clearing the photo drops only the
    /// id; its files are the photo store's to delete (REQ-BOARD-033).
    func applyProfile(_ command: DomainCommand) throws -> CommandResult {
        let record: CarRecord
        let updated: Vehicle
        switch command {
        case let .setCarBody(set):
            record = try requireVehicle(set.vehicleID)
            updated = record.domain.applying(set)
        case let .setCarPhoto(set):
            record = try requireVehicle(set.vehicleID)
            updated = record.domain.applying(set)
        default:
            throw CarMemoryStoreError.storageFailure
        }
        record.update(from: updated)
        return .vehicleUpdated(updated)
    }

    private func completions(
        of operationID: MaintenanceOperationID,
        vehicleID: VehicleID
    ) throws -> [MaintenanceCompletion] {
        let vehicle = vehicleID.rawValue
        let operation = operationID.rawValue
        return try modelContext.fetch(
            FetchDescriptor<Schema1.MaintenanceCompletionRecord>(
                predicate: #Predicate { $0.vehicleID == vehicle && $0.operationID == operation }
            )
        ).map(\.domain)
    }

    private func reportRecords(
        _ operationID: MaintenanceOperationID,
        vehicleID: VehicleID
    ) throws -> [ReportRecord] {
        let vehicle = vehicleID.rawValue
        let operation = operationID.rawValue
        return try modelContext.fetch(
            FetchDescriptor<ReportRecord>(
                predicate: #Predicate { $0.vehicleID == vehicle && $0.operationID == operation }
            ))
    }
}
