import SwiftUI

extension ValidatedContent {
    /// What confirming does to a maintenance cycle, said before the owner confirms: a completion
    /// resets its cycle, a dashboard reading never does (core C5, ADR 0035).
    var cycleNote: LocalizedStringKey? {
        switch self {
        case .maintenanceCompletion: "pit.confirm.resetsCycle"
        case .vehicleServiceReport: "pit.confirm.reportNoReset"
        case .note, .odometerReading, .vehicleFact, .maintenancePolicy, .vehicleEvent, .expense: nil
        }
    }
}
