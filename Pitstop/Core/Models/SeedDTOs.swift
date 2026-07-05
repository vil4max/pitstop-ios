import Foundation

enum UpgradeStatus: String, Codable, Sendable {
    case planned
    case done
}

struct UpgradesDocument: Codable, Sendable {
    let schemaVersion: Int
    let items: [UpgradeItemDTO]
}

struct UpgradeItemDTO: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let costUah: Int
    let currencyCode: String?
    let status: UpgradeStatus
    let completedDate: String?
    let priority: Int?
    let sortOrder: Int
}

struct InsuranceDocument: Codable, Sendable {
    let schemaVersion: Int
    let policyNumber: String
    let insurer: String
    let contractDate: String
    let validFrom: String
    let validUntil: String
    let premiumUah: Int
    let plate: String
    let verificationUrl: String
}

struct MaintenancePlanDocument: Codable, Sendable {
    let schemaVersion: Int
    let vehicle: VehicleDTO
    let calculation: CalculationDTO
    let dealerStatement: DealerStatementDTO
    let visits: [VisitDTO]
}

struct VehicleDTO: Codable, Sendable {
    let vin: String
    let make: String
    let model: String
    let modelYear: Int
    let purchaseDate: String
    let engineLabel: String
    let odometerKm: Int
    let mileageBaselineKm: Int
    let mileageBaselineMonths: Int
    let averageMonthlyMileageKm: Int
}

struct CalculationDTO: Codable, Sendable {
    let mode: String
    let primaryRule: String
    let averageMonthlyMileageKm: Int
    let oilIntervalKm: OilIntervalDTO
    let expectedOilChangeCostUah: Int
    let lastOilChangeOdometerKm: Int
    let kmSinceLastOil: Int
    let nextOilTargetKmMin: Int
    let nextOilTargetKmMax: Int
    let nextOilTargetKmDefault: Int
    let regularService: RegularServiceDTO
}

struct OilIntervalDTO: Codable, Sendable {
    let min: Int
    let max: Int
    let `default`: Int

    enum CodingKeys: String, CodingKey {
        case min, max
        case `default` = "default"
    }
}

struct RegularServiceDTO: Codable, Sendable {
    let intervalKmMin: Int
    let intervalKmMax: Int
    let intervalKmDefault: Int
    let nextTargetKm: Int
    let nextWindowFromKm: Int
    let nextWindowToKm: Int
}

struct DealerStatementDTO: Codable, Sendable {
    let dealer: String
    let arteonVisitsTotalUah: Int
    let arteonVisits: [DealerVisitDTO]
    let otherPayments: [OtherPaymentDTO]
    let otherPaymentsTotalUah: Int

    var totalSpentUah: Int {
        arteonVisitsTotalUah + otherPaymentsTotalUah
    }
}

struct DealerVisitDTO: Codable, Sendable, Identifiable {
    var id: String { visitId }
    let visitId: String
    let serviceDate: String
    let completedOdometerKm: Int
    let odometerIsEstimate: Bool?
    let includesOilChange: Bool
    let costProfile: String
    let totalUah: Int
    let payments: [PaymentDTO]
}

struct OtherPaymentDTO: Codable, Sendable, Identifiable {
    var id: String { date + String(amountUah) }
    let date: String
    let amountUah: Int
    let title: String
    let category: String
}

struct PaymentDTO: Codable, Sendable, Identifiable {
    var id: String { date + String(amountUah) }
    let date: String
    let amountUah: Int
    let card: String
    let payee: String
}

enum VisitKind: String, Codable, Sendable {
    case regular
    case milestone
}

struct VisitDTO: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let kind: VisitKind
    let sortOrder: Int
    let targetOdometerKm: Int
    let serviceScope: String?
    let includesOilChange: Bool
    let tasks: [TaskDTO]
    let isCompleted: Bool
    let completedOdometer: Int?
    let completedAt: String?
    let dealer: String?
    let costUah: Int?
    let costProfile: String?
    let estimatedOilPortionUah: Int?
    let windowKm: Int?
    let windowFromKm: Int?
    let windowToKm: Int?
    let odometerIsEstimate: Bool?
    let payments: [PaymentDTO]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        kind = try container.decode(VisitKind.self, forKey: .kind)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        targetOdometerKm = try container.decode(Int.self, forKey: .targetOdometerKm)
        serviceScope = try container.decodeIfPresent(String.self, forKey: .serviceScope)
        includesOilChange = try container.decodeIfPresent(Bool.self, forKey: .includesOilChange) ?? false
        tasks = try container.decode([TaskDTO].self, forKey: .tasks)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        completedOdometer = try container.decodeIfPresent(Int.self, forKey: .completedOdometer)
        completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        dealer = try container.decodeIfPresent(String.self, forKey: .dealer)
        costUah = try container.decodeIfPresent(Int.self, forKey: .costUah)
        costProfile = try container.decodeIfPresent(String.self, forKey: .costProfile)
        estimatedOilPortionUah = try container.decodeIfPresent(Int.self, forKey: .estimatedOilPortionUah)
        windowKm = try container.decodeIfPresent(Int.self, forKey: .windowKm)
        windowFromKm = try container.decodeIfPresent(Int.self, forKey: .windowFromKm)
        windowToKm = try container.decodeIfPresent(Int.self, forKey: .windowToKm)
        odometerIsEstimate = try container.decodeIfPresent(Bool.self, forKey: .odometerIsEstimate)
        payments = try container.decodeIfPresent([PaymentDTO].self, forKey: .payments)
    }
}

struct TaskDTO: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let sortOrder: Int
    let isMandatory: Bool
    let isApplicable: Bool
    let isDone: Bool
}

enum BundleJSONLoader {
    static func load<T: Decodable>(_ type: T.Type, resource: String, extension ext: String = "json") throws -> T {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            throw LoaderError.missingResource("\(resource).\(ext)")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    enum LoaderError: Error {
        case missingResource(String)
    }
}
