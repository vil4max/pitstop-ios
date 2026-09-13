import Foundation

public enum NoteStatus: String, Codable, Sendable {
    case active
    case archived
}

public enum NoteContext: String, Codable, Sendable, CaseIterable {
    case carWash
    case service
    case shopping
}

public struct Note: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let vehicleID: VehicleID?
    public let rawText: String
    public let createdAt: Date
    public var status: NoteStatus
    public var canonicalContexts: Set<NoteContext>

    public init(
        id: UUID = UUID(),
        vehicleID: VehicleID? = nil,
        rawText: String,
        createdAt: Date = Date(),
        status: NoteStatus = .active,
        canonicalContexts: Set<NoteContext> = []
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.rawText = rawText
        self.createdAt = createdAt
        self.status = status
        self.canonicalContexts = canonicalContexts
    }
}

public enum HistoryEventKind: String, Codable, Sendable {
    case service
    case carWash
    case odometer
    case insurance
    case purchase
    case other
}

public struct HistoryEvent: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let vehicleID: VehicleID
    public let kind: HistoryEventKind
    public let date: Date
    public let odometerKm: Int?
    public let amount: Decimal?
    public let note: String?

    public init(
        id: UUID = UUID(),
        vehicleID: VehicleID,
        kind: HistoryEventKind,
        date: Date = Date(),
        odometerKm: Int? = nil,
        amount: Decimal? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.kind = kind
        self.date = date
        self.odometerKm = odometerKm
        self.amount = amount
        self.note = note
    }
}
