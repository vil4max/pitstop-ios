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
