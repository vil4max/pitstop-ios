import Foundation

struct ProvisionalCarContext: Equatable {
    static let defaultName = "My New Car"

    var name: String
    /// `nil` means no odometer reading was supplied; zero is a real reading.
    var odometerKm: Int?
    var make: String?
    var model: String?
    var year: Int?

    static var firstLaunch: ProvisionalCarContext {
        ProvisionalCarContext(
            name: defaultName,
            odometerKm: nil,
            make: nil,
            model: nil,
            year: nil
        )
    }
}
