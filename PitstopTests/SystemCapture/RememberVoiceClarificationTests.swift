import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(30 * 86400)

/// SYS-006: the missing detail is asked by voice, one question at a time, and answered through the
/// same pipeline as Pit (ADR 0026).
@Suite("Remember in PitStop voice clarification")
struct RememberVoiceClarificationTests {
    @Test("REQ-CAPTURE-020, ADR-0026: a missing mileage is asked as a number, heard back, and recorded")
    func mileageIsAsked() async throws {
        let app = try RememberHarness(interpreter: .missing(.odometerReading))
        let prompter = FakePrompter(steps: [.answer(.spoken("84 200 km")), .choice(.record)])

        let reply = try await app.say("записал показания", prompter: prompter)

        #expect(
            prompter.questions == [
                .value(.odometerKm, repeated: false),
                .confirm(.odometerReading(kilometers: 84200, recordedAt: now), conflicts: []),
            ])
        #expect(reply == .saved(.carBoard, preservedRaw: false))
        #expect(try await app.readings().map(\.value) == [84200])
    }

    @Test(
        "REQ-CAPTURE-005, ADR-0026: a spoken mileage is never auto-accepted; cancelling its confirmation writes nothing"
    )
    func spokenMileageIsConfirmed() async throws {
        let app = try RememberHarness(interpreter: .missing(.odometerReading))
        let prompter = FakePrompter(steps: [.answer(.spoken("about 80")), .choice(.cancel)])

        let reply = try await app.say("записал показания", prompter: prompter)

        #expect(prompter.questions.last == .confirm(.odometerReading(kilometers: 80, recordedAt: now), conflicts: []))
        #expect(reply == .cancelled)
        #expect(try await app.isUnchanged())
    }

    @Test("ADR-0026: a mileage the validator would reject is asked again, not kept as words")
    func zeroMileageIsAskedAgain() async throws {
        let app = try RememberHarness(interpreter: .missing(.odometerReading))
        let prompter = FakePrompter(steps: [.answer(.spoken("0")), .answer(.spoken("91500")), .choice(.record)])

        let reply = try await app.say("записал показания", prompter: prompter)

        #expect(
            prompter.questions.prefix(2) == [
                .value(.odometerKm, repeated: false),
                .value(.odometerKm, repeated: true),
            ])
        #expect(reply == .saved(.carBoard, preservedRaw: false))
        #expect(try await app.readings().map(\.value) == [91500])
    }

    @Test("ADR-0026: \"80 thousand\" is not read as 80 km; it is asked again")
    func multiplierWordIsAskedAgain() async throws {
        let app = try RememberHarness(interpreter: .missing(.odometerReading))
        let prompter = FakePrompter(steps: [
            .answer(.spoken("I don't know, about 80 thousand")),
            .answer(.unknown),
        ])

        let reply = try await app.say("записал показания", prompter: prompter)

        #expect(
            prompter.questions == [
                .value(.odometerKm, repeated: false),
                .value(.odometerKm, repeated: true),
            ])
        #expect(reply == .saved(.notes, preservedRaw: true))
        #expect(try await app.readings().isEmpty)
    }

    @Test("REQ-CAPTURE-020, ADR-0026: a missing operation is chosen from the catalog, then confirmed on its own")
    func operationIsChosenThenConfirmed() async throws {
        let app = try RememberHarness(interpreter: .missing(.maintenanceCompletion, odometerKm: 84200))
        let prompter = FakePrompter(steps: [.answer(.picked(.operation(.engineOilService))), .choice(.record)])

        let reply = try await app.say("сделал работу на 84200", prompter: prompter)

        let catalog = MaintenanceOperationID.catalog.map(ClarificationAnswer.operation)
        #expect(
            prompter.questions == [
                .pick(.operationID, options: catalog),
                .confirm(
                    .maintenanceCompletion(operationID: .engineOilService, performedAt: now, odometerKm: 84200),
                    conflicts: []
                ),
            ])
        #expect(reply == .saved(.service, preservedRaw: false))
        #expect(try await app.completions().map(\.operationID) == [.engineOilService])
    }

    @Test("REQ-CAPTURE-020, ADR-0026: a missing event kind is chosen from the kinds Pit offers")
    func eventKindIsChosen() async throws {
        let app = try RememberHarness(interpreter: .missing(.vehicleEvent))
        let prompter = FakePrompter(steps: [.answer(.picked(.eventKind(.carWash))), .choice(.record)])

        let reply = try await app.say("было событие", prompter: prompter)

        #expect(
            prompter.questions.first
                == .pick(
                    .eventKind,
                    options: HistoryEventKind.userSelectable.map(ClarificationAnswer.eventKind)
                ))
        #expect(prompter.questions.count == 2)
        #expect(reply == .saved(.history, preservedRaw: false))
        #expect(try await app.events().map(\.kind) == [.carWash])
    }

    @Test("REQ-CAPTURE-020, ADR-0026: a missing amount is asked as a number and read like Pit reads it")
    func amountIsAsked() async throws {
        let app = try RememberHarness(interpreter: .missing(.expense))
        let prompter = FakePrompter(steps: [.answer(.spoken("1 500 ₽")), .choice(.record)])

        let reply = try await app.say("заплатил за мойку", prompter: prompter)

        #expect(prompter.questions.first == .value(.amount, repeated: false))
        #expect(reply == .saved(.history, preservedRaw: false))
        #expect(try await app.events().map(\.amount) == [1500])
    }

    @Test("ADR-0026: an unreadable number is asked once more, and a readable second answer is recorded")
    func unreadableNumberIsAskedAgain() async throws {
        let app = try RememberHarness(interpreter: .missing(.odometerReading))
        let prompter = FakePrompter(steps: [
            .answer(.spoken("около того")),
            .answer(.spoken("91500")),
            .choice(.record),
        ])

        let reply = try await app.say("записал показания", prompter: prompter)

        #expect(
            prompter.questions.prefix(2) == [
                .value(.odometerKm, repeated: false),
                .value(.odometerKm, repeated: true),
            ])
        #expect(prompter.questions.count == 3)
        #expect(reply == .saved(.carBoard, preservedRaw: false))
        #expect(try await app.readings().map(\.value) == [91500])
    }

    @Test("REQ-CAPTURE-008, ADR-0026: two unreadable numbers keep the words, as \"I don't know\" would")
    func twoUnreadableNumbersKeepWords() async throws {
        let app = try RememberHarness(interpreter: .missing(.odometerReading))
        let prompter = FakePrompter(steps: [.answer(.spoken("много")), .answer(.spoken("84.5"))])

        let reply = try await app.say("записал показания", prompter: prompter)

        #expect(prompter.questions.count == 2)
        #expect(reply == .saved(.notes, preservedRaw: true))
        #expect(try await app.notes().map(\.rawText) == ["записал показания"])
        #expect(try await app.readings().isEmpty)
    }

    @Test(
        "REQ-CAPTURE-008, ADR-0026: \"I don't know\" keeps the words without the structure",
        arguments: [ProposalKind.odometerReading, .maintenanceCompletion]
    )
    func unknownKeepsWords(kind: ProposalKind) async throws {
        let app = try RememberHarness(interpreter: .missing(kind))
        let prompter = FakePrompter(steps: [.answer(.unknown)])

        let reply = try await app.say("что-то сделал", prompter: prompter)

        #expect(prompter.questions.count == 1)
        #expect(reply == .saved(.notes, preservedRaw: true))
        #expect(try await app.notes().map(\.rawText) == ["что-то сделал"])
        #expect(try await app.completions().isEmpty)
        #expect(try await app.readings().isEmpty)
    }

    @Test("REQ-CAPTURE-005, ADR-0026: cancelling the second question writes nothing from the first answer")
    func cancelMidClarificationWritesNothing() async throws {
        let app = try RememberHarness(interpreter: .missing(.maintenancePolicyDraft))
        let prompter = FakePrompter(steps: [.answer(.picked(.operation(.cabinFilter))), .choice(.cancel)])

        let reply = try await app.say("менять фильтр чаще", prompter: prompter)

        #expect(
            prompter.questions == [
                .pick(.operationID, options: MaintenanceOperationID.catalog.map(ClarificationAnswer.operation)),
                .clarify(.policyInterval),
            ])
        #expect(reply == .cancelled)
        #expect(try await app.isUnchanged())
        #expect(app.stages.events.filter { $0.stage == .captureDiscarded }.count == 1)
    }

    @Test("REQ-CAPTURE-005, ADR-0026: a dismissed number prompt writes nothing and reaches the system")
    func dismissedValuePromptWritesNothing() async throws {
        let app = try RememberHarness(interpreter: .missing(.odometerReading))

        await #expect(throws: PromptDismissed.self) {
            try await app.say("записал показания", prompter: FakePrompter(failingWith: PromptDismissed()))
        }

        #expect(try await app.isUnchanged())
        #expect(app.stages.events.last?.stage == .captureDiscarded)
    }

    @Test("REQ-CAPTURE-025, ADR-0026: no question asked on the way repeats the words, on screen or by voice")
    func askedQuestionsNeverRepeatWords() async throws {
        let words = "стук справа при повороте"
        let app = try RememberHarness(interpreter: .missing(.maintenanceCompletion))
        let prompter = FakePrompter(steps: [
            .answer(.picked(.operation(.brakeFluid))),
            .choice(.wordsOnly),
        ])

        _ = try await app.say(words, prompter: prompter)

        #expect(prompter.questions.count == 2)
        for question in prompter.questions {
            for language in ["en", "ru", "uk"] {
                for voiceOnly in [false, true] {
                    let speech = RememberSpeech(locale: Locale(identifier: language), isVoiceOnly: voiceOnly)
                    #expect(!String(localized: speech.question(question)).contains("стук"))
                }
            }
        }
    }

    @Test(
        "ADR-0026: spoken numbers are read with Pit's parsers",
        arguments: [
            ("84 200 km", ProposalField.odometerKm, ClarificationAnswer.odometerKm(84200)),
            ("84,200", .odometerKm, .odometerKm(84200)),
            ("пробег 91500 км.", .odometerKm, .odometerKm(91500)),
            ("1500 ₽", .amount, .amount(1500)),
            ("1,200", .amount, .amount(1200)),
            ("12,50", .amount, .amount(Decimal(1250) / 100)),
            ("1.234", .amount, .amount(1234)),
            ("84200 kilometres", .odometerKm, .odometerKm(84200)),
            ("84 200 километров", .odometerKm, .odometerKm(84200)),
            ("1500 rubles", .amount, .amount(1500)),
            ("1500 рублей", .amount, .amount(1500)),
            ("1500 р.", .amount, .amount(1500)),
            ("200 грв", .amount, .amount(200)),
            ("200 грн", .amount, .amount(200)),
            ("50 USD", .amount, .amount(50)),
        ] as [(String, ProposalField, ClarificationAnswer?)]
    )
    func spokenNumbersAreRead(text: String, field: ProposalField, expected: ClarificationAnswer?) {
        #expect(RememberIntentHandler.clarificationAnswer(text, for: field) == expected)
    }

    @Test(
        "ADR-0026: what Pit would reject is not guessed",
        arguments: [
            ("84.5", ProposalField.odometerKm),
            ("много", .odometerKm),
            ("9 999 999", .odometerKm),
            ("0", .amount),
            ("12.3.4", .amount),
            ("84k", .odometerKm),
            ("84 thousand", .odometerKm),
            ("84 тысячи", .odometerKm),
            ("1.5 thousand", .amount),
            ("I don't know, about 80 thousand", .odometerKm),
            ("0", .odometerKm),
            ("1500 km", .amount),
            ("", .amount),
        ] as [(String, ProposalField)]
    )
    func unreadableNumbersAreRejected(text: String, field: ProposalField) {
        #expect(RememberIntentHandler.clarificationAnswer(text, for: field) == nil)
    }
}
