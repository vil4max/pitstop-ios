import Foundation
@testable import Pitstop
import SwiftUI
import Testing

private let now = DomainFixtures.Odometers.baseDate

@MainActor
@Suite("Pit capture sheet moment")
struct PitSheetMomentTests {
    private func moment(_ model: PitCaptureViewModel, question: PitQuestionPhase = .silent) -> PitSheetMoment {
        PitSheetMoment(capture: model.phase, question: question)
    }

    @Test("REQ-PIT-021: across several captures in one sheet session the sheet shows only the current moment")
    func sequenceShowsOnlyTheCurrentMoment() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.pitCapture(store, now: now)
        #expect(moment(model) == .composing(.none))

        model.text = "Спросить про пятно на заднем сиденье"
        await model.submit(from: .carBoard)
        #expect(moment(model) == .saved(.notes, preservedRaw: true))

        model.reset()
        #expect(moment(model) == .composing(.none))

        model.text = "поменял масло на 85000"
        await model.submit(from: .service)
        guard case let .confirming(pending) = moment(model) else {
            Issue.record("expected a confirmation, got \(moment(model))")
            return
        }
        // The confirmation carries this capture's words only, not the note saved before it.
        #expect(pending.rawText == "поменял масло на 85000")

        await model.confirm()
        #expect(moment(model) == .saved(.service, preservedRaw: false))

        model.reset()
        #expect(moment(model) == .composing(.none))
    }

    @Test("REQ-PIT-021: each moment has its own title")
    func eachMomentHasItsTitle() {
        let capture = CaptureInput(payload: .text("записал показания"), source: .pitText, capturedAt: now)
        let draft = MemoryProposal(sourceInputID: capture.id, kind: .odometerReading, rawText: "записал показания")
        let request = ClarificationRequest(input: capture, proposal: draft, question: .odometerKm, remaining: [])

        #expect(PitSheetMoment(capture: .composing, question: .silent).title == .remember)
        #expect(PitSheetMoment(capture: .working, question: .silent).title == .remember)
        #expect(PitSheetMoment(capture: .clarifying(request), question: .silent).title == .oneThing)
        #expect(PitSheetMoment(capture: .saved(.history, preservedRaw: false), question: .silent).title == .saved)
        #expect(PitSheetMoment(capture: .saved(.notes, preservedRaw: true), question: .silent).title == .saved)
    }

    @Test("REQ-PIT-021: a confirmation is titled as the question it asks")
    func confirmationTitle() async {
        let model = TestViewModels.pitCapture(FakeCarMemoryStore(), now: now)
        model.text = "поменял масло на 85000"
        await model.submit(from: .service)

        #expect(moment(model).title == .isThisRight)
    }

    @Test("REQ-PIT-003, ADR-0017: Pit's pending question sits above the composer and waits during a clarification")
    func oneQuestionAtATime() {
        let asked = PitAskedQuestion.currentMileage(lastKnownKm: 42500)
        let capture = CaptureInput(payload: .text("записал показания"), source: .pitText, capturedAt: now)
        let draft = MemoryProposal(sourceInputID: capture.id, kind: .odometerReading, rawText: "записал показания")
        let request = ClarificationRequest(input: capture, proposal: draft, question: .odometerKm, remaining: [])

        #expect(PitSheetMoment(capture: .composing, question: .asking(asked)) == .composing(.question(asked)))
        #expect(PitSheetMoment(capture: .composing, question: .working(asked)) == .composing(.question(asked)))
        #expect(PitSheetMoment(capture: .composing, question: .answered(kilometers: 43100))
            == .composing(.answered(kilometers: 43100)))
        // The capture's own clarification is the one question on screen; Pit's question is not drawn beside it.
        #expect(PitSheetMoment(capture: .clarifying(request), question: .asking(asked)) == .clarifying(request))
        #expect(PitSheetMoment(capture: .working, question: .asking(asked)) == .working)
    }

    @Test(
        "Capture section, REQ-PIT-025: while the user writes, Remember is pinned above the keyboard at every text size",
        arguments: DynamicTypeSize.allCases
    )
    func rememberIsPinnedWhileWriting(size: DynamicTypeSize) {
        #expect(PitSheetMoment(capture: .composing, question: .silent).rememberAction(at: size)?.placement == .pinned)
        #expect(PitSheetMoment(capture: .composing, question: .answered(kilometers: 43100)).rememberAction(at: size)?
            .placement == .pinned)
    }

    @Test(
        "REQ-PIT-025: with Pit's question pending or its answer saving at an accessibility size, Remember stays pinned above the keyboard",
        arguments: DynamicTypeSize.allCases.filter(\.isAccessibilitySize)
    )
    func rememberIsPinnedWithAQuestionAtAccessibilitySizes(size: DynamicTypeSize) {
        let asked = PitAskedQuestion.currentMileage(lastKnownKm: 42500)

        #expect(PitSheetMoment(capture: .composing, question: .asking(asked)).rememberAction(at: size)?
            .placement == .pinned)
        #expect(PitSheetMoment(capture: .composing, question: .working(asked)).rememberAction(at: size)?
            .placement == .pinned)
    }

    @Test(
        "Capture section: below the accessibility sizes, with Pit's question pending or its answer saving, Remember stays under the composer, not pinned over the question card",
        arguments: DynamicTypeSize.allCases.filter { !$0.isAccessibilitySize }
    )
    func rememberIsInlineWithAQuestion(size: DynamicTypeSize) {
        let asked = PitAskedQuestion.currentMileage(lastKnownKm: 42500)

        #expect(PitSheetMoment(capture: .composing, question: .asking(asked)).rememberAction(at: size)?
            .placement == .inline)
        #expect(PitSheetMoment(capture: .composing, question: .working(asked)).rememberAction(at: size)?
            .placement == .inline)
    }

    @Test(
        "Capture section (one prominent action): with Pit's question pending, its Save is the prominent action and Remember is quiet; otherwise Remember is prominent",
        arguments: DynamicTypeSize.allCases
    )
    func oneProminentAction(size: DynamicTypeSize) {
        let asked = PitAskedQuestion.currentMileage(lastKnownKm: 42500)

        #expect(PitSheetMoment(capture: .composing, question: .asking(asked)).rememberAction(at: size)?
            .isProminent == false)
        #expect(PitSheetMoment(capture: .composing, question: .working(asked)).rememberAction(at: size)?
            .isProminent == false)
        #expect(PitSheetMoment(capture: .composing, question: .silent).rememberAction(at: size)?.isProminent == true)
        #expect(PitSheetMoment(capture: .composing, question: .answered(kilometers: 43100)).rememberAction(at: size)?
            .isProminent == true)
    }

    @Test("REQ-PIT-021: outside the composing moment there is no Remember action")
    func noRememberOutsideComposing() {
        #expect(PitSheetMoment(capture: .working, question: .silent).rememberAction(at: .large) == nil)
        #expect(PitSheetMoment(capture: .saved(.notes, preservedRaw: true), question: .silent)
            .rememberAction(at: .accessibility5) == nil)
    }

    @Test("REQ-CAPTURE-005: Close on the composer cancels the unsent words and writes nothing")
    func closeCancelsUnsentWords() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.pitCapture(store, now: now)
        model.text = "проверить давление в шинах"

        model.cancel()

        #expect(model.text.isEmpty)
        #expect(moment(model) == .composing(.none))
        #expect(await store.executed.isEmpty)
    }
}
