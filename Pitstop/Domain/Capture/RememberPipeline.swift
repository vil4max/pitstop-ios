import Foundation

public enum RememberMode: String, Hashable, Sendable {
    /// Save the wording, assign no stronger meaning, call no interpreter.
    case raw
    /// Ask the interpreter for typed meaning first. The wording is preserved either way.
    case interpreted
}

/// A validated proposal the user has not accepted yet. Nothing was written when one exists.
public struct PendingCapture: Identifiable, Hashable, Sendable {
    let input: CaptureInput
    let validated: ValidatedProposal

    public var id: UUID {
        input.id
    }

    public var kind: ProposalKind {
        validated.proposal.kind
    }

    public var content: ValidatedContent {
        validated.content
    }

    public var rawText: String {
        validated.proposal.rawText
    }

    public var conflicts: [ProposalConflict] {
        validated.conflicts
    }
}

/// One missing field, asked on its own. Clarification is never a form (REQ-CAPTURE-020).
public struct ClarificationRequest: Identifiable, Hashable, Sendable {
    let input: CaptureInput
    let proposal: MemoryProposal
    public let question: ProposalField
    /// Fields still missing after this one. The user is asked about them one at a time.
    public let remaining: [ProposalField]

    public var id: UUID {
        input.id
    }

    public var kind: ProposalKind {
        proposal.kind
    }

    public var rawText: String {
        proposal.rawText
    }
}

public enum ClarificationAnswer: Hashable, Sendable {
    case odometerKm(Double)
    case operation(MaintenanceOperationID)
    case eventKind(HistoryEventKind)
    case amount(Decimal)
    case policyInterval(distanceKm: Int?, months: Int?)
    /// "I don't know" is a valid answer (core C2); the wording is saved without the structure.
    case unknown
}

public enum RememberOutcome: Hashable, Sendable {
    /// Persistence succeeded. `preservedRaw` is true when no stronger meaning was applied.
    case saved(CommandResult, preservedRaw: Bool)
    /// There was nothing to remember: blank input, or the capture was cancelled before anything was
    /// written (REQ-CAPTURE-005).
    case nothingToSave
    /// The proposal may not mutate anything until the user accepts it.
    case needsConfirmation(PendingCapture)
    /// One field is missing; ask for it, or save the wording as it is.
    case needsClarification(ClarificationRequest)
}

public enum RememberError: Error, Hashable, Sendable {
    /// Nothing was saved; the caller keeps the input so the user can retry (REQ-CAPTURE-009).
    case notSaved
    /// This very proposal was already written. Retrying cannot help and nothing was lost, so the
    /// surface says so instead of offering a retry.
    case alreadySaved
}

/// The one path from a `CaptureInput` to persisted memory, for every source and both modes
/// (core C4). Raw mode calls no interpreter. Interpreted mode asks one, and every proposal it
/// returns goes through the same validator, confirmation policy, mapper, and store.
public struct RememberPipeline: Sendable {
    private let store: any CarMemoryStore
    private let interpreter: any SemanticInterpreting
    private let observer: any CaptureStageObserving
    private let deadline: InterpretationDeadline
    private let now: @Sendable () -> Date

    public init(
        store: any CarMemoryStore,
        interpreter: any SemanticInterpreting = NoSemanticInterpreter(),
        observer: any CaptureStageObserving = NoCaptureStageObserver(),
        deadline: InterpretationDeadline = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.interpreter = interpreter
        self.observer = observer
        self.deadline = deadline
        self.now = now
    }

    public func rememberRaw(_ input: CaptureInput) async throws(RememberError) -> RememberOutcome {
        try await remember(input, mode: .raw)
    }

