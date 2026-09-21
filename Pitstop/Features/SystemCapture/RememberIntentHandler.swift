import Foundation

/// What PitStop asks before it writes from outside the app (ADR 0023).
enum RememberQuestion: Equatable, Sendable {
    /// A proposal that may be written only once the person accepts it (ADR 0006).
    case confirm(ValidatedContent, conflicts: [ProposalConflict])
    /// A detail is missing. It is not asked by voice yet (SYS-006), so only the words can be kept.
    case clarify(ProposalField)
}

enum RememberChoice: Equatable, Sendable {
    case record
    case wordsOnly
    case cancel
}

/// Asks the person one question in place. The intent maps this to Siri's choice prompt.
protocol RememberPrompting {
    /// Throws when the person dismissed the prompt; the capture is then discarded and the error rethrown.
    func choose(_ question: RememberQuestion) async throws -> RememberChoice
}

/// What the intent tells the person. It names destinations and kinds, never the words (REQ-CAPTURE-025).
enum RememberReply: Equatable, Sendable {
    case saved(PitDestination, preservedRaw: Bool)
    case alreadySaved
    case nothingToSave
    case cancelled
    /// Nothing was written. Siri cannot keep the words for a retry (owner decision, ADR 0023).
    case notSaved
    /// The on-disk store is not open; a save would vanish with the process (REQ-CAPTURE-009).
    case storageUnavailable
}

/// The testable body of `RememberInPitStopIntent`: it builds a `CaptureInput` and follows the same
/// pipeline as Pit (core C4). Every decision about meaning and writing stays in the pipeline.
struct RememberIntentHandler: Sendable {
    private let pipeline: RememberPipeline
    private let persistence: AppEnvironment.Persistence
    private let analytics: any AnalyticsPipelineControlling
    private let now: @Sendable () -> Date

    init(
        pipeline: RememberPipeline,
        persistence: AppEnvironment.Persistence,
        analytics: any AnalyticsPipelineControlling = NoAnalyticsPipeline(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.pipeline = pipeline
        self.persistence = persistence
        self.analytics = analytics
        self.now = now
    }

    /// A background run never reaches RootView's flush on leaving the app, so the intent sends what
    /// it queued itself (ADR 0023). Detached, so the spoken reply does not wait for the network; with
    /// analytics off the queue is empty or the pipeline is a no-op.
    @discardableResult
    func flushAnalytics() -> Task<Void, Never> {
        Task.detached(priority: .utility) { [analytics] in await analytics.flush() }
    }

    func remember(
        _ text: String,
        locale: Locale,
        prompter: some RememberPrompting
    ) async throws -> RememberReply {
        guard persistence == .durable else { return .storageUnavailable }
        // `.siri` covers every App Intents entry: no documented signal tells a voice run from a
        // Shortcuts or Spotlight run (ADR 0023). `.text`, because the intent receives a string.
        let input = CaptureInput(
            payload: .text(text),
            source: .siri,
            capturedAt: now(),
            localeIdentifier: locale.identifier
        )
        do {
            var outcome = try await pipeline.remember(input, mode: .interpreted)
            while true {
                switch outcome {
                case let .saved(result, preservedRaw):
                    return .saved(PitDestination(result), preservedRaw: preservedRaw)
                case .nothingToSave:
                    return Task.isCancelled ? .cancelled : .nothingToSave
                case let .needsConfirmation(pending):
                    let question = RememberQuestion.confirm(pending.content, conflicts: pending.conflicts)
                    switch try await ask(question, input: input, kind: pending.kind, prompter: prompter) {
                    case .record: outcome = try await pipeline.confirm(pending)
                    case .wordsOnly: outcome = try await pipeline.preserveRaw(input, kind: pending.kind)
                    case .cancel: return .cancelled
                    }
                case let .needsClarification(request):
                    switch try await ask(
                        .clarify(request.question),
                        input: input,
                        kind: request.kind,
                        prompter: prompter
                    ) {
                    case .wordsOnly: outcome = try await pipeline.preserveRaw(input, kind: request.kind)
                    // Recording needs the missing detail, which Siri does not ask yet.
                    case .record, .cancel: return .cancelled
                    }
                }
            }
        } catch let error as RememberError {
            return error == .alreadySaved ? .alreadySaved : .notSaved
        }
    }

    /// Cancel and dismissal both end the capture with no write (REQ-CAPTURE-005). A choice arriving
    /// after the intent task was cancelled is not acted on either.
    private func ask(
        _ question: RememberQuestion,
        input: CaptureInput,
        kind: ProposalKind,
        prompter: some RememberPrompting
    ) async throws -> RememberChoice {
        let choice: RememberChoice
        do {
            choice = try await prompter.choose(question)
        } catch {
            pipeline.cancel(input, kind: kind)
            throw error
        }
        if choice == .cancel || Task.isCancelled {
            pipeline.cancel(input, kind: kind)
            return .cancel
        }
        return choice
    }
}
