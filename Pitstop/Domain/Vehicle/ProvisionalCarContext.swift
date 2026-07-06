import Foundation

struct ProvisionalCarContext: Equatable {
    static let defaultName = "My New Car"

    var name: String
    var odometerKm: Int
    var make: String?
    var model: String?
    var year: Int?

    static var firstLaunch: ProvisionalCarContext {
        ProvisionalCarContext(
            name: defaultName,
            odometerKm: 0,
            make: nil,
            model: nil,
            year: nil
        )
    }
}
