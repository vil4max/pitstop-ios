import AppIntents
import Foundation
@testable import Pitstop
import Testing

/// Checks the App Shortcuts the build hands to the system: the App Intents metadata extracted from
/// `PitStopShortcuts` and the compiled `AppShortcuts` phrases in the test host's bundle (ADR 0024).
/// Both are build outputs whose formats Apple does not document (`AppShortcut` exposes no properties);
/// a failure in the parsing helpers below may mean the toolchain changed its format, not a product defect.
@Suite("App Shortcuts")
struct AppShortcutsTests {
    private static let applicationName = "${applicationName}"
    private static let locales = ["en", "ru", "uk"]

    private struct ShortcutMetadata {
        let intent: String
        let phrases: [String]
        let shortTitleKey: String
        let systemImageName: String
    }

    private func extractedShortcuts() throws -> [ShortcutMetadata] {
        let format = "undocumented App Intents metadata format changed?"
        let url = try #require(
            Bundle.main.url(forResource: "extract", withExtension: "actionsdata", subdirectory: "Metadata.appintents"),
            "No Metadata.appintents/extract.actionsdata in the test host; did App Intents metadata extraction run?"
        )
        let root = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
            "extract.actionsdata is not a JSON object (\(format))"
        )
        let shortcuts = try #require(root["autoShortcuts"] as? [[String: Any]], "No autoShortcuts array (\(format))")
        return try shortcuts.map { shortcut in
            let templates = try #require(
                shortcut["phraseTemplates"] as? [[String: Any]],
                "No phraseTemplates (\(format))"
            )
            let shortTitle = try #require(shortcut["shortTitle"] as? [String: Any], "No shortTitle (\(format))")
            return try ShortcutMetadata(
                intent: #require(shortcut["actionIdentifier"] as? String, "No actionIdentifier (\(format))"),
                phrases: templates
                    .map { try #require($0["key"] as? String, "Phrase template without key (\(format))") },
                shortTitleKey: #require(shortTitle["key"] as? String, "Short title without key (\(format))"),
                systemImageName: #require(shortcut["systemImageName"] as? String, "No systemImageName (\(format))")
            )
        }
    }

    /// Localized phrases keyed by source phrase. The compiled catalog stores each string-set variant as
    /// `#!SET#!_<source phrase>[<index>]`, an undocumented Xcode 27 output observed in the built app.
    private func localizedPhrases(_ locale: String) throws -> [String: [String]] {
        let url = try #require(
            Bundle.main.url(
                forResource: "AppShortcuts",
                withExtension: "strings",
                subdirectory: nil,
                localization: locale
            ),
            "No \(locale).lproj/AppShortcuts.strings in the test host; is \(locale) missing from the catalog?"
        )
        let table = try #require(
            NSDictionary(contentsOf: url) as? [String: String],
            "\(locale) AppShortcuts.strings is not a string table (undocumented compiled format changed?)"
        )
        var phrases: [String: [String]] = [:]
        for (key, value) in table {
            let source = key.replacing("#!SET#!_", with: "").replacing(/\[\d+\]$/, with: "")
            phrases[source, default: []].append(value)
        }
        return phrases
    }

    @Test("ADR-0024, REQ-CAPTURE-002: exactly two shortcuts, Remember first, then Open Pit")
    func exposesTheIntendedShortcuts() throws {
        #expect(PitStopShortcuts.appShortcuts.count == 2)
        let shortcuts = try extractedShortcuts()
        #expect(shortcuts.map(\.intent) == ["RememberInPitStopIntent", "OpenPitIntent"])
        #expect(shortcuts.map(\.shortTitleKey) == ["shortcut.remember.title", "shortcut.openPit.title"])
        #expect(shortcuts.allSatisfy { !$0.systemImageName.isEmpty })
    }

    @Test("ADR-0024: every source phrase names the app, and no phrase runs two shortcuts")
    func sourcePhrasesNameTheApp() throws {
        let phrases = try extractedShortcuts().flatMap(\.phrases)
        #expect(!phrases.isEmpty)
        #expect(phrases.allSatisfy { $0.contains(Self.applicationName) })
        #expect(Set(phrases).count == phrases.count)
    }

    @Test("ADR-0024: every phrase has variants in en, ru and uk, and each names the app", arguments: locales)
    func localizedPhrasesNameTheApp(locale: String) throws {
        let sources = try Set(extractedShortcuts().flatMap(\.phrases))
        let localized = try localizedPhrases(locale)
        #expect(Set(localized.keys) == sources)
        let variants = localized.values.flatMap(\.self)
        #expect(variants.allSatisfy { $0.contains(Self.applicationName) })
        // One spoken phrase must not be claimed by two shortcuts in the same language.
        #expect(Set(variants).count == variants.count)
    }

    @Test("ADR-0024, REQ-CAPTURE-023: Open Pit brings the app forward and runs in the app process")
    func openPitRunsInTheForeground() {
        #expect(OpenPitIntent.supportedModes == .foreground(.immediate))
        #expect(OpenPitIntent.allowedExecutionTargets == .main)
        #expect(OpenPitIntent.authenticationPolicy == .requiresLocalDeviceAuthentication)
    }

    @Test("ADR-0025: as an OpenIntent, Open Pit's target defaults to Pit, its only value, so nothing asks for it")
    func openPitTargetsOnlyPit() throws {
        #expect(CaptureSurface.allCases == [.pit])
        let url = try #require(
            Bundle.main.url(forResource: "extract", withExtension: "actionsdata", subdirectory: "Metadata.appintents")
        )
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let actions = try #require(root["actions"] as? [String: [String: Any]])
        let parameters = try #require(actions["OpenPitIntent"]?["parameters"] as? [[String: Any]])
        #expect(parameters.count == 1)
        let target = try #require(parameters.first)
        #expect(target["name"] as? String == "target")
        // The default is stored as `[marker, {"string": {"wrapper": "pit"}}]` (undocumented format).
        let metadata = String(describing: target["typeSpecificMetadata"] ?? "")
        #expect(metadata.contains("DefaultValue") && metadata.contains("pit"), "No default target (format changed?)")
    }
}

