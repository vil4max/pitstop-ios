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
    static let destinationKey = "arteon.destination"

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

enum TestNotificationStack {
    struct Item: Sendable {
        let id: String
        let dayOffset: Int
        let category: NotificationCategory
        let relatedOdometerKm: Int?
        let relatedDate: Date?

        var destination: AppDestination { category.navigationDestination }
    }

    /// One notification per category variant, spread across 13 days at 10:00.
    static let items: [Item] = {
        let calendar = Calendar.current
        let insuranceExpiry = calendar.date(byAdding: .day, value: 45, to: Date()) ?? Date()
        return [
            Item(id: "test.stack.odometer", dayOffset: 1, category: .monthlyOdometer, relatedOdometerKm: nil, relatedDate: nil),
            Item(id: "test.stack.oil.due", dayOffset: 2, category: .oilDue, relatedOdometerKm: 16_000, relatedDate: nil),
            Item(id: "test.stack.oil.window", dayOffset: 3, category: .oilWindowEnd, relatedOdometerKm: 18_000, relatedDate: nil),
            Item(id: "test.stack.oil.plan30", dayOffset: 4, category: .oilPlan30, relatedOdometerKm: 20_000, relatedDate: nil),
            Item(id: "test.stack.oil.plan7", dayOffset: 5, category: .oilPlan7, relatedOdometerKm: 20_000, relatedDate: nil),
            Item(id: "test.stack.oil.plan1", dayOffset: 6, category: .oilPlan1, relatedOdometerKm: 20_000, relatedDate: nil),
            Item(id: "test.stack.plan.20000", dayOffset: 7, category: .plan20000, relatedOdometerKm: 20_000, relatedDate: nil),
            Item(id: "test.stack.plan.22000", dayOffset: 8, category: .plan22000, relatedOdometerKm: 22_000, relatedDate: nil),
            Item(id: "test.stack.seasonal.spring", dayOffset: 9, category: .seasonalSpring, relatedOdometerKm: nil, relatedDate: nil),
            Item(id: "test.stack.seasonal.autumn", dayOffset: 10, category: .seasonalAutumn, relatedOdometerKm: nil, relatedDate: nil),
            Item(id: "test.stack.insurance.30", dayOffset: 11, category: .insurance30, relatedOdometerKm: nil, relatedDate: insuranceExpiry),
            Item(id: "test.stack.insurance.7", dayOffset: 12, category: .insurance7, relatedOdometerKm: nil, relatedDate: insuranceExpiry),
            Item(id: "test.stack.insurance.1", dayOffset: 13, category: .insurance1, relatedOdometerKm: nil, relatedDate: insuranceExpiry),
        ]
    }()

    static func fireDate(dayOffset: Int, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: dayOffset, to: start) ?? start
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = 10
        components.minute = 0
        return calendar.date(from: components) ?? day
    }
}
