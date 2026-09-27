import AppIntents

/// "Hey Siri, count Push-ups in Tallyho."
struct TallyhoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CountTallyIntent(),
            phrases: [
                "Count \(\.$tally) in \(.applicationName)",
                "Add to \(\.$tally) in \(.applicationName)",
                "\(.applicationName) \(\.$tally)",
            ],
            shortTitle: "Count a Tally",
            systemImageName: "plus.circle"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .orange
}
