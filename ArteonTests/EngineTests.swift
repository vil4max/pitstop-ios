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
}

@Suite("NotificationPlanBuilder")
struct NotificationPlanBuilderTests {
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
}

@Suite("UpgradeTotals")
struct UpgradeTotalsTests {
    @Test func totalSpentUah_is83000() {
        let items = [
            UpgradeItemSnapshot(id: "1", title: "A", costUah: 11_000, currencyCode: "UAH", status: .done, completedDate: nil, priority: nil),
            UpgradeItemSnapshot(id: "2", title: "B", costUah: 7_000, currencyCode: "UAH", status: .done, completedDate: nil, priority: nil),
            UpgradeItemSnapshot(id: "3", title: "C", costUah: 25_000, currencyCode: "UAH", status: .done, completedDate: nil, priority: nil),
            UpgradeItemSnapshot(id: "4", title: "D", costUah: 40_000, currencyCode: "UAH", status: .done, completedDate: nil, priority: nil),
            UpgradeItemSnapshot(id: "5", title: "E", costUah: 500, currencyCode: "USD", status: .planned, completedDate: nil, priority: 1),
        ]
        #expect(UpgradeTotals.totalSpentUah(items: items) == 83_000)
        #expect(UpgradeTotals.totalPlannedUsd(items: items) == 500)
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
}
