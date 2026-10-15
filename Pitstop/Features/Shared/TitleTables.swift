import SwiftUI

// The app's one title table per type: screens and the spoken Remember answers read the same keys. The widget
// keeps its own `widget.operation.*` copy, since it ships in its own bundle (ADR 0036).

extension MaintenanceOperationID {
    /// Localized titles are presentation only; the ID stays the domain identity. Nil for an ID without a known
    /// title, which every surface shows as it is stored.
    var titleResource: LocalizedStringResource? {
        switch self {
        case .engineOilService: "operation.engineOilService"
        case .dsgService: "operation.dsgService"
        case .awdCouplingService: "operation.awdCouplingService"
        case .brakeFluid: "operation.brakeFluid"
        case .cabinFilter: "operation.cabinFilter"
        case .airFilter: "operation.airFilter"
        case .sparkPlugs: "operation.sparkPlugs"
        default: nil
        }
    }

    /// An ID without a known title is shown verbatim, so it is neither looked up nor parsed as a format string.
    var titleText: Text {
        titleResource.map { Text($0) } ?? Text(verbatim: rawValue)
    }

    /// The same title as plain text, for announcements and other string-only APIs.
    var localizedTitle: String {
        titleResource.map { String(localized: $0) } ?? rawValue
    }
}

extension HistoryEventKind {
    var title: LocalizedStringResource {
        switch self {
        case .service: "history.kind.service"
        case .carWash: "history.kind.carWash"
        case .odometer: "history.kind.odometer"
        case .insurance: "history.kind.insurance"
        case .purchase: "history.kind.purchase"
        case .other: "history.kind.other"
        }
    }
}
