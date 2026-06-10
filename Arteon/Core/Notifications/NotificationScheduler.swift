import Foundation
@preconcurrency import UserNotifications

enum NotificationBadge {
    static func clear() async {
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
    }
}

protocol NotificationScheduling: Sendable {
    func requestAuthorization() async throws -> Bool
    func scheduleAll(
        settings: AppSettingsEntity,
        vehicle: VehicleConfig,
        insurance: InsurancePolicyEntity?,
        lastOilOdometer: Int?
    ) async throws
    func scheduleTestStack() async throws
    func pendingPlan(
        settings: AppSettingsEntity,
        vehicle: VehicleConfig,
        insurance: InsurancePolicyEntity?,
        lastOilOdometer: Int?
    ) -> [PlannedNotification]
}

final class NotificationScheduler: NotificationScheduling {
    static let authorizationOptions: UNAuthorizationOptions = [.alert, .sound, .badge]

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: Self.authorizationOptions)
    }

    func pendingPlan(
        settings: AppSettingsEntity,
        vehicle: VehicleConfig,
        insurance: InsurancePolicyEntity?,
        lastOilOdometer: Int?
    ) -> [PlannedNotification] {
        NotificationPlanBuilder.build(
            NotificationPlanInput(
                serviceRemindersEnabled: settings.serviceRemindersEnabled,
                insuranceRemindersEnabled: settings.insuranceRemindersEnabled,
                monthlyOdometerReminderEnabled: settings.monthlyOdometerReminderEnabled,
                odometerKm: vehicle.odometerKm,
                averageMonthlyMileageKm: vehicle.averageMonthlyMileageKm,
                lastOilOdometer: lastOilOdometer,
                insuranceValidUntil: insurance?.validUntil,
                referenceDate: Date(),
                calendar: Calendar.current
            )
        )
    }

    func scheduleAll(
        settings: AppSettingsEntity,
        vehicle: VehicleConfig,
        insurance: InsurancePolicyEntity?,
        lastOilOdometer: Int?
    ) async throws {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let planned = pendingPlan(
            settings: settings,
            vehicle: vehicle,
            insurance: insurance,
            lastOilOdometer: lastOilOdometer
        )
        for item in planned {
            try await add(
                id: item.id,
                category: item.category,
                fireDate: item.fireDate,
                repeats: item.repeats,
                relatedDate: item.relatedDate,
                relatedOdometerKm: item.relatedOdometerKm,
                to: center
            )
        }
        if AppConfiguration.installTestNotificationStack {
            try await scheduleTestStack()
        }
    }

    func scheduleTestStack() async throws {
        let center = UNUserNotificationCenter.current()
        for item in TestNotificationStack.items {
            let fireDate = TestNotificationStack.fireDate(dayOffset: item.dayOffset)
            let content = UNMutableNotificationContent()
            content.title = item.category.pushTitle(relatedOdometerKm: item.relatedOdometerKm)
            content.body = item.category.pushBody(
                fireDate: fireDate,
                relatedDate: item.relatedDate,
                relatedOdometerKm: item.relatedOdometerKm
            )
            applyDeliveryOptions(to: content)
            content.userInfo = NotificationPayload.userInfo(for: item.destination)
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
            try await center.add(request)
        }
    }

    private func add(
        id: String,
        category: NotificationCategory,
        fireDate: Date,
        repeats: Bool,
        relatedDate: Date?,
        relatedOdometerKm: Int?,
        to center: UNUserNotificationCenter
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = category.pushTitle(relatedOdometerKm: relatedOdometerKm)
        content.body = category.pushBody(
            fireDate: fireDate,
            relatedDate: relatedDate,
            relatedOdometerKm: relatedOdometerKm
        )
        applyDeliveryOptions(to: content)
        content.userInfo = NotificationPayload.userInfo(for: category.navigationDestination)
        let trigger = trigger(for: PlannedNotification(
            id: id,
            category: category,
            titleKey: "",
            bodyKey: "",
            fireDate: fireDate,
            repeats: repeats,
            relatedDate: relatedDate,
            relatedOdometerKm: relatedOdometerKm
        ))
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await center.add(request)
    }

    private func localizedPushString(_ key: String) -> String {
        LocalizedFormat.string(String.LocalizationValue(stringLiteral: key))
    }

    private func applyDeliveryOptions(to content: UNMutableNotificationContent) {
        content.sound = .default
        content.badge = 1
    }

    private func trigger(for item: PlannedNotification) -> UNNotificationTrigger {
        if item.repeats {
            let components = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: item.fireDate)
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}
