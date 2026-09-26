import Foundation

// Change this one value if you use a different App Group in Xcode.
enum HydrationConfiguration {
    static let appGroup = "group.MMT.Hydration"
    static let snapshotKey = "hydration.snapshot.v1"
}

enum DrinkKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case water, sparklingWater, tea, coffee, milk, juice, soda, sportsDrink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water: "Water"
        case .sparklingWater: "Sparkling"
        case .tea: "Tea"
        case .coffee: "Coffee"
        case .milk: "Milk"
        case .juice: "Juice"
        case .soda: "Soda"
        case .sportsDrink: "Sports"
        }
    }

    var symbol: String {
        switch self {
        case .water: "drop.fill"
        case .sparklingWater: "bubbles.and.sparkles.fill"
        case .tea: "cup.and.saucer.fill"
        case .coffee: "mug.fill"
        case .milk: "waterbottle.fill"
        case .juice: "takeoutbag.and.cup.and.straw.fill"
        case .soda: "waterbottle.fill"
        case .sportsDrink: "figure.run"
        }
    }

    /// The portion counted toward hydration. Editable defaults can be added later.
    var hydrationFactor: Double {
        switch self {
        case .water, .sparklingWater: 1.0
        case .tea: 0.95
        case .coffee: 0.90
        case .milk: 0.90
        case .juice: 0.85
        case .soda: 0.80
        case .sportsDrink: 0.95
        }
    }

    var caffeinePer100ML: Double {
        switch self {
        case .coffee: 40
        case .tea: 20
        case .soda: 10
        default: 0
        }
    }
}

enum VesselKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case glass, cup, mug, can, bottle, tumbler

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .glass: "mug.fill"
        case .cup: "cup.and.saucer.fill"
        case .mug: "mug.fill"
        case .can: "cylinder.fill"
        case .bottle: "waterbottle.fill"
        case .tumbler: "takeoutbag.and.cup.and.straw.fill"
        }
    }

    var defaultML: Int {
        switch self {
        case .glass: 250
        case .cup: 300
        case .mug: 350
        case .can: 330
        case .bottle: 500
        case .tumbler: 590
        }
    }
}

struct QuickDrink: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var drink: DrinkKind
    var vessel: VesselKind
    var amountML: Int

    var title: String { "\(amountML) ml" }
}

struct HydrationEntry: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var date = Date()
    var amountML: Int
    var drink: DrinkKind
    var vessel: VesselKind

    var hydratedML: Int { Int((Double(amountML) * drink.hydrationFactor).rounded()) }
    var caffeineMG: Int { Int((Double(amountML) / 100 * drink.caffeinePer100ML).rounded()) }
}

enum ReminderSchedule: String, Codable, CaseIterable, Identifiable, Sendable {
    case fixed, interval
    var id: String { rawValue }
    var title: String { self == .fixed ? "At a time" : "Repeating window" }
}

/// Which built-in color/pattern theme is active. The actual colors (which need
/// SwiftUI) live in the iPhone-only HydroThemeCatalog — this file only stores
/// the id, so it stays framework-agnostic like the rest of the shared model.
enum HydroThemeID: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case ocean, sunrise, citrus, midnight, amethyst, coffee, christmas, halloween
    var id: String { rawValue }
}

enum PatternIntensity: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case off, subtle, bold
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: "Off"
        case .subtle: "Subtle"
        case .bold: "Bold"
        }
    }
}

struct HydrationReminder: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name = "Hydration"
    var enabled = true
    var schedule: ReminderSchedule = .fixed
    var hour = 10
    var minute = 0
    var startHour = 8
    var startMinute = 0
    var endHour = 20
    var endMinute = 0
    var intervalMinutes = 120
    /// Calendar weekday values: Sunday = 1 ... Saturday = 7.
    var weekdays: Set<Int> = Set(1...7)
}

