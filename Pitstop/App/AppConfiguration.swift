import Foundation
import SwiftData

enum AppConfiguration {
    static let forcedLocale: Locale? = nil
}

protocol ActiveVehicleSelecting: AnyObject {
    var activeVIN: String? { get set }
    func activeVehicle(from vehicles: [VehicleConfig]) -> VehicleConfig?
    func select(_ vehicle: VehicleConfig)
}

@Observable
@MainActor
final class ActiveVehicleStore: ActiveVehicleSelecting {
    private static let storageKey = "pitstop.activeVehicleVIN"

    var activeVIN: String? {
        didSet {
            if let activeVIN {
                UserDefaults.standard.set(activeVIN, forKey: Self.storageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.storageKey)
            }
        }
    }

    init() {
        activeVIN = UserDefaults.standard.string(forKey: Self.storageKey)
    }

    func activeVehicle(from vehicles: [VehicleConfig]) -> VehicleConfig? {
        if let activeVIN, let match = vehicles.first(where: { $0.vin == activeVIN }) {
            return match
        }
        if let first = vehicles.first {
            activeVIN = first.vin
            return first
        }
        return nil
    }

    func select(_ vehicle: VehicleConfig) {
        activeVIN = vehicle.vin
    }
}
