import Foundation
import SwiftData

enum NotificationRefresh {
    private static let defaultsMigrationKey = "notificationPreferencesDefaultsApplied"

    @MainActor
    static func apply(
        context: ModelContext,
        visits: [ServiceVisitEntity],
        scheduler: NotificationScheduling = NotificationScheduler()
    ) async {
        let settings = ensureSettings(in: context)
        let vehicle = (try? context.fetch(FetchDescriptor<VehicleConfig>()))?.first
        let insurance = (try? context.fetch(FetchDescriptor<InsurancePolicyEntity>()))?.first
        guard let vehicle else { return }
        applyDefaultNotificationPreferencesIfNeeded(settings: settings, context: context)
        await NotificationBadge.clear()
        let granted = (try? await scheduler.requestAuthorization()) ?? false
        guard granted else { return }
        let lastOil = MaintenanceEngine.lastOilChangeOdometer(visits: visits.map(VisitSnapshot.init(from:)))
        try? await scheduler.scheduleAll(
            settings: settings,
            vehicle: vehicle,
            insurance: insurance,
            lastOilOdometer: lastOil
        )
    }

    @MainActor
    private static func ensureSettings(in context: ModelContext) -> AppSettingsEntity {
        if let existing = (try? context.fetch(FetchDescriptor<AppSettingsEntity>()))?.first {
            return existing
        }
        let settings = AppSettingsEntity(
            serviceRemindersEnabled: true,
            insuranceRemindersEnabled: true,
            monthlyOdometerReminderEnabled: true
        )
        context.insert(settings)
        try? context.save()
        return settings
    }

    @MainActor
    private static func applyDefaultNotificationPreferencesIfNeeded(
        settings: AppSettingsEntity,
        context: ModelContext
    ) {
        guard !UserDefaults.standard.bool(forKey: defaultsMigrationKey) else { return }
        settings.serviceRemindersEnabled = true
        settings.insuranceRemindersEnabled = true
        settings.monthlyOdometerReminderEnabled = true
        try? context.save()
        UserDefaults.standard.set(true, forKey: defaultsMigrationKey)
    }
}
