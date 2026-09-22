import Foundation
import SwiftData

/// V3 plus the car's own service readings (MNT-VR-002, ADR 0035). The V1, V2 and V3 record classes
/// are reused unchanged, so V3 is now frozen like the others: a change to any of them needs a new
/// version (ADR 0016).
enum PitstopSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        PitstopSchemaV3.models + [VehicleServiceReportRecord.self]
    }

    /// One row per entered reading; only the newest per operation is read, and deleting removes them all.
    /// The remaining value keeps its own unit, as `OdometerReadingRecord` does, and no interval field
    /// exists here: a reading is an observation, never a rule.
    @Model
    final class VehicleServiceReportRecord {
        @Attribute(.unique) var id: UUID
        var vehicleID: UUID
        var operationID: String
        var reportedAt: Date
        var odometerKm: Int?
        var remainingDistance: Double?
        var distanceUnit: String
        var remainingDays: Int?
        var source: String
        /// The operation's completions already saved when this reading was saved (ADR 0035, same-day
        /// order). Amended in V4 before any release shipped it.
        var completionIDsAtEntry: [UUID]

        init(
            id: UUID,
            vehicleID: UUID,
            operationID: String,
            reportedAt: Date,
            odometerKm: Int?,
            remainingDistance: Double?,
            distanceUnit: String,
            remainingDays: Int?,
            source: String,
            completionIDsAtEntry: [UUID]
        ) {
            self.id = id
            self.vehicleID = vehicleID
            self.operationID = operationID
            self.reportedAt = reportedAt
            self.odometerKm = odometerKm
            self.remainingDistance = remainingDistance
            self.distanceUnit = distanceUnit
            self.remainingDays = remainingDays
            self.source = source
            self.completionIDsAtEntry = completionIDsAtEntry
        }
    }
}
