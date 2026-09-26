import Observation
import Foundation
import SwiftUI
import UserNotifications
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

@MainActor
@Observable
final class HydrationStore {
    private(set) var snapshot: HydrationSnapshot
    var isLoggingDrink = false
    var celebration: PourCelebration?
    var lastDeletedEntry: HydrationEntry?
    var lastAddedEntry: HydrationEntry?
    private(set) var pourFeedback = UUID()
    private(set) var today = Date()

    init() {
        snapshot = HydrationStorage.load()
        if snapshot.settings.randomizeThemeEachLaunch {
            let pool = snapshot.settings.enabledThemeIDs.isEmpty
                ? [HydroThemeID.ocean.rawValue]
                : Array(snapshot.settings.enabledThemeIDs)
            snapshot.settings.activeThemeID = pool.randomElement() ?? HydroThemeID.ocean.rawValue
        }
        _ = PhoneWatchBridge.shared
        unlockAchievements(announce: false)
        persist()
    }

    var todayEntries: [HydrationEntry] {
        HydrationMath.entries(on: today, from: snapshot.entries).sorted { $0.date > $1.date }
    }

    var todayHydratedML: Int { todayEntries.reduce(0) { $0 + $1.hydratedML } }
    var todayCaffeineMG: Int { todayEntries.reduce(0) { $0 + $1.caffeineMG } }
    var goalML: Int { snapshot.settings.dailyGoalML }
    var progress: Double { Double(todayHydratedML) / Double(max(goalML, 1)) }
    var streak: Int { HydrationMath.streak(snapshot: snapshot) }

    var activeTheme: HydroTheme {
        let id = HydroThemeID(rawValue: snapshot.settings.activeThemeID) ?? .ocean
        return HydroThemeCatalog.theme(for: id)
    }

    func add(drink: DrinkKind, vessel: VesselKind, amountML: Int, date: Date = Date()) {
        today = Date()
        let priorProgress = progress
        let entry = HydrationEntry(date: date, amountML: max(1, amountML), drink: drink, vessel: vessel)
        snapshot.entries.append(entry)
        lastAddedEntry = entry
        today = Date()
        pourFeedback = UUID()
        lastDeletedEntry = nil
        let awards = unlockAchievements(announce: false)
        if snapshot.settings.celebration, !awards.isEmpty || (priorProgress < 1 && progress >= 1) {
            celebration = PourCelebration(awards: awards, reachedGoal: priorProgress < 1 && progress >= 1)
        }
        persist()
    }

    func add(_ quick: QuickDrink) {
        add(drink: quick.drink, vessel: quick.vessel, amountML: quick.amountML)
    }

    func undoLastAdd() {
        guard let lastAddedEntry,
              let index = snapshot.entries.firstIndex(where: { $0.id == lastAddedEntry.id }) else { return }
        snapshot.entries.remove(at: index)
        self.lastAddedEntry = nil
        celebration = nil
        persist()
    }

    func delete(_ entry: HydrationEntry) {
        lastDeletedEntry = entry
        snapshot.entries.removeAll { $0.id == entry.id }
        if lastAddedEntry?.id == entry.id { lastAddedEntry = nil }
        celebration = nil
        persist()
    }

    func undoDelete() {
        guard let entry = lastDeletedEntry else { return }
        if !snapshot.entries.contains(where: { $0.id == entry.id }) { snapshot.entries.append(entry) }
        lastDeletedEntry = nil
        persist()
    }

    func updateEntry(_ entry: HydrationEntry) {
        guard let index = snapshot.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        snapshot.entries[index] = entry
        unlockAchievements(announce: false)
        persist()
    }

    var activeFinish: String {
        let value = snapshot.settings.vesselFinish
        guard value != "clear" else { return value }
        return HydrationAchievement.allCases.contains { $0.finishID == value && snapshot.unlockedAchievementIDs.contains($0.id) } ? value : "clear"
    }

    func updateSettings(_ mutate: (inout HydrationSettings) -> Void) {
        // A caller may read the store while preparing an update. Mutating a
        // detached value avoids overlapping access to the observed snapshot.
        var settings = snapshot.settings
        mutate(&settings)
        snapshot.settings = settings
        persist()
        unlockAchievements(announce: false)
    }

    func replaceReminders(_ reminders: [HydrationReminder]) {
        snapshot.reminders = reminders
        persist()
        Task { await ReminderCoordinator.reschedule(snapshot.reminders) }
    }

    func deleteAllData() {
        snapshot = .empty
        lastAddedEntry = nil
        lastDeletedEntry = nil
        celebration = nil
        persist()
        Task { await ReminderCoordinator.removeAll() }
    }

