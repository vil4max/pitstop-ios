import Foundation

/// Facts the validator needs from current product state. A snapshot, so validation stays pure.
public struct ProposalValidationContext: Hashable, Sendable {
    public let vehicle: Vehicle
    public let latestOdometerKm: Double?
    public let now: Date

    public init(vehicle: Vehicle, latestOdometerKm: Double? = nil, now: Date) {
        self.vehicle = vehicle
        self.latestOdometerKm = latestOdometerKm
        self.now = now
    }
}

public enum ProposalConflict: Hashable, Sendable {
    case odometerBelowLatest(latestKm: Double)
    case replacesVehicleFact(field: VehicleFactField, existing: String)
}

public enum RawPreservationReason: String, Hashable, Codable, Sendable {
    case unsupportedKind
    case invalidExtractedValue
    /// The producer altered the user's wording or pointed at another input (core P1).
    case sourceMismatch
    /// The capture was made for another vehicle than the one in the current snapshot.
    case vehicleMismatch
}

/// Typed content with every required field present. Only the validator creates it.
public enum ValidatedContent: Hashable, Sendable {
    case note(text: String, contexts: Set<NoteContext>)
    case odometerReading(kilometers: Double, recordedAt: Date)
    case vehicleFact(VehicleFact)
    case maintenanceCompletion(operationID: MaintenanceOperationID, performedAt: Date, odometerKm: Int?)
    case maintenancePolicy(operationID: MaintenanceOperationID, distanceIntervalKm: Int?, timeIntervalMonths: Int?)
    case vehicleEvent(kind: HistoryEventKind, date: Date, odometerKm: Int?, amount: Decimal?)
    case expense(kind: HistoryEventKind, date: Date, odometerKm: Int?, amount: Decimal)
}

public struct ValidatedProposal: Hashable, Sendable {
    public let proposal: MemoryProposal
    public let source: CaptureSource
    public let vehicleID: VehicleID
    public let content: ValidatedContent
    public let conflicts: [ProposalConflict]

    /// Only the validator in this file may create a validated proposal.
    fileprivate init(
        proposal: MemoryProposal,
        source: CaptureSource,
        vehicleID: VehicleID,
        content: ValidatedContent,
        conflicts: [ProposalConflict] = []
    ) {
        self.proposal = proposal
        self.source = source
        self.vehicleID = vehicleID
        self.content = content
        self.conflicts = conflicts
    }
}

public enum ProposalValidation: Hashable, Sendable {
    case valid(ValidatedProposal)
    /// Meaning is supported but a required field is absent; ask for it one at a time.
    case incomplete(MemoryProposal, missing: [ProposalField])
    /// Structure cannot be trusted; the wording must still be kept.
    case preserveRaw(MemoryProposal, reason: RawPreservationReason)
    /// Nothing to remember.
    case empty(MemoryProposal)
}

public struct ProposalValidator: Sendable {
    public init() {}

    public func validate(
        _ proposal: MemoryProposal,
        input: CaptureInput,
        context: ProposalValidationContext
    ) -> ProposalValidation {
        let rawContent = input.payload.rawContent
        guard !rawContent.isBlank else { return .empty(proposal) }
        guard proposal.sourceInputID == input.id, proposal.rawText == rawContent else {
            return .preserveRaw(proposal, reason: .sourceMismatch)
        }
        let date = proposal.extractedDate ?? input.capturedAt
        // Notes skip these guards: they are the raw fallback, and the wording must always be savable (core P1).
        if !proposal.kind.isNote {
            if let selected = input.selectedVehicleID, selected != context.vehicle.id {
                return .preserveRaw(proposal, reason: .vehicleMismatch)
            }
            guard DomainCommandLimits.isNotFuture(date, now: context.now) else {
                return .preserveRaw(proposal, reason: .invalidExtractedValue)
            }
        }
        do throws(Rejection) {
            let (content, conflicts) = try content(of: proposal, rawContent: rawContent, date: date, context: context)
            return .valid(
                ValidatedProposal(
                    proposal: proposal,
                    source: input.source,
                    vehicleID: context.vehicle.id,
                    content: content,
                    conflicts: conflicts
                )
            )
        } catch {
            switch error {
            case let .missing(fields):
                return .incomplete(proposal, missing: fields)
            case let .preserve(reason):
                return .preserveRaw(proposal, reason: reason)
            }
        }
    }

    private enum Rejection: Error {
        case missing([ProposalField])
        case preserve(RawPreservationReason)
    }

    private typealias Checked = (ValidatedContent, [ProposalConflict])

