import AppIntents

/// The App Intents entry for Remember (ADR 0023). It only collects the words and speaks the result;
/// `RememberIntentHandler` runs the capture through the same pipeline as Pit (REQ-CAPTURE-002, 003).
struct RememberInPitStopIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.remember.title"
    static let description = IntentDescription("intent.remember.description")
    /// Never opens the app: confirmation is asked in place (ADR 0023).
    static let supportedModes: IntentModes = .background
    /// The store lives in the app's own container, so the intent runs in the app process only.
    static let allowedExecutionTargets: IntentExecutionTargets = .main
    /// Owner decision: capture only from an unlocked phone, whatever device the request came from.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "intent.remember.parameter", requestValueDialog: "intent.remember.ask")
    var text: String

    @Dependency private var handler: RememberIntentHandler

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let speech = RememberSpeech(locale: systemContext.locale)
        defer { handler.flushAnalytics() }
        let reply = try await handler.remember(text, locale: speech.locale, prompter: SiriPrompter(
            intent: self,
            speech: speech
        ))
        switch reply {
        case .notSaved, .storageUnavailable:
            // A thrown error marks the run as failed in Shortcuts; Siri speaks its description.
            throw AppIntentError(description: speech.reply(reply))
        case .saved, .alreadySaved, .nothingToSave, .cancelled:
            return .result(dialog: IntentDialog(speech.reply(reply)))
        }
    }
}

/// Maps a question to Siri's choice prompt. `requestChoice` throws when the person picks Cancel or
/// dismisses the prompt, so a returned Cancel option is only a fallback.
private struct SiriPrompter: RememberPrompting {
    let intent: RememberInPitStopIntent
    let speech: RememberSpeech

    func choose(_ question: RememberQuestion) async throws -> RememberChoice {
        let record = IntentChoiceOption(title: speech.record)
        let wordsOnly = IntentChoiceOption(title: speech.wordsOnly)
        let offered: [(option: IntentChoiceOption, choice: RememberChoice)] = switch question {
        case .confirm: [(record, .record), (wordsOnly, .wordsOnly), (.cancel, .cancel)]
        case .clarify: [(wordsOnly, .wordsOnly), (.cancel, .cancel)]
        }
        let options = offered.map(\.option)
        let chosen = try await intent.requestChoice(between: options, dialog: IntentDialog(speech.question(question)))
        // Mapped by the position of the returned option among those offered. Whether the system returns
        // an option equal to the one offered is a SYS-006 device check (ADR 0023); until then an
        // unmatched option is logged and writes nothing.
        guard let index = options.firstIndex(of: chosen) else {
            AppLog.logger(category: "intent.remember").error("Unmatched choice option; treated as cancel")
            return .cancel
        }
        return offered[index].choice
    }
}