    func dismissCelebration() {
        celebration = nil
    }

    func exportData() -> Data? {
        try? JSONEncoder.pretty.encode(snapshot)
    }

    func restore(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        snapshot = try decoder.decode(HydrationSnapshot.self, from: data)
        lastAddedEntry = nil
        lastDeletedEntry = nil
        celebration = nil
        today = Date()
        persist()
        unlockAchievements(announce: false)
        Task { await ReminderCoordinator.reschedule(snapshot.reminders) }
    }

    func refreshFromDisk() {
        today = Date()
        let stored = HydrationStorage.load()
        guard stored.lastModified > snapshot.lastModified else { return }
        snapshot = stored
        unlockAchievements(announce: false)
    }

    func mergeFromWatch(_ watchSnapshot: HydrationSnapshot) {
        var known = Set(snapshot.entries.map(\.id))
        for entry in watchSnapshot.entries where known.insert(entry.id).inserted {
            snapshot.entries.append(entry)
        }
        snapshot.unlockedAchievementIDs.formUnion(watchSnapshot.unlockedAchievementIDs)
        persist()
        unlockAchievements(announce: true)
    }

    private func persist() {
        snapshot.lastModified = Date()
        HydrationStorage.save(snapshot)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        PhoneWatchBridge.shared.send(snapshot)
    }

    @discardableResult
    private func unlockAchievements(announce: Bool) -> [HydrationAchievement] {
        let milestones = HydrationMilestones(snapshot: snapshot)
        var earned: [HydrationAchievement] = []
        for achievement in HydrationAchievement.allCases where achievement.progress(milestones: milestones).fraction >= 1 {
            guard snapshot.unlockedAchievementIDs.insert(achievement.id).inserted else { continue }
            earned.append(achievement)
        }
        if announce, snapshot.settings.celebration, !earned.isEmpty {
            celebration = PourCelebration(awards: earned, reachedGoal: false)
        }
        HydrationStorage.save(snapshot)
        return earned
    }
}

struct PourCelebration: Identifiable {
    let id = UUID()
    let awards: [HydrationAchievement]
    let reachedGoal: Bool
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

enum ReminderCoordinator {
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(_ reminders: [HydrationReminder]) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard await requestPermission() else { return }

        for reminder in reminders where reminder.enabled {
            for request in requests(for: reminder) {
                try? await center.add(request)
            }
        }
    }

    static func removeAll() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private static func requests(for reminder: HydrationReminder) -> [UNNotificationRequest] {
        let times: [(Int, Int)]
        if reminder.schedule == .fixed {
            times = [(reminder.hour, reminder.minute)]
        } else {
            let start = reminder.startHour * 60 + reminder.startMinute
            let end = reminder.endHour * 60 + reminder.endMinute
            guard end >= start else { return [] }
            times = stride(from: start, through: end, by: max(reminder.intervalMinutes, 15)).map { ($0 / 60, $0 % 60) }
        }

        let content = UNMutableNotificationContent()
        content.title = reminder.name
        content.body = "Your next drink is due."
        content.sound = .default

        return reminder.weekdays.sorted().flatMap { weekday in
            times.map { hour, minute in
                var components = DateComponents()
                components.weekday = weekday
                components.hour = hour
                components.minute = minute
                let id = "hydration.\(reminder.id).\(weekday).\(hour).\(minute)"
                return UNNotificationRequest(
                    identifier: id,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                )
            }
        }
    }
}

#if canImport(WatchConnectivity)
final class PhoneWatchBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneWatchBridge()
    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func send(_ snapshot: HydrationSnapshot) {
        guard WCSession.isSupported(), let data = try? JSONEncoder().encode(snapshot) else { return }
        try? WCSession.default.updateApplicationContext(["snapshot": data])
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let raw = message["quickAmount"] as? Int else { return }
        Task { @MainActor in
            NotificationCenter.default.post(name: .watchQuickAdd, object: raw)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["snapshot"] as? Data,
              let received = try? JSONDecoder().decode(HydrationSnapshot.self, from: data) else { return }
        Task { @MainActor in
            NotificationCenter.default.post(name: .watchSnapshot, object: received)
        }
    }
}

extension Notification.Name {
    static let watchQuickAdd = Notification.Name("watchQuickAdd")
    static let watchSnapshot = Notification.Name("watchSnapshot")
}
#else
final class PhoneWatchBridge: @unchecked Sendable {
    static let shared = PhoneWatchBridge()
    func send(_ snapshot: HydrationSnapshot) {}
}
#endif
