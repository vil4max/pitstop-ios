import Foundation
import SwiftData

@Model
final class VehicleConfig {
    var vin: String
    var make: String
    var model: String
    var modelYear: Int
    var purchaseDate: Date
    var engineLabel: String
    var odometerKm: Int
    var odometerUpdatedAt: Date
    var averageMonthlyMileageKm: Int
    var mileageBaselineKm: Int
    var mileageBaselineMonths: Int
    var seedVersion: Int
    @Attribute(.externalStorage) var photoData: Data?

    init(
        vin: String,
        make: String,
        model: String,
        modelYear: Int,
        purchaseDate: Date,
        engineLabel: String,
        odometerKm: Int,
        odometerUpdatedAt: Date,
        averageMonthlyMileageKm: Int,
        mileageBaselineKm: Int,
        mileageBaselineMonths: Int,
        seedVersion: Int,
        photoData: Data? = nil
    ) {
        self.vin = vin
        self.make = make
        self.model = model
        self.modelYear = modelYear
        self.purchaseDate = purchaseDate
        self.engineLabel = engineLabel
        self.odometerKm = odometerKm
        self.odometerUpdatedAt = odometerUpdatedAt
        self.averageMonthlyMileageKm = averageMonthlyMileageKm
        self.mileageBaselineKm = mileageBaselineKm
        self.mileageBaselineMonths = mileageBaselineMonths
        self.seedVersion = seedVersion
        self.photoData = photoData
    }
}

@Model
final class ServiceVisitEntity {
    var seedId: String
    var title: String
    var kindRaw: String
    var sortOrder: Int
    var targetOdometerKm: Int
    var serviceScope: String
    var includesOilChange: Bool
    var isCompleted: Bool
    var completedOdometer: Int?
    var completedAt: Date?
    var dealer: String?
    var costUah: Int?
    var costProfile: String?
    var estimatedOilPortionUah: Int?
    var windowKm: Int?
    var windowFromKm: Int?
    var windowToKm: Int?
    var odometerIsEstimate: Bool
    @Relationship(deleteRule: .cascade, inverse: \ServiceTaskEntity.visit) var tasks: [ServiceTaskEntity]

    init(
        seedId: String,
        title: String,
        kindRaw: String,
        sortOrder: Int,
        targetOdometerKm: Int,
        serviceScope: String,
        includesOilChange: Bool,
        isCompleted: Bool,
        completedOdometer: Int?,
        completedAt: Date?,
        dealer: String?,
        costUah: Int?,
        costProfile: String?,
        estimatedOilPortionUah: Int?,
        windowKm: Int?,
        windowFromKm: Int?,
        windowToKm: Int?,
        odometerIsEstimate: Bool,
        tasks: [ServiceTaskEntity] = []
    ) {
        self.seedId = seedId
        self.title = title
        self.kindRaw = kindRaw
        self.sortOrder = sortOrder
        self.targetOdometerKm = targetOdometerKm
        self.serviceScope = serviceScope
        self.includesOilChange = includesOilChange
        self.isCompleted = isCompleted
        self.completedOdometer = completedOdometer
        self.completedAt = completedAt
        self.dealer = dealer
        self.costUah = costUah
        self.costProfile = costProfile
        self.estimatedOilPortionUah = estimatedOilPortionUah
        self.windowKm = windowKm
        self.windowFromKm = windowFromKm
        self.windowToKm = windowToKm
        self.odometerIsEstimate = odometerIsEstimate
        self.tasks = tasks
    }

    var kind: VisitKind {
        VisitKind(rawValue: kindRaw) ?? .regular
    }
}

@Model
final class ServiceTaskEntity {
    var seedId: String
    var title: String
    var sortOrder: Int
    var isMandatory: Bool
    var isApplicable: Bool
    var isEnabled: Bool
    var isDone: Bool
    var doneAt: Date?
    var doneOdometer: Int?
    var isUserAdded: Bool
    var visit: ServiceVisitEntity?

    init(
        seedId: String,
        title: String,
        sortOrder: Int,
        isMandatory: Bool,
        isApplicable: Bool,
        isEnabled: Bool,
        isDone: Bool,
        doneAt: Date? = nil,
        doneOdometer: Int? = nil,
        isUserAdded: Bool = false,
        visit: ServiceVisitEntity? = nil
    ) {
        self.seedId = seedId
        self.title = title
        self.sortOrder = sortOrder
        self.isMandatory = isMandatory
        self.isApplicable = isApplicable
        self.isEnabled = isEnabled
        self.isDone = isDone
        self.doneAt = doneAt
        self.doneOdometer = doneOdometer
        self.isUserAdded = isUserAdded
        self.visit = visit
    }
}

@Model
final class UpgradeItemEntity {
    var seedId: String
    var title: String
    var costUah: Int
    var currencyCode: String
    var statusRaw: String
    var completedDate: Date?
    var priority: Int?
    var sortOrder: Int

    init(
        seedId: String,
        title: String,
        costUah: Int,
        currencyCode: String = "UAH",
        statusRaw: String,
        completedDate: Date?,
        priority: Int?,
        sortOrder: Int
    ) {
        self.seedId = seedId
        self.title = title
        self.costUah = costUah
        self.currencyCode = currencyCode
        self.statusRaw = statusRaw
        self.completedDate = completedDate
        self.priority = priority
        self.sortOrder = sortOrder
    }

    var status: UpgradeStatus {
        UpgradeStatus(rawValue: statusRaw) ?? .planned
    }
}

@Model
final class InsurancePolicyEntity {
    var policyNumber: String
    var insurer: String
    var contractDate: Date
    var validFrom: Date
    var validUntil: Date
    var premiumUah: Int
    var plate: String
    var verificationUrl: String

    init(
        policyNumber: String,
        insurer: String,
        contractDate: Date,
        validFrom: Date,
        validUntil: Date,
        premiumUah: Int,
        plate: String,
        verificationUrl: String
    ) {
        self.policyNumber = policyNumber
        self.insurer = insurer
        self.contractDate = contractDate
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.premiumUah = premiumUah
        self.plate = plate
        self.verificationUrl = verificationUrl
    }
}

enum AppThemeMode: String, Codable, CaseIterable {
    case system
    case light
    case dark
}

@Model
final class AppSettingsEntity {
    var themeRaw: String
    var serviceRemindersEnabled: Bool
    var insuranceRemindersEnabled: Bool
    var monthlyOdometerReminderEnabled: Bool

    init(
        themeRaw: String = AppThemeMode.system.rawValue,
        serviceRemindersEnabled: Bool = true,
        insuranceRemindersEnabled: Bool = true,
        monthlyOdometerReminderEnabled: Bool = true
    ) {
        self.themeRaw = themeRaw
        self.serviceRemindersEnabled = serviceRemindersEnabled
        self.insuranceRemindersEnabled = insuranceRemindersEnabled
        self.monthlyOdometerReminderEnabled = monthlyOdometerReminderEnabled
    }

    var theme: AppThemeMode {
        get { AppThemeMode(rawValue: themeRaw) ?? .system }
        set { themeRaw = newValue.rawValue }
    }
}

enum AppModelContainerFactory {
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            VehicleConfig.self,
            ServiceVisitEntity.self,
            ServiceTaskEntity.self,
            UpgradeItemEntity.self,
            InsurancePolicyEntity.self,
            AppSettingsEntity.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

enum SeedDateParser {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(from string: String) -> Date? {
        dayFormatter.date(from: string)
    }
}