struct HydrationSettings: Codable, Hashable, Sendable {
    var dailyGoalML = 2_000
    var unitIsOunces = false
    var haptics = true
    var celebration = true
    var quickDrinks: [QuickDrink] = [
        QuickDrink(drink: .water, vessel: .glass, amountML: 250),
        QuickDrink(drink: .water, vessel: .bottle, amountML: 500),
        QuickDrink(drink: .coffee, vessel: .mug, amountML: 350),
        QuickDrink(drink: .soda, vessel: .can, amountML: 330)
    ]
    var enabledThemeIDs: Set<String> = [HydroThemeID.ocean.rawValue]
    var activeThemeID: String = HydroThemeID.ocean.rawValue
    var randomizeThemeEachLaunch = false
    var patternIntensity: PatternIntensity = .subtle
    var appearance = "system"
    var vesselFinish = "clear"

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dailyGoalML = try container.decodeIfPresent(Int.self, forKey: .dailyGoalML) ?? 2_000
        unitIsOunces = try container.decodeIfPresent(Bool.self, forKey: .unitIsOunces) ?? false
        haptics = try container.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        celebration = try container.decodeIfPresent(Bool.self, forKey: .celebration) ?? true
        quickDrinks = try container.decodeIfPresent([QuickDrink].self, forKey: .quickDrinks) ?? [
            QuickDrink(drink: .water, vessel: .glass, amountML: 250),
            QuickDrink(drink: .water, vessel: .bottle, amountML: 500),
            QuickDrink(drink: .coffee, vessel: .mug, amountML: 350),
            QuickDrink(drink: .soda, vessel: .can, amountML: 330)
        ]
        enabledThemeIDs = try container.decodeIfPresent(Set<String>.self, forKey: .enabledThemeIDs) ?? [HydroThemeID.ocean.rawValue]
        activeThemeID = try container.decodeIfPresent(String.self, forKey: .activeThemeID) ?? HydroThemeID.ocean.rawValue
        randomizeThemeEachLaunch = try container.decodeIfPresent(Bool.self, forKey: .randomizeThemeEachLaunch) ?? false
        patternIntensity = try container.decodeIfPresent(PatternIntensity.self, forKey: .patternIntensity) ?? .subtle
        appearance = try container.decodeIfPresent(String.self, forKey: .appearance) ?? "system"
        vesselFinish = try container.decodeIfPresent(String.self, forKey: .vesselFinish) ?? "clear"
        dailyGoalML = min(max(dailyGoalML, 500), 6_000)
    }
}

struct HydrationSnapshot: Codable, Hashable, Sendable {
    var entries: [HydrationEntry] = []
    var reminders: [HydrationReminder] = []
    var settings = HydrationSettings()
    var unlockedAchievementIDs: Set<String> = []
    var lastModified = Date()

    static let empty = HydrationSnapshot()
}

enum HydrationStorage {
    static var defaults: UserDefaults {
        UserDefaults(suiteName: HydrationConfiguration.appGroup) ?? .standard
    }

    static func load() -> HydrationSnapshot {
        guard let data = defaults.data(forKey: HydrationConfiguration.snapshotKey),
              let value = try? JSONDecoder().decode(HydrationSnapshot.self, from: data)
        else { return .empty }
        return value
    }

    static func save(_ snapshot: HydrationSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: HydrationConfiguration.snapshotKey)
    }
}

enum HydrationMath {
    static let calendar = Calendar.autoupdatingCurrent

    static func entries(on day: Date, from entries: [HydrationEntry]) -> [HydrationEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    static func hydrated(on day: Date, from entries: [HydrationEntry]) -> Int {
        self.entries(on: day, from: entries).reduce(0) { $0 + $1.hydratedML }
    }

    static func caffeine(on day: Date, from entries: [HydrationEntry]) -> Int {
        self.entries(on: day, from: entries).reduce(0) { $0 + $1.caffeineMG }
    }

    static func streak(snapshot: HydrationSnapshot, endingAt date: Date = Date()) -> Int {
        var streak = 0
        var day = calendar.startOfDay(for: date)
        let todayTotal = hydrated(on: day, from: snapshot.entries)
        if todayTotal < snapshot.settings.dailyGoalML,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: day) {
            day = yesterday
        }
        while hydrated(on: day, from: snapshot.entries) >= max(snapshot.settings.dailyGoalML, 1) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}

/// Rules inspect the full history, so restored and backdated entries count too.
struct AchievementProgress: Sendable {
    let current: Int
    let target: Int
    let unit: String
    var fraction: Double { min(Double(current) / Double(max(target, 1)), 1) }
    var label: String { "\(min(current, target)) of \(target) \(unit)" }
}

struct HydrationMilestones: Sendable {
    var goalDays = 0
    var bestStreak = 0
    var earlyML = 0
    var mostTypes = 0
    var rhythmDays = 0
    var returnDays = 0
    var totalML = 0
    var entries = 0

    init(snapshot: HydrationSnapshot) {
        let calendar = HydrationMath.calendar
        let grouped = Dictionary(grouping: snapshot.entries.filter { $0.date <= Date() }) {
            calendar.startOfDay(for: $0.date)
        }
        var previousGoal: Date?
        var previousLog: Date?
        var run = 0
        for day in grouped.keys.sorted() {
            let logs = grouped[day] ?? []
            let total = logs.reduce(0) { $0 + $1.hydratedML }
            totalML += total
            entries += logs.count
            if total >= max(snapshot.settings.dailyGoalML, 1) {
                goalDays += 1
                run = previousGoal.flatMap { calendar.dateComponents([.day], from: $0, to: day).day } == 1 ? run + 1 : 1
                bestStreak = max(bestStreak, run)
                previousGoal = day
            }
            earlyML = max(earlyML, logs.filter { calendar.component(.hour, from: $0.date) < 10 }.reduce(0) { $0 + $1.hydratedML })
            mostTypes = max(mostTypes, Set(logs.map(\.drink)).count)
            let hours = logs.map { calendar.component(.hour, from: $0.date) }
            if hours.contains(where: { $0 >= 5 && $0 < 12 }) && hours.contains(where: { $0 >= 12 && $0 < 17 }) && hours.contains(where: { $0 >= 17 && $0 < 23 }) { rhythmDays += 1 }
            if let previousLog, (calendar.dateComponents([.day], from: previousLog, to: day).day ?? 0) >= 3 { returnDays += 1 }
            previousLog = day
        }
    }
}

enum HydrationAchievement: String, CaseIterable, Identifiable, Sendable {
    // Keep the original raw values so existing awards survive updates and restores.
    case firstPour, goalDay, threeDay, sevenDay, thirtyDay, earlyBird, balanced, ocean
    case steadyRhythm, freshStart

