import Foundation
@testable import Pitstop
import SwiftData

/// Writes a store as an older build wrote it: a container that knows only `schema`, filled through that
/// schema's own record classes. Today's `SwiftDataCarMemoryStore` cannot do this since V5: its car record is
/// `PitstopSchemaV5.VehicleRecord`, which an older container does not know, and SwiftData traps on the cast.
struct LegacyStoreWriter {
    let container: ModelContainer
    private let context: ModelContext
    private let major: Int

    init(_ schema: any VersionedSchema.Type, url: URL) throws {
        let legacy = Schema(versionedSchema: schema)
        container = try ModelContainer(for: legacy, configurations: ModelConfiguration(schema: legacy, url: url))
        context = ModelContext(container)
        major = schema.versionIdentifier.major
    }

    /// The car as the store of that build held it; by default the first-launch car it created on demand.
    @discardableResult
    func car(
        id: VehicleID = Vehicle.provisionalID,
        name: String = ProvisionalCarContext.defaultName,
        isProvisional: Bool = true,
        createdAt: Date = .now
    ) -> VehicleID {
        context.insert(PitstopSchemaV1.VehicleRecord(
            id: id.rawValue, name: name, isProvisional: isProvisional, createdAt: createdAt
        ))
        return id
    }

    func insert(_ reading: OdometerReading) {
        context.insert(PitstopSchemaV1.OdometerReadingRecord(reading))
    }

    func insert(_ policy: MaintenancePolicy, vehicleID: VehicleID) {
        context.insert(PitstopSchemaV1.MaintenancePolicyRecord(policy, vehicleID: vehicleID))
    }

    func insert(_ completion: MaintenanceCompletion) {
        context.insert(PitstopSchemaV1.MaintenanceCompletionRecord(completion))
    }

    func insert(_ note: Note) {
        context.insert(PitstopSchemaV1.NoteRecord(note))
    }

    func insert(_ event: PlannedDatedEvent) throws {
        try requireVersion(3)
        context.insert(PitstopSchemaV3.PlannedVehicleEventRecord(event))
    }

    func insert(_ report: VehicleServiceReport) throws {
        try requireVersion(4)
        context.insert(PitstopSchemaV4.VehicleServiceReportRecord(report))
    }

    func save() throws {
        try context.save()
    }

    struct EntityUnknownToSchema: Error {}

    /// A record the older build could not have written is a broken test, not a store to migrate.
    private func requireVersion(_ version: Int) throws {
        guard major >= version else { throw EntityUnknownToSchema() }
    }
}
