import SwiftUI

/// How a maintenance status is drawn on Service, Car Board and the next-service widget, so all three say it with
/// the same glyph and colour.
extension MaintenanceStatus {
    /// Status is always said in words (`statusLabel`); colour only supports it (non-colour status meaning).
    var color: Color {
        switch self {
        // Secondary, not tertiary: the "Not enough facts" chip is text and must stay readable (mockup `.chip.unk`).
        case .unknown: PitColor.contentSecondary
        case .upToDate: PitColor.statusUpToDate
        case .approaching: PitColor.statusApproaching
        // Due is attention, not danger.
        case .due: PitColor.statusDue
        }
    }

    /// The shared state glyph (REQ-DESIGN-001); "Not enough facts" is dashed like a Road milestone waiting for
    /// mileage.
    var glyph: StatusGlyph {
        switch self {
        case .unknown: .dashed
        case .upToDate: .ring
        case .approaching: .half
        case .due: .filled
        }
    }
}
