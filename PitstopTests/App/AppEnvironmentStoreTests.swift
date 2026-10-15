import Foundation
@testable import Pitstop
import Testing

private let now = Date(timeIntervalSince1970: 1_800_000_000)

/// The composition root's store choice, against temporary locations only: these tests never resolve the
/// App Group container or the app's own store.
@Suite("App environment store choice")
struct AppEnvironmentStoreTests {
    @Test("REQ-WIDGET-003: a store that opens is the durable store, kept at its location")
    func openedStoreIsDurable() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let environment = AppEnvironment.live(arguments: [], sources: testSources(durableURL: url))
        #expect(environment.persistence == .durable)
        let id = try await environment.store.currentVehicle().id
        try await environment.store.execute(.createNote(.init(vehicleID: id, rawText: "Fictional note")), now: now)
        #expect(try await TestStore.carMemory(url: url).notes().map(\.rawText) == ["Fictional note"])
    }

    @Test("REQ-WIDGET-003: a store that cannot open falls back to memory, and nothing is wrapped for reloads")
    func unopenableStoreFallsBackToMemory() async throws {
        let url = TestStore.temporaryURL()
        defer { TestStore.remove(at: url) }
        let spy = ReloadSpy()
        var sources = testSources(durableURL: url, reloader: spy)
        let open = sources.open
        sources.open = { location, registry in location == nil ? open(nil, registry) : nil }
        let environment = AppEnvironment.live(arguments: [], sources: sources)
        #expect(environment.persistence == .temporary)
        #expect(!(environment.store is WidgetReloadingCarMemoryStore))
        #expect(spy.requests == 0)
        let id = try await environment.store.currentVehicle().id
        try await environment.store.execute(.createNote(.init(vehicleID: id, rawText: "Fictional note")), now: now)
        #expect(try await environment.store.notes().count == 1)
    }

    @Test("REQ-WIDGET-003: without a durable location, as after a move without the App Group, nothing durable opens")
    func missingDurableLocationOpensNothingDurable() {
        let spy = ReloadSpy()
        var sources = testSources(durableURL: nil, reloader: spy)
        let open = sources.open
        var openedLocations: [URL?] = []
        sources.open = { location, registry in
            openedLocations.append(location)
            return open(location, registry)
        }
        let environment = AppEnvironment.live(arguments: [], sources: sources)
        #expect(environment.persistence == .temporary)
        #expect(openedLocations == [nil])
        #expect(spy.requests == 0)
    }

    @Test("ADR-0017: when not even a memory store can be built, every store call fails visibly")
    func noStoreAtAllIsUnavailable() async {
        var sources = testSources(durableURL: TestStore.temporaryURL())
        sources.open = { _, _ in nil }
        let environment = AppEnvironment.live(arguments: [], sources: sources)
        #expect(environment.persistence == .temporary)
        #expect(environment.store is UnavailableCarMemoryStore)
        #expect(environment.questions is UnavailablePitQuestionStore)
        await #expect(throws: CarMemoryStoreError.storageFailure) {
            try await environment.store.currentVehicle()
        }
    }

    @Test("ADR-0036: a hosted unit-test run launches on the in-memory store, a normal launch is unchanged")
    func hostedTestRunLaunchesInMemory() {
        let hosted = ["XCTestConfigurationFilePath": "/tmp/fictional.xctestconfiguration"]
        #expect(AppEnvironment.launchArguments(["Pitstop"], environment: hosted)
            == ["Pitstop", AppEnvironment.inMemoryArgument])
        #expect(AppEnvironment.launchArguments(["Pitstop", AppEnvironment.inMemoryArgument], environment: hosted)
            == ["Pitstop", AppEnvironment.inMemoryArgument])
        #expect(AppEnvironment.launchArguments(["Pitstop"], environment: [:]) == ["Pitstop"])
        // This process is the test host, so the arguments `PitstopApp.init` reads here ask for memory.
        #expect(AppEnvironment.launchArguments().contains(AppEnvironment.inMemoryArgument))
    }

    private func testSources(durableURL: URL?, reloader: any NextServiceReloading = ReloadSpy())
        -> AppEnvironment.StoreSources
    {
        var sources = AppEnvironment.StoreSources.live
        sources.durableURL = { durableURL }
        sources.reloader = reloader
        return sources
    }
}