    public func remember(_ input: CaptureInput, mode: RememberMode) async throws(RememberError) -> RememberOutcome {
        report(.captureReceived, input)
        guard !input.payload.rawContent.isBlank else {
            report(.captureDiscarded, input)
            return .nothingToSave
        }

        guard mode == .interpreted else { return try await save(input, proposal: rawProposal(for: input)) }

        var interpreted: MemoryProposal?
        report(.interpretationStarted, input)
        do {
            let interpreter = interpreter
            if case let .finished(proposal) = try await deadline.run({ try await interpreter.interpret(input) }) {
                interpreted = proposal
            }
        } catch {
            // The interpreter being unavailable must not lose the input (REQ-CAPTURE-007).
            interpreted = nil
        }
        // A capture cancelled while it was being interpreted ends here, before any store access, so a
        // cancellation-aware read cannot turn it into a failure the user is asked to retry.
        guard !Task.isCancelled else {
            report(.captureDiscarded, input)
            return .nothingToSave
        }
        report(.interpretationCompleted, input, kind: interpreted?.kind)
        guard let interpreted else {
            // No supported meaning, or no interpreter: the wording is kept instead (REQ-CAPTURE-006, 007).
            return try await save(input, proposal: rawProposal(for: input), degraded: true)
        }
        return try await route(interpreted, input: input)
    }

    /// The user accepted a proposal that needed confirmation.
    public func confirm(_ pending: PendingCapture) async throws(RememberError) -> RememberOutcome {
        guard let permit = ConfirmationPolicy().permit(for: pending.validated, userConfirmed: true) else {
            report(.pipelineFailed, pending.input, kind: pending.kind)
            throw .notSaved
        }
        return try await execute(permit, input: pending.input, preservedRaw: false)
    }

    /// The user declined the proposed meaning, or answered "I don't know". The wording is kept.
    public func preserveRaw(_ input: CaptureInput,
                            kind _: ProposalKind) async throws(RememberError) -> RememberOutcome
    {
        try await save(input, proposal: rawProposal(for: input), degraded: true)
    }

    /// Answers the one question that was asked, then continues on the same path.
    public func answer(
        _ request: ClarificationRequest,
        with answer: ClarificationAnswer
    ) async throws(RememberError) -> RememberOutcome {
        guard answer != .unknown else { return try await preserveRaw(request.input, kind: request.kind) }
        return try await route(request.proposal.answering(answer), input: request.input)
    }

    /// Cancelling performs no mutation at all (REQ-CAPTURE-005).
    public func cancel(_ input: CaptureInput, kind: ProposalKind? = nil) {
        report(.captureDiscarded, input, kind: kind)
    }

    // MARK: - Private

    private func rawProposal(for input: CaptureInput) -> MemoryProposal {
        RawProposalFactory().proposal(for: input)
    }

    private func route(
        _ proposal: MemoryProposal,
        input: CaptureInput,
        degraded: Bool = false
    ) async throws(RememberError) -> RememberOutcome {
        let vehicle: Vehicle
        let latestKm: Double?
        do {
            vehicle = try await store.currentVehicle()
            // The latest reading is part of validation: a reading below it is a conflict the user
            // must confirm, not a silent write (REQ-CAPTURE-017).
            latestKm = try await store.odometerReadings().latest?.valueInKilometers
        } catch {
            report(.pipelineFailed, input, kind: proposal.kind)
            throw .notSaved
        }
        let context = ProposalValidationContext(vehicle: vehicle, latestOdometerKm: latestKm, now: now())
        let validation = ProposalValidator().validate(proposal, input: input, context: context)
        let policy = ConfirmationPolicy()
        let outcome = policy.outcome(for: validation)
        report(.proposalValidated, input, kind: proposal.kind, outcome: outcome)

        switch validation {
        case let .valid(validated):
            let pending = PendingCapture(input: input, validated: validated)
            guard let permit = policy.permit(for: validated, userConfirmed: false) else {
                report(.confirmationRequired, input, kind: proposal.kind, outcome: outcome)
                return .needsConfirmation(pending)
            }
            return try await execute(
                permit,
                input: input,
                preservedRaw: proposal.kind == .rawNote,
                degraded: degraded
            )
        case let .incomplete(proposal, missing):
            guard proposal.kind != .rawNote, let question = policy.nextClarification(for: validation) else {
                report(.pipelineFailed, input, kind: proposal.kind)
                throw .notSaved
            }
            report(.clarificationRequired, input, kind: proposal.kind, outcome: outcome)
            return .needsClarification(ClarificationRequest(
                input: input,
                proposal: proposal,
                question: question,
                remaining: Array(missing.dropFirst())
            ))
        case .preserveRaw:
            // Unsupported or untrusted structure. The wording is still saved (REQ-CAPTURE-006). A raw
            // note that itself fails validation cannot be saved at all, so it is reported, not retried.
            guard proposal.kind != .rawNote else {
                report(.pipelineFailed, input, kind: proposal.kind)
                throw .notSaved
            }
            return try await preserveRaw(input, kind: proposal.kind)
        case .empty:
            report(.captureDiscarded, input, kind: proposal.kind)
            return .nothingToSave
        }
    }

