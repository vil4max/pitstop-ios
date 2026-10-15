import Foundation

/// A request from the next-service widget's `pitstop://service` link to show Service (ADR 0036). Like an
/// Open Pit request (ADR 0024) it is kept until `RootView` takes it, so a cold launch still arrives on
/// Service, and it waits while a sheet or an editor is open instead of closing what the person was doing.
final class ServiceLinkRequests: PendingScreenRequest {}

/// The app's only entry for `pitstop://` links: each known link becomes the pending request of its
/// screen; anything else is ignored. Returns whether the URL was a PitStop link.
enum AppLinkRouter {
    @MainActor
    @discardableResult
    static func route(_ url: URL, capture: CaptureSurfaceRequests, service: ServiceLinkRequests) -> Bool {
        switch AppLink(url: url) {
        case .pit:
            capture.request()
        case .service:
            service.request()
        case nil:
            return false
        }
        return true
    }
}
