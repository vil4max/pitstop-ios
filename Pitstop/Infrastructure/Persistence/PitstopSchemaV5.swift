import Foundation
import SwiftData

/// V4 with the car's profile (RD-012, ADR 0040): its own copy of the car record gains the owner's body
/// choice and the photo id. Every other record class is reused unchanged, so V4 is now frozen like the
/// others: a change to any of them needs a new version (ADR 0007, ADR 0016).
enum PitstopSchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            VehicleRecord.self,
            PitstopSchemaV1.OdometerReadingRecord.self,
            PitstopSchemaV1.NoteRecord.self,
            PitstopSchemaV1.HistoryEventRecord.self,
            PitstopSchemaV1.MaintenancePolicyRecord.self,
            PitstopSchemaV1.MaintenanceCompletionRecord.self,
            PitstopSchemaV2.PitQuestionStateRecord.self,
            PitstopSchemaV3.PlannedVehicleEventRecord.self,
            PitstopSchemaV4.VehicleServiceReportRecord.self,
        ]
    }

    /// `PitstopSchemaV1.VehicleRecord` plus two optional attributes, so the V4 → V5 stage stays lightweight
    /// and a migrated car has neither. The photo is only an id naming files in the App Group container;
    /// no image bytes have a field here (REQ-BOARD-029).
    @Model
    final class VehicleRecord {
        @Attribute(.unique) var id: UUID
        var name: String
        var make: String?
        var model: String?
        var year: Int?
        var vin: String?
        var isProvisional: Bool
        var createdAt: Date
        /// `CarBody.rawValue`; `nil` means no choice was made.
        var body: String?
        var photoID: UUID?

        init(id: UUID, name: String, isProvisional: Bool, createdAt: Date) {
            self.id = id
            self.name = name
            self.isProvisional = isProvisional
            self.createdAt = createdAt
        }
    }
}
