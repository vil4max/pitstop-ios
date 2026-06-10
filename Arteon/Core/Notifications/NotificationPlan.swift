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

enum NotificationReminderTopic: String, CaseIterable, Sendable, Identifiable {
    case odometer
    case oilChange
    case maintenancePlan
    case seasonalTires
    case insurance

    var id: String { rawValue }

    var categories: Set<NotificationCategory> {
        switch self {
        case .odometer:
            [.monthlyOdometer]
        case .oilChange:
            [.oilDue, .oilWindowEnd, .oilPlan30, .oilPlan7, .oilPlan1]
        case .maintenancePlan:
            [.plan20000, .plan22000]
        case .seasonalTires:
            [.seasonalSpring, .seasonalAutumn]
        case .insurance:
            [.insurance30, .insurance7, .insurance1]
        }
    }

    var titleKey: String {
        switch self {
        case .odometer: "notifications.topic.odometer"
        case .oilChange: "notifications.topic.oil"
        case .maintenancePlan: "notifications.topic.maintenance"
        case .seasonalTires: "notifications.topic.seasonal"
        case .insurance: "notifications.topic.insurance"
        }
    }

    var symbol: String {
        switch self {
        case .odometer: "gauge.with.dots.needle.67percent"
        case .oilChange: "drop.fill"
        case .maintenancePlan: "wrench.and.screwdriver.fill"
        case .seasonalTires: "snowflake"
        case .insurance: "shield.checkered"
        }
    }

    var sortOrder: Int {
        switch self {
        case .odometer: 0
        case .oilChange: 1
        case .maintenancePlan: 2
        case .seasonalTires: 3
        case .insurance: 4
        }
    }

    func aboutText(from items: [PlannedNotification]) -> String {
        switch self {
        case .odometer:
            return LocalizedFormat.string("notifications.topic.odometer.about")
        case .oilChange:
            let windowStart = items.first(where: { $0.category == .oilDue })?.relatedOdometerKm
            let windowEnd = items.first(where: { $0.category == .oilWindowEnd })?.relatedOdometerKm
            if let windowStart, let windowEnd {
                return LocalizedFormat.string("notifications.topic.oil.aboutWindow", windowStart, windowEnd)
            }
            if let windowStart {
                return LocalizedFormat.string("notifications.schedule.detail.oilKmTarget", windowStart)
            }
            return LocalizedFormat.string("notifications.schedule.detail.oil")
        case .maintenancePlan:
            let kms = Array(Set(items.compactMap(\.relatedOdometerKm))).sorted()
            guard let first = kms.first else {
                return LocalizedFormat.string("notifications.topic.maintenance.about")
            }
            if kms.count == 1 {
                return LocalizedFormat.string("notifications.topic.maintenance.aboutSingleKm", first)
            }
            return LocalizedFormat.string("notifications.topic.maintenance.aboutKm", first, kms[1])
        case .seasonalTires:
            return LocalizedFormat.string("notifications.topic.seasonal.about")
        case .insurance:
            if let date = items.compactMap(\.relatedDate).first {
                return LocalizedFormat.string("notifications.schedule.detail.insuranceExpiry", LocalizedFormat.date(date))
            }
            return LocalizedFormat.string("insurance.title")
        }
    }
}

struct NotificationReminderGroup: Identifiable, Sendable {
    let topic: NotificationReminderTopic
    let items: [PlannedNotification]

    var id: String { topic.id }

    var repeatsAnnuallyOrMonthly: Bool {
        items.contains(where: \.repeats)
    }
}

enum NotificationReminderGrouper {
    static func groups(from planned: [PlannedNotification]) -> [NotificationReminderGroup] {
        NotificationReminderTopic.allCases.compactMap { topic in
            let items = planned
                .filter { topic.categories.contains($0.category) }
                .sorted { $0.fireDate < $1.fireDate }
            guard !items.isEmpty else { return nil }
            return NotificationReminderGroup(topic: topic, items: items)
        }
        .sorted { $0.topic.sortOrder < $1.topic.sortOrder }
    }
}

