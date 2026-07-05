import Foundation
import SwiftData
import Testing
@testable import Arteon

@Suite("MaintenanceEngine")
struct MaintenanceEngineTests {
    @Test func nearestOilWindow_whenLastOil11000_returns16000To18000() {
        let window = MaintenanceEngine.nextOilWindow(lastOilOdometer: 11_000)
        #expect(window.minKm == 16_000)
        #expect(window.maxKm == 18_000)
        #expect(window.defaultKm == 17_000)
    }

    @Test func kmSinceLastOil_whenOdometer13600_is2600() {
        let value = MaintenanceEngine.kmSinceLastOil(odometer: 13_600, lastOilOdometer: 11_000)
        #expect(value == 2_600)
    }

    @Test func oilDueSoon_whenOdometer16000_isTrue() {
        #expect(MaintenanceEngine.oilDueSoon(kmSinceLastOil: 5_000))
    }

    @Test func nearestVisit_whenOdometer13600_returns17000Interval() {
        let visits = [
            VisitSnapshot(
                id: "visit-11000",
                kind: .regular,
                sortOrder: 11_000,
                targetOdometerKm: 11_000,
                includesOilChange: true,
                isCompleted: true,
                completedOdometer: 11_000,
                windowFromKm: nil,
                windowToKm: nil
            ),
            VisitSnapshot(
                id: "visit-17000",
                kind: .regular,
                sortOrder: 17_000,
                targetOdometerKm: 17_000,
                includesOilChange: true,
                isCompleted: false,
                completedOdometer: nil,
                windowFromKm: 16_000,
                windowToKm: 18_000
            ),
            VisitSnapshot(
                id: "visit-24000",
                kind: .regular,
                sortOrder: 24_000,
                targetOdometerKm: 24_000,
                includesOilChange: true,
                isCompleted: false,
                completedOdometer: nil,
                windowFromKm: 23_000,
                windowToKm: 25_000
            ),
        ]
        let nearest = MaintenanceEngine.nearestVisit(visits: visits, odometer: 13_600)
        #expect(nearest?.id == "visit-17000")
    }

    @Test func canCompleteVisit_whenMandatoryDone_isTrue() {
        let tasks = [
            TaskSnapshot(isMandatory: true, isApplicable: true, isEnabled: true, isDone: true),
            TaskSnapshot(isMandatory: false, isApplicable: true, isEnabled: true, isDone: false),
        ]
        #expect(MaintenanceEngine.canCompleteVisit(tasks: tasks))
    }

    @Test func canCompleteVisit_whenMandatoryUndone_isFalse() {
        let tasks = [
            TaskSnapshot(isMandatory: true, isApplicable: true, isEnabled: true, isDone: false),
            TaskSnapshot(isMandatory: false, isApplicable: true, isEnabled: true, isDone: true),
        ]
        #expect(!MaintenanceEngine.canCompleteVisit(tasks: tasks))
    }

    @Test func lastCompletedVisit_returnsHighestSortOrderAmongCompleted() {
        let visits = [
            VisitSnapshot(
                id: "visit-6000",
                kind: .regular,
                sortOrder: 6_000,
                targetOdometerKm: 6_000,
                includesOilChange: true,
                isCompleted: true,
                completedOdometer: 6_000,
                windowFromKm: nil,
                windowToKm: nil
            ),
            VisitSnapshot(
                id: "visit-11000",
                kind: .regular,
                sortOrder: 11_000,
                targetOdometerKm: 11_000,
                includesOilChange: true,
                isCompleted: true,
                completedOdometer: 11_000,
                windowFromKm: nil,
                windowToKm: nil
            ),
            VisitSnapshot(
                id: "visit-17000",
                kind: .regular,
                sortOrder: 17_000,
                targetOdometerKm: 17_000,
                includesOilChange: true,
                isCompleted: false,
                completedOdometer: nil,
                windowFromKm: 16_000,
                windowToKm: 18_000
            ),
        ]
        #expect(MaintenanceEngine.lastCompletedVisit(visits: visits)?.id == "visit-11000")
    }

    @Test func insuranceExpiringSoon_whenWithin30Days_isTrue() {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let validUntil = Calendar.current.date(byAdding: .day, value: 20, to: reference)!
        #expect(MaintenanceEngine.insuranceExpiringSoon(validUntil: validUntil, from: reference))
    }

    @Test func insuranceExpiringSoon_whenMoreThan30Days_isFalse() {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let validUntil = Calendar.current.date(byAdding: .day, value: 90, to: reference)!
        #expect(!MaintenanceEngine.insuranceExpiringSoon(validUntil: validUntil, from: reference))
    }

