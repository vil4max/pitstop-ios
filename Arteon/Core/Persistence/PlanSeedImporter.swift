import Foundation
import SwiftData

enum PlanSeedImporter {
    static func importIfNeeded(into context: ModelContext) throws {
        let plan = try BundleJSONLoader.load(MaintenancePlanDocument.self, resource: "maintenance-plan")
        let vehicles = try context.fetch(FetchDescriptor<VehicleConfig>())

        if vehicles.isEmpty {
            let upgrades = try BundleJSONLoader.load(UpgradesDocument.self, resource: "upgrades")
            let insurance = try BundleJSONLoader.load(InsuranceDocument.self, resource: "insurance")
            try performInitialImport(plan: plan, upgrades: upgrades, insurance: insurance, into: context)
            return
        }

        try syncSeedCompletionState(plan: plan, into: context)
        if let vehicle = vehicles.first {
            try syncPlanTemplate(plan: plan, vehicle: vehicle, into: context)
        }
    }

    private static func performInitialImport(
        plan: MaintenancePlanDocument,
        upgrades: UpgradesDocument,
        insurance: InsuranceDocument,
        into context: ModelContext
    ) throws {
        let now = Date()
        let vehicle = VehicleConfig(
            vin: plan.vehicle.vin,
            make: plan.vehicle.make,
            model: plan.vehicle.model,
            modelYear: plan.vehicle.modelYear,
            purchaseDate: SeedDateParser.date(from: plan.vehicle.purchaseDate) ?? now,
            engineLabel: plan.vehicle.engineLabel,
            odometerKm: plan.vehicle.odometerKm,
            odometerUpdatedAt: now,
            averageMonthlyMileageKm: plan.vehicle.averageMonthlyMileageKm,
            mileageBaselineKm: plan.vehicle.mileageBaselineKm,
            mileageBaselineMonths: plan.vehicle.mileageBaselineMonths,
            seedVersion: plan.schemaVersion
        )
        context.insert(vehicle)

        for visitDTO in plan.visits {
            insertVisit(from: visitDTO, into: context)
        }

        for item in upgrades.items {
            context.insert(
                UpgradeItemEntity(
                    seedId: item.id,
                    title: item.title,
                    costUah: item.costUah,
                    currencyCode: item.currencyCode ?? "UAH",
                    statusRaw: item.status.rawValue,
                    completedDate: item.completedDate.flatMap(SeedDateParser.date(from:)),
                    priority: item.priority,
                    sortOrder: item.sortOrder
                )
            )
        }

        context.insert(
            InsurancePolicyEntity(
                policyNumber: insurance.policyNumber,
                insurer: insurance.insurer,
                contractDate: SeedDateParser.date(from: insurance.contractDate) ?? now,
                validFrom: SeedDateParser.date(from: insurance.validFrom) ?? now,
                validUntil: SeedDateParser.date(from: insurance.validUntil) ?? now,
                premiumUah: insurance.premiumUah,
                plate: insurance.plate,
                verificationUrl: insurance.verificationUrl
            )
        )

        context.insert(
            AppSettingsEntity(
                serviceRemindersEnabled: true,
                insuranceRemindersEnabled: true,
                monthlyOdometerReminderEnabled: true
            )
        )
        try context.save()
    }

    private static func syncSeedCompletionState(plan: MaintenancePlanDocument, into context: ModelContext) throws {
        let visits = try context.fetch(FetchDescriptor<ServiceVisitEntity>())
        let visitsBySeedId = Dictionary(uniqueKeysWithValues: visits.map { ($0.seedId, $0) })
        var didChange = false

        for visitDTO in plan.visits where visitDTO.isCompleted {
            guard let visit = visitsBySeedId[visitDTO.id], !visit.isCompleted else { continue }
            applyCompletedVisit(from: visitDTO, to: visit)
            didChange = true
        }

        for visit in visits where visit.isCompleted {
            guard let completedOdometer = visit.completedOdometer else { continue }
            guard MaintenanceEngine.isPrematureVisitCompletion(
                targetOdometerKm: visit.targetOdometerKm,
                windowFromKm: visit.windowFromKm,
                completedOdometer: completedOdometer
            ) else { continue }
            ServiceVisitCompletion.reopenVisit(visit)
            didChange = true
        }

        if didChange {
            try context.save()
        }
    }

