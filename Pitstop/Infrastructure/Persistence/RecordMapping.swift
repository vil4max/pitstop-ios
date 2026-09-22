import Foundation
import SwiftData

private typealias Schema1 = PitstopSchemaV1

extension Schema1.VehicleRecord {
    var domain: Vehicle {
        Vehicle(
            id: VehicleID(rawValue: id),
            name: name,
            make: make,
            model: model,
            year: year,
            vin: vin,
            isProvisional: isProvisional
        )
    }

    func update(from vehicle: Vehicle) {
        name = vehicle.name
        make = vehicle.make
        model = vehicle.model
        year = vehicle.year
        vin = vehicle.vin
        isProvisional = vehicle.isProvisional
    }
}

extension Schema1.OdometerReadingRecord {
    convenience init(_ reading: OdometerReading) {
        self.init(
            id: reading.id,
            vehicleID: reading.vehicleID.rawValue,
            value: reading.value,
            unit: reading.unit.rawValue,
            recordedAt: reading.recordedAt,
            source: reading.source.rawValue
        )
    }

    /// A reading whose unit cannot be read is dropped rather than guessed: treating an
    /// unknown unit as kilometres would invent mileage (core C2).
    var domain: OdometerReading? {
        guard let unit = DistanceUnit(rawValue: unit) else { return nil }
        return OdometerReading(
            id: id,
            vehicleID: VehicleID(rawValue: vehicleID),
            value: value,
            unit: unit,
            recordedAt: recordedAt,
            source: ReadingSource(rawValue: source) ?? .manualEntry
        )
    }
}

extension Schema1.NoteRecord {
    convenience init(_ note: Note) {
        self.init(
            id: note.id,
            vehicleID: note.vehicleID?.rawValue,
            rawText: note.rawText,
            createdAt: note.createdAt,
            status: note.status.rawValue,
            contexts: note.canonicalContexts.map(\.rawValue).sorted()
        )
    }

    var domain: Note {
        Note(
            id: id,
            vehicleID: vehicleID.map(VehicleID.init(rawValue:)),
            rawText: rawText,
            createdAt: createdAt,
            // An unreadable status must not hide the note, so it falls back to visible.
            status: NoteStatus(rawValue: status) ?? .active,
            canonicalContexts: Set(contexts.compactMap(NoteContext.init(rawValue:)))
        )
    }
}

extension Schema1.HistoryEventRecord {
    convenience init(_ event: HistoryEvent) {
        self.init(
            id: event.id,
            vehicleID: event.vehicleID.rawValue,
            kind: event.kind.rawValue,
            date: event.date,
            odometerKm: event.odometerKm,
            amount: event.amount,
            note: event.note
        )
    }

    var domain: HistoryEvent {
        HistoryEvent(
            id: id,
            vehicleID: VehicleID(rawValue: vehicleID),
            kind: HistoryEventKind(rawValue: kind) ?? .other,
            date: date,
            odometerKm: odometerKm,
            amount: amount,
            note: note
        )
    }
}

extension Schema1.MaintenancePolicyRecord {
    convenience init(_ policy: MaintenancePolicy, vehicleID: VehicleID) {
        self.init(
            vehicleID: vehicleID.rawValue,
            operationID: policy.operationID.rawValue,
            distanceIntervalKm: policy.distanceIntervalKm,
            timeIntervalMonths: policy.timeIntervalMonths,
            source: policy.source.rawValue
        )
    }

    var domain: MaintenancePolicy {
        MaintenancePolicy(
            operationID: MaintenanceOperationID(rawValue: operationID),
            distanceIntervalKm: distanceIntervalKm,
            timeIntervalMonths: timeIntervalMonths,
            // A rule this version cannot attribute is never treated as the owner's: it neither outranks the
            // owner's own rule nor offers "Stop tracking", whose delete matches `userCustom` only (ADR 0031).
            source: PolicySource(rawValue: source) ?? .defaultRecommendation
        )
    }
}

extension Schema1.MaintenanceCompletionRecord {
    convenience init(_ completion: MaintenanceCompletion) {
        self.init(
            id: completion.id,
            vehicleID: completion.vehicleID.rawValue,
            operationID: completion.operationID.rawValue,
            performedAt: completion.performedAt,
            odometerKm: completion.odometerKm,
            engineHours: completion.engineHours,
            sourceEventID: completion.sourceEventID
        )
    }

