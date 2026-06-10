import Foundation

enum AppConfiguration {
    /// Override system language for debugging. `nil` follows the device locale.
    static let forcedLocale: Locale? = nil

    /// Schedules three test pushes: tomorrow, day after tomorrow, and in one week.
    static let installTestNotificationStack = true
}
