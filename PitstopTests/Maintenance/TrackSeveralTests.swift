import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(30 * 86400)

@MainActor
@Suite("Track several starter")
struct TrackSeveralTests {
    private func makeModel(
        _ store: FakeCarMemoryStore,
        operations: [MaintenanceOperationID] = MaintenanceOperationID.catalog,
        onSaved: @escaping @MainActor () async -> Void = {}
    ) -> TrackSeveralViewModel {
        TrackSeveralViewModel(store: store, operations: operations, now: { now }, onSaved: onSaved)
    }

    /// Oil by distance and time, brake fluid by time: both valid owner intervals.
    private func reviewedOilAndBrakes(_ store: FakeCarMemoryStore) -> TrackSeveralViewModel {
        let model = makeModel(store)
        model.toggle(.engineOilService)
        model.toggle(.brakeFluid)
        model.continueToIntervals()
        model.setKilometers("10 000", for: .engineOilService)
        model.setMonths("12", for: .engineOilService)
        model.setMonths("24", for: .brakeFluid)
        #expect(model.continueToReview())
        return model
    }

    private func policyAttempts(_ store: FakeCarMemoryStore) async -> [MaintenanceOperationID] {
        await store.executed.compactMap {
            if case let .setMaintenancePolicy(set) = $0 {
                set.policy.operationID
            } else {
                nil
            }
        }
    }

    @Test("REQ-MAINT-025: the starter offers the untracked operations with nothing selected and no value filled")
    func startsWithNothingChosen() {
        let model = makeModel(FakeCarMemoryStore(), operations: [.engineOilService, .brakeFluid, .sparkPlugs])

        #expect(model.step == .choose)
        #expect(model.operations == [.engineOilService, .brakeFluid, .sparkPlugs])
        #expect(model.selected.isEmpty && model.entries.isEmpty)
        #expect(model.gearbox == .notAnswered && model.drive == .notAnswered)
    }

    @Test("REQ-MAINT-025: the owner selects and deselects; an operation outside the offer cannot be selected")
    func selection() {
        let model = makeModel(FakeCarMemoryStore(), operations: [.engineOilService, .brakeFluid, .sparkPlugs])

        model.continueToIntervals()
        #expect(model.step == .choose)

        model.toggle(.sparkPlugs)
        model.toggle(.engineOilService)
        model.toggle(.sparkPlugs)
        model.toggle(.dsgService)
        #expect(model.selected == [.engineOilService])
        #expect(model.isSelected(.engineOilService) && !model.isSelected(.sparkPlugs))

        model.toggle(.brakeFluid)
        model.continueToIntervals()
        #expect(model.step == .intervals)
        #expect(model.selected == [.engineOilService, .brakeFluid])
    }

    @Test("REQ-MAINT-026: no interval is preselected; every selected operation starts with blank fields")
    func noPreselectedValues() {
        let model = makeModel(FakeCarMemoryStore())
        for operation in MaintenanceOperationID.catalog {
            model.toggle(operation)
        }
        model.continueToIntervals()

        for operation in model.selected {
            #expect(model.entry(for: operation) == IntervalEntry())
        }
        #expect(!model.continueToReview())
        #expect(model.invalid == Set(MaintenanceOperationID.catalog))
    }

