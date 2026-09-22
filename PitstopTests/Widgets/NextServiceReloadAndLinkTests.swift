import Foundation
@testable import Pitstop
import Synchronization
import Testing

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private final class ReloadSpy: NextServiceReloading {
    let count = Mutex(0)

    func reloadNextService() {
        count.withLock { $0 += 1 }
    }

    var requests: Int {
        count.withLock { $0 }
    }
}

@Suite("Next-service widget reloads")
struct NextServiceReloadTests {
    @Test("REQ-WIDGET-009: a saved command asks the widget to reload once")
    func savedCommandReloads() async throws {
        let spy = ReloadSpy()
        let store = WidgetReloadingCarMemoryStore(base: FakeCarMemoryStore(), reloader: spy)
        let id = try await store.currentVehicle().id
        try await store.execute(.setMaintenancePolicy(.init(vehicleID: id, policy: MaintenanceFixture.custom(
            .engineOilService, km: 15000
        ))), now: now)
        #expect(spy.requests == 1)
        #expect(try await store.maintenancePolicies().map(\.operationID) == [.engineOilService])
    }

    @Test("REQ-WIDGET-009: a failed or rejected command and plain reads ask for nothing")
    func failedCommandDoesNotReload() async throws {
        let spy = ReloadSpy()
        let base = FakeCarMemoryStore()
        let store = WidgetReloadingCarMemoryStore(base: base, reloader: spy)
        let id = try await store.currentVehicle().id
        _ = try await (store.maintenancePolicies(), store.odometerReadings(), store.notes())
        await #expect(throws: CarMemoryStoreError.invalidCommand(.emptyNoteText)) {
            try await store.execute(.createNote(.init(vehicleID: id, rawText: "  ")), now: now)
        }
        await base.failCommands()
        await #expect(throws: CarMemoryStoreError.storageFailure) {
            try await store.execute(.setMaintenancePolicy(.init(vehicleID: id, policy: MaintenanceFixture.custom(
                .engineOilService, km: 15000
            ))), now: now)
        }
        #expect(spy.requests == 0)
    }

    @Test("REQ-WIDGET-009: a test or preview launch's temporary store is not wrapped for reloads")
    func temporaryStoreDoesNotReload() {
        let environment = AppEnvironment.live(arguments: [AppEnvironment.inMemoryArgument])
        #expect(!(environment.store is WidgetReloadingCarMemoryStore))
    }

    @Test("REQ-WIDGET-009: the durable store wired at launch is wrapped for reloads")
    func durableStoreReloads() {
        // The test host's own store, as the app opened it at launch; opening it again changes nothing.
        let environment = AppEnvironment.live(arguments: [])
        #expect(environment.persistence == .durable)
        #expect(environment.store is WidgetReloadingCarMemoryStore)
    }
}

@Suite("Service link")
@MainActor
struct ServiceLinkTests {
    @Test("REQ-WIDGET-007: the widget's link is pitstop://service and asks for Service, not Pit")
    func serviceLinkOpensService() throws {
        #expect(AppLink.service.url.absoluteString == "pitstop://service")
        let capture = CaptureSurfaceRequests()
        let service = ServiceLinkRequests()
        #expect(AppLinkRouter.route(AppLink.service.url, capture: capture, service: service))
        #expect(service.isPending && !capture.isPending)
        #expect(CaptureSurface(url: AppLink.service.url) == nil)
        #expect(try AppLink(url: #require(URL(string: "PITSTOP://Service/"))) == .service)
    }

    @Test("ADR-0025: pitstop://pit still asks for Pit only")
    func pitLinkStillOpensPit() {
        let capture = CaptureSurfaceRequests()
        let service = ServiceLinkRequests()
        #expect(AppLinkRouter.route(AppLink.pit.url, capture: capture, service: service))
        #expect(capture.isPending && !service.isPending)
    }

    @Test(
        "REQ-WIDGET-007: any other link opens nothing",
        arguments: ["pitstop://settings", "pitstop://service/notes", "pitstop://service?id=1", "https://service"]
    )
    func otherLinksAreIgnored(_ string: String) throws {
        let capture = CaptureSurfaceRequests()
        let service = ServiceLinkRequests()
        #expect(try !AppLinkRouter.route(#require(URL(string: string)), capture: capture, service: service))
        #expect(!capture.isPending && !service.isPending)
    }

    @Test("REQ-WIDGET-007: the link waits while a sheet or editor is open, then opens Service once")
    func linkWaitsWhileBlocked() {
        let requests = ServiceLinkRequests()
        requests.request()
        #expect(!requests.take(isPresentationBlocked: true))
        #expect(requests.isPending)
        #expect(requests.take(isPresentationBlocked: false))
        #expect(!requests.take(isPresentationBlocked: false))
    }
}
