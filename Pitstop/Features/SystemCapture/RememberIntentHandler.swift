import Foundation

/// What PitStop asks before it writes from outside the app (ADR 0023, ADR 0026). One question at a
/// time: the next one is asked only after the previous answer went through the pipeline (REQ-CAPTURE-020).
enum RememberQuestion: Equatable, Sendable {
    /// A proposal that may be written only once the person accepts it (ADR 0006). Asked with `choose`.
    case confirm(ValidatedContent, conflicts: [ProposalConflict])
    /// A detail that cannot be answered in one spoken step (a vehicle fact, an interval), so only the
    /// words can be kept. Asked with `choose`.
    case clarify(ProposalField)
    /// A number: the mileage or the amount. `repeated` after an answer that could not be read.
    /// Asked with `answer`.
    case value(ProposalField, repeated: Bool)
    /// One of a known list: an operation from the catalog or an event kind. Asked with `answer`.
    /// `forDashboardReading` asks which service the car means rather than what was done (ADR 0035).
    case pick(ProposalField, options: [ClarificationAnswer], forDashboardReading: Bool = false)
}

enum RememberChoice: Equatable, Sendable {
    case record
    case wordsOnly
    case cancel
}

/// An answer to a clarification question.
enum RememberAnswer: Equatable, Sendable {
    /// What the person said or typed for a number; the handler reads it as Pit does.
    case spoken(String)
    case picked(ClarificationAnswer)
    /// "I don't know" is a valid answer (core C2): the words are kept without the structure.
    case unknown
    case cancel
}

/// Asks the person one question in place. The intent maps these to Siri's prompts.
protocol RememberPrompting {
    /// Throws when the person dismissed the prompt; the capture is then discarded and the error rethrown.
    func choose(_ question: RememberQuestion) async throws -> RememberChoice
    /// Same contract as `choose`, for `.value` and `.pick` questions.
    func answer(_ question: RememberQuestion) async throws -> RememberAnswer
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
    private let persistence: PersistenceMode
    private let analytics: any AnalyticsPipelineControlling
    private let now: @Sendable () -> Date