    @Test func serviceEstimateSoon_whenWithin30Days_isTrue() {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let estimated = Calendar.current.date(byAdding: .day, value: 14, to: reference)!
        #expect(MaintenanceEngine.serviceEstimateSoon(estimatedDate: estimated, from: reference))
    }
    @Test func estimatedDate_when2400KmRemaining_usesAverageMonthly() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = DateComponents(calendar: calendar, year: 2026, month: 6, day: 6, hour: 12).date!
        let estimated = MaintenanceEngine.estimatedDate(
            targetOdometerKm: 16_000,
            currentOdometerKm: 13_600,
            averageMonthlyKm: 563,
            from: reference,
            calendar: calendar
        )
        let expected = calendar.date(byAdding: .day, value: 128, to: calendar.startOfDay(for: reference))
        #expect(estimated == expected)
    }

    @Test func estimatedMonths_when6000Remaining_isAbout11() {
        #expect(MaintenanceEngine.estimatedMonths(kmRemaining: 6000, averageMonthlyKm: 563) == 11)
    }

    @Test func canCompleteVisitAtOdometer_when13600On16000Window_isFalse() {
        let visit = VisitSnapshot(
            id: "visit-17000",
            kind: .regular,
            sortOrder: 17_000,
            targetOdometerKm: 17_000,
            includesOilChange: true,
            isCompleted: false,
            completedOdometer: nil,
            windowFromKm: 16_000,
            windowToKm: 18_000
        )
        #expect(!MaintenanceEngine.canCompleteVisitAtOdometer(visit: visit, odometer: 13_600))
        #expect(MaintenanceEngine.canCompleteVisitAtOdometer(visit: visit, odometer: 16_000))
    }

    @Test func lastOilChangeOdometer_ignoresNonOilAndIncomplete() {
        let visits = [
            VisitSnapshot(
                id: "a",
                kind: .regular,
                sortOrder: 1,
                targetOdometerKm: 3_000,
                includesOilChange: false,
                isCompleted: true,
                completedOdometer: 3_000,
                windowFromKm: nil,
                windowToKm: nil
            ),
            VisitSnapshot(
                id: "b",
                kind: .regular,
                sortOrder: 2,
                targetOdometerKm: 11_000,
                includesOilChange: true,
                isCompleted: false,
                completedOdometer: nil,
                windowFromKm: nil,
                windowToKm: nil
            ),
            VisitSnapshot(
                id: "c",
                kind: .regular,
                sortOrder: 3,
                targetOdometerKm: 11_000,
                includesOilChange: true,
                isCompleted: true,
                completedOdometer: 11_000,
                windowFromKm: nil,
                windowToKm: nil
            ),
        ]
        #expect(MaintenanceEngine.lastOilChangeOdometer(visits: visits) == 11_000)
    }

    @Test func oilDueSoon_thresholdBoundary() {
        #expect(!MaintenanceEngine.oilDueSoon(kmSinceLastOil: 4_999))
        #expect(MaintenanceEngine.oilDueSoon(kmSinceLastOil: 5_000))
    }

    @Test func nearestVisit_whenAllCompleted_returnsNil() {
        let visits = [
            VisitSnapshot(
                id: "done",
                kind: .regular,
                sortOrder: 1,
                targetOdometerKm: 6_000,
                includesOilChange: true,
                isCompleted: true,
                completedOdometer: 6_000,
                windowFromKm: nil,
                windowToKm: nil
            ),
        ]
        #expect(MaintenanceEngine.nearestVisit(visits: visits, odometer: 13_600) == nil)
    }

    @Test func nearestVisit_whenPastAllTargets_returnsLastPending() {
        let visits = [
            VisitSnapshot(
                id: "late",
                kind: .regular,
                sortOrder: 17_000,
                targetOdometerKm: 17_000,
                includesOilChange: true,
                isCompleted: false,
                completedOdometer: nil,
                windowFromKm: 16_000,
                windowToKm: 18_000
            ),
            VisitSnapshot(
                id: "later",
                kind: .regular,
                sortOrder: 24_000,
                targetOdometerKm: 24_000,
                includesOilChange: true,
                isCompleted: false,
                completedOdometer: nil,
                windowFromKm: 23_000,
                windowToKm: 25_000
            ),
        ]
        #expect(MaintenanceEngine.nearestVisit(visits: visits, odometer: 30_000)?.id == "later")
    }

    @Test func kmRemaining_neverNegative() {
        let visit = VisitSnapshot(
            id: "v",
            kind: .regular,
            sortOrder: 1,
            targetOdometerKm: 17_000,
            includesOilChange: true,
            isCompleted: false,
            completedOdometer: nil,
            windowFromKm: nil,
            windowToKm: nil
        )
        #expect(MaintenanceEngine.kmRemaining(visit: visit, odometer: 20_000) == 0)
    }

    @Test func estimatedDate_whenAtTarget_returnsReference() {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let estimated = MaintenanceEngine.estimatedDate(
            targetOdometerKm: 17_000,
            currentOdometerKm: 17_000,
            averageMonthlyKm: 563,
            from: reference
        )
        #expect(estimated == reference)
    }

    @Test func estimatedDate_whenAverageZero_returnsNil() {
        #expect(
            MaintenanceEngine.estimatedDate(
                targetOdometerKm: 20_000,
                currentOdometerKm: 13_600,
                averageMonthlyKm: 0
            ) == nil
        )
    }

    @Test func estimatedDays_whenNoRemainingKm_isZero() {
        #expect(MaintenanceEngine.estimatedDays(kmRemaining: 0, averageMonthlyKm: 563) == 0)
        #expect(MaintenanceEngine.estimatedDays(kmRemaining: 100, averageMonthlyKm: 0) == 0)
    }

    @Test func isInServiceWindow_respectsBounds() {
        let visit = VisitSnapshot(
            id: "v",
            kind: .regular,
            sortOrder: 1,
            targetOdometerKm: 17_000,
            includesOilChange: true,
            isCompleted: false,
            completedOdometer: nil,
            windowFromKm: 16_000,
            windowToKm: 18_000
        )
        #expect(!MaintenanceEngine.isInServiceWindow(visit: visit, odometer: 15_999))
        #expect(MaintenanceEngine.isInServiceWindow(visit: visit, odometer: 17_000))
        #expect(!MaintenanceEngine.isInServiceWindow(visit: visit, odometer: 18_001))
    }

    @Test func isInServiceWindow_withoutWindow_isFalse() {
        let visit = VisitSnapshot(
            id: "v",
            kind: .regular,
            sortOrder: 1,
            targetOdometerKm: 17_000,
            includesOilChange: true,
            isCompleted: false,
            completedOdometer: nil,
            windowFromKm: nil,
            windowToKm: nil
        )
        #expect(!MaintenanceEngine.isInServiceWindow(visit: visit, odometer: 17_000))
    }

    @Test func isPrematureVisitCompletion_usesWindowStart() {
        #expect(
            MaintenanceEngine.isPrematureVisitCompletion(
                targetOdometerKm: 17_000,
                windowFromKm: 16_000,
                completedOdometer: 15_500
            )
        )
        #expect(
            !MaintenanceEngine.isPrematureVisitCompletion(
                targetOdometerKm: 17_000,
                windowFromKm: 16_000,
                completedOdometer: 16_000
            )
        )
        #expect(
            !MaintenanceEngine.isPrematureVisitCompletion(
                targetOdometerKm: 17_000,
                windowFromKm: nil,
                completedOdometer: 17_000
            )
        )
    }

    @Test func daysUntil_pastDate_isNegative() {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let past = Calendar.current.date(byAdding: .day, value: -5, to: reference)!
        #expect(MaintenanceEngine.daysUntil(past, from: reference) == -5)
    }

    @Test func insuranceExpiringSoon_whenExpired_isFalse() {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let expired = Calendar.current.date(byAdding: .day, value: -1, to: reference)!
        #expect(!MaintenanceEngine.insuranceExpiringSoon(validUntil: expired, from: reference))
    }

    @Test func serviceEstimateSoon_whenBeyond30Days_isFalse() {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let far = Calendar.current.date(byAdding: .day, value: 45, to: reference)!
        #expect(!MaintenanceEngine.serviceEstimateSoon(estimatedDate: far, from: reference))
    }

    @Test func canCompleteVisit_ignoresDisabledAndNonApplicableMandatory() {
        let tasks = [
            TaskSnapshot(isMandatory: true, isApplicable: false, isEnabled: true, isDone: false),
            TaskSnapshot(isMandatory: true, isApplicable: true, isEnabled: false, isDone: false),
            TaskSnapshot(isMandatory: false, isApplicable: true, isEnabled: true, isDone: false),
        ]
        #expect(MaintenanceEngine.canCompleteVisit(tasks: tasks))
    }

    @Test func minimumCompletionOdometerKm_prefersWindowStart() {
        #expect(MaintenanceEngine.minimumCompletionOdometerKm(windowFromKm: 16_000, targetOdometerKm: 17_000) == 16_000)
        #expect(MaintenanceEngine.minimumCompletionOdometerKm(windowFromKm: nil, targetOdometerKm: 17_000) == 17_000)
    }

    @Test func canCompleteVisitAtOdometer_withoutWindow_usesTarget() {
        let visit = VisitSnapshot(
            id: "v",
            kind: .regular,
            sortOrder: 1,
            targetOdometerKm: 17_000,
            includesOilChange: true,
            isCompleted: false,
            completedOdometer: nil,
            windowFromKm: nil,
            windowToKm: nil
        )
        #expect(!MaintenanceEngine.canCompleteVisitAtOdometer(visit: visit, odometer: 16_999))
        #expect(MaintenanceEngine.canCompleteVisitAtOdometer(visit: visit, odometer: 17_000))
    }

    @Test func daysUntil_futureDate_isPositive() {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let future = Calendar.current.date(byAdding: .day, value: 12, to: reference)!
        #expect(MaintenanceEngine.daysUntil(future, from: reference) == 12)
    }

    @Test func insuranceExpiringSoon_exactly30Days_isTrue() {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let validUntil = Calendar.current.date(byAdding: .day, value: 30, to: reference)!
        #expect(MaintenanceEngine.insuranceExpiringSoon(validUntil: validUntil, from: reference))
    }

    @Test func serviceEstimateSoon_whenExpired_isFalse() {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let past = Calendar.current.date(byAdding: .day, value: -1, to: reference)!
        #expect(!MaintenanceEngine.serviceEstimateSoon(estimatedDate: past, from: reference))
    }

    @Test func serviceEstimateSoon_exactly30Days_isTrue() {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let estimated = Calendar.current.date(byAdding: .day, value: 30, to: reference)!
        #expect(MaintenanceEngine.serviceEstimateSoon(estimatedDate: estimated, from: reference))
    }

    @Test func lastOilChangeOdometer_whenNoCompletedOilVisits_returnsNil() {
        let visits = [
            VisitSnapshot(
                id: "a",
                kind: .regular,
                sortOrder: 1,
                targetOdometerKm: 6_000,
                includesOilChange: true,
                isCompleted: false,
                completedOdometer: nil,
                windowFromKm: nil,
                windowToKm: nil
            ),
        ]
        #expect(MaintenanceEngine.lastOilChangeOdometer(visits: visits) == nil)
    }

    @Test func lastCompletedVisit_whenNoneCompleted_returnsNil() {
        let visits = [
            VisitSnapshot(
                id: "pending",
                kind: .regular,
                sortOrder: 1,
                targetOdometerKm: 17_000,
                includesOilChange: true,
                isCompleted: false,
                completedOdometer: nil,
                windowFromKm: nil,
                windowToKm: nil
            ),
        ]
        #expect(MaintenanceEngine.lastCompletedVisit(visits: visits) == nil)
    }

    @Test func estimatedMonths_whenAverageZero_isZero() {
        #expect(MaintenanceEngine.estimatedMonths(kmRemaining: 6_000, averageMonthlyKm: 0) == 0)
    }

    @Test func kmRemaining_whenBelowTarget_returnsDifference() {
        let visit = VisitSnapshot(
            id: "v",
            kind: .regular,
            sortOrder: 1,
            targetOdometerKm: 17_000,
            includesOilChange: true,
            isCompleted: false,
            completedOdometer: nil,
            windowFromKm: nil,
            windowToKm: nil
        )
        #expect(MaintenanceEngine.kmRemaining(visit: visit, odometer: 13_600) == 3_400)
    }
}

