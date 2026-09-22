import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(30 * 86400)
private let day: TimeInterval = 86400

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

private let today = utc.startOfDay(for: now)

@MainActor
@Suite("Road planned date entry")
struct PlannedEventViewModelTests {
    private func makeModel(_ store: FakeCarMemoryStore = FakeCarMemoryStore()) async -> RoadViewModel {
        let model = RoadViewModel(store: store, now: { now }, calendar: utc)
        await model.load()
        return model
    }

    private func draft(_ kind: PlannedEventDraft.Kind = .insuranceExpiry, inDays days: Double, label: String = "")
        -> PlannedEventDraft
    {
        PlannedEventDraft(kind: kind, date: now.addingTimeInterval(days * day), label: label)
    }

    @Test("REQ-ROAD-016: an insurance expiry added on Road is stored as a day and appears on Road by days left")
    func addInsurance() async throws {
        let store = FakeCarMemoryStore()
        let model = await makeModel(store)
        #expect(model.newDraft().kind == .insuranceExpiry)

        #expect(await model.save(draft(inDays: 40)))

        let stored = try #require(await store.planned.first)
        #expect(stored.kind == .insuranceExpiry && stored.label == nil)
        #expect(stored.date == utc.startOfDay(for: now.addingTimeInterval(40 * day)))
        let vehicleID = await store.vehicle.id
        #expect(stored.createdAt == now && stored.vehicleID == vehicleID)
        let lead = try #require(model.state.projection?.slots.first?.lead)
        #expect(lead.subject == .planned(.insuranceExpiry, id: stored.id))
        // The date is 40 calendar days away, whatever the time of day (ADR 0032).
        #expect(lead.remainingDays == 40)
        #expect(model.state.plannedEvents == [stored])
        // A plan is not a History event and resets nothing (core C5).
        let (events, completions) = await (store.events, store.completions)
        #expect(events.isEmpty && completions.isEmpty)
    }

