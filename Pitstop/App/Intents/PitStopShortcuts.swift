import AppIntents

/// PitStop's App Shortcuts (ADR 0024). Phrases are read at build time, so they stay literals here;
/// ru and uk variants live in `AppShortcuts.xcstrings`. Every phrase names the app (Apple requires it),
/// and none carries the words to remember: Siri asks for them with the intent's request dialog.
struct PitStopShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RememberInPitStopIntent(),
            phrases: [
                "Remember in \(.applicationName)",
                "Make a note in \(.applicationName)",
            ],
            shortTitle: "shortcut.remember.title",
            systemImageName: "text.bubble"
        )
        AppShortcut(
            intent: OpenPitIntent(),
            phrases: [
                "Open Pit in \(.applicationName)",
                "Show Pit in \(.applicationName)",
            ],
            shortTitle: "shortcut.openPit.title",
            systemImageName: "square.and.pencil"
        )
    }
}
