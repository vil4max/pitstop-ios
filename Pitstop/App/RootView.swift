import SwiftUI

/// Hosts navigation and the utility layer. The layer sits outside the navigation stack, so
/// Settings and Pit keep one position on Car Board and on every detail screen (REQ-UTILITY-003, 005).
struct RootView: View {
    let carBoard: CarBoardViewModel
    let notes: NotesViewModel
    let history: HistoryViewModel
    let service: ServiceViewModel
    let road: RoadViewModel
    let pitCapture: PitCaptureViewModel
    let pitQuestion: PitQuestionViewModel
    /// Where capture is open: over the layer or over a sheet, never both (REQ-PIT-026).
    let pitEntry: PitCaptureEntry
    let analyticsSharing: AnalyticsSharing
    let captureRequests: CaptureSurfaceRequests
    let serviceRequests: ServiceLinkRequests
    /// DEBUG demo seeding; it must finish before any surface loads, or a surface opened first reads an empty store.
    var prepare: (@Sendable () async -> Void)?

    @State private var pit = PitPresenceModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var path: [CarBoardRoute] = RootView.initialPath()
    @State private var sheet: UtilitySheet?
    @State private var isPrepared = false
    @State private var wasInBackground = false

    /// DEBUG only: `-pitstop-pit "text"` opens Pit and submits the text, for smoke checks without taps.
    private static func initialCapture(arguments: [String] = ProcessInfo.processInfo.arguments) -> String? {
        #if DEBUG
            if let index = arguments.firstIndex(of: "-pitstop-pit"), arguments.indices.contains(index + 1) {
                return arguments[index + 1]
            }
        #endif
        return nil
    }

    /// Capture opened from Pit inside a sheet reports apart from the root's own utility sheet.
    private static let captureOverSheet = PitActivitySource.unique()

    /// The user settles on a surface before Pit may knock; arriving is not idleness.
    private static let questionSettleDelay: Duration = .seconds(2)

    /// DEBUG only: `-pitstop-show-question` opens Pit as soon as it asks, for smoke checks without taps.
    private static func opensAskedQuestion(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        #if DEBUG
            return arguments.contains("-pitstop-show-question")
        #else
            return false
        #endif
    }

    /// DEBUG only: `-pitstop-open road` opens a surface directly, for smoke checks without taps.
    private static func initialPath(arguments: [String] = ProcessInfo.processInfo.arguments) -> [CarBoardRoute] {
        #if DEBUG
            if let index = arguments.firstIndex(of: "-pitstop-open"), arguments.indices.contains(index + 1),
               let kind = CarBoardTileKind(rawValue: arguments[index + 1])
            {
                return [.tile(kind)]
            }
        #endif
        return []
    }

    private enum UtilitySheet: String, Identifiable {
        case settings
        case pit

        var id: String {
            rawValue
        }
    }

    var body: some View {
        if prepare == nil || isPrepared {
            content
        } else {
            PitColor.surfacePrimary
                .ignoresSafeArea()
                .task {
                    await prepare?()
                    isPrepared = true
                }
        }
    }

    /// One modifier chain, split into slices only for length; the slices apply in the original order.
    private var content: some View {
        systemEntry(pitCoordination(boardNavigation))
            // Outside `systemEntry`, so Settings, presented there, keeps Pit as feature sheets do (REQ-UTILITY-012).
            .environment(\.pitInSheet, PitInSheetContext(entry: pitEntry, presence: pit, visible: visibleFeature))
    }