    var domain: MaintenanceCompletion {
        MaintenanceCompletion(
            id: id,
            vehicleID: VehicleID(rawValue: vehicleID),
            operationID: MaintenanceOperationID(rawValue: operationID),
            performedAt: performedAt,
            odometerKm: odometerKm,
            engineHours: engineHours,
            sourceEventID: sourceEventID
        )
    }
}

extension PitstopSchemaV3.PlannedVehicleEventRecord {
    static let insuranceExpiryKind = "insuranceExpiry"
    private static let otherKind = "other"

    convenience init(_ event: PlannedDatedEvent) {
        self.init(
            id: event.id,
            vehicleID: event.vehicleID.rawValue,
            kind: event.isInsuranceExpiry ? Self.insuranceExpiryKind : Self.otherKind,
            label: event.label,
            date: event.date,
            createdAt: event.createdAt
        )
    }

    var domain: PlannedDatedEvent {
        PlannedDatedEvent(
            id: id,
            vehicleID: VehicleID(rawValue: vehicleID),
            // A kind this version cannot read stays visible and deletable as the owner's own date rather
            // than disappearing, and it never blocks a new insurance expiry.
            kind: kind == Self.insuranceExpiryKind ? .insuranceExpiry : .other(label: label),
            date: date,
            createdAt: createdAt
        )
    }

    func update(from event: PlannedDatedEvent) {
        kind = event.isInsuranceExpiry ? Self.insuranceExpiryKind : Self.otherKind
        label = event.label
        date = event.date
    }
}

extension PitstopSchemaV4.VehicleServiceReportRecord {
    convenience init(_ report: VehicleServiceReport) {
        self.init(
            id: report.id,
            vehicleID: report.vehicleID.rawValue,
            operationID: report.operationID.rawValue,
            reportedAt: report.reportedAt,
            odometerKm: report.odometerKm,
            remainingDistance: report.remainingDistance,
            distanceUnit: report.distanceUnit.rawValue,
            remainingDays: report.remainingDays,
            source: report.source.rawValue,
            completionIDAtEntry: report.completionIDAtEntry
        )
    }

    /// A reading whose unit cannot be read drops its distance rather than guessing: treating miles as
    /// kilometres would move the anchor by 60% (core C2). Its day part, if any, still counts.
    var domain: VehicleServiceReport {
        let unit = DistanceUnit(rawValue: distanceUnit)
        return VehicleServiceReport(
            id: id,
            vehicleID: VehicleID(rawValue: vehicleID),
            operationID: MaintenanceOperationID(rawValue: operationID),
            reportedAt: reportedAt,
            odometerKm: odometerKm,
            remainingDistance: unit == nil ? nil : remainingDistance,
            distanceUnit: unit ?? .kilometers,
            remainingDays: remainingDays,
            source: VehicleServiceReport.Source(rawValue: source) ?? .manualEntry,
            completionIDAtEntry: completionIDAtEntry
        )
    }
}

protocol Identified {
    static func matching(_ id: UUID) -> Predicate<Self>
}

extension Schema1.OdometerReadingRecord: Identified {
    static func matching(_ id: UUID) -> Predicate<PitstopSchemaV1.OdometerReadingRecord> {
        #Predicate { $0.id == id }
    }
}

extension Schema1.HistoryEventRecord: Identified {
    static func matching(_ id: UUID) -> Predicate<PitstopSchemaV1.HistoryEventRecord> {
        #Predicate { $0.id == id }
    }
}

extension PitstopSchemaV3.PlannedVehicleEventRecord: Identified {
    static func matching(_ id: UUID) -> Predicate<PitstopSchemaV3.PlannedVehicleEventRecord> {
        #Predicate { $0.id == id }
    }
}

extension PitstopSchemaV4.VehicleServiceReportRecord: Identified {
    static func matching(_ id: UUID) -> Predicate<PitstopSchemaV4.VehicleServiceReportRecord> {
        #Predicate { $0.id == id }
    }
}

extension Schema1.MaintenanceCompletionRecord: Identified {
    static func matching(_ id: UUID) -> Predicate<PitstopSchemaV1.MaintenanceCompletionRecord> {
        #Predicate { $0.id == id }
    }
}
