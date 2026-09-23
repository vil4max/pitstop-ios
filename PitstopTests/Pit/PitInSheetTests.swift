import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate

/// Pit inside sheets (REQ-UTILITY-012) and capture opened from there (REQ-PIT-026).
@MainActor
@Suite("Pit in sheets")
struct PitInSheetTests {
    private static let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent() // Pit
        .deletingLastPathComponent() // PitstopTests
        .deletingLastPathComponent()

    /// The one file that presents capture over a sheet, and the root, which presents Settings and capture itself.
    private static let presenters: Set = ["PitInSheet.swift", "RootView.swift"]

    static func entry(_ store: FakeCarMemoryStore = FakeCarMemoryStore()) throws -> PitCaptureEntry {
        let registry = try PitQuestionRegistry.product()
        return PitCaptureEntry(
            capture: TestViewModels.pitCapture(store, now: now),
            question: PitQuestionViewModel(
                questions: FakePitQuestionStore(registry: registry), store: store, registry: registry, now: { now }
            )
        )
    }

    @Test("REQ-UTILITY-012: every feature sheet is presented with Pit, and only the root presents a plain sheet")
    func everySheetKeepsPit() throws {
        let files = try Self.swiftFiles(under: "Pitstop")
        #expect(files.count > 10, "the app sources were not found; the rule would pass vacuously")
        let plain = try files.filter { !Self.presenters.contains($0.lastPathComponent) }
            .flatMap { try Self.lines(containing: [".sheet(", ".fullScreenCover(", ".popover("], in: $0) }
        #expect(plain.isEmpty, "sheets presented without Pit: \(plain)")
        let kept = try files.flatMap { try Self.lines(containing: [".pitSheet("], in: $0) }
        #expect(kept.count >= 5, "Car Board, Notes, History, Road and Service present their sheets with Pit: \(kept)")
    }

    @Test("REQ-UTILITY-012: Settings keeps Pit and capture does not, and Pit rides above the keyboard in a sheet")
    func rootSheetsAndKeyboard() throws {
        let root = try Self.source("Pitstop/App/RootView.swift")
        let settings = try #require(root.range(of: "case .settings:"))
        let capture = try #require(root.range(of: "case .pit:"))
        #expect(root[settings.upperBound ..< capture.lowerBound].contains(".pitStaysInSheet()"))
        let captureCase = root[capture.upperBound...].prefix(400)
        #expect(!captureCase.contains("pitStaysInSheet"), "the capture surface shows Pit in its header instead")
        // The layer itself never rides up over the keyboard; Pit inside a sheet does.
        #expect(root.contains(".ignoresSafeArea(.keyboard, edges: .bottom)"))
        #expect(try !Self.source("Pitstop/Features/Pit/PitInSheet.swift").contains("ignoresSafeArea"))
    }

    @Test("REQ-UTILITY-012: capture opened in a sheet is over that sheet, and the layer's Pit opens it once it closes")
    func sheetHostReturnsToTheLayer() throws {
        let entry = try Self.entry()
        let sheet = PitCaptureEntry.Host.sheet(UUID())

        #expect(entry.open(from: sheet))
        #expect(entry.host == sheet && entry.isOverSheet)
        // One capture at a time: neither the layer nor another sheet opens a second one.
        #expect(!entry.open(from: .utilityLayer))
        #expect(!entry.open(from: .sheet(UUID())))

        entry.close(from: sheet)
        #expect(entry.host == nil && !entry.isOverSheet)
        #expect(entry.open(from: .utilityLayer))
        #expect(!entry.isOverSheet)
    }

    @Test("REQ-UTILITY-012: a close from another host leaves the open capture alone")
    func closeFromAnotherHostIsIgnored() throws {
        let entry = try Self.entry()
        let sheet = PitCaptureEntry.Host.sheet(UUID())
        entry.open(from: sheet)
        entry.close(from: .utilityLayer)
        entry.close(from: .sheet(UUID()))
        #expect(entry.host == sheet)
    }

    @Test("REQ-PIT-026: a capture saved over Track several returns to it with its choices and intervals unchanged")
    func captureOverASheetKeepsItsInput() async throws {
        let store = FakeCarMemoryStore()
        let service = TestViewModels.service(store, now: now)
        await service.load()
        let entry = try Self.entry(store)
        let trackSeveral = service.makeTrackSeveral()
        trackSeveral.toggle(.brakeFluid)
        trackSeveral.toggle(.cabinFilter)
        trackSeveral.continueToIntervals()
        trackSeveral.setKilometers("30000", for: .brakeFluid)
        trackSeveral.setMonths("24", for: .cabinFilter)
        let sheet = PitCaptureEntry.Host.sheet(UUID())

        #expect(entry.open(from: sheet))
        entry.capture.text = "поменял масло на 85000"
        await entry.capture.submit(from: .service)
        await entry.capture.confirm()
        #expect(entry.capture.phase == .saved(.service, preservedRaw: false))
        entry.close(from: sheet)
        // The root refreshes the surface under the sheets once capture closes.
        await service.load()

        #expect(entry.host == nil)
        #expect(trackSeveral.step == .intervals)
        #expect(trackSeveral.selected == [.brakeFluid, .cabinFilter])
        #expect(trackSeveral.entry(for: .brakeFluid) == IntervalEntry(kilometers: "30000"))
        #expect(trackSeveral.entry(for: .cabinFilter) == IntervalEntry(months: "24"))
        #expect(await store.completions.count == 1)
    }

