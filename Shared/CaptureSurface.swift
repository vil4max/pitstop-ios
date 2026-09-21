import AppIntents
import Foundation

/// The places outside entries may open (ADR 0025). Only Pit exists: `OpenIntent` needs a target type, and
/// the `pitstop://` URL scheme accepts nothing else, so the scheme cannot reach any other screen or data.
enum CaptureSurface: String, AppEnum {
    case pit

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("intent.captureSurface.type", table: "OpenPit")
    )
    static let caseDisplayRepresentations: [CaptureSurface: DisplayRepresentation] = [
        .pit: DisplayRepresentation(title: LocalizedStringResource("intent.captureSurface.pit", table: "OpenPit")),
    ]

    static let urlScheme = "pitstop"

    /// The widget's link, `pitstop://pit`.
    var url: URL {
        guard let url = URL(string: "\(Self.urlScheme)://\(rawValue)") else {
            preconditionFailure("A fixed ASCII scheme and a case name as host always form a URL")
        }
        return url
    }

    /// Accepts exactly `pitstop://pit` (a trailing slash allowed, scheme and host in any case). Anything else,
    /// including a path, query, fragment, or user, is not a capture surface, so a link from another app or a
    /// web page can open the Pit sheet and nothing more.
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == Self.urlScheme,
              components.path.isEmpty || components.path == "/",
              components.query == nil, components.fragment == nil,
              components.user == nil, components.password == nil, components.port == nil,
              let host = components.host?.lowercased()
        else { return nil }
        self.init(rawValue: host)
    }
}