    @Test("REQ-ROAD-016: an `other` date keeps a trimmed one-line label, and a blank one is no label")
    func otherLabel() async {
        let store = FakeCarMemoryStore()
        let model = await makeModel(store)

        #expect(await model.save(draft(.other, inDays: 10, label: "  Winter\ntyres ")))
        #expect(await model.save(draft(.other, inDays: 20, label: "   ")))
        // The label field belongs to `other`: switching to insurance drops what was typed.
        #expect(await model.save(draft(inDays: 30, label: "Ignored")))

        #expect(await store.planned.map(\.kind) == [
            .other(label: "Winter tyres"),
            .other(label: nil),
            .insuranceExpiry,
        ])
        let titles = model.state.projection?.slots.flatMap(\.milestones).map(\.plannedLabel)
        #expect(titles == ["Winter tyres", nil, nil])
    }

    @Test("REQ-ROAD-018: with an insurance expiry on Road, a new date defaults to `other` and insurance is refused")
    func secondInsurance() async throws {
        let store = FakeCarMemoryStore()
        let model = await makeModel(store)
        #expect(await model.save(draft(inDays: 40)))
        let insurance = try #require(await store.planned.first)

        #expect(!model.canChooseInsurance(editing: nil))
        #expect(model.canChooseInsurance(editing: insurance))
        #expect(model.newDraft().kind == .other)

        #expect(await model.save(draft(inDays: 100)) == false)
        #expect(model.state.failure == .insuranceAlreadyPlanned)
        #expect(await store.planned.count == 1)
    }

    @Test("REQ-ROAD-017: a date outside the window is refused before anything is written")
    func dateOutsideWindow() async {
        let store = FakeCarMemoryStore()
        let model = await makeModel(store)

        #expect(await model.save(draft(inDays: -20)) == false)
        #expect(model.state.failure == .dateOutOfRange)
        #expect(await model.save(draft(inDays: Double(PlannedEventLimits.maximumDaysAhead) + 2)) == false)
        #expect(await store.executed.isEmpty)

        model.dismissFailure()
        #expect(model.state.failure == nil)
    }

    @Test("REQ-ROAD-017: the picker offers today up to the limit, and an existing past date stays selectable")
    func dateRange() async {
        let store = FakeCarMemoryStore()
        let model = await makeModel(store)
        let range = model.dateRange(editing: nil)
        #expect(range.lowerBound == today)
        #expect(range.upperBound <= PlannedEventLimits.latestDate(now: now))
        #expect(PlannedEventLimits.isPlausibleDate(range.upperBound, now: now))

        let passed = await PlannedDatedEvent(
            vehicleID: store.vehicle.id, kind: .insuranceExpiry, date: today.addingTimeInterval(-5 * day),
            createdAt: now
        )
        #expect(model.dateRange(editing: passed).lowerBound == passed.date)
    }

    @Test("REQ-ROAD-017: a label longer than the limit is refused")
    func labelTooLong() async {
        let store = FakeCarMemoryStore()
        let model = await makeModel(store)
        let label = String(repeating: "a", count: PlannedEventLimits.maximumLabelLength + 1)

        #expect(await model.save(draft(.other, inDays: 5, label: label)) == false)
        #expect(model.state.failure == .labelTooLong)
        #expect(await store.planned.isEmpty)
    }

    @Test("REQ-ROAD-019: editing changes the kind, date and label of the same plan and keeps its creation time")
    func edit() async throws {
        let store = FakeCarMemoryStore()
        let model = await makeModel(store)
        #expect(await model.save(draft(.other, inDays: 10, label: "Warranty")))
        let original = try #require(await store.planned.first)
        var edited = model.draft(for: original)
        #expect(edited == PlannedEventDraft(kind: .other, date: original.date, label: "Warranty"))

        edited.label = "Warranty ends"
        edited.date = now.addingTimeInterval(60 * day)
        #expect(await model.save(edited, replacing: original))

        let stored = try #require(await store.planned.first)
        #expect(await store.planned.count == 1)
        #expect(stored.id == original.id && stored.createdAt == original.createdAt)
        #expect(stored.kind == .other(label: "Warranty ends"))
        #expect(stored.date == utc.startOfDay(for: now.addingTimeInterval(60 * day)))
        #expect(model.state.projection?.slots.first?.lead?.plannedLabel == "Warranty ends")
    }

    @Test("REQ-ROAD-019: delete waits for confirmation; cancel keeps the date, confirm removes only it")
    func deleteNeedsConfirmation() async throws {
        let store = FakeCarMemoryStore()
        let model = await makeModel(store)
        #expect(await model.save(draft(inDays: 40)))
        #expect(await model.save(draft(.other, inDays: 50)))
        let insurance = try #require(await store.planned.first(where: \.isInsuranceExpiry))

        model.requestDelete(insurance)
        #expect(model.state.deleteCandidate == insurance)
        model.cancelDelete()
        #expect(model.state.deleteCandidate == nil)
        #expect(await store.planned.count == 2)

        model.requestDelete(insurance)
        #expect(await model.confirmDelete(insurance))

        #expect(model.state.deleteCandidate == nil)
        #expect(await store.planned.map(\.isInsuranceExpiry) == [false])
        #expect(model.state.projection?.slots.count == 1)
        // With the insurance gone, a new one may be planned again.
        #expect(model.canChooseInsurance(editing: nil))
    }

    @Test("REQ-ROAD-019: a failed delete is reported on the list and the date stays")
    func deleteFailure() async throws {
        let store = FakeCarMemoryStore()
        let model = await makeModel(store)
        #expect(await model.save(draft(inDays: 40)))
        let insurance = try #require(await store.planned.first)
        await store.failCommands()

        #expect(await model.confirmDelete(insurance) == false)

        #expect(model.state.listFailure == .notSaved && model.state.failure == nil)
        #expect(await store.planned == [insurance])
        #expect(model.state.projection?.slots.count == 1)
    }

    @Test("REQ-ROAD-016: a failed save keeps the editor open with a failure and writes nothing")
    func saveFailure() async {
        let store = FakeCarMemoryStore()
        let model = await makeModel(store)
        await store.failCommands()

        #expect(await model.save(draft(inDays: 40)) == false)

        #expect(model.state.failure == .notSaved)
        #expect(await store.planned.isEmpty)
        #expect(model.state.projection?.slots.isEmpty == true)
    }

    @Test("REQ-BOARD-010: the Car Board tile and the Road screen project the same dates and estimates")
    func tileAgreesWithScreen() async throws {
        let store = FakeCarMemoryStore()
        // A tracked distance operation and a reading history, so the projections must agree on the
        // date estimate too and not only on the planned dates (ADR 0034).
        try await seedDrivenCar(store)
        let screen = await makeModel(store)
        #expect(await screen.save(draft(inDays: 40)))
        #expect(await screen.save(draft(.other, inDays: 200, label: "Warranty ends")))
        let board = CarBoardViewModel(store: store, now: { now }, calendar: utc)

        await board.load()

        let tile = try #require(board.state.road)
        #expect(tile == screen.state.projection)
        let milestones = tile.slots.flatMap(\.milestones)
        // The two planned dates in order; the insurance expiry has no label of its own.
        let plannedLabels = milestones.compactMap { milestone -> String? in
            guard case .planned = milestone.subject else { return nil }
            return milestone.plannedLabel ?? "insurance"
        }
        #expect(plannedLabels == ["insurance", "Warranty ends"])
        #expect(milestones.contains { $0.subject == .maintenance(.engineOilService) && $0.estimate != nil })
    }

    /// 46 km/day over three months and an oil change 5,900 km ahead: enough history for an estimate.
    private func seedDrivenCar(_ store: FakeCarMemoryStore) async throws {
        let vehicleID = await store.vehicle.id
        let policy = MaintenancePolicy(operationID: .engineOilService, distanceIntervalKm: 10000, source: .userCustom)
        _ = try await store.execute(.setMaintenancePolicy(.init(vehicleID: vehicleID, policy: policy)), now: now)
        let done = MaintenanceCompletion(
            vehicleID: vehicleID,
            operationID: .engineOilService,
            performedAt: now.addingTimeInterval(-90 * day),
            odometerKm: 48000
        )
        _ = try await store.execute(.confirmMaintenanceCompletion(.init(completion: done)), now: now)
        for (daysAgo, km) in [(90.0, 48000.0), (60, 49400), (30, 50800), (2, 52100)] {
            let reading = OdometerReading(
                vehicleID: vehicleID, value: km, recordedAt: now.addingTimeInterval(-daysAgo * day)
            )
            _ = try await store.execute(.recordOdometerReading(.init(reading: reading)), now: now)
        }
    }

    @Test("ADR-0008: a date that passed more than 14 days ago is gone from Road but kept in the store")
    func expiredDateLeavesRoad() async throws {
        let store = FakeCarMemoryStore()
        let vehicleID = await store.vehicle.id
        let old = PlannedDatedEvent(
            vehicleID: vehicleID, kind: .insuranceExpiry, date: now.addingTimeInterval(-14 * day), createdAt: now
        )
        _ = try await store.execute(.addPlannedEvent(.init(event: old)), now: now)
        let later = RoadViewModel(store: store, now: { now.addingTimeInterval(day) }, calendar: utc)

        await later.load()

        #expect(later.state.projection?.slots.isEmpty == true)
        #expect(later.state.plannedEvents == [old])
        #expect(later.canChooseInsurance(editing: nil))
    }
}