@Suite("ServiceVisitCompletion")
struct ServiceVisitCompletionTests {
    @Test func markTaskUndone_onCompletedVisit_reopensVisit() throws {
        let container = try AppModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        try PlanSeedImporter.importIfNeeded(into: context)
        let visit = try context.fetch(FetchDescriptor<ServiceVisitEntity>()).first { $0.isCompleted }!
        let task = visit.tasks.first { $0.isDone }!
        ServiceVisitCompletion.markTaskUndone(task, visit: visit)
        #expect(visit.isCompleted == false)
        #expect(visit.completedAt == nil)
        #expect(task.isDone == false)
    }

    @Test func completeVisit_marksMandatoryApplicableTasksDone() throws {
        let container = try AppModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        try PlanSeedImporter.importIfNeeded(into: context)
        let visit = try context.fetch(FetchDescriptor<ServiceVisitEntity>()).first { $0.seedId == "visit-17000" }!
        let completedAt = Date(timeIntervalSince1970: 1_750_000_000)
        ServiceVisitCompletion.completeVisit(visit, completedAt: completedAt, completedOdometer: 17_000)
        #expect(visit.isCompleted)
        #expect(visit.completedOdometer == 17_000)
        let mandatory = visit.tasks.filter { $0.isMandatory && $0.isApplicable }
        #expect(!mandatory.isEmpty)
        #expect(mandatory.allSatisfy { $0.isDone })
        #expect(mandatory.allSatisfy { $0.doneOdometer == 17_000 })
    }