    init(
        pipeline: RememberPipeline,
        persistence: PersistenceMode,
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
                    guard let next = try await clarify(request, input: input, prompter: prompter) else {
                        return .cancelled
                    }
                    outcome = next
                }
            }
        } catch let error as RememberError {
            return error == .alreadySaved ? .alreadySaved : .notSaved
        }
    }

    /// Asks for the one missing field and hands the answer to the pipeline, which may ask the next one.
    /// Nil when the person cancelled; nothing was written then.
    private func clarify(
        _ request: ClarificationRequest,
        input: CaptureInput,
        prompter: some RememberPrompting
    ) async throws -> RememberOutcome? {
        let field = request.question
        let kind = request.kind
        switch field {
        case .odometerKm, .amount:
            // An unreadable number is asked once more; a second one keeps the words, as "I don't know"
            // would (ADR 0026). Re-asking without end would only run into the system time limit.
            for repeated in [false, true] {
                let answer = try await ask(.cancel, input: input, kind: kind) {
                    try await prompter.answer(.value(field, repeated: repeated))
                }
                switch answer {
                case let .spoken(text)?:
                    // A misheard number would otherwise be written without the person hearing it back.
                    if let parsed = Self.clarificationAnswer(text, for: field) {
                        return try await pipeline.answer(request, with: parsed, confirmBeforeWriting: true)
                    }
                case .unknown?:
                    return try await pipeline.answer(request, with: .unknown)
                case .picked?, .cancel?:
                    return cancelled(input, kind: kind)
                case nil:
                    return nil
                }
            }
            return try await pipeline.answer(request, with: .unknown)
        case .operationID, .eventKind:
            let options = Self.options(for: field)
            let answer = try await ask(.cancel, input: input, kind: kind) {
                try await prompter.answer(.pick(
                    field, options: options, forDashboardReading: kind == .vehicleServiceReport
                ))
            }
            switch answer {
            case let .picked(choice)? where options.contains(choice):
                return try await pipeline.answer(request, with: choice)
            case .unknown?:
                return try await pipeline.answer(request, with: .unknown)
            case .picked?, .spoken?, .cancel?:
                return cancelled(input, kind: kind)
            case nil:
                return nil
            }
        case .vehicleFact, .policyInterval, .remainingValue:
            let choice = try await ask(.cancel, input: input, kind: kind) {
                try await prompter.choose(.clarify(field))
            }
            // Recording needs a detail that is not asked by voice; only the words can be kept.
            switch choice {
            case .wordsOnly?: return try await pipeline.preserveRaw(input, kind: kind)
            case .record?, .cancel?: return cancelled(input, kind: kind)
            case nil: return nil
            }
        }
    }

    /// The same choices Pit offers for the field (PitCaptureView).
    static func options(for field: ProposalField) -> [ClarificationAnswer] {
        switch field {
        case .operationID: MaintenanceOperationID.catalog.map(ClarificationAnswer.operation)
        case .eventKind: HistoryEventKind.userSelectable.map(ClarificationAnswer.eventKind)
        case .odometerKm, .amount, .vehicleFact, .policyInterval, .remainingValue: []
        }
    }

    /// Reads a spoken number with Pit's parsers. Speech arrives with words around the digits
    /// ("84 200 km", "1500 ₽"), so only the digits and what lies between them are parsed. A word after
    /// the number must be a unit: "84 thousand" or "84k" would otherwise be read a thousand times too
    /// small, so it is unreadable and asked again. A grouped whole amount ("1,200") is accepted too:
    /// dictation groups thousands, and three digits after a separator are never a fraction of money.
    /// A mileage below 1 km is unreadable as well, so the repeat applies instead of a silent
    /// fallback to the words (ADR 0026).
    static func clarificationAnswer(_ text: String, for field: ProposalField) -> ClarificationAnswer? {
        guard let first = text.firstIndex(where: \.isASCIIDigit),
              let last = text.lastIndex(where: \.isASCIIDigit),
              onlyUnitsFollow(text[text.index(after: last)...], for: field)
        else { return nil }
        let number = String(text[first ... last])
        switch field {
        case .odometerKm:
            guard let kilometers = InputParsing.kilometers(from: number).intValue,
                  kilometers >= 1,
                  DomainCommandLimits.isPlausibleOdometer(Double(kilometers))
            else { return nil }
            return .odometerKm(Double(kilometers))
        case .amount:
            if case let .value(amount) = InputParsing.amount(from: number) {
                return .amount(amount)
            }
            return WholeNumberInput.parsePositive(number, upTo: Int(Int32.max)).intValue.map { .amount(Decimal($0)) }
        case .operationID, .eventKind, .vehicleFact, .policyInterval, .remainingValue:
            return nil
        }
    }

    /// Unit words a spoken number may end with, matched as word prefixes so inflected forms count.
    /// Symbols such as "₽" are not letters and never make an answer unreadable.
    private static let unitStems: [ProposalField: [String]] = [
        .odometerKm: ["km", "kilomet", "км", "километр", "кілометр"],
        .amount: [
            "rub", "руб", "uah", "hryvn", "грн", "гривн", "гривен", "eur", "евро", "євро", "usd", "dollar", "доллар",
            "долар",
        ],
    ]

    /// Abbreviations too short to match as prefixes without catching unrelated words.
    private static let unitAbbreviations: [ProposalField: Set<String>] = [
        .amount: ["р", "руб", "грв"],
    ]

    private static func onlyUnitsFollow(_ tail: Substring, for field: ProposalField) -> Bool {
        let stems = unitStems[field] ?? []
        let abbreviations = unitAbbreviations[field] ?? []
        let words = tail.lowercased().split { !$0.isLetter }
        return words.allSatisfy { word in
            abbreviations.contains(String(word)) || stems.contains { word.hasPrefix($0) }
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
        let choice = try await ask(.cancel, input: input, kind: kind) { try await prompter.choose(question) }
        return choice ?? .cancel
    }

    /// Nil when the person cancelled or the intent task was cancelled while the prompt was open.
    private func ask<Answer: Equatable>(
        _ cancel: Answer,
        input: CaptureInput,
        kind: ProposalKind,
        _ prompt: () async throws -> Answer
    ) async throws -> Answer? {
        let answer: Answer
        do {
            answer = try await prompt()
        } catch {
            pipeline.cancel(input, kind: kind)
            throw error
        }
        guard answer != cancel, !Task.isCancelled else {
            pipeline.cancel(input, kind: kind)
            return nil
        }
        return answer
    }

    private func cancelled(_ input: CaptureInput, kind: ProposalKind) -> RememberOutcome? {
        pipeline.cancel(input, kind: kind)
        return nil
    }
}

private extension Character {
    var isASCIIDigit: Bool {
        isASCII && isNumber
    }
}
