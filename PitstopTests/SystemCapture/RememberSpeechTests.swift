import Foundation
@testable import Pitstop
import Testing

private let speechNow = DomainFixtures.Odometers.baseDate

@Suite("Remember in PitStop speech")
struct RememberSpeechTests {
    private static let replies: [RememberReply] = [
        .saved(.notes, preservedRaw: true),
        .saved(.notes, preservedRaw: false),
        .saved(.service, preservedRaw: false),
        .saved(.history, preservedRaw: false),
        .saved(.carBoard, preservedRaw: false),
        .alreadySaved,
        .nothingToSave,
        .cancelled,
        .notSaved,
        .storageUnavailable,
    ]

    private static let questions: [RememberQuestion] = [
        .confirm(
            .maintenanceCompletion(operationID: .engineOilService, performedAt: speechNow, odometerKm: 84200),
            conflicts: []
        ),
        .confirm(
            .maintenanceCompletion(operationID: .brakeFluid, performedAt: speechNow, odometerKm: nil),
            conflicts: []
        ),
        .confirm(.odometerReading(kilometers: 85000, recordedAt: speechNow), conflicts: []),
        .confirm(
            .odometerReading(kilometers: 85000, recordedAt: speechNow),
            conflicts: [.odometerBelowLatest(latestKm: 91500)]
        ),
        .confirm(.vehicleEvent(kind: .carWash, date: speechNow, odometerKm: nil, amount: 450), conflicts: []),
        .confirm(
            .maintenancePolicy(operationID: .cabinFilter, distanceIntervalKm: 15000, timeIntervalMonths: nil),
            conflicts: []
        ),
        .confirm(.vehicleFact(VehicleFact(field: .name, value: "Arteon")), conflicts: []),
        .confirm(.note(text: "стук справа при повороте", contexts: []), conflicts: []),
        .clarify(.odometerKm),
        .value(.odometerKm, repeated: false),
        .value(.odometerKm, repeated: true),
        .value(.amount, repeated: false),
        .value(.amount, repeated: true),
        .pick(.operationID, options: MaintenanceOperationID.catalog.map(ClarificationAnswer.operation)),
        .pick(.eventKind, options: HistoryEventKind.userSelectable.map(ClarificationAnswer.eventKind)),
    ]

    private func spoken(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }

    @Test("REQ-CAPTURE-008, REQ-CAPTURE-010: every reply is translated in en, ru and uk", arguments: replies)
    func repliesAreTranslated(reply: RememberReply) {
        let texts = ["en", "ru", "uk"].map { spoken(RememberSpeech(locale: Locale(identifier: $0)).reply(reply)) }

        #expect(texts.allSatisfy { !$0.hasPrefix("intent.") && !$0.isEmpty })
        #expect(Set(texts).count == 3)
    }

    @Test("REQ-CAPTURE-010: saved replies name different destinations")
    func savedRepliesNameDestinations() {
        let speech = RememberSpeech(locale: Locale(identifier: "en"))
        let saved = Self.replies.prefix(5).map { spoken(speech.reply($0)) }

        #expect(Set(saved).count == saved.count)
    }

    @Test("REQ-CAPTURE-025: questions name kinds and values, never the words", arguments: questions)
    func questionsNeverRepeatWords(question: RememberQuestion) {
        for language in ["en", "ru", "uk"] {
            for voiceOnly in [false, true] {
                let speech = RememberSpeech(locale: Locale(identifier: language), isVoiceOnly: voiceOnly)
                let text = spoken(speech.question(question))
                #expect(!text.hasPrefix("intent.") && !text.isEmpty)
                #expect(!text.contains("стук") && !text.contains("Arteon"))
            }
        }
    }

    @Test("ADR-0026: a voice-only saved reply names PitStop with the destination, in every language")
    func voiceOnlyRepliesNameTheApp() {
        for language in ["en", "ru", "uk"] {
            let locale = Locale(identifier: language)
            let voice = Self.replies.prefix(5)
                .map { spoken(RememberSpeech(locale: locale, isVoiceOnly: true).reply($0)) }
            let screen = Self.replies.prefix(5).map { spoken(RememberSpeech(locale: locale).reply($0)) }

            #expect(voice.allSatisfy { $0.contains("PitStop") && !$0.hasPrefix("intent.") })
            #expect(Set(voice).count == voice.count)
            #expect(zip(voice, screen).allSatisfy { $0 != $1 })
        }
    }

