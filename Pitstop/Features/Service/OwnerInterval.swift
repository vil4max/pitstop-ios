import Foundation

/// The owner's typed cadence for one operation, shared by the Track sheet and the "Track several" starter so
/// both accept exactly the same input (ADR 0010, ADR 0033).
enum OwnerInterval {
    static let maximumKilometers = 1_000_000
    static let maximumMonths = 600

    /// A `userCustom` policy when both fields are blank-or-positive whole numbers and at least one is filled;
    /// otherwise nil. Blank never becomes zero.
    static func policy(
        for operation: MaintenanceOperationID,
        kilometersText: String,
        monthsText: String
    ) -> MaintenancePolicy? {
        let kilometers = WholeNumberInput.parsePositive(kilometersText, upTo: maximumKilometers)
        let months = WholeNumberInput.parsePositive(monthsText, upTo: maximumMonths)
        guard kilometers != .invalid, months != .invalid, kilometers.intValue != nil || months.intValue != nil else {
            return nil
        }
        return MaintenancePolicy(
            operationID: operation,
            distanceIntervalKm: kilometers.intValue,
            timeIntervalMonths: months.intValue,
            source: .userCustom
        )
    }
}
