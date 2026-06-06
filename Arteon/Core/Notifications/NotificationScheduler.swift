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
    func pendingPlan(
        settings: AppSettingsEntity,
        vehicle: VehicleConfig,
        insurance: InsurancePolicyEntity?,
        lastOilOdometer: Int?
    ) -> [PlannedNotification]
}

final class NotificationScheduler: NotificationScheduling {
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
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
            let content = UNMutableNotificationContent()
            content.title = item.category.notificationTitle(relatedOdometerKm: item.relatedOdometerKm)
            content.body = item.category.notificationBody(
                relatedDate: item.relatedDate,
                relatedOdometerKm: item.relatedOdometerKm
            )
            content.badge = 1
            let trigger = trigger(for: item)
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
            try await center.add(request)
        }
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
