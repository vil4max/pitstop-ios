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
        .pit: DisplayRepresentation(title: LocalizedStringResource("intent.captureSurface.pit", table: "OpenPit"))
    ]

    /// The widget's link, `pitstop://pit`; `AppLinkRouter` turns it back into a Pit request.
    var url: URL {
        AppLink.pit.url
    }
}
