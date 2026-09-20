import Foundation

public struct VehicleID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue.uuidString
    }
}

public struct Vehicle: Identifiable, Hashable, Codable, Sendable {
    public let id: VehicleID
    public var name: String
    public var make: String?
    public var model: String?
    public var year: Int?
    public var vin: String?

    public init(
        id: VehicleID = VehicleID(),
        name: String,
        make: String? = nil,
        model: String? = nil,
        year: Int? = nil,
        vin: String? = nil
    ) {
        self.id = id
        self.name = name
        self.make = make
        self.model = model
        self.year = year
        self.vin = vin
    }
}

public enum DistanceUnit: String, Codable, Sendable {
    case kilometers = "km"
    case miles = "mi"
}

public enum ReadingSource: String, Codable, Sendable {
    case manualEntry
    case pitCapture
    case detected
}

public struct OdometerReading: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let vehicleID: VehicleID
    public let value: Double
    public let unit: DistanceUnit
    public let recordedAt: Date
    public let source: ReadingSource

    public init(
        id: UUID = UUID(),
        vehicleID: VehicleID,
        value: Double,
        unit: DistanceUnit = .kilometers,
        recordedAt: Date = Date(),
        source: ReadingSource = .manualEntry
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.value = value
        self.unit = unit
        self.recordedAt = recordedAt
        self.source = source
    }

    public var valueInKilometers: Double {
        switch unit {
        case .kilometers:
            value
        case .miles:
            value * 1.609344
        }
    }
}

public enum VehicleFactField: String, Codable, Sendable, CaseIterable {
    case name
    case make
    case model
    case year
    case vin

    /// Exact identity facts select which maintenance recommendations apply, so a wrong
    /// value silently changes service guidance. `name` is a display label only.
    public var affectsRecommendationApplicability: Bool {
        self != .name
    }
}

public struct VehicleFact: Hashable, Codable, Sendable {
    public let field: VehicleFactField
    public let value: String

    public init(field: VehicleFactField, value: String) {
        self.field = field
        self.value = value
    }
}

public extension Vehicle {
    func value(of field: VehicleFactField) -> String? {
        switch field {
        case .name: name
        case .make: make
        case .model: model
        case .year: year.map(String.init)
        case .vin: vin
        }
    }
}
