import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case myCar
    case service
    case upgrade
    case settings

    var title: LocalizedStringKey {
        switch self {
        case .myCar: "tab.myCar"
        case .service: "tab.service"
        case .upgrade: "tab.upgrade"
        case .settings: "tab.settings"
        }
    }

    var symbol: String {
        switch self {
        case .myCar: "car.side.fill"
        case .service: "wrench.and.screwdriver.fill"
        case .upgrade: "sparkles"
        case .settings: "gearshape.fill"
        }
    }
}
