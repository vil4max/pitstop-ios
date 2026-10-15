import Foundation

/// A request from outside the view tree to show the Pit capture surface (ADR 0024). `OpenPitIntent` and the
/// widget's `pitstop://pit` link (ADR 0025) record it; `RootView` takes it and opens the Pit sheet, as a tap
/// on Pit would (REQ-PIT-013).
final class CaptureSurfaceRequests: PendingScreenRequest {}
