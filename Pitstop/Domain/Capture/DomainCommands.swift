import Foundation

// Domain mutation boundary (capture-pipeline.md): these commands are the only values
// allowed to change product state, and each one checks its own invariants so a proposal
// that bypassed the validator still cannot write nonsense.

public enum DomainCommandError: Error, Hashable, Sendable {
    case emptyNoteText
    case odometerOutOfRange
    case dateInFuture
    case emptyVehicleFactValue
    case invalidVehicleYear
    case policyWithoutInterval
    case nonPositiveInterval
    case nonPositiveAmount
    case emptyNoteUpdate
}

public enum DomainCommandLimits {
    public static let maximumOdometerKm: Double = 5_000_000
    /// Covers clock skew only. Anything later is a plan, and a plan is never performed work (REQ-DOMAIN-009).
    public static let futureTolerance: TimeInterval = 5 * 60
    public static let earliestVehicleYear = 1886

    public static func isPlausibleOdometer(_ kilometers: Double) -> Bool {
        kilometers.isFinite && (0 ... maximumOdometerKm).contains(kilometers)
    }

    public static func isNotFuture(_ date: Date, now: Date) -> Bool {
        date <= now.addingTimeInterval(futureTolerance)
    }

    public static func isValidVehicleYear(_ value: String, now: Date) -> Bool {
        let nextModelYear = Calendar(identifier: .gregorian).component(.year, from: now) + 1
        guard let year = Int(value.trimmingCharacters(in: .whitespaces)) else { return false }
        return (earliestVehicleYear ... nextModelYear).contains(year)
    }
}

public struct CreateNoteCommand: Hashable, Sendable {
    public let vehicleID: VehicleID?
    public let rawText: String
    public let canonicalContexts: Set<NoteContext>
    public let createdAt: Date?

    public init(
        vehicleID: VehicleID? = nil,
        rawText: String,
        canonicalContexts: Set<NoteContext> = [],
        createdAt: Date? = nil
    ) {
        self.vehicleID = vehicleID
        self.rawText = rawText
        self.canonicalContexts = canonicalContexts
        self.createdAt = createdAt
    }
}

/// The user's own correction or archive action. Archiving changes only the status; it never
/// records work or history (REQ-DOMAIN-013). A model may not issue this command: its
/// reclassification must leave the wording alone (REQ-CAPTURE-013).
public struct UpdateNoteCommand: Hashable, Sendable {
    public let noteID: UUID
    public let rawText: String?
    public let status: NoteStatus?

    public init(noteID: UUID, rawText: String? = nil, status: NoteStatus? = nil) {
        self.noteID = noteID
        self.rawText = rawText
        self.status = status
    }
}

public struct RecordOdometerReadingCommand: Hashable, Sendable {
    public let reading: OdometerReading

    public init(reading: OdometerReading) {
        self.reading = reading
    }
}

public struct RecordVehicleFactCommand: Hashable, Sendable {
    public let vehicleID: VehicleID
    public let fact: VehicleFact

    public init(vehicleID: VehicleID, fact: VehicleFact) {
        self.vehicleID = vehicleID
        self.fact = fact
    }
}

public struct ConfirmMaintenanceCompletionCommand: Hashable, Sendable {
    public let completion: MaintenanceCompletion

    public init(completion: MaintenanceCompletion) {
        self.completion = completion
    }
}

public struct SetMaintenancePolicyCommand: Hashable, Sendable {
    public let vehicleID: VehicleID
    public let policy: MaintenancePolicy

    public init(vehicleID: VehicleID, policy: MaintenancePolicy) {
        self.vehicleID = vehicleID
        self.policy = policy
    }
}

public struct RecordVehicleEventCommand: Hashable, Sendable {
    public let event: HistoryEvent

    public init(event: HistoryEvent) {
        self.event = event
    }
}

/// The user's correction of a recorded event. It replaces the fields of an existing event and
/// keeps its identity; surfaces re-read the corrected record (REQ-DOMAIN-016).
public struct CorrectVehicleEventCommand: Hashable, Sendable {
    public let event: HistoryEvent

