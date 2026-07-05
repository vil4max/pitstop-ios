import UIKit
import UserNotifications

final class NotificationAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in
            await NotificationBadge.clear()
        }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in
            await NotificationBadge.clear()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let destination = NotificationPayload.destination(from: userInfo) else { return }
        await NotificationBadge.clear()
        await MainActor.run {
            NotificationCenter.default.post(name: .pitstopOpenDestination, object: destination)
        }
    }
}
