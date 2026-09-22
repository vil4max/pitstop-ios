import Foundation
@testable import Pitstop
import Synchronization
import Testing

private let now = DomainFixtures.Odometers.baseDate

@MainActor
@Suite("Pit capture surface")
struct PitCaptureViewModelTests {
    @Test("REQ-CAPTURE-026, ADR-0030: a typed Pit capture carries the injected locale to the interpreter")
    func captureCarriesInjectedLocale() async {
        let interpreter = InputRecordingInterpreter()
        let model = PitCaptureViewModel(
            pipeline: RememberPipeline(store: FakeCarMemoryStore(), interpreter: interpreter, now: { now }),
            now: { now },
            locale: { Locale(identifier: "uk_UA") }
        )
        model.text = "перевірити тиск у шинах"

        await model.submit(from: .carBoard)

        let inputs = await interpreter.inputs
        #expect(inputs.map(\.localeIdentifier) == ["uk_UA"])
        #expect(inputs.first?.source == .pitText)
    }

    @Test("REQ-CAPTURE-026, ADR-0030: the locale is read when the capture is submitted, not when Pit is built")
    func localeIsReadPerCapture() async {
        let interpreter = InputRecordingInterpreter()
        let current = SettableLocale(Locale(identifier: "ru_RU"))
        let model = PitCaptureViewModel(
            pipeline: RememberPipeline(store: FakeCarMemoryStore(), interpreter: interpreter, now: { now }),
            now: { now },
            locale: { current.value }
        )
        model.text = "мысль"
        await model.submit(from: .carBoard)
        model.reset()
        current.value = Locale(identifier: "en_GB")
        model.text = "a thought"
        await model.submit(from: .carBoard)

        #expect(await interpreter.inputs.map(\.localeIdentifier) == ["ru_RU", "en_GB"])
    }

    @Test("REQ-CAPTURE-010: a raw thought is saved and the surface names where it went")
    func thoughtIsSavedToNotes() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.pitCapture(store, now: now)
        model.text = "Спросить про пятно на заднем сиденье"

        await model.submit(from: .carBoard)

