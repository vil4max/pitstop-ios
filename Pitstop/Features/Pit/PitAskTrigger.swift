/// When the root view checks whether Pit may ask. The view restarts `run` whenever the trigger changes, so
/// a check is cancelled by navigation or by the user becoming busy, and a surface that becomes idle again
/// gets a fresh settle delay and a fresh check instead of losing the question for the whole visit (ADR 0019).
struct PitAskTrigger: Equatable {
    let path: [CarBoardRoute]
    let isInterfaceIdle: Bool

    @MainActor
    func run(settle: () async throws -> Void, ask: () async -> Void) async {
        guard isInterfaceIdle else { return }
        do {
            try await settle()
        } catch {
            return
        }
        await ask()
    }
}
