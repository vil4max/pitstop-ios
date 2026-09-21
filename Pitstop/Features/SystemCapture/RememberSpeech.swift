import Foundation

/// Spoken text for `RememberInPitStopIntent`, in the request's locale. Every sentence stands on its
/// own without a screen, and none repeats what the person said (REQ-CAPTURE-025): it names kinds,
/// operations, and typed values only.
struct RememberSpeech {
    let locale: Locale

    func reply(_ reply: RememberReply) -> LocalizedStringResource {
        switch reply {
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
        }
    }

    var record: LocalizedStringResource {
        resource("intent.remember.choice.record")
    }

    var wordsOnly: LocalizedStringResource {
        resource("intent.remember.choice.wordsOnly")
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
        let key: String.LocalizationValue
        switch operation {
        case .engineOilService: key = "operation.engineOilService"
        case .dsgService: key = "operation.dsgService"
        case .awdCouplingService: key = "operation.awdCouplingService"
        case .brakeFluid: key = "operation.brakeFluid"
        case .cabinFilter: key = "operation.cabinFilter"
        case .airFilter: key = "operation.airFilter"
        case .sparkPlugs: key = "operation.sparkPlugs"
        default: return operation.rawValue
        }
        return String(localized: resource(key))
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
