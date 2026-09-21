import Foundation
import Observation

/// Where a saved memory went, so the surface can say so (REQ-CAPTURE-010).
enum PitDestination: Equatable {
    case notes
    case history
    case service
    case carBoard

    init(_ result: CommandResult) {
        switch result {
        case .noteCreated, .noteUpdated: self = .notes
        case .eventRecorded, .eventCorrected: self = .history
        case .completionConfirmed, .completionRevoked, .policySet: self = .service
        case .readingRecorded, .vehicleUpdated: self = .carBoard
        }
    }
}

enum PitCapturePhase: Equatable {
    case composing
    case working
    case confirming(PendingCapture)
    case clarifying(ClarificationRequest)
    /// `preservedRaw` is told to the user: saved as written, without stronger meaning (REQ-CAPTURE-008).
    case saved(PitDestination, preservedRaw: Bool)
}

enum PitCaptureFailure: Equatable {
    case notSaved
    case alreadySaved
    case invalidMileage
    case invalidAmount
}

/// The Pit capture surface. It only turns what the user wrote into a `CaptureInput` and follows the
/// pipeline's answer; every decision about meaning, confirmation, and writing belongs to the pipeline.
@MainActor
@Observable
final class PitCaptureViewModel {
    var text = ""
    var mode: RememberMode = .interpreted
    private(set) var phase: PitCapturePhase = .composing
    private(set) var failure: PitCaptureFailure?

    private let pipeline: RememberPipeline
    private let now: @Sendable () -> Date
    private var input: CaptureInput?
    /// Identifies the capture on screen. A step that finishes after the surface was reset or closed
    /// belongs to a capture that is gone, and must not write its result into the new one.
    private var session = UUID()

    init(pipeline: RememberPipeline, now: @escaping @Sendable () -> Date = { Date() }) {
        self.pipeline = pipeline
        self.now = now
    }

    var canSubmit: Bool {
        phase == .composing && !text.isBlank
    }

    /// `visible` is the surface the user came from; it is a prior only (REQ-CAPTURE-022).
    func submit(from visible: VisibleFeature?) async {
        guard canSubmit else { return }
        let capture = CaptureInput(payload: .text(text), source: .pitText, capturedAt: now(), visibleFeature: visible)
        input = capture
        await run { [pipeline, mode] in try await pipeline.remember(capture, mode: mode) }
    }

    func confirm() async {
        guard case let .confirming(pending) = phase else { return }
        await run { [pipeline] in try await pipeline.confirm(pending) }
    }

    /// The user declined the proposed meaning: the words are kept as a note.
    func keepWordsOnly() async {
        guard let input, let kind = pendingKind else { return }
        await run { [pipeline] in try await pipeline.preserveRaw(input, kind: kind) }
    }

    /// A typed answer to the one question asked. Unreadable input is reported, never guessed.
    func answer(_ answer: ClarificationAnswer) async {
        guard case let .clarifying(request) = phase else { return }
        await run { [pipeline] in try await pipeline.answer(request, with: answer) }
    }

    func answer(text: String) async {
        guard case let .clarifying(request) = phase else { return }
        switch request.question {
        case .odometerKm:
            guard let kilometers = CarBoardViewModel.kilometers(from: text).intValue
            else { return fail(.invalidMileage) }
            await answer(.odometerKm(Double(kilometers)))
        case .amount:
            guard case let .value(amount) = HistoryViewModel.amount(from: text) else { return fail(.invalidAmount) }
            await answer(.amount(amount))
        case .operationID, .vehicleFact, .policyInterval, .eventKind:
            // These are answered by choosing, not typing; the surface offers the choices.
            return
        }
    }

    /// Cancelling writes nothing (REQ-CAPTURE-005).
    func cancel() {
        // Only a proposal still waiting is an abandoned capture; a saved one is simply done.
        if let input, let kind = pendingKind {
            pipeline.cancel(input, kind: kind)
        }
        reset()
    }

    func reset() {
        session = UUID()
        text = ""
        input = nil
        failure = nil
        phase = .composing
    }

    func dismissFailure() {
        failure = nil
    }

    private var pendingKind: ProposalKind? {
        switch phase {
        case let .confirming(pending): pending.kind
        case let .clarifying(request): request.kind
        case .composing, .working, .saved: nil
        }
    }

    private func run(_ step: () async throws -> RememberOutcome) async {
        guard phase != .working else { return }
        let previous = phase
        let owner = session
        phase = .working
        failure = nil
        let outcome: Result<RememberOutcome, RememberError>
        do {
            outcome = try await .success(step())
        } catch {
            outcome = .failure(error as? RememberError ?? .notSaved)
        }
        guard owner == session else { return }
        switch outcome {
        case let .success(.saved(result, preservedRaw)):
            phase = .saved(PitDestination(result), preservedRaw: preservedRaw)
        case .success(.nothingToSave):
            phase = .composing
        case let .success(.needsConfirmation(pending)):
            phase = .confirming(pending)
        case let .success(.needsClarification(request)):
            phase = .clarifying(request)
        case .failure(.alreadySaved):
            // Nothing was lost and retrying cannot help, so the surface starts over.
            text = ""
            input = nil
            phase = .composing
            failure = .alreadySaved
        case .failure:
            // The step stays where it was, so the user can retry without typing again (REQ-CAPTURE-009).
            phase = previous
            failure = .notSaved
        }
    }

    private func fail(_ failure: PitCaptureFailure) {
        self.failure = failure
    }
}