    private var boardNavigation: some View {
        NavigationStack(path: $path) {
            CarBoardView(viewModel: carBoard)
                .navigationDestination(for: CarBoardRoute.self) { route in
                    destination(for: route)
                }
        }
        .tint(PitColor.accentPrimary)
        .environment(\.pitActivityReporter, .forwarding(to: pit))
        // Car Board is a projection: refresh it whenever the user comes back from an owned surface.
        .onChange(of: path) { _, newPath in
            if newPath.isEmpty {
                Task { await carBoard.load() }
            }
        }
        // A safe-area inset, not an overlay: scroll content is inset by the layer's height, so the
        // last tile always scrolls clear of the controls (REQ-UTILITY-008).
        .safeAreaInset(edge: .bottom, spacing: 0) {
            UtilityLayer(onSettings: { sheet = .settings }, onPit: { sheet = .pit }, pitState: pit.state)
        }
        // Text input lives in sheets, which cover the layer; it never rides up over a keyboard.
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func pitCoordination(_ view: some View) -> some View {
        view
            // Pit waits nearby and yields to whatever the user is doing: the utility sheets report here, and
            // every screen, editor, and scroll view below reports through the environment (ADR 0019).
            .task(id: reduceMotion) { pit.setReduceMotion(reduceMotion) }
            .onChange(of: sheet) { _, newSheet in
                pit.report(newSheet == nil ? [] : newSheet == .pit ? .capturing : .modalTask, from: .utilitySheet)
                // Whatever Pit saved shows on the board and on the surface the user is on.
                if newSheet == nil {
                    Task { await refreshVisibleSurface() }
                }
            }
            // However Pit was closed — Close or a swipe — the entry cancels a pending capture (REQ-PIT-026).
            .onChange(of: sheet == .pit) { wasPit, isPit in
                if isPit {
                    pitEntry.open(from: .utilityLayer)
                } else if wasPit {
                    pitEntry.close(from: .utilityLayer)
                }
            }
            .onChange(of: pitEntry.host) { oldHost, newHost in
                pit.report(pitEntry.isOverSheet ? .capturing : [], from: Self.captureOverSheet)
                guard let oldHost, newHost == nil else { return }
                // Pit leaves the sheet: its eyes close for a moment where he waits (ADR 0028).
                Task { await pit.leave() }
                // The root's own sheet refreshes when it closes; a capture over another sheet refreshes here.
                if oldHost != .utilityLayer {
                    Task { await refreshVisibleSurface() }
                }
            }
            // Pit may interrupt only where the question belongs and only once the user has settled there
            // (REQ-PIT-006, 007); the policy and the question's relevance decide the rest (ADR 0017). Settling
            // restarts after every navigation and every return to an idle interface (ADR 0019).
            .task(id: askTrigger) {
                await askTrigger.run(
                    settle: { try await Task.sleep(for: Self.questionSettleDelay) },
                    ask: { await askIfUseful() }
                )
            }
            .onChange(of: pitQuestion.isAsking) { wasAsking, isAsking in
                if wasAsking, !isAsking {
                    pit.endQuestion()
                }
            }
            // A capture may have supplied the fact the pending question asks for (ADR 0017).
            .onChange(of: pitCapture.phase) { _, phase in
                if case .saved = phase {
                    Task { await pitQuestion.revalidate() }
                }
            }
            .onChange(of: pitQuestion.phase) { _, phase in
                // An answer changes what Service, Road, and the board show; they update under the sheet.
                if case .answered = phase {
                    Task { await refreshVisibleSurface() }
                }
            }
            .onDisappear { pit.stop() }
    }

    private func systemEntry(_ view: some View) -> some View {
        view
            // Queued analytics live only in memory; leaving the app is the last good moment to send them (ADR 0022).
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    wasInBackground = true
                    Task.detached(priority: .utility) { [analyticsSharing] in await analyticsSharing.flush() }
                case .active where wasInBackground:
                    // Siri may have saved while the app was suspended (ADR 0023); show it on return. Only a
                    // return from the background: launch and Control Center or alert dismissals load nothing.
                    wasInBackground = false
                    Task { await refreshAfterReturn() }
                default:
                    break
                }
            }
            // "Open Pit" from Siri, Shortcuts, or Spotlight opens capture over the current surface, as a tap
            // on Pit would (REQ-PIT-013, REQ-CAPTURE-023). `initial` covers a request made during a cold launch;
            // an open feature editor defers the request until it closes (ADR 0024), and capture already open meets it.
            .onChange(of: openPitGate, initial: true) { _, gate in
                if pitEntry.takeRequest(from: captureRequests, isPresentationBlocked: gate.isBlocked) {
                    sheet = .pit
                }
            }
            // The next-service widget's link (ADR 0036). It waits while a sheet or an editor is open, so
            // opening Service never discards what the person was writing.
            .onChange(of: serviceLinkGate, initial: true) { _, gate in
                if serviceRequests.take(isPresentationBlocked: gate.isBlocked) {
                    path = [.tile(.service)]
                }
            }
            .task {
                guard let text = Self.initialCapture() else { return }
                pitCapture.text = text
                sheet = .pit
                await pitCapture.submit(from: visibleFeature)
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .settings:
                    SettingsView(isStorageTemporary: carBoard.state.isStorageTemporary, analytics: analyticsSharing)
                        .pitStaysInSheet()
                case .pit:
                    PitCaptureView(
                        viewModel: pitCapture, question: pitQuestion, visible: visibleFeature
                    ) { destination in
                        open(destination)
                    }
                }
            }
    }

    private struct RequestGate: Equatable {
        let isPending: Bool
        let isBlocked: Bool
    }

    private var openPitGate: PitCaptureEntry.RequestGate {
        pitEntry.requestGate(for: captureRequests, isPresentationBlocked: pit.isFeatureTaskPresented)
    }

    private var serviceLinkGate: RequestGate {
        RequestGate(
            isPending: serviceRequests.isPending,
            isBlocked: sheet != nil || pit.isFeatureTaskPresented
        )
    }

    private var askTrigger: PitAskTrigger {
        PitAskTrigger(path: path, isInterfaceIdle: pit.isInterfaceIdle)
    }

    /// The surface under the sheet, passed to capture as a prior only (REQ-CAPTURE-022).
    private var visibleFeature: VisibleFeature {
        switch path.last {
        case .tile(.notes): .notes
        case .tile(.service): .service
        case .tile(.history): .history
        case .tile(.road): .road
        case .none: .carBoard
        }
    }

    private func askIfUseful() async {
        // A reading saved in an editor since the ask may have made the pending question pointless.
        await pitQuestion.revalidate()
        guard await pitQuestion.evaluate(context: visibleFeature, activity: { pit.activity }) else { return }
        await pit.askPermissionToInterrupt()
        if Self.opensAskedQuestion(), sheet == nil {
            sheet = .pit
        }
    }

    private func open(_ destination: PitDestination) {
        switch destination {
        case .notes: path = [.tile(.notes)]
        case .history: path = [.tile(.history)]
        case .service: path = [.tile(.service)]
        case .carBoard: path = []
        }
    }

    /// A mileage saved through Siri may have made the pending question pointless (REQ-PIT-009).
    private func refreshAfterReturn() async {
        await pitQuestion.revalidate()
        await refreshVisibleSurface()
    }

    private func refreshVisibleSurface() async {
        await carBoard.load()
        switch path.last {
        case .tile(.notes): await notes.load()
        case .tile(.history): await history.load()
        case .tile(.service): await service.load()
        case .tile(.road): await road.load()
        case .none: break
        }
    }

    @ViewBuilder
    private func destination(for route: CarBoardRoute) -> some View {
        switch route {
        case .tile(.notes):
            NotesView(viewModel: notes, carName: carBoard.state.car.name)
        case .tile(.road):
            RoadView(viewModel: road, carName: carBoard.state.car.name)
        case .tile(.service):
            ServiceView(viewModel: service, carName: carBoard.state.car.name)
        case .tile(.history):
            HistoryView(viewModel: history, carName: carBoard.state.car.name)
        }
    }
}