    @Test("ADR-0026: replies other than a save read the same with or without a screen")
    func otherRepliesDoNotChange() {
        let locale = Locale(identifier: "en")
        for reply in Self.replies.dropFirst(5) {
            #expect(spoken(RememberSpeech(locale: locale, isVoiceOnly: true).reply(reply))
                == spoken(RememberSpeech(locale: locale).reply(reply)))
        }
    }

    @Test("ADR-0026: by voice, a number question says how to answer, including \"I don't know\"")
    func voiceOnlyNumberQuestionAddsHowToAnswer() {
        let question = RememberQuestion.value(.odometerKm, repeated: false)
        for language in ["en", "ru", "uk"] {
            let locale = Locale(identifier: language)
            let screen = spoken(RememberSpeech(locale: locale).question(question))
            let voice = spoken(RememberSpeech(locale: locale, isVoiceOnly: true).question(question))
            let unknown = spoken(RememberSpeech(locale: locale).unknownOption)

            #expect(voice.hasPrefix(screen) && voice.count > screen.count)
            #expect(voice.localizedCaseInsensitiveContains(unknown))
        }
    }

    @Test("ADR-0026: a repeated number question says the first answer was not understood")
    func repeatedQuestionDiffers() {
        let speech = RememberSpeech(locale: Locale(identifier: "en"))
        for field in [ProposalField.odometerKm, .amount] {
            #expect(spoken(speech.question(.value(field, repeated: true)))
                != spoken(speech.question(.value(field, repeated: false))))
        }
    }

    @Test("ADR-0026: offered answers carry the titles Pit shows, translated and distinct")
    func optionsAreTitled() {
        let answers = MaintenanceOperationID.catalog.map(ClarificationAnswer.operation)
            + HistoryEventKind.userSelectable.map(ClarificationAnswer.eventKind)
            + [.unknown]
        for language in ["en", "ru", "uk"] {
            let speech = RememberSpeech(locale: Locale(identifier: language))
            let titles = answers.compactMap { speech.option($0).map(spoken) }

            #expect(titles.count == answers.count)
            #expect(titles.allSatisfy { !$0.hasPrefix("operation.") && !$0.hasPrefix("history.") })
            #expect(Set(titles).count == titles.count)
        }
        #expect(RememberSpeech(locale: Locale(identifier: "en")).option(.odometerKm(1)) == nil)
    }

    @Test(
        "ADR-0026: \"I don't know\" is recognised in the request language as a whole answer",
        arguments: [
            ("en", "I don't know.", true),
            ("en", "I don’t know", true),
            ("en", "No idea", true),
            ("ru", "Не знаю", true),
            ("ru", "понятия не имею", true),
            ("uk", "Гадки не маю!", true),
            ("uk", "не знаю", true),
            ("ru", "не знаю, около 80 тысяч", false),
            ("en", "84200", false),
            ("en", "I know", false),
            ("ru", "не знаю, 84 200", false),
            ("en", "I don't know 84200", false),
        ]
    )
    func unknownIsRecognised(language: String, spoken text: String, expected: Bool) {
        #expect(RememberSpeech(locale: Locale(identifier: language)).isUnknown(text) == expected)
    }

    @Test("ADR-0023: a completion names the operation and the mileage; a lower reading names both readings")
    func questionsCarryTypedValues() {
        let speech = RememberSpeech(locale: Locale(identifier: "en"))

        let completion = spoken(speech.question(Self.questions[0]))
        let lower = spoken(speech.question(Self.questions[3]))

        // Numbers are spoken with the locale's grouping ("84,200"), so only the digits are compared.
        #expect(completion.filter(\.isNumber) == "84200" && !completion.contains("operation."))
        #expect(completion.contains(String(localized: LocalizedStringResource(
            "operation.engineOilService",
            locale: Locale(identifier: "en")
        ))))
        #expect(lower.filter(\.isNumber) == "8500091500")
    }
}