    @Test func reopenVisit_clearsCompletionAndTaskFlags() throws {
        let container = try AppModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        try PlanSeedImporter.importIfNeeded(into: context)
        let visit = try context.fetch(FetchDescriptor<ServiceVisitEntity>()).first { $0.seedId == "visit-11000" }!
        #expect(visit.isCompleted)
        ServiceVisitCompletion.reopenVisit(visit)
        #expect(!visit.isCompleted)
        #expect(visit.completedAt == nil)
        #expect(visit.completedOdometer == nil)
        #expect(visit.tasks.filter(\.isApplicable).allSatisfy { !$0.isDone })
    }

    @Test func markTaskDone_setsDoneFlags() throws {
        let container = try AppModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        try PlanSeedImporter.importIfNeeded(into: context)
        let visit = try context.fetch(FetchDescriptor<ServiceVisitEntity>()).first { $0.seedId == "visit-17000" }!
        let task = visit.tasks.first { !$0.isDone && $0.isApplicable }!
        ServiceVisitCompletion.markTaskDone(task, visit: visit, odometerKm: 16_500)
        #expect(task.isDone)
        #expect(task.doneOdometer == 16_500)
        #expect(task.doneAt != nil)
        #expect(!visit.isCompleted)
    }
}

@Suite("NotificationPlanBuilder")
struct NotificationPlanBuilderTests {
    @Test func groupedTopics_groupsOilAndSeasonalSeparately() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = DateComponents(calendar: calendar, year: 2026, month: 6, day: 6, hour: 12).date!
        let validUntil = DateComponents(calendar: calendar, year: 2027, month: 5, day: 30).date!
        let plan = NotificationPlanBuilder.build(
            NotificationPlanInput(
                serviceRemindersEnabled: true,
                insuranceRemindersEnabled: true,
                monthlyOdometerReminderEnabled: true,
                odometerKm: 13_600,
                averageMonthlyMileageKm: 563,
                lastOilOdometer: 11_000,
                insuranceValidUntil: validUntil,
                referenceDate: reference,
                calendar: calendar
            )
        )
        let groups = NotificationReminderGrouper.groups(from: plan)
        #expect(groups.contains { $0.topic == .oilChange && $0.items.count >= 2 })
        #expect(groups.contains { $0.topic == .seasonalTires && $0.items.count == 2 })
        #expect(groups.contains { $0.topic == .insurance })
        #expect(!groups.contains { $0.topic == .oilChange && $0.items.contains { $0.category == .seasonalSpring } })
    }

    @Test func build_whenAllEnabled_includesOdometerAndInsurance() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = DateComponents(calendar: calendar, year: 2026, month: 6, day: 6, hour: 12).date!
        let validUntil = DateComponents(calendar: calendar, year: 2027, month: 5, day: 30).date!
        let plan = NotificationPlanBuilder.build(
            NotificationPlanInput(
                serviceRemindersEnabled: true,
                insuranceRemindersEnabled: true,
                monthlyOdometerReminderEnabled: true,
                odometerKm: 13_600,
                averageMonthlyMileageKm: 563,
                lastOilOdometer: 11_000,
                insuranceValidUntil: validUntil,
                referenceDate: reference,
                calendar: calendar
            )
        )
        #expect(plan.contains { $0.id == "monthly.odometer" })
        #expect(plan.contains { $0.id == "seasonal.spring" })
        #expect(plan.contains { $0.id == "oil.due" })
        #expect(plan.contains { $0.id == "oil.window.end" })
        #expect(plan.contains { $0.id == "plan.20000" })
        #expect(plan.contains { $0.id == "oil.plan.30" })
        #expect(plan.contains { $0.category == .insurance30 })
    }

    @Test func build_whenOdometerIncreases_oilDueMovesEarlier() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = DateComponents(calendar: calendar, year: 2026, month: 6, day: 6, hour: 12).date!
        let input = { (odometerKm: Int) in
            NotificationPlanInput(
                serviceRemindersEnabled: true,
                insuranceRemindersEnabled: false,
                monthlyOdometerReminderEnabled: false,
                odometerKm: odometerKm,
                averageMonthlyMileageKm: 563,
                lastOilOdometer: 11_000,
                insuranceValidUntil: nil,
                referenceDate: reference,
                calendar: calendar
            )
        }
        let lowerPlan = NotificationPlanBuilder.build(input(13_600))
        let higherPlan = NotificationPlanBuilder.build(input(15_000))
        let lowerOilDue = lowerPlan.first { $0.id == "oil.due" }?.fireDate
        let higherOilDue = higherPlan.first { $0.id == "oil.due" }?.fireDate
        #expect(lowerOilDue != nil)
        #expect(higherOilDue != nil)
        #expect(higherOilDue! < lowerOilDue!)
    }

    @Test func build_whenBelowOilWindow_schedulesEstimatedMileageReminders() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = DateComponents(calendar: calendar, year: 2026, month: 6, day: 6, hour: 12).date!
        let plan = NotificationPlanBuilder.build(
            NotificationPlanInput(
                serviceRemindersEnabled: true,
                insuranceRemindersEnabled: false,
                monthlyOdometerReminderEnabled: false,
                odometerKm: 13_600,
                averageMonthlyMileageKm: 563,
                lastOilOdometer: 11_000,
                insuranceValidUntil: nil,
                referenceDate: reference,
                calendar: calendar
            )
        )
        let oilDue = plan.first { $0.id == "oil.due" }
        #expect(oilDue?.relatedOdometerKm == 16_000)
        #expect((oilDue?.fireDate ?? reference) > reference)
    }

    @Test func build_whenOilWindowOpen_schedulesImmediateOilDue() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = DateComponents(calendar: calendar, year: 2026, month: 6, day: 6, hour: 12).date!
        let plan = NotificationPlanBuilder.build(
            NotificationPlanInput(
                serviceRemindersEnabled: true,
                insuranceRemindersEnabled: false,
                monthlyOdometerReminderEnabled: false,
                odometerKm: 16_200,
                averageMonthlyMileageKm: 563,
                lastOilOdometer: 11_000,
                insuranceValidUntil: nil,
                referenceDate: reference,
                calendar: calendar
            )
        )
        let oilDue = plan.first { $0.id == "oil.due" }
        #expect(oilDue != nil)
        #expect(oilDue?.fireDate == NotificationPlanBuilderTests.nextFireDate(from: reference, calendar: calendar))
    }

    @Test func build_whenAt20000_omitsPlanAndEstimateReminders() {
        let plan = NotificationPlanBuilder.build(
            NotificationPlanInput(
                serviceRemindersEnabled: true,
                insuranceRemindersEnabled: false,
                monthlyOdometerReminderEnabled: false,
                odometerKm: 20_100,
                averageMonthlyMileageKm: 563,
                lastOilOdometer: 11_000,
                insuranceValidUntil: nil,
                referenceDate: Date(),
                calendar: Calendar.current
            )
        )
        #expect(!plan.contains { $0.id == "plan.20000" })
        #expect(!plan.contains { $0.id == "oil.plan.30" })
    }

    static func nextFireDate(from reference: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: reference)
        components.hour = 9
        components.minute = 0
        let today = calendar.date(from: components) ?? reference
        if today > reference {
            return today
        }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? reference.addingTimeInterval(86_400)
    }

    @Test func build_whenAllDisabled_returnsEmpty() {
        let plan = NotificationPlanBuilder.build(
            NotificationPlanInput(
                serviceRemindersEnabled: false,
                insuranceRemindersEnabled: false,
                monthlyOdometerReminderEnabled: false,
                odometerKm: 13_600,
                averageMonthlyMileageKm: 563,
                lastOilOdometer: 11_000,
                insuranceValidUntil: Date(),
                referenceDate: Date(),
                calendar: Calendar.current
            )
        )
        #expect(plan.isEmpty)
    }

    @Test func groupedTopics_coversAllFiveTopics() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = DateComponents(calendar: calendar, year: 2026, month: 6, day: 6, hour: 12).date!
        let validUntil = DateComponents(calendar: calendar, year: 2027, month: 5, day: 30).date!
        let plan = NotificationPlanBuilder.build(
            NotificationPlanInput(
                serviceRemindersEnabled: true,
                insuranceRemindersEnabled: true,
                monthlyOdometerReminderEnabled: true,
                odometerKm: 13_600,
                averageMonthlyMileageKm: 563,
                lastOilOdometer: 11_000,
                insuranceValidUntil: validUntil,
                referenceDate: reference,
                calendar: calendar
            )
        )
        let topics = Set(NotificationReminderGrouper.groups(from: plan).map(\.topic))
        #expect(topics == Set(NotificationReminderTopic.allCases))
    }

    @Test func navigationDestination_mapsEveryCategory() {
        for category in NotificationCategory.allCases {
            let destination = category.navigationDestination
            switch category {
            case .monthlyOdometer:
                #expect(destination == .reminderTopic(.odometer))
            case .oilDue, .oilWindowEnd, .oilPlan30, .oilPlan7, .oilPlan1:
                #expect(destination == .reminderTopic(.oilChange))
            case .plan20000, .plan22000:
                #expect(destination == .reminderTopic(.maintenancePlan))
            case .seasonalSpring, .seasonalAutumn:
                #expect(destination == .reminderTopic(.seasonalTires))
            case .insurance30, .insurance7, .insurance1:
                #expect(destination == .reminderTopic(.insurance))
            }
        }
    }

    @Test func pushCopy_isNonEmptyForAllCategories() {
        let fireDate = Date(timeIntervalSince1970: 1_800_000_000)
        for category in NotificationCategory.allCases {
            #expect(!category.pushTitle(relatedOdometerKm: 20_000).isEmpty)
            #expect(!category.pushBody(fireDate: fireDate, relatedDate: fireDate, relatedOdometerKm: 20_000).isEmpty)
            #expect(!category.scheduleMomentLabel(relatedOdometerKm: 20_000).isEmpty)
        }
    }

    @Test func build_whenOilBelowThreshold_omitsOilDue() {
        let plan = NotificationPlanBuilder.build(
            NotificationPlanInput(
                serviceRemindersEnabled: true,
                insuranceRemindersEnabled: false,
                monthlyOdometerReminderEnabled: false,
                odometerKm: 13_600,
                averageMonthlyMileageKm: 563,
                lastOilOdometer: nil,
                insuranceValidUntil: nil,
                referenceDate: Date(),
                calendar: Calendar.current
            )
        )
        #expect(!plan.contains { $0.id == "oil.due" })
    }

    @Test func build_whenOnlyInsuranceEnabled_includesInsuranceOnly() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = DateComponents(calendar: calendar, year: 2026, month: 6, day: 6, hour: 12).date!
        let validUntil = DateComponents(calendar: calendar, year: 2027, month: 5, day: 30).date!
        let plan = NotificationPlanBuilder.build(
            NotificationPlanInput(
                serviceRemindersEnabled: false,
                insuranceRemindersEnabled: true,
                monthlyOdometerReminderEnabled: false,
                odometerKm: 13_600,
                averageMonthlyMileageKm: 563,
                lastOilOdometer: 11_000,
                insuranceValidUntil: validUntil,
                referenceDate: reference,
                calendar: calendar
            )
        )
        #expect(plan.allSatisfy { $0.category == .insurance30 || $0.category == .insurance7 || $0.category == .insurance1 })
        #expect(plan.count == 3)
    }

    @Test func build_whenServiceDisabled_omitsOilAndSeasonal() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = DateComponents(calendar: calendar, year: 2026, month: 6, day: 6, hour: 12).date!
        let plan = NotificationPlanBuilder.build(
            NotificationPlanInput(
                serviceRemindersEnabled: false,
                insuranceRemindersEnabled: false,
                monthlyOdometerReminderEnabled: true,
                odometerKm: 13_600,
                averageMonthlyMileageKm: 563,
                lastOilOdometer: 11_000,
                insuranceValidUntil: nil,
                referenceDate: reference,
                calendar: calendar
            )
        )
        #expect(plan.count == 1)
        #expect(plan.first?.id == "monthly.odometer")
        #expect(plan.first?.repeats == true)
    }

    @Test func groupedTopics_monthlyOdometer_repeatsAnnuallyOrMonthly() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = DateComponents(calendar: calendar, year: 2026, month: 6, day: 6, hour: 12).date!
        let plan = NotificationPlanBuilder.build(
            NotificationPlanInput(
                serviceRemindersEnabled: false,
                insuranceRemindersEnabled: false,
                monthlyOdometerReminderEnabled: true,
                odometerKm: 13_600,
                averageMonthlyMileageKm: 563,
                lastOilOdometer: nil,
                insuranceValidUntil: nil,
                referenceDate: reference,
                calendar: calendar
            )
        )
        let group = NotificationReminderGrouper.groups(from: plan).first { $0.topic == .odometer }
        #expect(group?.repeatsAnnuallyOrMonthly == true)
    }
}