    private static func syncPlanTemplate(
        plan: MaintenancePlanDocument,
        vehicle: VehicleConfig,
        into context: ModelContext
    ) throws {
        guard vehicle.seedVersion < plan.schemaVersion else { return }

        let existing = try context.fetch(FetchDescriptor<ServiceVisitEntity>())
        for visit in existing where !visit.isCompleted {
            context.delete(visit)
        }

        let remainingIds = Set(
            try context.fetch(FetchDescriptor<ServiceVisitEntity>()).map(\.seedId)
        )
        for visitDTO in plan.visits where !visitDTO.isCompleted && !remainingIds.contains(visitDTO.id) {
            insertVisit(from: visitDTO, into: context)
        }

        vehicle.seedVersion = plan.schemaVersion
        try context.save()
    }

    private static func insertVisit(from visitDTO: VisitDTO, into context: ModelContext) {
        let completedAt = visitDTO.completedAt.flatMap(SeedDateParser.date(from:))
        let tasks = visitDTO.tasks.map { task in
            makeTaskEntity(from: task, visitDTO: visitDTO, completedAt: completedAt)
        }
        let visit = ServiceVisitEntity(
            seedId: visitDTO.id,
            title: visitDTO.title,
            kindRaw: visitDTO.kind.rawValue,
            sortOrder: visitDTO.sortOrder,
            targetOdometerKm: visitDTO.targetOdometerKm,
            serviceScope: visitDTO.serviceScope ?? "general",
            includesOilChange: visitDTO.includesOilChange,
            isCompleted: visitDTO.isCompleted,
            completedOdometer: visitDTO.completedOdometer,
            completedAt: completedAt,
            dealer: visitDTO.dealer,
            costUah: visitDTO.costUah,
            costProfile: visitDTO.costProfile,
            estimatedOilPortionUah: visitDTO.estimatedOilPortionUah,
            windowKm: visitDTO.windowKm,
            windowFromKm: visitDTO.windowFromKm,
            windowToKm: visitDTO.windowToKm,
            odometerIsEstimate: visitDTO.odometerIsEstimate ?? false,
            tasks: tasks
        )
        for task in tasks {
            task.visit = visit
        }
        context.insert(visit)
    }

    private static func applyCompletedVisit(from visitDTO: VisitDTO, to visit: ServiceVisitEntity) {
        let completedAt = visitDTO.completedAt.flatMap(SeedDateParser.date(from:))
        visit.isCompleted = true
        visit.completedAt = completedAt
        visit.completedOdometer = visitDTO.completedOdometer
        visit.dealer = visitDTO.dealer
        visit.costUah = visitDTO.costUah
        visit.costProfile = visitDTO.costProfile
        visit.estimatedOilPortionUah = visitDTO.estimatedOilPortionUah

        let taskDTOById = Dictionary(uniqueKeysWithValues: visitDTO.tasks.map { ($0.id, $0) })
        for task in visit.tasks {
            guard let taskDTO = taskDTOById[task.seedId] else { continue }
            let isDone = taskDTO.isDone || (visitDTO.isCompleted && task.isApplicable)
            guard isDone else { continue }
            task.isDone = true
            task.doneAt = task.doneAt ?? completedAt
            task.doneOdometer = task.doneOdometer ?? visitDTO.completedOdometer
        }
    }

    private static func makeTaskEntity(from task: TaskDTO, visitDTO: VisitDTO, completedAt: Date?) -> ServiceTaskEntity {
        let isDone = task.isDone || (visitDTO.isCompleted && task.isApplicable)
        return ServiceTaskEntity(
            seedId: task.id,
            title: task.title,
            sortOrder: task.sortOrder,
            isMandatory: task.isMandatory,
            isApplicable: task.isApplicable,
            isEnabled: true,
            isDone: isDone,
            doneAt: isDone ? completedAt : nil,
            doneOdometer: isDone ? visitDTO.completedOdometer : nil
        )
    }
}
