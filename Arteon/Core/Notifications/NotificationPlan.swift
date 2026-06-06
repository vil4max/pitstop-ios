import Foundation

enum NotificationCategory: String, Sendable, CaseIterable {
    case monthlyOdometer
    case oilDue
    case oilWindowEnd
    case plan20000
    case plan22000
    case oilPlan30
    case oilPlan7
    case oilPlan1
    case seasonalSpring
    case seasonalAutumn
    case insurance30
    case insurance7
    case insurance1
}

struct PlannedNotification: Identifiable, Sendable, Equatable {
    let id: String
    let category: NotificationCategory
    let titleKey: String
    let bodyKey: String
    let fireDate: Date
    let repeats: Bool
    let relatedDate: Date?
    let relatedOdometerKm: Int?
}

enum NotificationScheduleSection: Int, CaseIterable, Sendable {
    case odometer
    case service
    case insurance

    var titleKey: String {
        switch self {
        case .odometer: "notifications.schedule.section.odometer"
        case .service: "notifications.schedule.section.service"
        case .insurance: "notifications.schedule.section.insurance"
        }
    }

    var categories: [NotificationCategory] {
        switch self {
        case .odometer: [.monthlyOdometer]
        case .service: [
            .oilDue,
            .oilWindowEnd,
            .plan20000,
            .plan22000,
            .oilPlan30,
            .oilPlan7,
            .oilPlan1,
            .seasonalSpring,
            .seasonalAutumn,
        ]
        case .insurance: [.insurance30, .insurance7, .insurance1]
        }
    }

    func items(in planned: [PlannedNotification]) -> [PlannedNotification] {
        let allowed = Set(categories)
        return planned
            .filter { allowed.contains($0.category) }
            .sorted { $0.fireDate < $1.fireDate }
    }
}

extension NotificationCategory {
    var scheduleSection: NotificationScheduleSection {
        switch self {
        case .monthlyOdometer: .odometer
        case .oilDue, .oilWindowEnd, .plan20000, .plan22000, .oilPlan30, .oilPlan7, .oilPlan1, .seasonalSpring,
             .seasonalAutumn:
            .service
        case .insurance30, .insurance7, .insurance1: .insurance
        }
    }

    func scheduleTitle(relatedOdometerKm: Int? = nil) -> String {
        switch self {
        case .monthlyOdometer:
            return LocalizedFormat.string("odometer.update")
        case .oilDue:
            return LocalizedFormat.string("nextOil.title")
        case .oilWindowEnd:
            return LocalizedFormat.string("notification.oilWindowEnd.title")
        case .plan20000, .plan22000:
            guard let relatedOdometerKm else {
                return LocalizedFormat.string("notification.plan.km.title", 0)
            }
            return LocalizedFormat.string("notification.plan.km.title", relatedOdometerKm)
        case .oilPlan30:
            return LocalizedFormat.string("notifications.schedule.oilPlan.beforeDays", 30)
        case .oilPlan7:
            return LocalizedFormat.string("notifications.schedule.oilPlan.beforeDays", 7)
        case .oilPlan1:
            return LocalizedFormat.string("notifications.schedule.oilPlan.beforeDays", 1)
        case .seasonalSpring:
            return LocalizedFormat.string("notification.seasonal.spring.title")
        case .seasonalAutumn:
            return LocalizedFormat.string("notification.seasonal.autumn.title")
        case .insurance30:
            return LocalizedFormat.string("notifications.schedule.insurance.beforeDays", 30)
        case .insurance7:
            return LocalizedFormat.string("notifications.schedule.insurance.beforeDays", 7)
        case .insurance1:
            return LocalizedFormat.string("notifications.schedule.insurance.beforeDays", 1)
        }
    }

    func scheduleDetail(relatedDate: Date?, relatedOdometerKm: Int?) -> String {
        switch self {
        case .monthlyOdometer:
            return LocalizedFormat.string("notifications.schedule.detail.odometer")
        case .oilDue:
            guard let relatedOdometerKm else {
                return LocalizedFormat.string("notifications.schedule.detail.oil")
            }
            return LocalizedFormat.string("notifications.schedule.detail.oilKmTarget", relatedOdometerKm)
        case .oilWindowEnd:
            guard let relatedOdometerKm else {
                return LocalizedFormat.string("notifications.schedule.detail.oilWindowEnd", 0)
            }
            return LocalizedFormat.string("notifications.schedule.detail.oilWindowEnd", relatedOdometerKm)
        case .plan20000, .plan22000:
            guard let relatedOdometerKm else {
                return LocalizedFormat.string("notifications.schedule.detail.planKm", 0)
            }
            return LocalizedFormat.string("notifications.schedule.detail.planKm", relatedOdometerKm)
        case .oilPlan30, .oilPlan7, .oilPlan1:
            guard let relatedDate else {
                return LocalizedFormat.string("notifications.schedule.detail.oilPlanEstimate", "")
            }
            return LocalizedFormat.string(
                "notifications.schedule.detail.oilPlanEstimate",
                LocalizedFormat.date(relatedDate)
            )
        case .seasonalSpring:
            return LocalizedFormat.string("notifications.schedule.detail.seasonalSpring")
        case .seasonalAutumn:
            return LocalizedFormat.string("notifications.schedule.detail.seasonalAutumn")
        case .insurance30, .insurance7, .insurance1:
            guard let relatedDate else {
                return LocalizedFormat.string("notification.insurance.body", insuranceDaysBefore)
            }
            return LocalizedFormat.string(
                "notifications.schedule.detail.insuranceExpiry",
                LocalizedFormat.date(relatedDate)
            )
        }
    }