@Suite("UpgradeTotals")
struct UpgradeTotalsTests {
    @Test func sortedPlanned_ordersByPriority() {
        let items = [
            UpgradeItemSnapshot(id: "1", title: "C", status: .planned, completedDate: nil, priority: 3),
            UpgradeItemSnapshot(id: "2", title: "A", status: .planned, completedDate: nil, priority: 1),
            UpgradeItemSnapshot(id: "3", title: "B", status: .planned, completedDate: nil, priority: 2),
            UpgradeItemSnapshot(id: "4", title: "Done", status: .done, completedDate: nil, priority: nil),
        ]
        let planned = UpgradeTotals.sortedPlanned(items)
        #expect(planned.map(\.id) == ["2", "3", "1"])
    }

    @Test func sortedPlanned_emptyInput_returnsEmpty() {
        #expect(UpgradeTotals.sortedPlanned([]).isEmpty)
    }

    @Test func sortedDone_nilCompletedDate_sortsLast() {
        let items = [
            UpgradeItemSnapshot(id: "1", title: "No date", status: .done, completedDate: nil, priority: nil),
            UpgradeItemSnapshot(id: "2", title: "Dated", status: .done, completedDate: Date(timeIntervalSince1970: 1_700_000_000), priority: nil),
        ]
        #expect(UpgradeTotals.sortedDone(items).map(\.id) == ["2", "1"])
    }

