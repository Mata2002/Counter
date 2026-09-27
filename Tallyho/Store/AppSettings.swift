import Foundation

/// Keys and defaults for @AppStorage settings.
enum AppSettings {
    static let hapticEachTap = "settings.hapticEachTap"
    static let vibrateAtGoal = "settings.vibrateAtGoal"
    static let tapSound = "settings.tapSound"
    static let keepAwake = "settings.keepAwake"
    static let splitPanes = "settings.splitPanes"
    static let showMarks = "settings.showMarks"
    static let celebrate = "settings.celebrate"

    static let homeSort = "home.sort"
    static let homeDirection = "home.direction"   // "all" | "up" | "down"
    static let homePane = "home.pane"             // "up" | "down" when split
    static let homeTags = "home.tags"             // comma-separated
    static let homeGoalOnly = "home.goalOnly"
    static let homeShowHidden = "home.showHidden"
    static let finishedSort = "finished.sort"

    static func register() {
        UserDefaults.standard.register(defaults: [
            hapticEachTap: true,
            vibrateAtGoal: true,
            tapSound: false,
            keepAwake: true,
            splitPanes: false,
            showMarks: true,
            celebrate: true,
            homeSort: TallySort.lastUsed.rawValue,
            homeDirection: "all",
            homePane: "up",
            homeTags: "",
            homeGoalOnly: false,
            homeShowHidden: false,
            finishedSort: FinishedSort.recent.rawValue,
        ])
    }
}
