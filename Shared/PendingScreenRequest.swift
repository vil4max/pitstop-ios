import Foundation
import Observation

/// A request from outside the view tree to show one screen. It is kept until taken, so one made during a cold
/// launch is still honoured once the UI exists. Each screen has its own subclass: `AppDependencyManager` looks
/// dependencies up by concrete type, so two screens never share one.
@MainActor
@Observable
class PendingScreenRequest {
    private(set) var isPending = false

    func request() {
        isPending = true
    }

    /// Returns whether the screen should open now, and clears the request only then. While a feature editor or
    /// another modal task is presented, the root cannot present over it; the request stays pending and opens
    /// once that task closes, so it is never consumed by a presentation that cannot happen.
    func take(isPresentationBlocked: Bool) -> Bool {
        guard isPending, !isPresentationBlocked else { return false }
        isPending = false
        return true
    }
}
