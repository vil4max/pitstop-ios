import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate

@MainActor
@Suite("Feature analytics")
struct FeatureAnalyticsTests {
    @Test("ADR-0021: opening a context and archiving from it report the context, counts and age only")
    func notesContextAndArchive() async throws {
        let spy = RecordingAnalyticsClient()
        let store = FakeCarMemoryStore()
        let vehicleID = await store.vehicle.id
        for text in ["мойка у дома", "мойка на трассе"] {
            _ = try await store.execute(
                .createNote(CreateNoteCommand(vehicleID: vehicleID, rawText: text, canonicalContexts: [.carWash])),
                now: now
            )
        }
        let model = NotesViewModel(
            store: store,
            analytics: AnalyticsTracker(client: spy),
            now: { now.addingTimeInterval(3 * 86400) }
        )
        await model.load()

        model.select(context: .carWash)
        model.select(context: .carWash)
        let note = try #require(model.state.visibleNotes.first)
        #expect(await model.setStatus(.archived, for: note))

        #expect(spy.names == [.noteContextOpened, .noteArchived])
        #expect(spy.last(.noteContextOpened) == [.context: "car_wash", .activeNoteCountBucket: "2_3"])
        #expect(spy.last(.noteArchived) == [.sourceContext: "car_wash", .ageBucket: "lt_7d"])
    }

    @Test("ADR-0021: filtering the archive by context is not note_context_opened")
    func archivedContextIsNotOpened() async throws {
        let spy = RecordingAnalyticsClient()
        let store = FakeCarMemoryStore()
        let vehicleID = await store.vehicle.id
        let created = try await store.execute(
            .createNote(CreateNoteCommand(vehicleID: vehicleID, rawText: "мойка", canonicalContexts: [.carWash])),
            now: now
        )
        guard case let .noteCreated(note) = created else {
            Issue.record("expected a created note, got \(created)")
            return
        }
        _ = try await store.execute(.updateNote(UpdateNoteCommand(noteID: note.id, status: .archived)), now: now)
        let model = NotesViewModel(store: store, analytics: AnalyticsTracker(client: spy), now: { now })
        await model.load()

        model.select(scope: .archived)
        model.select(context: .carWash)

        #expect(model.state.visibleNotes.count == 1)
        #expect(spy.events.isEmpty)
    }

    @Test("ADR-0021: answering the mileage question is odometer_updated from the explicit source")
    func mileageAnswerReading() async throws {
        let spy = RecordingAnalyticsClient()
        let store = FakeCarMemoryStore()
        let vehicleID = await store.vehicle.id
        let past = MaintenanceFixture.date(0)
        _ = try await store.execute(
            .setMaintenancePolicy(.init(vehicleID: vehicleID, policy: MaintenanceFixture.oil10k)),
            now: past
        )
        // Same stale-mileage setup as the ADR 0017 tests: oil done at 50,000 km, last reading 120 days old.
        _ = try await store.execute(.confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
            vehicleID: vehicleID, operationID: .engineOilService, performedAt: past, odometerKm: 50000
        ))), now: past)
        _ = try await store.execute(.recordOdometerReading(.init(reading: OdometerReading(
            vehicleID: vehicleID, value: 51000, recordedAt: past
        ))), now: past)
        let moment = MaintenanceFixture.date(120)
        let model = try PitQuestionViewModel(
            questions: FakePitQuestionStore(registry: PitQuestionRegistry.product()),
            store: store,
            registry: PitQuestionRegistry.product(),
            analytics: AnalyticsTracker(client: spy),
            now: { moment }
        )
        #expect(await model.evaluate(context: .service, activity: .idle))
        model.answerText = "56 000"

        #expect(await model.answer())

        #expect(spy.names == [.odometerUpdated])
        #expect(spy.last(.odometerUpdated) == [.source: "explicit", .anomalyConfirmation: "none"])
    }

    @Test("ADR-0021: restoring an archived note is not an archive")
    func restoreIsNotArchive() async throws {
        let spy = RecordingAnalyticsClient()
        let store = FakeCarMemoryStore()
        let model = NotesViewModel(store: store, analytics: AnalyticsTracker(client: spy), now: { now })
        #expect(await model.add(text: "мысль"))
        let note = try #require(model.state.visibleNotes.first)
        #expect(await model.setStatus(.archived, for: note))
        model.select(scope: .archived)
        let archived = try #require(model.state.visibleNotes.first)

        #expect(await model.setStatus(.active, for: archived))

        #expect(spy.names == [.noteArchived])
    }

    @Test("ADR-0021: a mileage typed in the car editor is odometer_updated from the explicit source")
    func carEditorReading() async {
        let spy = RecordingAnalyticsClient()
        let model = CarBoardViewModel(
            store: FakeCarMemoryStore(),
            analytics: AnalyticsTracker(client: spy),
            now: { now }
        )
        await model.load()

        #expect(await model.saveCar(name: "", odometerText: "84 200"))

        #expect(spy.names == [.odometerUpdated])
        #expect(spy.last(.odometerUpdated) == [.source: "explicit", .anomalyConfirmation: "none"])
    }
}