    @Test(
        "REQ-MAINT-026: each operation is validated on its own with the Track sheet's rule",
        arguments: [("", ""), ("0", ""), ("", "0"), ("abc", "12"), ("10000", "1.5"), ("-5", "")]
    )
    func perItemValidation(kilometers: String, months: String) async {
        let store = FakeCarMemoryStore()
        let model = makeModel(store)
        model.toggle(.engineOilService)
        model.toggle(.brakeFluid)
        model.continueToIntervals()
        model.setKilometers("10000", for: .engineOilService)
        model.setKilometers(kilometers, for: .brakeFluid)
        model.setMonths(months, for: .brakeFluid)

        #expect(!model.continueToReview())

        #expect(model.step == .intervals && model.invalid == [.brakeFluid])
        model.setMonths("24", for: .brakeFluid)
        model.setKilometers("", for: .brakeFluid)
        #expect(model.invalid.isEmpty)
        #expect(model.continueToReview())
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-MAINT-026: a quick pick fills the field like typing and stays editable")
    func quickPickFillsTheField() {
        let model = makeModel(FakeCarMemoryStore())
        model.toggle(.engineOilService)
        model.continueToIntervals()

        model.pickKilometers(IntervalQuickPicks.kilometers[2], for: .engineOilService)
        model.pickMonths(IntervalQuickPicks.months[1], for: .engineOilService)
        #expect(model.entry(for: .engineOilService) == IntervalEntry(kilometers: "10000", months: "12"))

        model.setKilometers("9000", for: .engineOilService)
        #expect(model.continueToReview())
        #expect(model.reviewPolicies == [
            MaintenancePolicy(
                operationID: .engineOilService,
                distanceIntervalKm: 9000,
                timeIntervalMonths: 12,
                source: .userCustom
            ),
        ])
    }

    @Test("REQ-MAINT-027: nothing is saved before the confirmation, which lists every operation and interval")
    func nothingSavedBeforeConfirm() async {
        let store = FakeCarMemoryStore()
        let model = reviewedOilAndBrakes(store)

        #expect(model.step == .review)
        #expect(model.reviewPolicies == [
            MaintenancePolicy(
                operationID: .engineOilService,
                distanceIntervalKm: 10000,
                timeIntervalMonths: 12,
                source: .userCustom
            ),
            MaintenancePolicy(operationID: .brakeFluid, timeIntervalMonths: 24, source: .userCustom),
        ])
        #expect(await store.executed.isEmpty)
        #expect(await store.policies.isEmpty)

        model.back()
        #expect(model.step == .intervals)
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-MAINT-027: the sheet's Cancel abandons the starter; a filled review then saves nothing")
    func cancelSavesNothing() async {
        let store = FakeCarMemoryStore()
        var reloads = 0
        let model = makeModel(store) { reloads += 1 }
        model.toggle(.engineOilService)
        model.continueToIntervals()
        model.setKilometers("10000", for: .engineOilService)
        #expect(model.continueToReview())

        model.cancel()
        // A save task queued before the sheet closed must not write after Cancel.
        await model.apply()

        #expect(model.isCancelled && model.step == .review && model.results.isEmpty)
        #expect(await store.executed.isEmpty)
        #expect(await store.policies.isEmpty)
        #expect(reloads == 0)
    }

    @Test("REQ-MAINT-026: a failed Next names the invalid items in list order and counts each attempt")
    func firstInvalidFollowsListOrder() {
        let model = makeModel(FakeCarMemoryStore())
        model.drive = .allWheel
        model.toggle(.sparkPlugs)
        model.toggle(.brakeFluid)
        model.toggle(.awdCouplingService)
        model.continueToIntervals()
        model.setMonths("24", for: .brakeFluid)
        #expect(model.firstInvalid == nil && model.validationFailures == 0)

        #expect(!model.continueToReview())
        #expect(model.invalidInListOrder == [.awdCouplingService, .sparkPlugs])
        #expect(model.firstInvalid == .awdCouplingService && model.validationFailures == 1)

        #expect(!model.continueToReview())
        #expect(model.validationFailures == 2)

        model.setKilometers("60000", for: .awdCouplingService)
        #expect(model.firstInvalid == .sparkPlugs)
    }

    @Test("REQ-MAINT-027: confirming saves each item as the owner's own policy and reloads the surfaces")
    func confirmSavesOwnerPolicies() async {
        let store = FakeCarMemoryStore()
        var reloads = 0
        let model = makeModel(store) { reloads += 1 }
        model.toggle(.engineOilService)
        model.toggle(.brakeFluid)
        model.continueToIntervals()
        model.setKilometers("10000", for: .engineOilService)
        model.setMonths("24", for: .brakeFluid)
        #expect(model.continueToReview())

        await model.apply()

        #expect(model.step == .results && model.failedOperations.isEmpty && model.savedCount == 2)
        #expect(model.results == [.engineOilService: .saved, .brakeFluid: .saved])
        let policies = await store.policies
        #expect(policies.count == 2 && policies.allSatisfy { $0.source == .userCustom })
        #expect(await policyAttempts(store) == [.engineOilService, .brakeFluid])
        #expect(reloads == 1)
    }

    @Test("REQ-MAINT-028: a failed item is reported by name, the others stay saved, and retry saves only it")
    func partialFailureAndRetry() async {
        let store = FakeCarMemoryStore()
        await store.failPolicies(for: [.engineOilService])
        let model = reviewedOilAndBrakes(store)

        await model.apply()

        #expect(model.step == .results)
        #expect(model.results == [.engineOilService: .failed, .brakeFluid: .saved])
        #expect(model.failedOperations == [.engineOilService] && model.savedCount == 1)
        #expect(await store.policies.map(\.operationID) == [.brakeFluid])

        await store.recover()
        let attemptsBefore = await policyAttempts(store).count
        await model.apply()

        #expect(model.failedOperations.isEmpty && model.savedCount == 2)
        #expect(await Array(policyAttempts(store).dropFirst(attemptsBefore)) == [.engineOilService])
        #expect(await Set(store.policies.map(\.operationID)) == [.engineOilService, .brakeFluid])
    }

    @Test("REQ-MAINT-028: when every item fails nothing is saved, each is reported, and no reload runs")
    func everythingFails() async {
        let store = FakeCarMemoryStore()
        var reloads = 0
        let model = makeModel(store) { reloads += 1 }
        model.toggle(.brakeFluid)
        model.continueToIntervals()
        model.setMonths("24", for: .brakeFluid)
        #expect(model.continueToReview())
        await store.failEverything()

        await model.apply()

        #expect(model.failedOperations == [.brakeFluid] && model.savedCount == 0)
        #expect(await store.policies.isEmpty)
        #expect(reloads == 0)
    }

    @Test("REQ-MAINT-028: after everything is saved, apply does nothing more")
    func applyIsNotRepeated() async {
        let store = FakeCarMemoryStore()
        let model = reviewedOilAndBrakes(store)
        await model.apply()
        let attempts = await policyAttempts(store)

        await model.apply()

        #expect(await policyAttempts(store) == attempts)
    }

    @Test("REQ-MAINT-029: car-type answers only reorder the list; they select nothing and write nothing")
    func answersOnlyReorder() async {
        let store = FakeCarMemoryStore()
        let vehicle = await store.vehicle
        let model = makeModel(store)
        model.toggle(.brakeFluid)

        model.gearbox = .dualClutch
        model.drive = .allWheel
        #expect(Array(model.operations.prefix(2)) == [.dsgService, .awdCouplingService])

        model.gearbox = .manual
        model.drive = .twoWheel
        #expect(Array(model.operations.suffix(2)) == [.dsgService, .awdCouplingService])
        #expect(Set(model.operations) == Set(MaintenanceOperationID.catalog))

        model.gearbox = .notAnswered
        model.drive = .notAnswered
        #expect(model.operations == MaintenanceOperationID.catalog)

        #expect(model.selected == [.brakeFluid] && model.entries.isEmpty)
        #expect(await store.executed.isEmpty)
        #expect(await store.vehicle == vehicle)
    }

    @Test("REQ-MAINT-029: the review follows the list order the owner saw, not the tap order")
    func reviewFollowsListOrder() {
        let model = makeModel(FakeCarMemoryStore())
        model.drive = .allWheel
        model.toggle(.brakeFluid)
        model.toggle(.awdCouplingService)

        model.continueToIntervals()

        #expect(model.selected == [.awdCouplingService, .brakeFluid])
    }

    @Test("REQ-MAINT-025: Service offers the starter only after a successful load")
    func starterWaitsForASuccessfulLoad() async {
        let store = FakeCarMemoryStore()
        let service = ServiceViewModel(store: store, now: { now })
        #expect(await service.track(.engineOilService, kilometersText: "10000", monthsText: ""))
        let fresh = ServiceViewModel(store: store, now: { now })
        #expect(!fresh.state.canTrackSeveral)

        await store.failEverything()
        await fresh.load()
        #expect(fresh.state.isLoadFailed && !fresh.state.canTrackSeveral)

        await store.recover()
        await fresh.load()
        #expect(fresh.state.canTrackSeveral)
        #expect(!fresh.makeTrackSeveral().operations.contains(.engineOilService))
    }

    @Test("REQ-MAINT-025: Service offers only untracked operations and shows the saved ones after the starter")
    func serviceIntegration() async throws {
        let store = FakeCarMemoryStore()
        let service = ServiceViewModel(store: store, now: { now })
        // Brake fluid done 23 months ago: once tracked every 24 months, Road places it by date.
        let vehicleID = await store.vehicle.id
        _ = try await store.execute(
            .confirmMaintenanceCompletion(.init(completion: MaintenanceCompletion(
                vehicleID: vehicleID,
                operationID: .brakeFluid,
                performedAt: now.addingTimeInterval(-700 * 86400)
            ))),
            now: now
        )
        #expect(await service.track(.engineOilService, kilometersText: "10000", monthsText: ""))

        let model = service.makeTrackSeveral()
        #expect(!model.operations.contains(.engineOilService))
        model.toggle(.brakeFluid)
        model.continueToIntervals()
        model.setMonths("24", for: .brakeFluid)
        #expect(model.continueToReview())
        await model.apply()

        #expect(Set(service.state.operations.map(\.id)) == [.engineOilService, .brakeFluid])
        let board = CarBoardViewModel(store: store, now: { now })
        let road = RoadViewModel(store: store, now: { now })
        await board.load()
        await road.load()
        #expect(Set(board.state.service.map(\.id)) == [.engineOilService, .brakeFluid])
        let milestones = try #require(road.state.projection).slots.flatMap(\.milestones)
        #expect(milestones.contains { $0.subject == .maintenance(.brakeFluid) })
    }
}
