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

    private static func source(_ relativePath: String) throws -> String {
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
