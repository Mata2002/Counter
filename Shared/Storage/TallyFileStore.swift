import Foundation
import UserNotifications
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Reads and writes the one JSON file the app and its widgets share (in the app group container).
enum TallyFileStore {
    static let appGroup = "group.MMT.Tallyho"
    static let changedNotification = "MMT.Tallyho.changed"

    /// Set by demo/screenshot mode so real data is never touched.
    static var overrideURL: URL?

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static var url: URL {
        if let overrideURL { return overrideURL }
        let fm = FileManager.default
        let base = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("tallyho.json")
    }

    static func load() -> TallyData {
        guard let data = try? Data(contentsOf: url) else { return TallyData() }
        return (try? decoder.decode(TallyData.self, from: data)) ?? TallyData()
    }

    static func save(_ value: TallyData) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Tells other processes (the app, widgets) that the file changed.
    static func broadcastChange() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(changedNotification as CFString), nil, nil, true)
    }

    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadAllControls()
        }
        #endif
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

/// Counting from outside the app (widgets, controls, Shortcuts): read, change, write, notify.
enum TallyCounter {
    struct Outcome {
        let tally: Tally
        let reachedGoal: Bool
    }

    static func count(_ id: UUID, reverse: Bool) -> Outcome? {
        var data = TallyFileStore.load()
        guard let index = data.tallies.firstIndex(where: { $0.id == id }) else { return nil }
        let delta = reverse ? data.tallies[index].secondaryDelta : data.tallies[index].primaryDelta
        let reached = data.tallies[index].apply(delta)
        TallyFileStore.save(data)
        TallyFileStore.broadcastChange()
        TallyFileStore.reloadWidgets()
        let tally = data.tallies[index]
        if reached && tally.notifyAtGoal {
            GoalNotifier.post(for: tally)
        }
        return Outcome(tally: tally, reachedGoal: reached)
    }
}

/// Local notification when a goal is reached somewhere the celebration can't be seen.
enum GoalNotifier {
    static func post(for tally: Tally) {
        let content = UNMutableNotificationContent()
        content.title = "Tallyho! \(tally.emoji) \(tally.displayName)"
        if let target = tally.target {
            content.body = "You reached \(target). Open Tallyho to finish it or keep going."
        } else {
            content.body = "Goal reached."
        }
        content.sound = .default
        content.interruptionLevel = .active
        content.userInfo = ["tallyID": tally.id.uuidString]
        let request = UNNotificationRequest(identifier: "goal-\(tally.id.uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}
