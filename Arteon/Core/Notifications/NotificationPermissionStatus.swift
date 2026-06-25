import Foundation
import UserNotifications

struct NotificationPermissionStatus: Sendable, Equatable {
    let alertEnabled: Bool
    let soundEnabled: Bool

    var isFullyEnabled: Bool {
        alertEnabled && soundEnabled
    }

    static func load() async -> NotificationPermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationPermissionStatus(
            alertEnabled: settings.alertSetting == .enabled,
            soundEnabled: settings.soundSetting == .enabled
        )
    }
}
