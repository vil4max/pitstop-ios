import Foundation
@testable import Pitstop
import Testing

/// CAP-007: one thought typed into Pit, through the real pipeline and the real SwiftData store, to
/// what the Car Board shows. Nothing here is faked except the clock.
private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(30 * 86400)

@MainActor
private struct App {
    let store: SwiftDataCarMemoryStore
    let pit: PitCaptureViewModel
    let board: CarBoardViewModel

    init(storeURL: URL? = nil) throws {
        store = try SwiftDataCarMemoryStore(modelContainer: PersistenceContainer.make(storeURL: storeURL))
        pit = PitCaptureViewModel(
            pipeline: RememberPipeline(store: store, interpreter: RuleBasedInterpreter(), now: { now }),
            now: { now }
        )
        board = CarBoardViewModel(store: store, now: { now })
    }

    /// Types the words into Pit and submits them from the Car Board, as the user would.
    func say(_ words: String) async {
        pit.reset()
        pit.text = words
        await pit.submit(from: .carBoard)
    }

    /// Accepts a proposal if Pit asked for confirmation; returns whether it had to.
    @discardableResult
    func confirmIfAsked() async -> Bool {
        guard case .confirming = pit.phase else { return false }
        await pit.confirm()
        return true
    }
}

@Suite("Remember end to end")
@MainActor
struct RememberEndToEndTests {
    @Test("REQ-CAPTURE-001, REQ-CAPTURE-010: a plain thought is saved as written and the Notes tile shows it")
    func thoughtReachesNotesTile() async throws {
        let app = try App()

        await app.say("стук справа при повороте")
        await app.board.load()

        #expect(app.pit.phase == .saved(.notes, preservedRaw: true))
        #expect(app.board.state.notes.activeCount == 1)
        #expect(app.board.state.notes.latest?.rawText == "стук справа при повороте")
    }

    @Test("REQ-CAPTURE-016: an oil change waits for confirmation, then reaches History and the timeline")
    func completionNeedsConfirmationThenShows() async throws {
        let app = try App()

        await app.say("поменял масло на 84200")
        await app.board.load()
        // Before confirmation nothing is written: no cycle reset, no timeline entry.
        guard case .confirming = app.pit.phase else {
            Issue.record("expected a confirmation, got \(app.pit.phase)")
            return
        }
        #expect(app.board.state.history.entries.isEmpty)

        await app.pit.confirm()
        await app.board.load()

        #expect(app.pit.phase == .saved(.service, preservedRaw: false))
        guard case let .completion(completion)? = app.board.state.history.latest else {
            Issue
                .record(
                    "expected the completion on the timeline, got \(String(describing: app.board.state.history.latest))"
                )
            return
        }
        #expect(completion.operationID == .engineOilService)
        #expect(completion.odometerKm == 84200)
        #expect(app.board.state.notes.activeCount == 0)
        // Marking oil done at 84 200 km says the car has reached it; header and Service agree (REQ-BOARD-026).
        #expect(app.board.state.mileage == .kilometers(84200))
    }

    @Test("REQ-CAPTURE-019: a car wash with a price reaches the History tile")
    func carWashReachesHistory() async throws {
        let app = try App()

        await app.say("помыл машину за 450")
        await app.confirmIfAsked()
        await app.board.load()

        #expect(app.pit.phase == .saved(.history, preservedRaw: false))
        guard case let .event(event)? = app.board.state.history.latest else {
            Issue.record("expected the wash on the timeline, got \(String(describing: app.board.state.history.latest))")
            return
        }
        #expect(event.kind == .carWash)
        #expect(event.amount == 450)
    }

    @Test("REQ-CAPTURE-010: a mileage said to Pit is saved as a reading and becomes the mileage on the board")
    func mileageReachesBoard() async throws {
        let app = try App()

        await app.say("пробег 91500")
        await app.confirmIfAsked()
        await app.board.load()

        #expect(app.pit.phase == .saved(.carBoard, preservedRaw: false))
        #expect(app.board.state.mileage == .kilometers(91500))
    }

    @Test("REQ-CAPTURE-005: closing Pit on a pending oil change leaves the board unchanged")
    func cancelledCompletionChangesNothing() async throws {
        let app = try App()

        await app.say("поменял масло на 84200")
        app.pit.cancel()
        await app.board.load()

        #expect(app.pit.phase == .composing)
        #expect(app.board.state.history.entries.isEmpty)
        #expect(app.board.state.notes.activeCount == 0)
        #expect(app.board.state.mileage == .unknown)
    }

    @Test("REQ-CAPTURE-014: an intention stays a note and changes no service, history or mileage")
    func intentionStaysANote() async throws {
        let app = try App()

        await app.say("надо поменять масло на 90000")
        await app.board.load()

        #expect(app.pit.phase == .saved(.notes, preservedRaw: true))
        #expect(app.board.state.notes.activeCount == 1)
        #expect(app.board.state.history.entries.isEmpty)
        #expect(app.board.state.mileage == .unknown)
    }

    @Test("REQ-CAPTURE-011: what Pit saved is still on the board after the app is relaunched")
    func savedMemorySurvivesRelaunch() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Pitstop.store")

        do {
            let first = try App(storeURL: url)
            await first.say("проверить давление в шинах")
            await first.say("поменял масло на 84200")
            await first.confirmIfAsked()
        }
        let relaunched = try App(storeURL: url)
        await relaunched.board.load()

        #expect(relaunched.board.state.notes.latest?.rawText == "проверить давление в шинах")
        guard case let .completion(completion)? = relaunched.board.state.history.latest else {
            Issue.record("expected the completion after relaunch")
            return
        }
        #expect(completion.odometerKm == 84200)
    }
}
