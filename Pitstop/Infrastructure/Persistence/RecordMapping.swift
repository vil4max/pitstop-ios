import Foundation
import SwiftData

private typealias Schema1 = PitstopSchemaV1

extension PitstopSchemaV5.VehicleRecord {
    /// A body this version cannot read is no choice, so the car shows as SUV rather than a guess
    /// (REQ-BOARD-030).
    var domain: Vehicle {
        Vehicle(
            id: VehicleID(rawValue: id),
            name: name,
            make: make,
            model: model,
            year: year,
            vin: vin,
            isProvisional: isProvisional,
            chosenBody: body.flatMap(CarBody.init(rawValue:)),
            photoID: photoID.map(CarPhotoID.init(rawValue:))
        )
    }

    func update(from vehicle: Vehicle) {
        name = vehicle.name
        make = vehicle.make
        model = vehicle.model
        year = vehicle.year
        vin = vehicle.vin
        isProvisional = vehicle.isProvisional
        body = vehicle.chosenBody?.rawValue
        photoID = vehicle.photoID?.rawValue
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
            completionIDsAtEntry: report.completionIDsAtEntry.sorted { $0.uuidString < $1.uuidString }
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
            completionIDsAtEntry: Set(completionIDsAtEntry)
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
