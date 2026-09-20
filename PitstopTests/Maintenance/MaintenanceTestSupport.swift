import Foundation
@testable import Pitstop

enum MaintenanceFixture {
    static let vehicleID = DomainFixtures.Vehicles.defaultID
    static let start = DomainFixtures.Odometers.baseDate
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    static let oil10k = MaintenancePolicy(
        operationID: .engineOilService,
        distanceIntervalKm: 10000,
        source: .userCustom
    )

    static func custom(_ operation: MaintenanceOperationID, km: Int? = nil, months: Int? = nil) -> MaintenancePolicy {
        MaintenancePolicy(
            operationID: operation,
            distanceIntervalKm: km,
            timeIntervalMonths: months,
            source: .userCustom
        )
    }

    static func date(_ daysAfterStart: Double) -> Date {
        start.addingTimeInterval(daysAfterStart * 86400)
    }

    static func reading(_ km: Double, day: Double) -> OdometerReading {
        OdometerReading(vehicleID: vehicleID, value: km, recordedAt: date(day))
    }

    /// A stable ID per fact, so two builds of the same completion compare equal.
    static func completion(_ operation: MaintenanceOperationID, km: Int?, day: Double = 0) -> MaintenanceCompletion {
        let seed = "\(operation.rawValue)-\(km ?? -1)-\(Int(day))"
        let hash = seed.unicodeScalars.reduce(5381) { (($0 << 5) &+ $0) &+ Int($1.value) } & 0xFFFF_FFFF_FFFF
        return MaintenanceCompletion(
            id: UUID(uuidString: "00000000-0000-4000-8000-" + String(format: "%012x", hash)) ?? UUID(),
            vehicleID: vehicleID,
            operationID: operation,
            performedAt: date(day),
            odometerKm: km
        )
    }

    static func context(_ completions: [MaintenanceCompletion], currentKm: Double?, day: Double) -> MaintenanceContext {
        MaintenanceContext(
            now: date(day),
            latestReading: currentKm.map { reading($0, day: day) },
            completions: completions
        )
    }

    static func states(
        _ policies: [MaintenancePolicy],
        _ completions: [MaintenanceCompletion],
        currentKm: Double?,
        day: Double
    ) -> [MaintenanceOperationState] {
        MaintenanceEngine().states(
            policies: policies,
            completions: completions,
            context: context(completions, currentKm: currentKm, day: day),
            calendar: utc
        )
    }
}
