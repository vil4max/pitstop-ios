import Foundation

public enum DomainCommandMappingError: Error, Hashable, Sendable {
    case invalidCommand(DomainCommandError)
}

public struct DomainCommandMapper: Sendable {
    public init() {}

    /// The permit is the only input: the content to map is the content that was authorized.
    public func command(for permit: MutationPermit, now: Date) throws(DomainCommandMappingError) -> DomainCommand {
        let command = makeCommand(for: permit.validated)
        do {
            try command.validate(now: now)
        } catch {
            throw .invalidCommand(error)
        }
        return command
    }

    private func makeCommand(for validated: ValidatedProposal) -> DomainCommand {
        let vehicleID = validated.vehicleID
        switch validated.content {
        case let .note(text, contexts):
            return .createNote(CreateNoteCommand(vehicleID: vehicleID, rawText: text, canonicalContexts: contexts))
        case let .odometerReading(kilometers, recordedAt):
            let reading = OdometerReading(
                vehicleID: vehicleID,
                value: kilometers,
                recordedAt: recordedAt,
                source: validated.source.readingSource
            )
            return .recordOdometerReading(RecordOdometerReadingCommand(reading: reading))
        case let .vehicleFact(fact):
            return .recordVehicleFact(RecordVehicleFactCommand(vehicleID: vehicleID, fact: fact))
        case let .maintenanceCompletion(operationID, performedAt, odometerKm):
            let completion = MaintenanceCompletion(
                vehicleID: vehicleID,
                operationID: operationID,
                performedAt: performedAt,
                odometerKm: odometerKm
            )
            return .confirmMaintenanceCompletion(ConfirmMaintenanceCompletionCommand(completion: completion))
        case let .maintenancePolicy(operationID, distanceIntervalKm, timeIntervalMonths):
            let policy = MaintenancePolicy(
                operationID: operationID,
                distanceIntervalKm: distanceIntervalKm,
                timeIntervalMonths: timeIntervalMonths,
                source: .userCustom
            )
            return .setMaintenancePolicy(SetMaintenancePolicyCommand(vehicleID: vehicleID, policy: policy))
        case let .vehicleEvent(kind, date, odometerKm, amount):
            return .recordVehicleEvent(RecordVehicleEventCommand(event: HistoryEvent(
                vehicleID: vehicleID,
                kind: kind,
                date: date,
                odometerKm: odometerKm,
                amount: amount,
                note: validated.proposal.rawText
            )))
        case let .expense(kind, date, odometerKm, amount):
            return .recordExpense(RecordExpenseCommand(event: HistoryEvent(
                vehicleID: vehicleID,
                kind: kind,
                date: date,
                odometerKm: odometerKm,
                amount: amount,
                note: validated.proposal.rawText
            )))
        }
    }
}

private extension CaptureSource {
    var readingSource: ReadingSource {
        switch self {
        case .directApp: .manualEntry
        case .pitVoice, .pitText, .widget, .siri, .shortcut: .pitCapture
        }
    }
}
