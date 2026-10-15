/// SF Symbol names one meaning shares across the app and its widgets, so no surface drifts from another.
enum PitSymbol {
    /// Service: the next-service widget, the Car Board tile, History's service rows and Service's empty state.
    static let service = "wrench.and.screwdriver"
    /// Pit capture: the Remember widget, the Open Pit control and the Open Pit App Shortcut, whose
    /// `systemImageName` stays a literal for build-time extraction and is held equal by a test.
    static let capture = "square.and.pencil"
}
