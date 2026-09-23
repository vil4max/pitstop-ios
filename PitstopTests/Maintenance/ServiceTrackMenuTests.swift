import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(30 * 86400)

/// The one "Track" toolbar menu (redesign proposal §4, decision 4) keeps the delivered disable rules of its two
/// items; the menu itself is disabled only when both items are.
@MainActor
@Suite("Service Track menu")
struct ServiceTrackMenuTests {
    @Test("ADR-0033: before the first load the menu offers one operation and keeps Track several disabled")
    func beforeTheFirstLoad() {
        let model = TestViewModels.service(FakeCarMemoryStore(), now: now)

        #expect(model.state.isTrackMenuEnabled)
        #expect(model.state.canTrackOne)
        #expect(!model.state.canTrackSeveral)
    }

    @Test("ADR-0033: a failed load keeps Track several disabled inside an enabled menu")
    func afterAFailedLoad() async {
        let store = FakeCarMemoryStore()
        let model = TestViewModels.service(store, now: now)
        await store.failEverything()

        await model.load()

        #expect(model.state.isLoadFailed)
        #expect(model.state.isTrackMenuEnabled && model.state.canTrackOne)
        #expect(!model.state.canTrackSeveral)
    }

    @Test("ADR-0033: after a successful load with something untracked both items are enabled")
    func afterASuccessfulLoad() async {
        let model = TestViewModels.service(FakeCarMemoryStore(), now: now)

        await model.load()

        #expect(model.state.isTrackMenuEnabled && model.state.canTrackOne && model.state.canTrackSeveral)
    }

    @Test("ADR-0033: with every operation tracked both items and the menu are disabled")
    func everythingTracked() async {
        let model = TestViewModels.service(FakeCarMemoryStore(), now: now)
        for operation in MaintenanceOperationID.catalog {
            #expect(await model.track(operation, kilometersText: "10000", monthsText: ""))
        }

        #expect(model.state.untrackedOperations.isEmpty)
        #expect(!model.state.canTrackOne && !model.state.canTrackSeveral)
        #expect(!model.state.isTrackMenuEnabled)
    }
}
