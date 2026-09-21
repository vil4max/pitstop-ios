import Foundation
@testable import Pitstop
import SwiftData
import Testing

@Suite("Persistence schema")
struct PersistenceSchemaTests {
    /// Entity and attribute shape of a schema, in a stable order.
    private static func shape(of schema: Schema) -> [String] {
        schema.entities.map { entity in
            let attributes = entity.attributes.map { attribute in
                let flags = (attribute.isOptional ? "?" : "") + (attribute.isUnique ? "!" : "")
                return "\(attribute.name):\(attribute.valueType)\(flags)"
            }
            let relationships = entity.relationships.map(\.name)
            return ([entity.name] + attributes.sorted() + relationships.sorted()).joined(separator: " ")
        }
        .sorted()
    }

    /// Captured 2026-09-21 from the V1 that shipped to TestFlight. Changing a V1 class changes the
    /// version hash, and stores on disk would then match no schema in the migration plan.
    private static let frozenV1 = [
        "HistoryEventRecord amount:Optional<NSDecimal>? date:Date id:UUID! kind:String note:Optional<String>? "
            + "odometerKm:Optional<Int>? vehicleID:UUID",
        "MaintenanceCompletionRecord engineHours:Optional<Double>? id:UUID! odometerKm:Optional<Int>? "
            + "operationID:String performedAt:Date sourceEventID:Optional<UUID>? vehicleID:UUID",
        "MaintenancePolicyRecord distanceIntervalKm:Optional<Int>? operationID:String source:String "
            + "timeIntervalMonths:Optional<Int>? vehicleID:UUID",
        "NoteRecord contexts:Array<String> createdAt:Date id:UUID! rawText:String status:String "
            + "vehicleID:Optional<UUID>?",
        "OdometerReadingRecord id:UUID! recordedAt:Date source:String unit:String value:Double vehicleID:UUID",
        "VehicleRecord createdAt:Date id:UUID! isProvisional:Bool make:Optional<String>? model:Optional<String>? "
            + "name:String vin:Optional<String>? year:Optional<Int>?",
    ]

    @Test("ADR-0016: schema V1 is frozen; a change must be a new version that copies its classes")
    func versionOneIsFrozen() {
        #expect(Self.shape(of: Schema(versionedSchema: PitstopSchemaV1.self)) == Self.frozenV1)
    }

    @Test("ADR-0007: schema V2 is V1 unchanged plus the question state entity")
    func versionTwoExtendsVersionOne() {
        let v2 = Self.shape(of: Schema(versionedSchema: PitstopSchemaV2.self))
        #expect(v2.filter { !$0.hasPrefix("PitQuestionStateRecord ") } == Self.frozenV1)
        #expect(v2.count == Self.frozenV1.count + 1)
    }
}
