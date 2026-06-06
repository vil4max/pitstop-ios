import Foundation

enum UpgradeTotals {
    static func totalSpentUah(items: [UpgradeItemSnapshot]) -> Int {
        items.filter { $0.status == .done }.map(\.costUah).reduce(0, +)
    }

    static func totalPlannedUsd(items: [UpgradeItemSnapshot]) -> Int {
        items
            .filter { $0.status == .planned && $0.currencyCode == "USD" }
            .map(\.costUah)
            .reduce(0, +)
    }

    static func sortedDone(_ items: [UpgradeItemSnapshot]) -> [UpgradeItemSnapshot] {
        items
            .filter { $0.status == .done }
            .sorted { lhs, rhs in
                (lhs.completedDate ?? .distantFuture) < (rhs.completedDate ?? .distantFuture)
            }
    }

    static func sortedPlanned(_ items: [UpgradeItemSnapshot]) -> [UpgradeItemSnapshot] {
        items
            .filter { $0.status == .planned }
            .sorted { ($0.priority ?? Int.max) < ($1.priority ?? Int.max) }
    }
}

struct UpgradeItemSnapshot: Sendable, Identifiable {
    let id: String
    let title: String
    let costUah: Int
    let currencyCode: String
    let status: UpgradeStatus
    let completedDate: Date?
    let priority: Int?
}
