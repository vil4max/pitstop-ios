import Foundation

/// A mileage fact at a moment: an odometer reading, a completion recorded with its mileage, or a dashboard
/// reading entered with its odometer. `MaintenanceContext` reads its current mileage from these, and the rate
/// estimate counts from the same history, so status and estimate agree (ADR 0010, REQ-BOARD-026). Compiled
/// into the widget with the maintenance engine.
public struct MileageObservation: Hashable, Sendable {
    public let date: Date
    public let km: Double

    public init(date: Date, km: Double) {
        self.date = date
        self.km = km
    }

    /// Every mileage fact the car has, oldest first. Readings in miles convert first. A dashboard
    /// reading entered with its odometer is a mileage fact too (ADR 0035).
    public static func history(
        readings: some Sequence<OdometerReading>,
        completions: some Sequence<MaintenanceCompletion>,
        reports: [VehicleServiceReport] = []
    ) -> [MileageObservation] {
        let recorded = readings.map { MileageObservation(date: $0.recordedAt, km: $0.valueInKilometers) }
        let done = completions.compactMap { completion in
            completion.odometerKm.map { MileageObservation(date: completion.performedAt, km: Double($0)) }
        }
        let reported = reports.compactMap { report in
            report.odometerKm.map { MileageObservation(date: report.reportedAt, km: Double($0)) }
        }
        return (recorded + done + reported).sorted { ($0.date, $0.km) < ($1.date, $1.km) }
    }
}
