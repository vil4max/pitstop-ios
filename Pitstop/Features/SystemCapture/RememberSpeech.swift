import Foundation

/// Spoken text for `RememberInPitStopIntent`, in the request's locale. Every sentence stands on its
/// own without a screen, and none repeats what the person said (REQ-CAPTURE-025): it names kinds,
/// operations, and typed values only.
struct RememberSpeech {
    let locale: Locale
    /// No screen at all (`systemContext.isVoiceOnly`): saved replies name the app with the destination,
    /// and number questions say how to answer, because no keyboard or "I don't know" button shows
    /// (ADR 0026).
    var isVoiceOnly = false

    func reply(_ reply: RememberReply) -> LocalizedStringResource {
        if isVoiceOnly, let spoken = voiceReply(reply) {
            return spoken
        }
        return switch reply {
        case .saved(_, preservedRaw: true): resource("intent.remember.reply.savedAsSaid")
        case .saved(.notes, preservedRaw: false): resource("intent.remember.reply.savedToNotes")
        case .saved(.service, preservedRaw: false): resource("intent.remember.reply.savedToService")
        case .saved(.history, preservedRaw: false): resource("intent.remember.reply.savedToHistory")
        case .saved(.carBoard, preservedRaw: false): resource("intent.remember.reply.savedToCarBoard")
        case .alreadySaved: resource("intent.remember.reply.alreadySaved")
        case .nothingToSave: resource("intent.remember.reply.nothingToSave")
        case .cancelled: resource("intent.remember.reply.cancelled")
        case .notSaved: resource("intent.remember.reply.notSaved")
        case .storageUnavailable: resource("intent.remember.reply.storageUnavailable")
        }
    }

    func question(_ question: RememberQuestion) -> LocalizedStringResource {
        switch question {
        case let .confirm(content, conflicts):
            if let latest = conflicts.lowerReading, case let .odometerReading(kilometers, _) = content {
                return resource(
                    "intent.remember.confirm.lowerReading \(Int(kilometers.rounded())) \(Int(latest.rounded()))"
                )
            }
            return confirmation(content)
        case .clarify:
            return resource("intent.remember.clarify")
        case let .value(field, repeated):
            let asked = valueQuestion(field, repeated: repeated)
            guard isVoiceOnly else { return asked }
            return resource("intent.remember.ask.voiceHint \(String(localized: asked))")
        case .pick(.operationID, _):
            return resource("intent.remember.ask.operationID")
        case .pick(.eventKind, _):
            return resource("intent.remember.ask.eventKind")
        case .pick:
            return resource("intent.remember.clarify")
        }
    }

    /// The title of one offered answer, as Pit shows it. Nil for answers that are never offered as a choice.
    func option(_ answer: ClarificationAnswer) -> LocalizedStringResource? {
        switch answer {
        // An ID without a title is offered as it is stored, as the Service screen shows it.
        case let .operation(operation): resource(operationKey(operation) ?? String
                .LocalizationValue(operation.rawValue))
        case let .eventKind(kind): resource(eventKindKey(kind))
        case .unknown: unknownOption
        case .odometerKm, .amount, .policyInterval: nil
        }
    }

    var unknownOption: LocalizedStringResource {
        resource("pit.clarify.unknown")
    }

    /// Whether a spoken answer means "I don't know" in the request's language. The phrases are a
    /// localized list, compared whole after dropping case and punctuation, so "I don't know." matches
    /// and "I don't know, about 80 thousand" does not. Any digit means a number was said.
    func isUnknown(_ spoken: String) -> Bool {
        guard !spoken.contains(where: \.isNumber) else { return false }
        let phrases = String(localized: resource("intent.remember.answer.unknown"))
            .split(separator: "|")
            .map { normalized(String($0)) }
        return phrases.contains(normalized(spoken))
    }

    var record: LocalizedStringResource {
        resource("intent.remember.choice.record")
    }

    var wordsOnly: LocalizedStringResource {
        resource("intent.remember.choice.wordsOnly")
    }

    private func voiceReply(_ reply: RememberReply) -> LocalizedStringResource? {
        switch reply {
        case .saved(_, preservedRaw: true): resource("intent.remember.reply.voice.savedAsSaid")
        case .saved(.notes, preservedRaw: false): resource("intent.remember.reply.voice.savedToNotes")
        case .saved(.service, preservedRaw: false): resource("intent.remember.reply.voice.savedToService")
        case .saved(.history, preservedRaw: false): resource("intent.remember.reply.voice.savedToHistory")
        case .saved(.carBoard, preservedRaw: false): resource("intent.remember.reply.voice.savedToCarBoard")
        case .alreadySaved, .nothingToSave, .cancelled, .notSaved, .storageUnavailable: nil
        }
    }

    private func valueQuestion(_ field: ProposalField, repeated: Bool) -> LocalizedStringResource {
        switch (field, repeated) {
        case (.amount, false): resource("intent.remember.ask.amount")
        case (.amount, true): resource("intent.remember.ask.amount.again")
        case (_, false): resource("intent.remember.ask.odometerKm")
        case (_, true): resource("intent.remember.ask.odometerKm.again")
        }
    }

    private func normalized(_ text: String) -> String {
        let kept = text.lowercased(with: locale)
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .unicodeScalars
            .map { CharacterSet.letters.contains($0) || $0 == "'" ? Character($0) : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    private func confirmation(_ content: ValidatedContent) -> LocalizedStringResource {
        switch content {
        case let .maintenanceCompletion(operation, _, kilometers?):
            resource("intent.remember.confirm.completionAt \(operationName(operation)) \(kilometers)")
        case let .maintenanceCompletion(operation, _, nil):
            resource("intent.remember.confirm.completion \(operationName(operation))")
        case let .odometerReading(kilometers, _):
            resource("intent.remember.confirm.reading \(Int(kilometers.rounded()))")
        case .vehicleEvent, .expense:
            resource("intent.remember.confirm.event")
        case let .maintenancePolicy(operation, _, _):
            resource("intent.remember.confirm.policy \(operationName(operation))")
        case .vehicleFact:
            resource("intent.remember.confirm.fact")
        case .note:
            resource("intent.remember.confirm.note")
        }
    }

    /// Resolved here, in the same locale as the sentence around it. An ID without a title is
    /// spoken as it is stored, as the Service screen shows it.
    private func operationName(_ operation: MaintenanceOperationID) -> String {
        guard let key = operationKey(operation) else { return operation.rawValue }
        return String(localized: resource(key))
    }

    private func operationKey(_ operation: MaintenanceOperationID) -> String.LocalizationValue? {
        switch operation {
        case .engineOilService: "operation.engineOilService"
        case .dsgService: "operation.dsgService"
        case .awdCouplingService: "operation.awdCouplingService"
        case .brakeFluid: "operation.brakeFluid"
        case .cabinFilter: "operation.cabinFilter"
        case .airFilter: "operation.airFilter"
        case .sparkPlugs: "operation.sparkPlugs"
        default: nil
        }
    }

    private func eventKindKey(_ kind: HistoryEventKind) -> String.LocalizationValue {
        switch kind {
        case .service: "history.kind.service"
        case .carWash: "history.kind.carWash"
        case .odometer: "history.kind.odometer"
        case .insurance: "history.kind.insurance"
        case .purchase: "history.kind.purchase"
        case .other: "history.kind.other"
        }
    }

    private func resource(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, locale: locale)
    }
}

private extension [ProposalConflict] {
    var lowerReading: Double? {
        for conflict in self {
            if case let .odometerBelowLatest(latestKm) = conflict {
                return latestKm
            }
        }
        return nil
    }
}
