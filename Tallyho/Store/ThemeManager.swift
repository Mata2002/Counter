import Foundation
import Observation
import SwiftUI
import UIKit

/// Owns the active theme: choice, favorites, shuffle and holiday switching.
/// The chosen theme is also written to the app group so widgets and the watch match.
@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    enum ShuffleMode: String, CaseIterable, Identifiable {
        case off, daily, eachOpen
        var id: String { rawValue }
        var title: String {
            switch self {
            case .off: return "Off"
            case .daily: return "Daily"
            case .eachOpen: return "Each open"
            }
        }
    }

    private enum Key {
        static let selected = "theme.selected"
        static let favorites = "theme.favorites"
        static let shuffle = "theme.shuffle"
        static let lastShuffleDay = "theme.lastShuffleDay"
        static let holidays = "theme.holidays"
        static let disabledHolidays = "theme.disabledHolidays"
        static let dismissedHoliday = "theme.dismissedHoliday"
        static let active = "theme.active" // read by widgets and sent to the watch
    }

    private let defaults = UserDefaults.standard

    private(set) var selectedID: String
    private(set) var active: TallyTheme
    private(set) var activeHolidayID: String?
    @ObservationIgnored var onChange: (() -> Void)?

    var favorites: Set<String> {
        didSet { defaults.set(Array(favorites).sorted(), forKey: Key.favorites) }
    }
    var shuffleMode: ShuffleMode {
        didSet { defaults.set(shuffleMode.rawValue, forKey: Key.shuffle) }
    }
    var holidaysEnabled: Bool {
        didSet { defaults.set(holidaysEnabled, forKey: Key.holidays); refresh() }
    }
    private(set) var disabledHolidays: Set<String> {
        didSet { defaults.set(Array(disabledHolidays).sorted(), forKey: Key.disabledHolidays) }
    }
    @ObservationIgnored private var dismissedHoliday: String

    private init() {
        let d = UserDefaults.standard
        let initial = TallyTheme.named(d.string(forKey: Key.selected)) ?? TallyTheme.fallback
        selectedID = initial.id
        active = initial
        activeHolidayID = nil
        favorites = Set(d.stringArray(forKey: Key.favorites) ?? [])
        shuffleMode = ShuffleMode(rawValue: d.string(forKey: Key.shuffle) ?? "") ?? .off
        holidaysEnabled = d.object(forKey: Key.holidays) as? Bool ?? true
        disabledHolidays = Set(d.stringArray(forKey: Key.disabledHolidays) ?? [])
        dismissedHoliday = d.string(forKey: Key.dismissedHoliday) ?? ""
        refresh()
    }

    /// For screenshots and previews.
    func force(_ id: String) {
        guard let theme = TallyTheme.named(id) else { return }
        selectedID = id
        holidaysEnabled = false
        active = theme
        publish()
    }

    func select(_ id: String) {
        guard TallyTheme.named(id) != nil else { return }
        // Choosing a theme during a holiday means "not this time".
        if let holiday = activeHolidayID, holiday != id {
            dismissedHoliday = marker(for: holiday)
            defaults.set(dismissedHoliday, forKey: Key.dismissedHoliday)
        }
        selectedID = id
        defaults.set(id, forKey: Key.selected)
        refresh()
    }

    func shuffle() {
        let pool = favorites.isEmpty ? TallyTheme.all : TallyTheme.all.filter { favorites.contains($0.id) }
        let candidates = pool.filter { $0.id != active.id }
        guard let next = (candidates.isEmpty ? pool : candidates).randomElement() else { return }
        select(next.id)
    }

    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
    }

    func isHolidayEnabled(_ id: String) -> Bool { !disabledHolidays.contains(id) }

    func setHoliday(_ id: String, enabled: Bool) {
        if enabled { disabledHolidays.remove(id) } else { disabledHolidays.insert(id) }
        refresh()
    }

    func appBecameActive(fromBackground: Bool) {
        switch shuffleMode {
        case .off:
            break
        case .daily:
            let today = Self.dayKey(Date())
            if defaults.string(forKey: Key.lastShuffleDay) != today {
                defaults.set(today, forKey: Key.lastShuffleDay)
                shuffle()
            }
        case .eachOpen:
            if fromBackground { shuffle() }
        }
        refresh()
    }

    private func refresh() {
        let now = Date()
        var holiday: TallyTheme?
        if holidaysEnabled {
            holiday = TallyTheme.holidays.first { theme in
                !disabledHolidays.contains(theme.id)
                    && HolidayCalendar.isActive(theme.id, on: now)
                    && dismissedHoliday != marker(for: theme.id)
            }
        }
        let next = holiday ?? TallyTheme.named(selectedID) ?? .fallback
        if activeHolidayID != holiday?.id { activeHolidayID = holiday?.id }
        if active != next {
            active = next
        }
        publish()
    }

    private func publish() {
        let shared = TallyFileStore.sharedDefaults
        if shared.string(forKey: Key.active) != active.id {
            shared.set(active.id, forKey: Key.active)
            TallyFileStore.reloadWidgets()
        }
        onChange?()
    }

    /// The theme id widgets and the watch should use.
    nonisolated static func sharedThemeID() -> String? {
        TallyFileStore.sharedDefaults.string(forKey: "theme.active")
    }

    private func marker(for holidayID: String) -> String {
        let start = HolidayCalendar.occurrence(of: holidayID, from: Date())?.start ?? Date()
        return holidayID + ":" + Self.dayKey(start)
    }

    private static func dayKey(_ date: Date) -> String {
        let p = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }
}

/// Switches themes with one smooth crossfade across the whole app, including open sheets.
@MainActor
enum ThemeCrossfade {
    static func perform(_ change: () -> Void) {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        guard let window, let snapshot = window.snapshotView(afterScreenUpdates: false) else {
            change()
            return
        }
        snapshot.isUserInteractionEnabled = false
        window.addSubview(snapshot)
        change()
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0.2 : 0.45, delay: 0,
                       options: [.curveEaseInOut, .allowUserInteraction]) {
            snapshot.alpha = 0
        } completion: { _ in
            snapshot.removeFromSuperview()
        }
    }
}