    func notificationTitle(relatedOdometerKm: Int? = nil) -> String {
        scheduleTitle(relatedOdometerKm: relatedOdometerKm)
    }

    func notificationBody(relatedDate: Date?, relatedOdometerKm: Int?) -> String {
        switch self {
        case .monthlyOdometer:
            return LocalizedFormat.string("notification.odometer.body")
        case .oilDue:
            return LocalizedFormat.string("notification.oil.body")
        case .oilWindowEnd:
            return LocalizedFormat.string("notification.oilWindowEnd.body")
        case .plan20000, .plan22000:
            guard let relatedOdometerKm else {
                return LocalizedFormat.string("notification.plan.km.body", 0)
            }
            return LocalizedFormat.string("notification.plan.km.body", relatedOdometerKm)
        case .oilPlan30, .oilPlan7, .oilPlan1:
            return LocalizedFormat.string("notification.oilPlan.body", oilPlanDaysBefore)
        case .seasonalSpring, .seasonalAutumn:
            return LocalizedFormat.string("notification.seasonal.body")
        case .insurance30, .insurance7, .insurance1:
            return LocalizedFormat.string("notification.insurance.body", insuranceDaysBefore)
        }
    }

    private var insuranceDaysBefore: Int {
        switch self {
        case .insurance30: 30
        case .insurance7: 7
        case .insurance1: 1
        default: 0
        }
    }

    private var oilPlanDaysBefore: Int {
        switch self {
        case .oilPlan30: 30
        case .oilPlan7: 7
        case .oilPlan1: 1
        default: 0
        }
    }
}

struct NotificationPlanInput: Sendable {
    let serviceRemindersEnabled: Bool
    let insuranceRemindersEnabled: Bool
    let monthlyOdometerReminderEnabled: Bool
    let odometerKm: Int
    let averageMonthlyMileageKm: Int
    let lastOilOdometer: Int?
    let insuranceValidUntil: Date?
    let referenceDate: Date
    let calendar: Calendar
}

enum NotificationPlanBuilder {
    private static let defaultFireHour = 9
    private static let defaultFireMinute = 0
    private static let planMilestonesKm = [20_000, 22_000]

    static func build(_ input: NotificationPlanInput) -> [PlannedNotification] {
        var planned: [PlannedNotification] = []
        if input.monthlyOdometerReminderEnabled {
            planned.append(monthlyOdometer(reference: input.referenceDate, calendar: input.calendar))
        }
        if input.serviceRemindersEnabled, let lastOil = input.lastOilOdometer {
            planned.append(contentsOf: mileageServiceReminders(input: input, lastOilOdometer: lastOil))
            planned.append(contentsOf: seasonalReminders(calendar: input.calendar))
        }
        if input.insuranceRemindersEnabled, let validUntil = input.insuranceValidUntil {
            planned.append(contentsOf: insuranceReminders(validUntil: validUntil, reference: input.referenceDate, calendar: input.calendar))
        }
        return planned.sorted { $0.fireDate < $1.fireDate }
    }

    private static func mileageServiceReminders(
        input: NotificationPlanInput,
        lastOilOdometer: Int
    ) -> [PlannedNotification] {
        let window = MaintenanceEngine.nextOilWindow(lastOilOdometer: lastOilOdometer)
        var planned: [PlannedNotification] = []
        if let reminder = mileageReminder(
            id: "oil.due",
            category: .oilDue,
            targetKm: window.minKm,
            input: input
        ) {
            planned.append(reminder)
        }
        if let reminder = mileageReminder(
            id: "oil.window.end",
            category: .oilWindowEnd,
            targetKm: window.maxKm,
            input: input
        ) {
            planned.append(reminder)
        }
        for targetKm in planMilestonesKm where input.odometerKm < targetKm {
            if let reminder = mileageReminder(
                id: "plan.\(targetKm)",
                category: targetKm == 20_000 ? .plan20000 : .plan22000,
                targetKm: targetKm,
                input: input
            ) {
                planned.append(reminder)
            }
        }
        planned.append(contentsOf: oilPlanDateReminders(targetKm: 20_000, input: input))
        return planned
    }

    private static func mileageReminder(
        id: String,
        category: NotificationCategory,
        targetKm: Int,
        input: NotificationPlanInput
    ) -> PlannedNotification? {
        let fireDate = fireDateForMilestone(
            targetKm: targetKm,
            odometerKm: input.odometerKm,
            averageMonthlyKm: input.averageMonthlyMileageKm,
            reference: input.referenceDate,
            calendar: input.calendar
        )
        guard let fireDate, fireDate >= input.referenceDate else { return nil }
        return makePlanned(
            id: id,
            category: category,
            fireDate: fireDate,
            relatedOdometerKm: targetKm
        )
    }

