import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(30 * 86400)

/// The starter as Service offers it, and what the other surfaces show after it saved.
extension TrackSeveralTests {
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
            .confirmMaintenanceCompletion(
                .init(
                    completion: MaintenanceCompletion(
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
