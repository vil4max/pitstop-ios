import Foundation
import os

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "dev.vil4max.pitstop"

    static func logger(category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
