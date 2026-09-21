import Observation

/// A request from outside the view tree to show the Pit capture surface (ADR 0024). `OpenPitIntent`
/// records it; `RootView` takes it and opens the Pit sheet, as a tap on Pit would (REQ-PIT-013).
/// The request is kept until taken, so one made during a cold launch opens Pit once the UI exists.
@MainActor
@Observable
final class CaptureSurfaceRequests {
    private(set) var isPending = false

    func request() {
        isPending = true
    }

    /// Returns whether Pit should open now, and clears the request only then. While a feature editor or
    /// another modal task is presented, the root cannot present Pit over it; the request stays pending
    /// and opens Pit once that task closes, so it is never consumed by a presentation that cannot happen.
    func take(isPresentationBlocked: Bool) -> Bool {
        guard isPending, !isPresentationBlocked else { return false }
        isPending = false
        return true
    }
}