    /// The raw path: a raw note is always auto-accepted, so it never stops to ask.
    private func save(
        _ input: CaptureInput,
        proposal: MemoryProposal,
        degraded: Bool = false
    ) async throws(RememberError) -> RememberOutcome {
        let outcome = try await route(proposal, input: input, degraded: degraded)
        if case .needsConfirmation = outcome {
            report(.pipelineFailed, input, kind: proposal.kind)
            throw .notSaved
        }
        return outcome
    }

    /// `preservedRaw` is what the user is told: saved without stronger meaning (REQ-CAPTURE-008).
    /// `degraded` is the narrower telemetry fact — interpretation was attempted and gave way — and it
    /// is reported only once the wording is actually stored, so a failed save never counts.
    private func execute(
        _ permit: MutationPermit,
        input: CaptureInput,
        preservedRaw: Bool,
        degraded: Bool = false
    ) async throws(RememberError) -> RememberOutcome {
        let moment = now()
        let kind = permit.validated.proposal.kind
        // The last point before a write, and the backstop for every path: a cancelled capture must not
        // mutate anything (REQ-CAPTURE-005).
        guard !Task.isCancelled else {
            report(.captureDiscarded, input, kind: kind)
            return .nothingToSave
        }
        do {
            let command = try DomainCommandMapper().command(for: permit, now: moment)
            report(.domainCommandCreated, input, kind: kind)
            let result = try await store.execute(command, now: moment)
            report(.mutationCompleted, input, kind: kind)
            if degraded {
                report(.rawPreserved, input, kind: kind)
            }
            return .saved(result, preservedRaw: preservedRaw)
        } catch {
            // A repeated confirmation of the same proposal is not a failure: nothing was lost, and
            // counting it as one would make the abandonment figure wrong.
            if let storeError = error as? CarMemoryStoreError, storeError == .duplicateRecord {
                throw .alreadySaved
            }
            report(.pipelineFailed, input, kind: kind)
            throw .notSaved
        }
    }

    private func report(
        _ stage: CaptureStage,
        _ input: CaptureInput,
        kind: ProposalKind? = nil,
        outcome: ConfirmationOutcome? = nil
    ) {
        observer.record(CaptureStageEvent(
            correlationID: input.id,
            stage: stage,
            source: input.source,
            proposalKind: kind,
            outcome: outcome
        ))
    }
}

private extension MemoryProposal {
    /// Returns the same draft with one more field filled. The wording is never touched
    /// (REQ-DOMAIN-011), so the answer can only add structure.
    func answering(_ answer: ClarificationAnswer) -> MemoryProposal {
        var odometer = extractedOdometerKm
        var operation = extractedOperationID
        var eventKind = extractedEventKind
        var amount = extractedAmount
        var distance = extractedDistanceIntervalKm
        var months = extractedTimeIntervalMonths
        switch answer {
        case let .odometerKm(value): odometer = value
        case let .operation(value): operation = value
        case let .eventKind(value): eventKind = value
        case let .amount(value): amount = value
        case let .policyInterval(distanceKm, monthsValue):
            distance = distanceKm
            months = monthsValue
        case .unknown: break
        }
        return MemoryProposal(
            id: id,
            sourceInputID: sourceInputID,
            kind: kind,
            rawText: rawText,
            confidence: confidence,
            extractedOdometerKm: odometer,
            extractedOperationID: operation,
            extractedDate: extractedDate,
            extractedNoteContexts: extractedNoteContexts,
            extractedVehicleFact: extractedVehicleFact,
            extractedDistanceIntervalKm: distance,
            extractedTimeIntervalMonths: months,
            extractedEventKind: eventKind,
            extractedAmount: amount
        )
    }
}
