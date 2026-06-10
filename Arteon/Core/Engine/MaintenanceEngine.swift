import Foundation

struct OilWindow: Equatable, Sendable {
    let minKm: Int
    let maxKm: Int
    let defaultKm: Int
}

enum MaintenanceEngine {
    static func lastOilChangeOdometer(visits: [VisitSnapshot]) -> Int? {
        visits
            .filter { $0.includesOilChange && $0.isCompleted }
            .map(\.completedOdometer)
            .compactMap { $0 }
            .max()
    }

    static func kmSinceLastOil(odometer: Int, lastOilOdometer: Int) -> Int {
        odometer - lastOilOdometer
    }

    static func nextOilWindow(lastOilOdometer: Int, intervalMin: Int = 5000, intervalMax: Int = 7000, intervalDefault: Int = 6000) -> OilWindow {
        OilWindow(
            minKm: lastOilOdometer + intervalMin,
            maxKm: lastOilOdometer + intervalMax,
            defaultKm: lastOilOdometer + intervalDefault
        )
    }

    static func oilDueSoon(kmSinceLastOil: Int, threshold: Int = 5000) -> Bool {
        kmSinceLastOil >= threshold
    }

    static func lastCompletedVisit(visits: [VisitSnapshot]) -> VisitSnapshot? {
        visits.filter(\.isCompleted).max(by: { $0.sortOrder < $1.sortOrder })
    }

    static func nearestVisit(visits: [VisitSnapshot], odometer: Int) -> VisitSnapshot? {
        let pending = visits.filter { !$0.isCompleted }
        let upcoming = pending
            .filter { $0.targetOdometerKm >= odometer }
            .sorted { $0.sortOrder < $1.sortOrder }
        if let next = upcoming.first {
            return next
        }
        return pending.sorted { $0.sortOrder < $1.sortOrder }.last
    }

    static func kmRemaining(visit: VisitSnapshot, odometer: Int) -> Int {
        max(visit.targetOdometerKm - odometer, 0)
    }

    static func estimatedMonths(kmRemaining: Int, averageMonthlyKm: Int) -> Int {
        guard averageMonthlyKm > 0 else { return 0 }
        return Int((Double(kmRemaining) / Double(averageMonthlyKm)).rounded(.up))
    }

    static func estimatedDays(kmRemaining: Int, averageMonthlyKm: Int) -> Int {
        guard averageMonthlyKm > 0, kmRemaining > 0 else { return 0 }
        return Int(ceil(Double(kmRemaining) * 30.0 / Double(averageMonthlyKm)))
    }

    static func estimatedDate(
        targetOdometerKm: Int,
        currentOdometerKm: Int,
        averageMonthlyKm: Int,
        from reference: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard averageMonthlyKm > 0 else { return nil }
        let kmRemaining = targetOdometerKm - currentOdometerKm
        if kmRemaining <= 0 {
            return reference
        }
        let days = estimatedDays(kmRemaining: kmRemaining, averageMonthlyKm: averageMonthlyKm)
        let start = calendar.startOfDay(for: reference)
        return calendar.date(byAdding: .day, value: max(days, 1), to: start)
    }

    static func isInServiceWindow(visit: VisitSnapshot, odometer: Int) -> Bool {
        guard let from = visit.windowFromKm, let to = visit.windowToKm else { return false }
        return odometer >= from && odometer <= to
    }

    static func canCompleteVisit(tasks: [TaskSnapshot]) -> Bool {
        tasks
            .filter { $0.isMandatory && $0.isApplicable && $0.isEnabled }
            .allSatisfy(\.isDone)
    }

    static func minimumCompletionOdometerKm(windowFromKm: Int?, targetOdometerKm: Int) -> Int {
        windowFromKm ?? targetOdometerKm
    }

    static func canCompleteVisitAtOdometer(visit: VisitSnapshot, odometer: Int) -> Bool {
        odometer >= minimumCompletionOdometerKm(
            windowFromKm: visit.windowFromKm,
            targetOdometerKm: visit.targetOdometerKm
        )
    }

    static func isPrematureVisitCompletion(
        targetOdometerKm: Int,
        windowFromKm: Int?,
        completedOdometer: Int
    ) -> Bool {
        completedOdometer < minimumCompletionOdometerKm(
            windowFromKm: windowFromKm,
            targetOdometerKm: targetOdometerKm
        )
    }

    static func daysUntil(_ date: Date, from reference: Date = Date()) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: reference)
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    static func insuranceExpiringSoon(validUntil: Date, thresholdDays: Int = 30, from reference: Date = Date()) -> Bool {
        let days = daysUntil(validUntil, from: reference)
        return days >= 0 && days <= thresholdDays
    }

    static func serviceEstimateSoon(estimatedDate: Date, thresholdDays: Int = 30, from reference: Date = Date()) -> Bool {
        let days = daysUntil(estimatedDate, from: reference)
        return days >= 0 && days <= thresholdDays
    }
}

struct VisitSnapshot: Sendable {
    let id: String
    let kind: VisitKind
    let sortOrder: Int
    let targetOdometerKm: Int
    let includesOilChange: Bool
    let isCompleted: Bool
    let completedOdometer: Int?
    let windowFromKm: Int?
    let windowToKm: Int?
}

struct TaskSnapshot: Sendable {
    let isMandatory: Bool
    let isApplicable: Bool
    let isEnabled: Bool
    let isDone: Bool
}
