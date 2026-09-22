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
    case emptyOperationID
    /// Earlier than the Road grace period or more than ten years ahead (ADR 0032).
    case plannedDateOutOfRange
    /// Blank, multi-line, or untrimmed; a missing label is `nil`, never an empty string.
    case invalidPlannedLabel
    case plannedLabelTooLong
    /// A dashboard reading that says neither a distance nor a number of days says nothing (ADR 0035).
    case reportWithoutRemainingValue
    /// A reported distance has no anchor without the mileage it was read at.
    case reportOdometerMissing
    case reportRemainingDistanceOutOfRange
    case reportRemainingDaysOutOfRange
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

/// The user takes back a confirmation made by mistake. The cycle returns to the previous completion,
/// or to unknown when there is none. Only the user can issue it; no proposal maps to it.
public struct RevokeMaintenanceCompletionCommand: Hashable, Sendable {
    public let completionID: UUID

    public init(completionID: UUID) {
        self.completionID = completionID
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

/// The owner stops tracking an operation: only the owner's own policy for it is removed. Completions
/// and History are performed facts and stay (ADR 0031). Only the user can issue it; no proposal maps to it.
public struct StopTrackingOperationCommand: Hashable, Sendable {
    public let vehicleID: VehicleID
    public let operationID: MaintenanceOperationID

    public init(vehicleID: VehicleID, operationID: MaintenanceOperationID) {
        self.vehicleID = vehicleID
        self.operationID = operationID
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

/// The owner states a future date for the car (ADR 0032). Only the user can issue it; no proposal maps
/// to it, so Remember cannot plan a date without a later, confirmed mapping.
public struct AddPlannedEventCommand: Hashable, Sendable {
    public let event: PlannedDatedEvent

    public init(event: PlannedDatedEvent) {
        self.event = event
    }
}

/// The owner's correction of a planned date: kind, date, and label change; identity, vehicle, and
/// creation time stay those of the stored event.
public struct UpdatePlannedEventCommand: Hashable, Sendable {
    public let event: PlannedDatedEvent

    public init(event: PlannedDatedEvent) {
        self.event = event
    }
}

/// The owner deletes a planned date. It was never a fact, so nothing else changes.
public struct RemovePlannedEventCommand: Hashable, Sendable {
    public let eventID: UUID

    public init(eventID: UUID) {
        self.eventID = eventID
    }
}

/// The owner enters what the car's own display says is left for one operation (ADR 0035). It
/// replaces the previous reading for that operation; it is never a policy and resets no cycle.
public struct RecordVehicleServiceReportCommand: Hashable, Sendable {
    public let report: VehicleServiceReport

    public init(report: VehicleServiceReport) {
        self.report = report
    }
}

/// The owner deletes the car's reading for one operation. Completions, History and the owner's own
/// interval are untouched; an operation kept visible by the reading alone leaves Service with it.
public struct RemoveVehicleServiceReportCommand: Hashable, Sendable {
    public let vehicleID: VehicleID
    public let operationID: MaintenanceOperationID

    public init(vehicleID: VehicleID, operationID: MaintenanceOperationID) {
        self.vehicleID = vehicleID
        self.operationID = operationID
    }
}

public enum DomainCommand: Hashable, Sendable {
    case createNote(CreateNoteCommand)
    case updateNote(UpdateNoteCommand)
    case recordOdometerReading(RecordOdometerReadingCommand)
    case recordVehicleFact(RecordVehicleFactCommand)
    case confirmMaintenanceCompletion(ConfirmMaintenanceCompletionCommand)
    case revokeMaintenanceCompletion(RevokeMaintenanceCompletionCommand)
    case setMaintenancePolicy(SetMaintenancePolicyCommand)
    case stopTrackingOperation(StopTrackingOperationCommand)
    case recordVehicleEvent(RecordVehicleEventCommand)
    case correctVehicleEvent(CorrectVehicleEventCommand)
    case recordExpense(RecordExpenseCommand)
    case addPlannedEvent(AddPlannedEventCommand)
    case updatePlannedEvent(UpdatePlannedEventCommand)
    case removePlannedEvent(RemovePlannedEventCommand)
    case recordVehicleServiceReport(RecordVehicleServiceReportCommand)
    case removeVehicleServiceReport(RemoveVehicleServiceReportCommand)

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
        case .revokeMaintenanceCompletion:
            break
        case let .setMaintenancePolicy(command):
            try Self.check(command.policy)
        case let .stopTrackingOperation(command):
            guard !command.operationID.rawValue.isBlank else { throw .emptyOperationID }
        case let .recordVehicleEvent(command):
            try Self.check(command.event, now: now, requiresAmount: false)
        case let .correctVehicleEvent(command):
            try Self.check(command.event, now: now, requiresAmount: false)
        case let .recordExpense(command):
            try Self.check(command.event, now: now, requiresAmount: true)
        case let .addPlannedEvent(command):
            try Self.check(command.event, now: now)
        case let .updatePlannedEvent(command):
            try Self.check(command.event, now: now)
        case .removePlannedEvent:
            break
        case let .recordVehicleServiceReport(command):
            try Self.check(command.report, now: now)
        case let .removeVehicleServiceReport(command):
            guard !command.operationID.rawValue.isBlank else { throw .emptyOperationID }
        }
    }

    /// Nothing is stored unless the reading can be turned into an anchor: an operation, at least one
    /// remaining value in range, and the mileage a reported distance was read at (ADR 0035).
    private static func check(_ report: VehicleServiceReport, now: Date) throws(DomainCommandError) {
        guard !report.operationID.rawValue.isBlank else { throw .emptyOperationID }
        try checkNotFuture(report.reportedAt, now: now)
        try checkOdometer(report.odometerKm.map(Double.init))
        guard report.remainingDistance != nil || report.remainingDays != nil else {
            throw .reportWithoutRemainingValue
        }
        if let kilometers = report.remainingDistanceKm {
            guard VehicleServiceReportLimits.isPlausibleRemainingKm(kilometers) else {
                throw .reportRemainingDistanceOutOfRange
            }
            guard report.odometerKm != nil else { throw .reportOdometerMissing }
        }
        if let days = report.remainingDays {
            guard VehicleServiceReportLimits.isPlausibleRemainingDays(days) else {
                throw .reportRemainingDaysOutOfRange
            }
        }
    }

    private static func check(_ event: PlannedDatedEvent, now: Date) throws(DomainCommandError) {
        guard PlannedEventLimits.isPlausibleDate(event.date, now: now) else { throw .plannedDateOutOfRange }
        guard let label = event.label else { return }
        guard PlannedEventLimits.isValidLabel(label) else { throw .invalidPlannedLabel }
        guard PlannedEventLimits.isLabelWithinLimit(label) else { throw .plannedLabelTooLong }
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
