import Foundation

/// What Car Board needs to know about the single car. A projection, never a source of truth.
struct ProvisionalCarContext: Equatable {
    static let defaultName = "My New Car"

    var name: String
    /// `nil` means no odometer reading was supplied; zero is a real reading.
    var odometerKm: Int?
    var make: String?
    var model: String?
    var year: Int?
    /// `true` while every value above is a placeholder rather than a user-supplied fact.
    var isProvisional = true

    static var firstLaunch: ProvisionalCarContext {
        ProvisionalCarContext(
            name: defaultName,
            odometerKm: nil,
            make: nil,
            model: nil,
            year: nil
        )
    }

    init(name: String, odometerKm: Int?, make: String?, model: String?, year: Int?, isProvisional: Bool = true) {
        self.name = name
        self.odometerKm = odometerKm
        self.make = make
        self.model = model
        self.year = year
        self.isProvisional = isProvisional
    }

    /// Mileage is the newest observation: a reading, or a completion saved with its mileage
    /// (REQ-BOARD-026). Nothing is estimated, so a car with neither stays unknown (REQ-BOARD-004).
    init(vehicle: Vehicle, observedKm: Double?) {
        self.init(
            name: vehicle.name,
            odometerKm: observedKm.map { Int($0.rounded()) },
            make: vehicle.make,
            model: vehicle.model,
            year: vehicle.year,
            isProvisional: vehicle.isProvisional
        )
    }
}
