import Foundation
import SwiftData

/// Records keep enums as raw strings and IDs as UUIDs so a later schema version can add
/// cases without a custom migration. Domain types never leave this folder as records.
///
/// Frozen: stores on disk are identified by these classes' shape, and V2 reuses them. A change to a
/// record needs a new schema version with its own copy of the class (ADR 0016, `PersistenceSchemaTests`).
enum PitstopSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            VehicleRecord.self,
            OdometerReadingRecord.self,
            NoteRecord.self,
            HistoryEventRecord.self,
            MaintenancePolicyRecord.self,
            MaintenanceCompletionRecord.self,
        ]
    }

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

        init(id: UUID, name: String, isProvisional: Bool, createdAt: Date) {
            self.id = id
            self.name = name
            self.isProvisional = isProvisional
            self.createdAt = createdAt
        }
    }

    @Model
    final class OdometerReadingRecord {
        @Attribute(.unique) var id: UUID
        var vehicleID: UUID
        var value: Double
        var unit: String
        var recordedAt: Date
        var source: String

        init(id: UUID, vehicleID: UUID, value: Double, unit: String, recordedAt: Date, source: String) {
            self.id = id
            self.vehicleID = vehicleID
            self.value = value
            self.unit = unit
            self.recordedAt = recordedAt
            self.source = source
        }
    }

    @Model
    final class NoteRecord {
        @Attribute(.unique) var id: UUID
        var vehicleID: UUID?
        var rawText: String
        var createdAt: Date
        var status: String
        var contexts: [String]

        init(id: UUID, vehicleID: UUID?, rawText: String, createdAt: Date, status: String, contexts: [String]) {
            self.id = id
            self.vehicleID = vehicleID
            self.rawText = rawText
            self.createdAt = createdAt
            self.status = status
            self.contexts = contexts
        }
    }

    @Model
    final class HistoryEventRecord {
        @Attribute(.unique) var id: UUID
        var vehicleID: UUID
        var kind: String
        var date: Date
        var odometerKm: Int?
        var amount: Decimal?
        var note: String?

        init(id: UUID, vehicleID: UUID, kind: String, date: Date, odometerKm: Int?, amount: Decimal?, note: String?) {
            self.id = id
            self.vehicleID = vehicleID
            self.kind = kind
            self.date = date
            self.odometerKm = odometerKm
            self.amount = amount
            self.note = note
        }
    }

    /// One row per vehicle, operation, and source. A custom policy is its own row, so the
    /// recommendation row stays intact; the effective rule is `policies.effective` (REQ-DOMAIN-006).
    @Model
    final class MaintenancePolicyRecord {
        var vehicleID: UUID
        var operationID: String
        var distanceIntervalKm: Int?
        var timeIntervalMonths: Int?
        var source: String

        init(vehicleID: UUID, operationID: String, distanceIntervalKm: Int?, timeIntervalMonths: Int?, source: String) {
            self.vehicleID = vehicleID
            self.operationID = operationID
            self.distanceIntervalKm = distanceIntervalKm
            self.timeIntervalMonths = timeIntervalMonths
            self.source = source
        }
    }

    @Model
    final class MaintenanceCompletionRecord {
        @Attribute(.unique) var id: UUID
        var vehicleID: UUID
        var operationID: String
        var performedAt: Date
        var odometerKm: Int?
        var engineHours: Double?
        var sourceEventID: UUID?

        init(
            id: UUID,
            vehicleID: UUID,
            operationID: String,
            performedAt: Date,
            odometerKm: Int?,
            engineHours: Double?,
            sourceEventID: UUID?
        ) {
            self.id = id
            self.vehicleID = vehicleID
            self.operationID = operationID
            self.performedAt = performedAt
            self.odometerKm = odometerKm
            self.engineHours = engineHours
            self.sourceEventID = sourceEventID
        }
    }
}
