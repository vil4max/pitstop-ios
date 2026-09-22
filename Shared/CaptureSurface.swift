import AppIntents
import Foundation

/// The capture surfaces outside entries may open (ADR 0025). Only Pit exists: `OpenIntent` needs a target
/// type. The URL scheme's other screen, Service, is an `AppLink` and never an intent target (ADR 0036).
enum CaptureSurface: String, AppEnum {
    case pit

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("intent.captureSurface.type", table: "OpenPit")
    )
    static let caseDisplayRepresentations: [CaptureSurface: DisplayRepresentation] = [
        .pit: DisplayRepresentation(title: LocalizedStringResource("intent.captureSurface.pit", table: "OpenPit")),
    ]

    static let urlScheme = AppLink.scheme

    /// The widget's link, `pitstop://pit`.
    var url: URL {
        AppLink.pit.url
    }

    /// Only `pitstop://pit` is a capture surface; every other link, including `pitstop://service`, is not,
    /// so a link from another app or a web page opens the Pit sheet and nothing more through this type.
    init?(url: URL) {
        guard AppLink(url: url) == .pit else { return nil }
        self = .pit
    }
}
