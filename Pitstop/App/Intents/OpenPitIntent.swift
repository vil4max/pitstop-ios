import AppIntents

/// Opens PitStop straight to the Pit capture surface (ADR 0024, REQ-CAPTURE-023). The capture itself
/// happens in the app, through the same sheet and pipeline as a tap on Pit (REQ-PIT-013).
struct OpenPitIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.openPit.title"
    static let description = IntentDescription("intent.openPit.description")
    /// The system brings the app forward before `perform()` runs, so the sheet opens on a visible scene.
    static let supportedModes: IntentModes = .foreground(.immediate)
    static let allowedExecutionTargets: IntentExecutionTargets = .main
    /// Same rule as Remember (ADR 0023): only an unlocked phone shows the car's memory.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Dependency private var captureRequests: CaptureSurfaceRequests

    @MainActor
    func perform() async throws -> some IntentResult {
        captureRequests.request()
        return .result()
    }
}