    @Test func sortedDone_ordersByCompletedDate() {
        let early = Date(timeIntervalSince1970: 1_700_000_000)
        let late = Date(timeIntervalSince1970: 1_800_000_000)
        let items = [
            UpgradeItemSnapshot(id: "1", title: "Late", status: .done, completedDate: late, priority: nil),
            UpgradeItemSnapshot(id: "2", title: "Early", status: .done, completedDate: early, priority: nil),
            UpgradeItemSnapshot(id: "3", title: "Planned", status: .planned, completedDate: nil, priority: 1),
        ]
        let done = UpgradeTotals.sortedDone(items)
        #expect(done.map(\.id) == ["2", "1"])
    }
}

@Suite("PlanSeedImporter")
struct PlanSeedImporterTests {
    @Test func importIfNeeded_isIdempotent() throws {
        let container = try AppModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        try PlanSeedImporter.importIfNeeded(into: context)
        try PlanSeedImporter.importIfNeeded(into: context)
        let vehicles = try context.fetch(FetchDescriptor<VehicleConfig>())
        #expect(vehicles.count == 1)
        let visits = try context.fetch(FetchDescriptor<ServiceVisitEntity>())
        #expect(visits.count == 15)
        let policies = try context.fetch(FetchDescriptor<InsurancePolicyEntity>())
        #expect(policies.count == 1)
        #expect(policies.first?.policyNumber == "238521403")
    }