    var id: String { rawValue }
    var title: String {
        switch self {
        case .firstPour: "First ripple"
        case .goalDay: "Full tide"
        case .threeDay: "Finding your flow"
        case .sevenDay: "Current keeper"
        case .thirtyDay: "Lunar tide"
        case .earlyBird: "Morning light"
        case .balanced: "Tasting notes"
        case .ocean: "Little ocean"
        case .steadyRhythm: "A day in balance"
        case .freshStart: "Welcome back"
        }
    }
    var detail: String {
        switch self {
        case .firstPour: "Log your first drink."
        case .goalDay: "Reach your daily hydration goal on one day."
        case .threeDay: "Reach your goal on 3 consecutive days."
        case .sevenDay: "Reach your goal on 7 consecutive days."
        case .thirtyDay: "Reach your goal on 30 consecutive days."
        case .earlyBird: "Record 500 ml of hydration before 10 am on one day."
        case .balanced: "Record 4 drink types in a day. A collection memento, not a recommendation."
        case .ocean: "Accumulate 100 liters of hydration over time. There is no deadline."
        case .steadyRhythm: "Log a drink in the morning (5–12), afternoon (12–17), and evening (17–23) on 3 days."
        case .freshStart: "Return to logging after at least 2 full days away."
        }
    }
    var meaning: String {
        switch self {
        case .firstPour: "Every routine starts with one small action."
        case .goalDay: "A full vessel, a day recorded."
        case .threeDay: "Small actions are becoming a rhythm."
        case .sevenDay: "A week of showing up for yourself."
        case .thirtyDay: "A whole lunar cycle of consistency."
        case .earlyBird: "A little room for yourself before the day gets busy."
        case .balanced: "A snapshot of the drinks that make up your day."
        case .ocean: "Small amounts add up, at your own pace."
        case .steadyRhythm: "Your log reflects moments across the day."
        case .freshStart: "Returning matters more than a perfect streak."
        }
    }
    var symbol: String {
        switch self {
        case .firstPour: "drop.fill"
        case .goalDay: "checkmark.seal.fill"
        case .threeDay: "diamond.fill"
        case .sevenDay: "water.waves"
        case .thirtyDay: "moon.stars.fill"
        case .earlyBird: "sunrise.fill"
        case .balanced: "circle.hexagongrid.fill"
        case .ocean: "sailboat.fill"
        case .steadyRhythm: "sun.max.fill"
        case .freshStart: "leaf.fill"
        }
    }
    var reward: String? {
        switch self {
        case .threeDay: "Prism glass"
        case .sevenDay: "Etched glass"
        case .thirtyDay: "Starlight glass"
        default: nil
        }
    }
    var finishID: String? {
        switch self {
        case .threeDay: "prism"
        case .sevenDay: "etched"
        case .thirtyDay: "starlight"
        default: nil
        }
    }
    func progress(in snapshot: HydrationSnapshot) -> AchievementProgress {
        progress(milestones: HydrationMilestones(snapshot: snapshot))
    }
    func progress(milestones m: HydrationMilestones) -> AchievementProgress {
        switch self {
        case .firstPour: .init(current: m.entries, target: 1, unit: "drink")
        case .goalDay: .init(current: m.goalDays, target: 1, unit: "goal day")
        case .threeDay: .init(current: m.bestStreak, target: 3, unit: "consecutive days")
        case .sevenDay: .init(current: m.bestStreak, target: 7, unit: "consecutive days")
        case .thirtyDay: .init(current: m.bestStreak, target: 30, unit: "consecutive days")
        case .earlyBird: .init(current: m.earlyML, target: 500, unit: "ml before 10 am")
        case .balanced: .init(current: m.mostTypes, target: 4, unit: "drink types")
        case .ocean: .init(current: m.totalML / 1_000, target: 100, unit: "liters")
        case .steadyRhythm: .init(current: m.rhythmDays, target: 3, unit: "balanced days")
        case .freshStart: .init(current: m.returnDays, target: 1, unit: "return")
        }
    }
    func isEarned(in snapshot: HydrationSnapshot) -> Bool { progress(in: snapshot).fraction >= 1 }
}

extension Int {
    func hydrationAmount(ounces: Bool) -> String {
        if ounces {
            return String(format: "%.1f oz", Double(self) / 29.5735)
        }
        return self >= 1_000
            ? String(format: "%.2f L", Double(self) / 1_000)
            : "\(self) ml"
    }
}