    private static func oilPlanDateReminders(targetKm: Int, input: NotificationPlanInput) -> [PlannedNotification] {
        guard input.odometerKm < targetKm else { return [] }
        guard let estimatedArrival = MaintenanceEngine.estimatedDate(
            targetOdometerKm: targetKm,
            currentOdometerKm: input.odometerKm,
            averageMonthlyKm: input.averageMonthlyMileageKm,
            from: input.referenceDate,
            calendar: input.calendar
        ) else { return [] }
        let offsets: [(Int, NotificationCategory, String)] = [
            (30, .oilPlan30, "oil.plan.30"),
            (7, .oilPlan7, "oil.plan.7"),
            (1, .oilPlan1, "oil.plan.1"),
        ]
        return offsets.compactMap { days, category, id in
            guard let rawDate = input.calendar.date(byAdding: .day, value: -days, to: estimatedArrival) else {
                return nil
            }
            let fireDate = normalizedFireDate(rawDate, calendar: input.calendar)
            guard fireDate >= input.referenceDate else { return nil }
            return makePlanned(
                id: id,
                category: category,
                fireDate: fireDate,
                relatedDate: estimatedArrival,
                relatedOdometerKm: targetKm
            )
        }
    }

    private static func fireDateForMilestone(
        targetKm: Int,
        odometerKm: Int,
        averageMonthlyKm: Int,
        reference: Date,
        calendar: Calendar
    ) -> Date? {
        if odometerKm >= targetKm {
            return nextScheduledFireDate(from: reference, calendar: calendar)
        }
        guard let estimated = MaintenanceEngine.estimatedDate(
            targetOdometerKm: targetKm,
            currentOdometerKm: odometerKm,
            averageMonthlyKm: averageMonthlyKm,
            from: reference,
            calendar: calendar
        ) else { return nil }
        return normalizedFireDate(estimated, calendar: calendar)
    }

    private static func normalizedFireDate(_ date: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = defaultFireHour
        components.minute = defaultFireMinute
        return calendar.date(from: components) ?? date
    }

    private static func nextScheduledFireDate(from reference: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: reference)
        components.hour = defaultFireHour
        components.minute = defaultFireMinute
        let today = calendar.date(from: components) ?? reference
        if today > reference {
            return today
        }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? reference.addingTimeInterval(86_400)
    }

    private static func makePlanned(
        id: String,
        category: NotificationCategory,
        fireDate: Date,
        repeats: Bool = false,
        relatedDate: Date? = nil,
        relatedOdometerKm: Int? = nil
    ) -> PlannedNotification {
        PlannedNotification(
            id: id,
            category: category,
            titleKey: "",
            bodyKey: "",
            fireDate: fireDate,
            repeats: repeats,
            relatedDate: relatedDate,
            relatedOdometerKm: relatedOdometerKm
        )
    }

    private static func monthlyOdometer(reference: Date, calendar: Calendar) -> PlannedNotification {
        var components = calendar.dateComponents([.year, .month], from: reference)
        components.day = 1
        components.hour = defaultFireHour
        components.minute = defaultFireMinute
        let fireDate = calendar.nextDate(after: reference, matching: components, matchingPolicy: .nextTime) ?? reference
        return makePlanned(
            id: "monthly.odometer",
            category: .monthlyOdometer,
            fireDate: fireDate,
            repeats: true
        )
    }

    private static func seasonalReminders(calendar: Calendar) -> [PlannedNotification] {
        [
            seasonalReminder(
                month: 4,
                day: 1,
                id: "seasonal.spring",
                category: .seasonalSpring,
                calendar: calendar
            ),
            seasonalReminder(
                month: 11,
                day: 1,
                id: "seasonal.autumn",
                category: .seasonalAutumn,
                calendar: calendar
            ),
        ]
    }

    private static func seasonalReminder(
        month: Int,
        day: Int,
        id: String,
        category: NotificationCategory,
        calendar: Calendar
    ) -> PlannedNotification {
        var components = DateComponents()
        components.month = month
        components.day = day
        components.hour = defaultFireHour
        components.minute = defaultFireMinute
        let fireDate = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) ?? Date()
        return makePlanned(
            id: id,
            category: category,
            fireDate: fireDate,
            repeats: true
        )
    }

    private static func insuranceReminders(validUntil: Date, reference: Date, calendar: Calendar) -> [PlannedNotification] {
        let offsets: [(Int, NotificationCategory, String)] = [
            (30, .insurance30, "insurance.30"),
            (7, .insurance7, "insurance.7"),
            (1, .insurance1, "insurance.1"),
        ]
        return offsets.compactMap { offset, category, id in
            guard let fireDate = calendar.date(byAdding: .day, value: -offset, to: validUntil),
                  fireDate >= reference else { return nil }
            let normalized = normalizedFireDate(fireDate, calendar: calendar)
            return makePlanned(
                id: id,
                category: category,
                fireDate: normalized,
                relatedDate: validUntil
            )
        }
    }
}
