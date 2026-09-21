import Foundation
@testable import Pitstop
import Testing

@Suite("Pit URL routing")
@MainActor
struct PitURLRoutingTests {
    @Test("ADR-0025, REQ-CAPTURE-023: the widget's link is pitstop://pit and routes back to Pit")
    func widgetLinkIsPit() {
        #expect(CaptureSurface.pit.url.absoluteString == "pitstop://pit")
        #expect(CaptureSurface(url: CaptureSurface.pit.url) == .pit)
    }

    @Test(
        "ADR-0025, REQ-CAPTURE-023: pitstop://pit asks for the Pit sheet",
        arguments: ["pitstop://pit", "pitstop://pit/", "PITSTOP://Pit"]
    )
    func pitURLRequestsPit(_ string: String) throws {
        let requests = CaptureSurfaceRequests()
        let url = try #require(URL(string: string))
        #expect(requests.request(opening: url))
        #expect(requests.take(isPresentationBlocked: false))
    }

    @Test(
        "ADR-0025: any other URL is ignored and opens nothing",
        arguments: [
            "pitstop://settings",
            "pitstop://notes",
            "pitstop://pit/notes",
            "pitstop://pit?text=oil",
            "pitstop://pit#capture",
            "pitstop://user@pit",
            "pitstop://pit:8080",
            "pitstop:pit",
            "pitstop://",
            "https://pit",
            "https://example.com/pitstop/pit",
            "otherapp://pit",
        ]
    )
    func otherURLsAreIgnored(_ string: String) throws {
        let requests = CaptureSurfaceRequests()
        let url = try #require(URL(string: string))
        #expect(!requests.request(opening: url))
        #expect(!requests.isPending)
        #expect(!requests.take(isPresentationBlocked: false))
    }

    @Test("ADR-0025, ADR-0024: a link opened while an editor is presented waits, then opens Pit once")
    func linkDefersWhileBlocked() {
        let requests = CaptureSurfaceRequests()
        #expect(requests.request(opening: CaptureSurface.pit.url))
        #expect(!requests.take(isPresentationBlocked: true))
        #expect(requests.isPending)
        #expect(requests.take(isPresentationBlocked: false))
        #expect(!requests.take(isPresentationBlocked: false))
    }

    @Test("ADR-0025: the app registers the pitstop scheme and no other")
    func appRegistersOnlyThePitstopScheme() throws {
        let types = try #require(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
            "No CFBundleURLTypes in the app's Info.plist"
        )
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        #expect(schemes == [CaptureSurface.urlScheme])
    }
}

/// Checks the widget extension as the build embeds it in the test host (ADR 0025). The App Intents metadata
/// is an undocumented build output (see `AppShortcutsTests`); a parsing failure may mean a format change.
@Suite("Widget extension")
struct WidgetExtensionTests {
    private static let locales = ["en", "ru", "uk"]
    private static let openPitKeys = [
        "intent.openPit.title",
        "intent.openPit.description",
        "intent.openPit.target",
        "intent.captureSurface.type",
        "intent.captureSurface.pit",
    ]
    private static let widgetKeys = [
        "control.openPit.title",
        "control.openPit.description",
        "widget.capture.title",
        "widget.capture.description",
        "widget.capture.action",
        "widget.capture.hint",
    ]

    private func extensionBundle() throws -> Bundle {
        let plugIns = try #require(Bundle.main.builtInPlugInsURL, "The test host has no PlugIns directory")
        return try #require(
            Bundle(url: plugIns.appending(path: "PitstopWidgets.appex")),
            "PitstopWidgets.appex is not embedded in the app"
        )
    }

    private func table(_ name: String, locale: String, in bundle: Bundle) throws -> [String: String] {
        let url = try #require(
            bundle.url(forResource: name, withExtension: "strings", subdirectory: nil, localization: locale),
            "No \(locale).lproj/\(name).strings in \(bundle.bundleURL.lastPathComponent)"
        )
        return try #require(NSDictionary(contentsOf: url) as? [String: String], "\(name).strings is not a table")
    }

    private func actions(in bundle: Bundle) throws -> [String: [String: Any]] {
        let url = try #require(
            bundle.url(forResource: "extract", withExtension: "actionsdata", subdirectory: "Metadata.appintents"),
            "No App Intents metadata in \(bundle.bundleURL.lastPathComponent)"
        )
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try #require(root["actions"] as? [String: [String: Any]], "No actions (metadata format changed?)")
    }

    @Test("ADR-0025: the extension is embedded with its bundle ID and the app's versions")
    func extensionIsEmbedded() throws {
        let widgets = try extensionBundle()
        #expect(widgets.bundleIdentifier == "dev.vil4max.pitstop.widgets")
        let point = (widgets
            .object(forInfoDictionaryKey: "NSExtension") as? [String: Any])?["NSExtensionPointIdentifier"]
        #expect(point as? String == "com.apple.widgetkit-extension")
        for key in ["CFBundleShortVersionString", "CFBundleVersion"] {
            let version = widgets.object(forInfoDictionaryKey: key) as? String
            #expect(version != nil)
            #expect(version == Bundle.main.object(forInfoDictionaryKey: key) as? String, "\(key) differs")
        }
    }

    @Test("ADR-0025, REQ-CAPTURE-023: both bundles declare Open Pit as an OpenIntent performed only in the app")
    func openPitIsAnOpenIntentInBothBundles() throws {
        for bundle in try [Bundle.main, extensionBundle()] {
            let name = bundle.bundleURL.lastPathComponent
            let openPit = try #require(try actions(in: bundle)["OpenPitIntent"], "No OpenPitIntent in \(name)")
            let protocols = openPit["systemProtocols"] as? [String] ?? []
            #expect(protocols.contains { $0.hasSuffix("OpenEntity") }, "OpenPitIntent is not an OpenIntent in \(name)")
            // Execution target type 1 is `.main`, as in the app's own metadata before the extension existed.
            let targets = (openPit["allowedTargets"] as? [[String: Any]])?.compactMap { $0["type"] as? Int }
            #expect(targets == [1], "OpenPitIntent may run outside the app in \(name)")
        }
        #expect(try actions(in: extensionBundle()).keys.sorted() == ["OpenPitIntent"])
    }

    @Test("ADR-0025: Open Pit's strings resolve identically in the app and the extension", arguments: locales)
    func openPitStringsMatch(locale: String) throws {
        let app = try table("OpenPit", locale: locale, in: .main)
        let widgets = try table("OpenPit", locale: locale, in: extensionBundle())
        #expect(Set(app.keys) == Set(Self.openPitKeys))
        #expect(app == widgets)
        #expect(app.allSatisfy { !$0.value.isEmpty && $0.value != $0.key })
    }

    @Test("ADR-0025: the control and the widget are named in every locale", arguments: locales)
    func widgetStringsAreLocalized(locale: String) throws {
        let widgets = try table("Localizable", locale: locale, in: extensionBundle())
        for key in Self.widgetKeys {
            let value = try #require(widgets[key], "\(key) missing in \(locale)")
            #expect(!value.isEmpty && value != key)
        }
    }
}
