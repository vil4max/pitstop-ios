import Foundation
import UserNotifications

struct NotificationPermissionStatus: Sendable, Equatable {
    let alertEnabled: Bool
    let soundEnabled: Bool
    let badgeEnabled: Bool

    var isFullyEnabled: Bool {
        alertEnabled && soundEnabled && badgeEnabled
    }

    static func load() async -> NotificationPermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationPermissionStatus(
            alertEnabled: settings.alertSetting == .enabled,
            soundEnabled: settings.soundSetting == .enabled,
            badgeEnabled: settings.badgeSetting == .enabled
        )
    }
}