        #expect(model.phase == .saved(.notes, preservedRaw: true))
        #expect(await store.storedNotes.map(\.rawText) == ["Спросить про пятно на заднем сиденье"])
    }

    @Test("REQ-CAPTURE-016: completed work stops for confirmation, and only confirming writes it")
    func completionIsConfirmedFirst() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.pitCapture(store, now: now)
        model.text = "поменял масло на 85000"

        await model.submit(from: .service)

        guard case .confirming = model.phase else {
            Issue.record("expected a confirmation, got \(model.phase)")
            return
        }
        #expect(await store.executed.isEmpty)

        await model.confirm()

        #expect(model.phase == .saved(.service, preservedRaw: false))
        #expect(await store.completions.count == 1)
    }

    @Test("REQ-CAPTURE-008: keeping only the words saves a note and says it was saved as written")
    func keepingWordsSavesANote() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.pitCapture(store, now: now)
        model.text = "помыл машину за 1200"
        await model.submit(from: .carBoard)

        await model.keepWordsOnly()

        #expect(model.phase == .saved(.notes, preservedRaw: true))
        #expect(await store.events.isEmpty)
    }

    @Test("REQ-CAPTURE-005: closing a pending proposal writes nothing and clears the surface")
    func cancellingWritesNothing() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.pitCapture(store, now: now)
        model.text = "поменял масло на 85000"
        await model.submit(from: .carBoard)

        model.cancel()

        #expect(model.phase == .composing && model.text.isEmpty)
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-CAPTURE-001: raw mode saves the words as they are, even for a report of work")
    func rawModeSavesAsWritten() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.pitCapture(store, now: now)
        model.mode = .raw
        model.text = "поменял масло на 85000"

        await model.submit(from: .carBoard)

        #expect(model.phase == .saved(.notes, preservedRaw: true))
        #expect(await store.completions.isEmpty)
    }

    @Test("REQ-CAPTURE-009: a failed confirmation stays on the confirmation and says nothing was saved")
    func failedSaveKeepsText() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.pitCapture(store, now: now)
        model.text = "поменял масло на 85000"
        await model.submit(from: .carBoard)
        await store.failCommands()

        await model.confirm()

        guard case .confirming = model.phase else {
            Issue.record("expected to stay on the confirmation, got \(model.phase)")
            return
        }
        #expect(model.failure == .notSaved)
        #expect(await store.completions.isEmpty)
    }

    @Test("ADR-0006: blank text cannot be submitted")
    func blankTextIsNotSubmitted() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.pitCapture(store, now: now)
        model.text = "   "

        #expect(!model.canSubmit)
        await model.submit(from: .carBoard)
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-CAPTURE-010: a mileage reading reports the car itself as its destination")
    func readingGoesToTheBoard() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.pitCapture(store, now: now)
        model.text = "пробег 84 200"

        await model.submit(from: .notes)

        #expect(model.phase == .saved(.carBoard, preservedRaw: false))
    }

    @Test("REQ-CAPTURE-005: closing a pending proposal is reported as discarded; closing a saved one is not")
    func onlyPendingCapturesAreDiscarded() async {
        let spy = StageSpy()
        let store = FakeCarMemoryStore()
        let model = PitCaptureViewModel(
            pipeline: RememberPipeline(store: store, interpreter: RuleBasedInterpreter(), observer: spy, now: { now }),
            now: { now }
        )
        model.text = "поменял масло на 85000"
        await model.submit(from: .carBoard)
        model.cancel()
        #expect(spy.events.last?.stage == .captureDiscarded)

        model.text = "мысль"
        await model.submit(from: .carBoard)
        let before = spy.events.count
        model.cancel()
        #expect(spy.events.count == before)
    }

    @Test("ADR-0011: a step that finishes after the surface was reset does not overwrite it")
    func staleStepIsIgnored() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.pitCapture(store, now: now)
        model.text = "поменял масло на 85000"
        await model.submit(from: .carBoard)

        async let confirming: Void = model.confirm()
        model.cancel()
        await confirming

        #expect(model.phase == .composing)
        #expect(model.text.isEmpty)
    }

    @Test("REQ-CAPTURE-020: a typed answer to the one question continues the same capture")
    func typedAnswerContinues() async {
        let store = FakeCarMemoryStore()
        let capture = CaptureInput(payload: .text("записал показания"), source: .pitText, capturedAt: now)
        let draft = MemoryProposal(sourceInputID: capture.id, kind: .odometerReading, rawText: "записал показания")
        let model = PitCaptureViewModel(
            pipeline: RememberPipeline(store: store, interpreter: FixedInterpreter(proposal: draft), now: { now }),
            now: { now }
        )
        model.text = "записал показания"
        await model.submit(from: .carBoard)
        guard case .clarifying = model.phase else {
            Issue.record("expected a clarification, got \(model.phase)")
            return
        }

        await model.answer(text: "8,5")
        #expect(model.failure == .invalidMileage)

        await model.answer(text: "84 200")
        #expect(model.phase == .saved(.carBoard, preservedRaw: false))
    }

    @Test("REQ-CAPTURE-009: confirming a proposal that was already saved starts over without a false error")
    func alreadySavedStartsOver() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.pitCapture(store, now: now)
        model.text = "поменял масло на 85000"
        await model.submit(from: .carBoard)
        guard case let .confirming(pending) = model.phase else {
            Issue.record("expected a confirmation")
            return
        }
        _ = try? await RememberPipeline(store: store, interpreter: RuleBasedInterpreter(), now: { now })
            .confirm(pending)

        await model.confirm()

        #expect(model.phase == .composing && model.failure == .alreadySaved && model.text.isEmpty)
        #expect(await store.completions.count == 1)
    }
}

/// Answers every capture with the same draft, whatever it says. The draft's input ID is rewritten to
/// the capture's own, as a real interpreter would produce it.
private struct FixedInterpreter: SemanticInterpreting {
    let proposal: MemoryProposal

    func interpret(_ input: CaptureInput) async throws -> MemoryProposal? {
        MemoryProposal(sourceInputID: input.id, kind: proposal.kind, rawText: input.payload.rawContent)
    }
}

/// A locale the person changes in Settings while the app keeps running.
private final class SettableLocale: Sendable {
    private let storage: Mutex<Locale>

    init(_ locale: Locale) {
        storage = Mutex(locale)
    }

    var value: Locale {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }
}