    private func content(
        of proposal: MemoryProposal,
        rawContent: String,
        date: Date,
        context: ProposalValidationContext
    ) throws(Rejection) -> Checked {
        switch proposal.kind {
        case .rawNote:
            (.note(text: rawContent, contexts: []), [])
        case .contextualNote:
            (.note(text: rawContent, contexts: proposal.extractedNoteContexts), [])
        case .odometerReading:
            try odometerReading(proposal, date: date, context: context)
        case .vehicleFact:
            try vehicleFact(proposal, context: context)
        case .maintenanceCompletion:
            try maintenanceCompletion(proposal, date: date)
        case .maintenancePolicyDraft:
            try maintenancePolicy(proposal)
        case .vehicleEvent:
            try vehicleEvent(proposal, date: date)
        case .expense:
            try expense(proposal, date: date)
        case .reminderCandidate, .unknown:
            throw .preserve(.unsupportedKind)
        }
    }

    private func odometerReading(
        _ proposal: MemoryProposal,
        date: Date,
        context: ProposalValidationContext
    ) throws(Rejection) -> Checked {
        guard let kilometers = proposal.extractedOdometerKm else { throw .missing([.odometerKm]) }
        guard DomainCommandLimits.isPlausibleOdometer(kilometers) else { throw .preserve(.invalidExtractedValue) }
        var conflicts: [ProposalConflict] = []
        if let latest = context.latestOdometerKm, kilometers < latest {
            conflicts.append(.odometerBelowLatest(latestKm: latest))
        }
        return (.odometerReading(kilometers: kilometers, recordedAt: date), conflicts)
    }

    private func vehicleFact(
        _ proposal: MemoryProposal,
        context: ProposalValidationContext
    ) throws(Rejection) -> Checked {
        guard let fact = proposal.extractedVehicleFact else { throw .missing([.vehicleFact]) }
        guard !fact.value.isBlank else { throw .preserve(.invalidExtractedValue) }
        if fact.field == .year, !DomainCommandLimits.isValidVehicleYear(fact.value, now: context.now) {
            throw .preserve(.invalidExtractedValue)
        }
        var conflicts: [ProposalConflict] = []
        // The provisional display name is a placeholder, not a known fact (core C2).
        let isPlaceholderName = fact.field == .name && context.vehicle.name == ProvisionalCarContext.defaultName
        if let existing = context.vehicle.value(of: fact.field), existing != fact.value, !isPlaceholderName {
            conflicts.append(.replacesVehicleFact(field: fact.field, existing: existing))
        }
        return (.vehicleFact(fact), conflicts)
    }

    private func maintenanceCompletion(_ proposal: MemoryProposal, date: Date) throws(Rejection) -> Checked {
        guard let operationID = proposal.extractedOperationID else { throw .missing([.operationID]) }
        let odometerKm = try wholeKilometers(proposal.extractedOdometerKm)
        return (.maintenanceCompletion(operationID: operationID, performedAt: date, odometerKm: odometerKm), [])
    }

    private func maintenancePolicy(_ proposal: MemoryProposal) throws(Rejection) -> Checked {
        let distance = proposal.extractedDistanceIntervalKm
        let months = proposal.extractedTimeIntervalMonths
        var missing: [ProposalField] = []
        if proposal.extractedOperationID == nil {
            missing.append(.operationID)
        }
        if distance == nil, months == nil {
            missing.append(.policyInterval)
        }
        guard missing.isEmpty, let operationID = proposal.extractedOperationID else { throw .missing(missing) }
        guard (distance ?? 1) > 0, (months ?? 1) > 0 else { throw .preserve(.invalidExtractedValue) }
        return (
            .maintenancePolicy(operationID: operationID, distanceIntervalKm: distance, timeIntervalMonths: months),
            []
        )
    }

    private func vehicleEvent(_ proposal: MemoryProposal, date: Date) throws(Rejection) -> Checked {
        guard let kind = proposal.extractedEventKind else { throw .missing([.eventKind]) }
        if let amount = proposal.extractedAmount, amount <= 0 {
            throw .preserve(.invalidExtractedValue)
        }
        let odometerKm = try wholeKilometers(proposal.extractedOdometerKm)
        return (.vehicleEvent(kind: kind, date: date, odometerKm: odometerKm, amount: proposal.extractedAmount), [])
    }

    private func expense(_ proposal: MemoryProposal, date: Date) throws(Rejection) -> Checked {
        guard let amount = proposal.extractedAmount else { throw .missing([.amount]) }
        guard amount > 0 else { throw .preserve(.invalidExtractedValue) }
        let odometerKm = try wholeKilometers(proposal.extractedOdometerKm)
        return (
            .expense(kind: proposal.extractedEventKind ?? .other, date: date, odometerKm: odometerKm, amount: amount),
            []
        )
    }

    private func wholeKilometers(_ kilometers: Double?) throws(Rejection) -> Int? {
        guard let kilometers else { return nil }
        guard DomainCommandLimits.isPlausibleOdometer(kilometers) else { throw .preserve(.invalidExtractedValue) }
        return Int(kilometers.rounded())
    }
}

private extension ProposalKind {
    var isNote: Bool {
        self == .rawNote || self == .contextualNote
    }
}
