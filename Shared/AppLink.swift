import Foundation

/// Every screen a `pitstop://` link may open (ADR 0025, ADR 0036). The scheme is public: any app or web
/// page can open it, so the list is closed and a link carries no data, only which screen to show.
enum AppLink: String, CaseIterable, Sendable {
    /// The Pit capture sheet: the capture widget, `pitstop://pit`.
    case pit
    /// The Service screen: the next-service widget, `pitstop://service`.
    case service

    static let scheme = "pitstop"

    var url: URL {
        guard let url = URL(string: "\(Self.scheme)://\(rawValue)") else {
            preconditionFailure("A fixed ASCII scheme and a case name as host always form a URL")
        }
        return url
    }

    /// Accepts exactly `pitstop://<screen>` (a trailing slash allowed, scheme and host in any case). A path,
    /// query, fragment, user, password or port makes it no link at all.
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == Self.scheme,
              components.path.isEmpty || components.path == "/",
              components.query == nil, components.fragment == nil,
              components.user == nil, components.password == nil, components.port == nil,
              let host = components.host?.lowercased()
        else { return nil }
        self.init(rawValue: host)
    }
}
