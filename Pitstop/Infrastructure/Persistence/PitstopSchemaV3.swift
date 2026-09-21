import Foundation
import SwiftData

/// V2 plus owner-stated planned dates (ROAD-EVT-001, ADR 0032). The V1 and V2 record classes are reused
/// unchanged, so V2 is now frozen like V1: a change to any of them needs a new version (ADR 0016).
enum PitstopSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        PitstopSchemaV2.models + [PlannedVehicleEventRecord.self]
    }

    /// One row per planned date. Only the date and the owner's optional label are kept: no insurer,
    /// policy number, or amount has a field here, so none can be stored by accident.
    @Model
    final class PlannedVehicleEventRecord {
        @Attribute(.unique) var id: UUID
        var vehicleID: UUID
        var kind: String
        var label: String?
        var date: Date
        var createdAt: Date

        init(id: UUID, vehicleID: UUID, kind: String, label: String?, date: Date, createdAt: Date) {
            self.id = id
            self.vehicleID = vehicleID
            self.kind = kind
            self.label = label
            self.date = date
            self.createdAt = createdAt
        }
    }
}