    @Test func syncSeedCompletionState_repairsStaleIncompleteVisits() throws {
        let container = try AppModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        try PlanSeedImporter.importIfNeeded(into: context)

        let visit = try context.fetch(FetchDescriptor<ServiceVisitEntity>()).first { $0.seedId == "visit-11000" }!
        visit.isCompleted = false
        visit.completedAt = nil
        visit.completedOdometer = nil
        for task in visit.tasks {
            task.isDone = false
            task.doneAt = nil
            task.doneOdometer = nil
        }
        try context.save()

        try PlanSeedImporter.importIfNeeded(into: context)

        #expect(visit.isCompleted)
        #expect(visit.completedOdometer == 11_000)
        #expect(visit.tasks.filter(\.isApplicable).allSatisfy { $0.isDone })
    }

    @Test func syncSeedCompletionState_revertsPrematureVisitCompletion() throws {
        let container = try AppModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        try PlanSeedImporter.importIfNeeded(into: context)

        let visit = try context.fetch(FetchDescriptor<ServiceVisitEntity>()).first { $0.seedId == "visit-17000" }!
        ServiceVisitCompletion.completeVisit(visit, completedAt: Date(), completedOdometer: 13_600)
        try context.save()
        #expect(visit.isCompleted)

        try PlanSeedImporter.importIfNeeded(into: context)

        #expect(!visit.isCompleted)
        #expect(visit.completedOdometer == nil)
    }

