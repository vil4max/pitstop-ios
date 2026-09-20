import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(30 * 86400)

@Suite("History timeline")
struct HistoryTimelineTests {
    @Test("REQ-BOARD-016: with no recorded events there is no latest entry")
    func emptyTimelineHasNoLatest() {
        #expect(HistoryTimeline.empty.latest == nil)
        #expect(HistoryTimeline(events: [], completions: []).entries.isEmpty)
    }

    @Test("ADR-0007: a standalone completion is history; one that came from a listed visit is not shown twice")
    func completionFromVisitIsNotDuplicated() {
        let visit = DomainFixtures.History.serviceVisit
        let fromVisit = MaintenanceCompletion(
            vehicleID: visit.vehicleID,
            operationID: .engineOilService,
            performedAt: visit.date,
            sourceEventID: visit.id
        )
        let standalone = DomainFixtures.Maintenance.brakeFluidCompletion

        let timeline = HistoryTimeline(events: [visit], completions: [fromVisit, standalone])

        #expect(timeline.entries == [.event(visit), .completion(standalone)])
    }

    @Test("ADR-0007: a completion whose visit is not in the timeline is shown, never lost")
    func completionWithMissingVisitIsKept() {
        let orphan = MaintenanceCompletion(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            operationID: .dsgService,
            performedAt: DomainFixtures.Odometers.baseDate,
            sourceEventID: UUID()
        )
        #expect(HistoryTimeline(events: [], completions: [orphan]).entries == [.completion(orphan)])
    }

    @Test("ADR-0007: the same records always give the same order, newest first")
    func orderIsDeterministic() {
        let events = [DomainFixtures.History.serviceVisit, DomainFixtures.History.carWashEvent]
        let forward = HistoryTimeline(events: events, completions: [])
        let reversed = HistoryTimeline(events: events.reversed(), completions: [])
        #expect(forward == reversed)
        #expect(forward.latest == .event(DomainFixtures.History.carWashEvent))
    }
}

@MainActor
@Suite("History view model")
struct HistoryViewModelTests {
    private func makeModel(_ store: FakeCarMemoryStore) -> HistoryViewModel {
        HistoryViewModel(store: store, now: { now })
    }

    @Test("ADR-0007: an event saved without mileage or cost keeps them unknown, not zero")
    func unknownFactsStayUnknown() async throws {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        var draft = model.newDraft()
        draft.kind = .carWash

        #expect(await model.save(draft))

        let event = try #require(await store.events.first)
        #expect(event.odometerKm == nil && event.amount == nil && event.note == nil)
        #expect(model.state.timeline.latest == .event(event))
    }

    @Test("REQ-DOMAIN-016: a corrected event keeps its identity and the timeline shows the corrected facts")
    func correctedEventKeepsIdentity() async throws {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        var draft = model.newDraft()
        draft.odometerText = "84 200"
        draft.amountText = "12500,50"
        #expect(await model.save(draft))
        let original = try #require(await store.events.first)
        #expect(original.amount == Decimal(string: "12500.5"))

        var correction = model.draft(for: original)
        correction.odometerText = "84300"
        #expect(await model.save(correction, replacing: original))

        let events = await store.events
        #expect(events.count == 1)
        #expect(events.first?.id == original.id)
        #expect(events.first?.odometerKm == 84300)
        #expect(model.state.timeline.entries.count == 1)
    }

    @Test("ADR-0006: an event dated in the future is a plan and is not recorded")
    func futureEventIsRejected() async {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        var draft = model.newDraft()
        draft.date = now.addingTimeInterval(86400)

        #expect(await !model.save(draft))
        #expect(model.state.failure == .futureDate)
        #expect(await store.events.isEmpty)
    }

    @Test(
        "ADR-0007: cost accepts a decimal comma or point and never guesses",
        arguments: [
            ("", HistoryViewModel.AmountInput.absent),
            ("1200", .value(1200)),
            ("1 200,50", .value(Decimal(string: "1200.5")!)),
            ("12.5", .value(Decimal(string: "12.5")!)),
            ("0", .invalid),
            ("-5", .invalid),
            ("12.345", .invalid),
            ("1,200", .invalid),
            ("1.200", .invalid),
            ("1.200,50", .invalid),
            ("abc", .invalid)
        ]
    )
    func amountParsing(text: String, expected: HistoryViewModel.AmountInput) {
        #expect(HistoryViewModel.amount(from: text) == expected)
    }

    @Test("REQ-CAPTURE-009: a failed save is reported and nothing appears in the timeline")
    func failedSaveIsReported() async {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        await store.failEverything()

        #expect(await !model.save(model.newDraft()))
        #expect(model.state.failure == .notSaved)
        #expect(model.state.timeline.entries.isEmpty)
    }

    @Test("REQ-BOARD-016: the History tile state shows the latest recorded event and ignores notes")
    func tileShowsLatestRecordedEvent() async throws {
        let store = FakeCarMemoryStore()
        let board = CarBoardViewModel(store: store, now: { now })
        _ = try await store.execute(.createNote(CreateNoteCommand(rawText: "заменить дворники")), now: now)
        await board.load()
        #expect(board.state.history.latest == nil)

        #expect(await makeModel(store).save(HistoryEventDraft(kind: .carWash, date: now)))
        await board.load()

        guard case let .event(latest) = board.state.history.latest else {
            Issue.record("expected the recorded event")
            return
        }
        #expect(latest.kind == .carWash)
    }

    @Test("ADR-0006: a correction cannot move a recorded event into the future")
    func correctionCannotMoveIntoFuture() async throws {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        #expect(await model.save(model.newDraft()))
        let original = try #require(await store.events.first)
        var correction = model.draft(for: original)
        correction.date = now.addingTimeInterval(7 * 86400)

        #expect(await !model.save(correction, replacing: original))

        #expect(model.state.failure == .futureDate)
        #expect(await store.events == [original])
    }

    @Test("REQ-CAPTURE-021: the correction command itself rejects a future date")
    func correctionCommandRejectsFuture() {
        let event = HistoryEvent(
            vehicleID: DomainFixtures.Vehicles.defaultID,
            kind: .service,
            date: now.addingTimeInterval(7 * 86400)
        )
        #expect(throws: DomainCommandError.dateInFuture) {
            try DomainCommand.correctVehicleEvent(CorrectVehicleEventCommand(event: event)).validate(now: now)
        }
    }

    @Test("ADR-0007: a correction may clear a fact the user no longer trusts")
    func correctionCanClearFacts() async throws {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        var draft = model.newDraft()
        draft.odometerText = "84200"
        draft.amountText = "500"
        #expect(await model.save(draft))
        let original = try #require(await store.events.first)
        var correction = model.draft(for: original)
        correction.odometerText = ""
        correction.amountText = ""

        #expect(await model.save(correction, replacing: original))

        let corrected = try #require(await store.events.first)
        #expect(corrected.odometerKm == nil && corrected.amount == nil)
    }

    @Test("REQ-BOARD-016: a confirmed completion is a recorded fact and can be the latest tile entry")
    func tileShowsConfirmedCompletion() async throws {
        let store = FakeCarMemoryStore()
        let completion = await MaintenanceCompletion(
            vehicleID: store.vehicle.id,
            operationID: .brakeFluid,
            performedAt: DomainFixtures.Odometers.baseDate
        )
        _ = try await store.execute(.confirmMaintenanceCompletion(.init(completion: completion)), now: now)
        let board = CarBoardViewModel(store: store, now: { now })

        await board.load()

        #expect(board.state.history.latest == .completion(completion))
    }
}