    @Test("REQ-PIT-026: closing capture over a sheet writes nothing unconfirmed and leaves a fresh composer")
    func closingOverASheetCancels() async throws {
        let store = FakeCarMemoryStore()
        let entry = try Self.entry(store)
        let sheet = PitCaptureEntry.Host.sheet(UUID())
        entry.open(from: sheet)
        entry.capture.text = "поменял масло на 85000"
        await entry.capture.submit(from: .service)
        guard case .confirming = entry.capture.phase else {
            Issue.record("expected a confirmation, got \(entry.capture.phase)")
            return
        }

        entry.close(from: sheet)

        #expect(entry.capture.phase == .composing && entry.capture.text.isEmpty)
        #expect(await store.executed.isEmpty)
    }

    @Test("REQ-PIT-026: over a sheet, the saved moment offers no screen to open, which would close that sheet")
    func noDestinationOverASheet() throws {
        let presenter = try Self.source("Pitstop/Features/Pit/PitInSheet.swift")
        let capture = try #require(presenter.range(of: "PitCaptureView("))
        #expect(presenter[capture.upperBound...].prefix(300).contains("onOpen: nil"))
    }

    @Test("REQ-PIT-026: an Open Pit request while capture is open over a sheet is met, not presented again")
    func openRequestWhileCapturingOverASheet() throws {
        let entry = try Self.entry()
        let requests = CaptureSurfaceRequests()
        let sheet = PitCaptureEntry.Host.sheet(UUID())
        entry.open(from: sheet)

        // Over a feature sheet the root's gate is blocked: the feature reports a modal task while its sheet is open.
        requests.request()
        #expect(!entry.takeRequest(from: requests, isPresentationBlocked: true))
        #expect(!requests.isPending, "met by the open capture, so it does not reopen capture once the sheet closes")
        #expect(entry.host == sheet)
        // Over Settings the gate is not blocked; the request is met the same way.
        requests.request()
        #expect(!entry.takeRequest(from: requests, isPresentationBlocked: false))
        #expect(!requests.isPending)

        // Blocked by an editor, the request still waits for it to close (ADR 0024).
        entry.close(from: sheet)
        requests.request()
        #expect(!entry.takeRequest(from: requests, isPresentationBlocked: true))
        #expect(requests.isPending)
        #expect(entry.takeRequest(from: requests, isPresentationBlocked: false))
    }

    @Test("REQ-PIT-026: a request waiting behind a sheet is met when the owner opens capture from Pit in that sheet")
    func waitingRequestIsMetByCaptureOverTheSheet() throws {
        let entry = try Self.entry()
        let requests = CaptureSurfaceRequests()
        let sheet = PitCaptureEntry.Host.sheet(UUID())
        // Mark as done is open, so the root is blocked and the request waits (ADR 0024).
        requests.request()
        #expect(!entry.takeRequest(from: requests, isPresentationBlocked: true))
        let waiting = entry.requestGate(for: requests, isPresentationBlocked: true)

        entry.open(from: sheet)

        // The root re-runs the request only when the gate changes, so opening capture must change it.
        let capturing = entry.requestGate(for: requests, isPresentationBlocked: true)
        #expect(capturing != waiting)
        #expect(!entry.takeRequest(from: requests, isPresentationBlocked: true))
        #expect(!requests.isPending, "met by the capture, so no second capture opens once the sheet closes")
    }

    @Test("REQ-PIT-026: a sheet that goes away closes the capture opened over it")
    func hostTeardownClosesCapture() throws {
        // Code lines only, so the comment explaining the rule does not satisfy it.
        let code = try Self.source("Pitstop/Features/Pit/PitInSheet.swift").split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        let modifier = try #require(code.range(of: "struct PitStaysInSheet"))
        let body = code[modifier.upperBound...]
        let close = try #require(
            body.range(of: ".onDisappear { context?.entry.close(from: host) }"),
            "PitStaysInSheet no longer closes its capture when the sheet goes away"
        )
        // On the host's content, not inside the capture sheet it presents.
        let capture = try #require(body.range(of: ".sheet(isPresented:"))
        #expect(close.upperBound < capture.lowerBound)
    }

    static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot.appending(path: relativePath), encoding: .utf8)
    }

    private static func swiftFiles(under relativePath: String) throws -> [URL] {
        let directory = repositoryRoot.appending(path: relativePath)
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// `file:line` for each code line containing one of `needles`; whole-line comments are skipped.
    private static func lines(containing needles: [String], in file: URL) throws -> [String] {
        let lines = try String(contentsOf: file, encoding: .utf8).split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        return lines.enumerated().compactMap { index, line in
            let code = line.trimmingCharacters(in: .whitespaces)
            guard !code.hasPrefix("//"), needles.contains(where: code.contains) else { return nil }
            return "\(file.lastPathComponent):\(index + 1)"
        }
    }
}