extension NotificationCategory {
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

    var navigationDestination: AppDestination {
        switch self {
        case .monthlyOdometer:
            return .reminderTopic(.odometer)
        case .oilDue, .oilWindowEnd, .oilPlan30, .oilPlan7, .oilPlan1:
            return .reminderTopic(.oilChange)
        case .plan20000, .plan22000:
            return .reminderTopic(.maintenancePlan)
        case .seasonalSpring, .seasonalAutumn:
            return .reminderTopic(.seasonalTires)
        case .insurance30, .insurance7, .insurance1:
            return .reminderTopic(.insurance)
        }
    }

    func pushTitle(relatedOdometerKm: Int? = nil) -> String {
        switch self {
        case .monthlyOdometer:
            return LocalizedFormat.string("notification.push.odometer.title")
        case .oilDue, .oilWindowEnd, .oilPlan30, .oilPlan7, .oilPlan1:
            return LocalizedFormat.string("notification.push.oil.title")
        case .plan20000, .plan22000:
            guard let relatedOdometerKm else {
                return LocalizedFormat.string("notification.push.service.title")
            }
            return LocalizedFormat.string("notification.push.service.titleKm", relatedOdometerKm)
        case .seasonalSpring, .seasonalAutumn:
            return LocalizedFormat.string("notification.push.seasonal.title")
        case .insurance30, .insurance7, .insurance1:
            return LocalizedFormat.string("notification.push.insurance.title")
        }
    }

    func pushBody(fireDate: Date, relatedDate: Date?, relatedOdometerKm: Int?) -> String {
        let days = MaintenanceEngine.daysUntil(fireDate)
        switch self {
        case .monthlyOdometer:
            return LocalizedFormat.string("notification.push.odometer.body", max(days, 0))
        case .oilDue:
            return LocalizedFormat.string("notification.push.oil.body.due")
        case .oilWindowEnd:
            return LocalizedFormat.string("notification.push.oil.body.windowEnd")
        case .oilPlan30, .oilPlan7, .oilPlan1:
            return LocalizedFormat.string("notification.push.oil.body.plan", oilPlanDaysBefore)
        case .plan20000, .plan22000:
            guard let relatedOdometerKm else {
                return LocalizedFormat.string("notification.push.service.body")
            }
            return LocalizedFormat.string("notification.push.service.bodyKm", relatedOdometerKm)
        case .seasonalSpring:
            return LocalizedFormat.string("notification.push.seasonal.body.summer", max(days, 0))
        case .seasonalAutumn:
            return LocalizedFormat.string("notification.push.seasonal.body.winter", max(days, 0))
        case .insurance30, .insurance7, .insurance1:
            return LocalizedFormat.string("notification.push.insurance.body", insuranceDaysBefore)
        }
    }

    func scheduleMomentLabel(relatedOdometerKm: Int? = nil) -> String {
        switch self {
        case .monthlyOdometer:
            return LocalizedFormat.string("notifications.topic.moment.monthly")
        case .oilDue:
            return LocalizedFormat.string("notifications.topic.moment.oilDue")
        case .oilWindowEnd:
            return LocalizedFormat.string("notifications.topic.moment.oilWindowEnd")
        case .plan20000, .plan22000:
            guard let relatedOdometerKm else {
                return LocalizedFormat.string("notifications.topic.moment.maintenance")
            }
            return LocalizedFormat.string("notifications.topic.moment.maintenanceKm", relatedOdometerKm)
        case .oilPlan30, .oilPlan7, .oilPlan1:
            return LocalizedFormat.string("notifications.topic.moment.beforeEstimate", oilPlanDaysBefore)
        case .seasonalSpring:
            return LocalizedFormat.string("notifications.topic.moment.seasonalSpring")
        case .seasonalAutumn:
            return LocalizedFormat.string("notifications.topic.moment.seasonalAutumn")
        case .insurance30, .insurance7, .insurance1:
            return LocalizedFormat.string("notifications.topic.moment.beforeExpiry", insuranceDaysBefore)
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
