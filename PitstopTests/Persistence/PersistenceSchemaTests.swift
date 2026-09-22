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

    /// Captured 2026-09-22 from the V2 that TestFlight `tf-1.1.0-2` shipped. V3 reuses these classes, so a
    /// store written by that build must keep matching them: V2 is frozen like V1 (ADR 0032).
    private static let frozenV2 = (frozenV1 + [
        "PitQuestionStateRecord lastAskedAt:Optional<Date>? lastDismissedAt:Optional<Date>? questionID:String! "
            + "resolution:String resolvedAt:Optional<Date>?",
    ]).sorted()

    @Test("ADR-0007: schema V2 is V1 unchanged plus the question state entity")
    func versionTwoExtendsVersionOne() {
        let v2 = Self.shape(of: Schema(versionedSchema: PitstopSchemaV2.self))
        #expect(v2.filter { !$0.hasPrefix("PitQuestionStateRecord ") } == Self.frozenV1)
        #expect(v2.count == Self.frozenV1.count + 1)
    }

    @Test("ADR-0032: schema V2 is frozen; a change must be a new version that copies its classes")
    func versionTwoIsFrozen() {
        #expect(Self.shape(of: Schema(versionedSchema: PitstopSchemaV2.self)) == Self.frozenV2)
    }

    @Test("ADR-0032: schema V3 is V2 unchanged plus the planned date entity, with no insurer or policy field")
    func versionThreeExtendsVersionTwo() {
        let v3 = Self.shape(of: Schema(versionedSchema: PitstopSchemaV3.self))
        #expect(v3.filter { !$0.hasPrefix("PlannedVehicleEventRecord ") } == Self.frozenV2)
        #expect(v3.filter { $0.hasPrefix("PlannedVehicleEventRecord ") } == [
            "PlannedVehicleEventRecord createdAt:Date date:Date id:UUID! kind:String label:Optional<String>? "
                + "vehicleID:UUID",
        ])
    }

    /// V3 as TestFlight builds after ROAD-EVT-001 wrote it. V4 reuses these classes, so V3 is frozen too.
    private static let frozenV3 = (frozenV2 + [
        "PlannedVehicleEventRecord createdAt:Date date:Date id:UUID! kind:String label:Optional<String>? "
            + "vehicleID:UUID",
    ]).sorted()

    @Test("ADR-0035: schema V3 is frozen; a change must be a new version that copies its classes")
    func versionThreeIsFrozen() {
        #expect(Self.shape(of: Schema(versionedSchema: PitstopSchemaV3.self)) == Self.frozenV3)
    }

    @Test("ADR-0035: schema V4 is V3 unchanged plus the dashboard reading entity, with no interval field")
    func versionFourExtendsVersionThree() {
        let v4 = Self.shape(of: Schema(versionedSchema: PitstopSchemaV4.self))
        #expect(v4.filter { !$0.hasPrefix("VehicleServiceReportRecord ") } == Self.frozenV3)
        #expect(v4.filter { $0.hasPrefix("VehicleServiceReportRecord ") } == [
            "VehicleServiceReportRecord completionIDsAtEntry:Array<UUID> distanceUnit:String id:UUID! "
                + "odometerKm:Optional<Int>? operationID:String "
                + "remainingDays:Optional<Int>? remainingDistance:Optional<Double>? reportedAt:Date source:String "
                + "vehicleID:UUID",
        ])
    }

    @Test("ADR-0035: the app opens the newest schema version")
    func containerUsesVersionFour() throws {
        let container = try PersistenceContainer.make(storeURL: nil)
        #expect(Self.shape(of: container.schema) == Self.shape(of: Schema(versionedSchema: PitstopSchemaV4.self)))
    }
}
