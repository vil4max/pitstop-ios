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
            let text = spoken(RememberSpeech(locale: Locale(identifier: language)).question(question))
            #expect(!text.hasPrefix("intent.") && !text.isEmpty)
            #expect(!text.contains("стук") && !text.contains("Arteon"))
        }
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