@Suite("Capture surface requests")
@MainActor
struct CaptureSurfaceRequestsTests {
    @Test("REQ-PIT-013, ADR-0024: nothing is pending until a shortcut asks for Pit")
    func startsWithoutRequest() {
        let requests = CaptureSurfaceRequests()
        #expect(!requests.isPending)
        #expect(!requests.take(isPresentationBlocked: false))
    }

    @Test("REQ-CAPTURE-023, ADR-0024: a request opens Pit once and is then cleared")
    func requestIsTakenOnce() {
        let requests = CaptureSurfaceRequests()
        requests.request()
        #expect(requests.isPending)
        #expect(requests.take(isPresentationBlocked: false))
        #expect(!requests.isPending)
        #expect(!requests.take(isPresentationBlocked: false))
    }

    @Test("ADR-0024: requests made before the UI takes them open Pit once, not once per request")
    func repeatedRequestsCoalesce() {
        let requests = CaptureSurfaceRequests()
        requests.request()
        requests.request()
        #expect(requests.take(isPresentationBlocked: false))
        #expect(!requests.take(isPresentationBlocked: false))
    }

    @Test("ADR-0024: a later request opens Pit again")
    func laterRequestIsPendingAgain() {
        let requests = CaptureSurfaceRequests()
        requests.request()
        _ = requests.take(isPresentationBlocked: false)
        requests.request()
        #expect(requests.take(isPresentationBlocked: false))
    }

    @Test("ADR-0024: an open editor defers the request without consuming it; Pit opens once the editor closes")
    func openEditorDefersRequest() {
        let requests = CaptureSurfaceRequests()
        requests.request()
        #expect(!requests.take(isPresentationBlocked: true))
        #expect(requests.isPending)
        #expect(!requests.take(isPresentationBlocked: true))
        #expect(requests.take(isPresentationBlocked: false))
        #expect(!requests.isPending)
    }
}

@Suite("Feature task presentation")
@MainActor
struct FeatureTaskPresentationTests {
    @Test("ADR-0024: an editor on a feature screen blocks Open Pit until it is withdrawn")
    func featureEditorBlocks() {
        let pit = PitPresenceModel()
        let editor = PitActivitySource.unique()
        #expect(!pit.isFeatureTaskPresented)
        pit.report(.modalTask, from: editor)
        #expect(pit.isFeatureTaskPresented)
        pit.report([], from: editor)
        #expect(!pit.isFeatureTaskPresented)
    }

    @Test("ADR-0024: the root's own Settings sheet does not block, and scrolling or editing alone does not either")
    func utilitySheetAndNonModalActivityDoNotBlock() {
        let pit = PitPresenceModel()
        pit.report(.modalTask, from: .utilitySheet)
        pit.report([.scrolling, .editing], from: .unique())
        #expect(!pit.isFeatureTaskPresented)
    }
}
