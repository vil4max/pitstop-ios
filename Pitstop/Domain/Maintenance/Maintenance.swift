import Foundation

public struct MaintenanceOperationID: Hashable, Codable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }

    public var description: String {
        rawValue
    }

    public static let engineOilService: MaintenanceOperationID = "engineOilService"
    public static let dsgService: MaintenanceOperationID = "dsgService"
    public static let awdCouplingService: MaintenanceOperationID = "awdCouplingService"
    public static let brakeFluid: MaintenanceOperationID = "brakeFluid"
    public static let cabinFilter: MaintenanceOperationID = "cabinFilter"
    public static let airFilter: MaintenanceOperationID = "airFilter"
    public static let sparkPlugs: MaintenanceOperationID = "sparkPlugs"

    /// Operations the app can name. An ID outside this list is still valid domain identity.
    public static let catalog: [MaintenanceOperationID] = [
        .engineOilService, .dsgService, .awdCouplingService, .brakeFluid, .cabinFilter, .airFilter, .sparkPlugs,
    ]
}

public enum PolicySource: String, Codable, Sendable {
    case defaultRecommendation
    case userCustom
    case vehicleCondition
}

public struct MaintenancePolicy: Hashable, Codable, Sendable {
    public let operationID: MaintenanceOperationID
    public let distanceIntervalKm: Int?
    public let timeIntervalMonths: Int?
    public let source: PolicySource

    public init(
        operationID: MaintenanceOperationID,
        distanceIntervalKm: Int? = nil,
        timeIntervalMonths: Int? = nil,
        source: PolicySource = .defaultRecommendation
    ) {
        self.operationID = operationID
        self.distanceIntervalKm = distanceIntervalKm
        self.timeIntervalMonths = timeIntervalMonths
        self.source = source
    }
}

public extension PolicySource {
    /// Higher wins when several rules exist for one operation. A custom policy outranks the
    /// recommendation without replacing its record (REQ-DOMAIN-006).
    var precedence: Int {
        switch self {
        case .defaultRecommendation: 0
        case .vehicleCondition: 1
        case .userCustom: 2
        }
    }
}

public extension Sequence<MaintenancePolicy> {
    /// One effective policy per operation, ordered by operation ID for stable output.
    var effective: [MaintenancePolicy] {
        Dictionary(grouping: self, by: \.operationID)
            .compactMap { $0.value.max { $0.source.precedence < $1.source.precedence } }
            .sorted { $0.operationID.rawValue < $1.operationID.rawValue }
    }
}

public struct MaintenanceCompletion: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let vehicleID: VehicleID
    public let operationID: MaintenanceOperationID
    public let performedAt: Date
    public let odometerKm: Int?
    public let engineHours: Double?
    public let sourceEventID: UUID?

    public init(
        id: UUID = UUID(),
        vehicleID: VehicleID,
        operationID: MaintenanceOperationID,
        performedAt: Date = Date(),
        odometerKm: Int? = nil,
        engineHours: Double? = nil,
        sourceEventID: UUID? = nil
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.operationID = operationID
        self.performedAt = performedAt
        self.odometerKm = odometerKm
        self.engineHours = engineHours
        self.sourceEventID = sourceEventID
    }
}

public enum MaintenanceStatus: String, Codable, Sendable {
    case unknown
    case upToDate
    case approaching
    case due
}