    public init(event: HistoryEvent) {
        self.event = event
    }
}

/// Money stays an attribute of a History Event (domain-model.md), so an expense is
/// recorded as an event that must carry an amount rather than as an accounting entry.
public struct RecordExpenseCommand: Hashable, Sendable {
    public let event: HistoryEvent

    public init(event: HistoryEvent) {
        self.event = event
    }
}

public enum DomainCommand: Hashable, Sendable {
    case createNote(CreateNoteCommand)
    case updateNote(UpdateNoteCommand)
    case recordOdometerReading(RecordOdometerReadingCommand)
    case recordVehicleFact(RecordVehicleFactCommand)
    case confirmMaintenanceCompletion(ConfirmMaintenanceCompletionCommand)
    case setMaintenancePolicy(SetMaintenancePolicyCommand)
    case recordVehicleEvent(RecordVehicleEventCommand)
    case correctVehicleEvent(CorrectVehicleEventCommand)
    case recordExpense(RecordExpenseCommand)

    public func validate(now: Date) throws(DomainCommandError) {
        switch self {
        case let .createNote(command):
            guard !command.rawText.isBlank else { throw .emptyNoteText }
        case let .updateNote(command):
            guard command.rawText != nil || command.status != nil else { throw .emptyNoteUpdate }
            if let text = command.rawText, text.isBlank {
                throw .emptyNoteText
            }
        case let .recordOdometerReading(command):
            try Self.checkOdometer(command.reading.valueInKilometers)
            try Self.checkNotFuture(command.reading.recordedAt, now: now)
        case let .recordVehicleFact(command):
            try Self.check(command.fact, now: now)
        case let .confirmMaintenanceCompletion(command):
            try Self.checkOdometer(command.completion.odometerKm.map(Double.init))
            try Self.checkNotFuture(command.completion.performedAt, now: now)
        case let .setMaintenancePolicy(command):
            try Self.check(command.policy)
        case let .recordVehicleEvent(command):
            try Self.check(command.event, now: now, requiresAmount: false)
        case let .correctVehicleEvent(command):
            try Self.check(command.event, now: now, requiresAmount: false)
        case let .recordExpense(command):
            try Self.check(command.event, now: now, requiresAmount: true)
        }
    }

    private static func checkOdometer(_ kilometers: Double?) throws(DomainCommandError) {
        guard let kilometers else { return }
        guard DomainCommandLimits.isPlausibleOdometer(kilometers) else { throw .odometerOutOfRange }
    }

    private static func checkNotFuture(_ date: Date, now: Date) throws(DomainCommandError) {
        guard DomainCommandLimits.isNotFuture(date, now: now) else { throw .dateInFuture }
    }

    private static func check(_ fact: VehicleFact, now: Date) throws(DomainCommandError) {
        guard !fact.value.isBlank else { throw .emptyVehicleFactValue }
        guard fact.field == .year else { return }
        guard DomainCommandLimits.isValidVehicleYear(fact.value, now: now) else { throw .invalidVehicleYear }
    }

    private static func check(_ policy: MaintenancePolicy) throws(DomainCommandError) {
        guard policy.distanceIntervalKm != nil || policy.timeIntervalMonths != nil else {
            throw .policyWithoutInterval
        }
        guard (policy.distanceIntervalKm ?? 1) > 0, (policy.timeIntervalMonths ?? 1) > 0 else {
            throw .nonPositiveInterval
        }
    }

    private static func check(
        _ event: HistoryEvent,
        now: Date,
        requiresAmount: Bool
    ) throws(DomainCommandError) {
        try checkOdometer(event.odometerKm.map(Double.init))
        try checkNotFuture(event.date, now: now)
        if let amount = event.amount {
            guard amount > 0 else { throw .nonPositiveAmount }
        } else if requiresAmount {
            throw .nonPositiveAmount
        }
    }
}

extension String {
    var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }
}
