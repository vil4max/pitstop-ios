import AppIntents

/// Opens PitStop straight to the Pit capture surface (ADR 0024, REQ-CAPTURE-023). The capture itself
/// happens in the app, through the same sheet and pipeline as a tap on Pit (REQ-PIT-013).
///
/// Compiled into the app and the widget extension (ADR 0025): a control can open the app only through an
/// `OpenIntent` that is a member of both targets. `perform()` still runs in the app process only.
struct OpenPitIntent: OpenIntent {
    static let title = LocalizedStringResource("intent.openPit.title", table: "OpenPit")
    static let description = IntentDescription(LocalizedStringResource("intent.openPit.description", table: "OpenPit"))
    /// The system brings the app forward before `perform()` runs, so the sheet opens on a visible scene.
    static let supportedModes: IntentModes = .foreground(.immediate)
    static let allowedExecutionTargets: IntentExecutionTargets = .main
    /// Same rule as Remember (ADR 0023): only an unlocked phone shows the car's memory.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    /// Required by `OpenIntent`. It has one value and a default, so neither Siri nor a control asks for it.
    @Parameter(title: LocalizedStringResource("intent.openPit.target", table: "OpenPit"), default: .pit)
    var target: CaptureSurface

    @Dependency private var captureRequests: CaptureSurfaceRequests

    @MainActor
    func perform() async throws -> some IntentResult {
        captureRequests.request()
        return .result()
    }
}
