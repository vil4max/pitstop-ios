import Foundation

/// Plausibility limits shared by every command and by the maintenance context. Kept apart from the
/// commands so the widget extension can compile the maintenance engine without the write path (ADR 0036).
public enum DomainCommandLimits {
    public static let maximumOdometerKm: Double = 5_000_000
    /// Covers clock skew only. Anything later is a plan, and a plan is never performed work (REQ-DOMAIN-009).
    public static let futureTolerance: TimeInterval = 5 * 60
    public static let earliestVehicleYear = 1886

    public static func isPlausibleOdometer(_ kilometers: Double) -> Bool {
        kilometers.isFinite && (0 ... maximumOdometerKm).contains(kilometers)
    }

    public static func isNotFuture(_ date: Date, now: Date) -> Bool {
        date <= now.addingTimeInterval(futureTolerance)
    }

    public static func isValidVehicleYear(_ value: String, now: Date) -> Bool {
        let nextModelYear = Calendar(identifier: .gregorian).component(.year, from: now) + 1
        guard let year = Int(value.trimmingCharacters(in: .whitespaces)) else { return false }
        return (earliestVehicleYear ... nextModelYear).contains(year)
    }
}