    @Test func odometerUpdate_persistsAfterSave() throws {
        let container = try AppModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        try PlanSeedImporter.importIfNeeded(into: context)

        let vehicle = try context.fetch(FetchDescriptor<VehicleConfig>()).first!
        #expect(vehicle.odometerKm == 13_600)

        let updatedAt = Date(timeIntervalSince1970: 1_734_000_000)
        vehicle.odometerKm = 14_200
        vehicle.odometerUpdatedAt = updatedAt
        try context.save()

        let reloadContext = ModelContext(container)
        let reloaded = try reloadContext.fetch(FetchDescriptor<VehicleConfig>()).first!
        #expect(reloaded.odometerKm == 14_200)
        #expect(reloaded.odometerUpdatedAt == updatedAt)

        try PlanSeedImporter.importIfNeeded(into: reloadContext)
        let afterSync = try reloadContext.fetch(FetchDescriptor<VehicleConfig>()).first!
        #expect(afterSync.odometerKm == 14_200)
    }

    @Test func seedTasks_mapToLocalizedKeys() throws {
        let container = try AppModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        try PlanSeedImporter.importIfNeeded(into: context)
        let tasks = try context.fetch(FetchDescriptor<ServiceTaskEntity>())
        #expect(!tasks.isEmpty)
        for task in tasks where !task.isUserAdded {
            #expect(task.localizedTitleKey != nil)
            #expect(task.localizedTitleKey?.hasPrefix("service.task.") == true)
        }
    }

    @Test func userAddedTask_hasNoLocalizedKey() {
        let task = ServiceTaskEntity(
            seedId: "custom-1",
            title: "Custom work",
            sortOrder: 1,
            isMandatory: false,
            isApplicable: true,
            isEnabled: true,
            isDone: false,
            isUserAdded: true
        )
        #expect(task.localizedTitleKey == nil)
    }
}

@Suite("NotificationPayload")
struct NotificationPayloadTests {
    @Test func roundTrip_allDestinationKinds() {
        let destinations: [AppDestination] = [
            .reminderTopic(.odometer),
            .reminderTopic(.oilChange),
            .reminderTopic(.maintenancePlan),
            .reminderTopic(.seasonalTires),
            .reminderTopic(.insurance),
            .carWidget(.service),
            .carWidget(.serviceEstimate),
            .serviceVisit(seedId: "visit-17000"),
        ]
        for destination in destinations {
            let userInfo = NotificationPayload.userInfo(for: destination)
            let restored = NotificationPayload.destination(from: userInfo)
            #expect(restored == destination)
        }
    }

    @Test func destination_invalidPayload_returnsNil() {
        #expect(NotificationPayload.destination(from: [:]) == nil)
        #expect(NotificationPayload.destination(from: ["kind": "topic", "value": "unknown"]) == nil)
        #expect(NotificationPayload.destination(from: ["kind": "widget", "value": "unknown"]) == nil)
        #expect(NotificationPayload.destination(from: ["kind": "unknown", "value": "oil"]) == nil)
    }

    @Test func roundTrip_serviceVisit_preservesSeedId() {
        let destination = AppDestination.serviceVisit(seedId: "visit-24000")
        let restored = NotificationPayload.destination(from: NotificationPayload.userInfo(for: destination))
        #expect(restored == destination)
    }
}
