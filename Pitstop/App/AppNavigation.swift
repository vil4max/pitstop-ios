import Foundation
import SwiftUI

enum CarStatusWidgetKind: String, Hashable, Sendable {
    case oil
    case insurance
    case service
    case serviceEstimate
}

enum AppDestination: Hashable, Identifiable, Sendable {
    case reminderTopic(NotificationReminderTopic)
    case carWidget(CarStatusWidgetKind)
    case serviceVisit(seedId: String)

    var id: String {
        switch self {
        case let .reminderTopic(topic):
            "topic.\(topic.rawValue)"
        case let .carWidget(widget):
            "widget.\(widget.rawValue)"
        case let .serviceVisit(seedId):
            "visit.\(seedId)"
        }
    }
}

enum NotificationPayload {
    static let destinationKey = "pitstop.destination"

    static func userInfo(for destination: AppDestination) -> [String: String] {
        switch destination {
        case let .reminderTopic(topic):
            ["kind": "topic", "value": topic.rawValue]
        case let .carWidget(widget):
            ["kind": "widget", "value": widget.rawValue]
        case let .serviceVisit(seedId):
            ["kind": "visit", "value": seedId]
        }
    }

    static func destination(from userInfo: [AnyHashable: Any]) -> AppDestination? {
        guard let kind = userInfo["kind"] as? String,
              let value = userInfo["value"] as? String else { return nil }
        switch kind {
        case "topic":
            guard let topic = NotificationReminderTopic(rawValue: value) else { return nil }
            return .reminderTopic(topic)
        case "widget":
            guard let widget = CarStatusWidgetKind(rawValue: value) else { return nil }
            return .carWidget(widget)
        case "visit":
            return .serviceVisit(seedId: value)
        default:
            return nil
        }
    }
}

@Observable
@MainActor
final class AppNavigationState {
    var selectedTab: AppTab = .myCar
    var presentedDetail: AppDestination?
    var serviceVisitSeedId: String?
    var showInsurancePolicy = false

    func open(_ destination: AppDestination) {
        switch destination {
        case let .serviceVisit(seedId):
            selectedTab = .service
            serviceVisitSeedId = seedId
        case .reminderTopic(.odometer):
            selectedTab = .myCar
        case .reminderTopic(.insurance), .carWidget(.insurance):
            openInsurancePolicy()
        case .reminderTopic, .carWidget:
            presentedDetail = destination
        }
    }

    func openInsurancePolicy() {
        showInsurancePolicy = true
    }
}
