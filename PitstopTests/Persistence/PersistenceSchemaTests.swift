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

    /// V4 as TestFlight `tf-1.1.0-3` shipped it. V5 reuses every class but the car record, so V4 is frozen too.
    private static let frozenV4 = (frozenV3 + [
        "VehicleServiceReportRecord completionIDsAtEntry:Array<UUID> distanceUnit:String id:UUID! "
            + "odometerKm:Optional<Int>? operationID:String "
            + "remainingDays:Optional<Int>? remainingDistance:Optional<Double>? reportedAt:Date source:String "
            + "vehicleID:UUID",
    ]).sorted()

    @Test("ADR-0040: schema V4 is frozen; a change must be a new version that copies its classes")
    func versionFourIsFrozen() {
        #expect(Self.shape(of: Schema(versionedSchema: PitstopSchemaV4.self)) == Self.frozenV4)
    }

    @Test("ADR-0040: schema V5 is V4 with only the car record changed, gaining the optional body and photo id")
    func versionFiveExtendsVersionFour() {
        let v5 = Self.shape(of: Schema(versionedSchema: PitstopSchemaV5.self))
        #expect(v5.filter { !$0.hasPrefix("VehicleRecord ") } == Self.frozenV4
            .filter { !$0.hasPrefix("VehicleRecord ") })
        // Only an id and a raw body value: no image bytes can be stored in the car record (ADR 0040).
        #expect(v5.filter { $0.hasPrefix("VehicleRecord ") } == [
            "VehicleRecord body:Optional<String>? createdAt:Date id:UUID! isProvisional:Bool "
                + "make:Optional<String>? model:Optional<String>? name:String photoID:Optional<UUID>? "
                + "vin:Optional<String>? year:Optional<Int>?",
        ])
    }

    @Test("ADR-0040: the app and the widget reader open the newest schema version")
    func containersUseVersionFive() throws {
        let newest = Self.shape(of: Schema(versionedSchema: PitstopSchemaV5.self))
        #expect(try Self.shape(of: PersistenceContainer.make(storeURL: nil).schema) == newest)
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        _ = try PersistenceContainer.make(storeURL: url)
        #expect(try Self.shape(of: PersistenceContainer.makeReadOnly(storeURL: url).schema) == newest)
    }
}
