import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers
import UIKit
import PhotosUI
import ImageIO
// MARK: - Data
enum LoomItemKind: String, Codable, CaseIterable {
    case habit
    case task
}
struct LoomItem: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: LoomItemKind
    var behavior: String
    var cue: String
    var identity: String
    var text: String
    var icon: String
    var colorIndex: Int
    var routineID: UUID?
    var title: String {
        kind == .habit ? behavior.capitalizingFirstLetter : text
    }
    var sentence: String {
        guard kind == .habit else { return text }
        let cuePart = cue.isEmpty ? "" : " \(cue)"
        return "I will \(behavior)\(cuePart), so I can become \(identity)."
    }
}
struct LoomRoutine: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var icon: String
    var trigger: String
    var order: [UUID]
}
struct FunActivity: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var icon: String
}
struct LoomChore: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String
    var done: Bool
}
struct LoomState: Codable, Equatable {
    var items: [LoomItem]
    var routines: [LoomRoutine]
    var funActivities: [FunActivity]
    var chores: [LoomChore]
    var completions: [String: [UUID]]
    var funCompletions: [String: [UUID]]
    var profilePhoto: Data? = nil
    var growthPins: [String]? = nil
    static func starter() -> LoomState {
        let meditate = UUID()
        let stretch = UUID()
        let shower = UUID()
        let read = UUID()
        let home = UUID()
        return LoomState(
            items: [
                LoomItem(
                    id: meditate,
                    kind: .habit,
                    behavior: "meditate for 5 minutes",
                    cue: "when I wake up",
                    identity: "a mindful person",
                    text: "",
                    icon: "🧘",
                    colorIndex: 0,
                    routineID: nil
                ),
                LoomItem(
                    id: stretch,
                    kind: .habit,
                    behavior: "stretch for 5 minutes",
                    cue: "when I get home",
                    identity: "someone who takes care of their body",
                    text: "",
                    icon: "🌿",
                    colorIndex: 1,
                    routineID: home
                ),
                LoomItem(
                    id: shower,
                    kind: .task,
                    behavior: "",
                    cue: "",
                    identity: "",
                    text: "Take a shower",
                    icon: "🚿",
                    colorIndex: 5,
                    routineID: home
                ),
                LoomItem(
                    id: read,
                    kind: .task,
                    behavior: "",
                    cue: "",
                    identity: "",
                    text: "Read for a bit",
                    icon: "📖",
                    colorIndex: 2,
                    routineID: home
                )
            ],
            routines: [
                LoomRoutine(
                    id: home,
                    name: "When I Get Home",
                    icon: "🚪",
                    trigger: "the moment I walk through the door",
                    order: [stretch, shower, read]
                )
            ],
            funActivities: [
                FunActivity(id: UUID(), name: "Reading", icon: "📖"),
                FunActivity(id: UUID(), name: "Meditating", icon: "🧘"),
                FunActivity(id: UUID(), name: "Stretching", icon: "🌿"),
                FunActivity(id: UUID(), name: "Push-ups", icon: "💪"),
                FunActivity(id: UUID(), name: "Working out", icon: "🏋️")
            ],
            chores: [
                LoomChore(id: UUID(), text: "Do the laundry", done: false),
                LoomChore(id: UUID(), text: "Wipe the kitchen counters", done: false)
            ],
            completions: [:],
            funCompletions: [:]
        )
    }
}
struct Trackable: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let isFun: Bool
    var pinKey: String { (isFun ? "activity:" : "item:") + id.uuidString }
}
enum StatPeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    var id: String { rawValue }
}
// MARK: - Store
private struct LoomStreak {
    let current: Int
    let best: Int

    static func calculate(days: [String], now: Date = Date(),
                          calendar: Calendar = .autoupdatingCurrent) -> LoomStreak {
        let today = calendar.startOfDay(for: now)
        let dates = Set(days.compactMap { key -> Date? in
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3,
                  let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
            let check = calendar.dateComponents([.year, .month, .day], from: date)
            guard check.year == parts[0], check.month == parts[1], check.day == parts[2],
                  date <= today else { return nil }
            return calendar.startOfDay(for: date)
        }).sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for date in dates {
            if let previous = previous,
               calendar.date(byAdding: .day, value: 1, to: previous) == date {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = date
        }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        let active = previous == today || (previous != nil && previous == yesterday)
        return LoomStreak(current: active ? run : 0, best: best)
    }
}

@MainActor
final class LoomStore: ObservableObject {
    @Published private(set) var state: LoomState {
        didSet {
            if oldValue.profilePhoto != state.profilePhoto {
                profileImage = state.profilePhoto.flatMap { UIImage(data: $0) }
            }
        }
    }
    @Published private(set) var profileImage: UIImage? = nil
    @Published private(set) var undoMessage: String? = nil
    private struct DeletedEntry {
        enum Kind: Equatable { case item, activity, routine }
        let kind: Kind
        let id: UUID
        let name: String
        let before: LoomState
    }
    private var deletions: [DeletedEntry] = []
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("LoomNative", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("loom-state.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? decoder.decode(LoomState.self, from: data) {
            state = saved
            normalize()
        } else {
            state = .starter()
            save()
        }
        profileImage = state.profilePhoto.flatMap { UIImage(data: $0) }
    }
    var todayKey: String { dateKey(Date()) }
    var todayDoneIDs: Set<UUID> {
        Set(state.completions[todayKey] ?? [])
    }
    var todayFunDoneIDs: Set<UUID> {
        Set(state.funCompletions[todayKey] ?? [])
    }
    var todayCompletionCount: Int {
        state.items.reduce(0) { $0 + (todayDoneIDs.contains($1.id) ? 1 : 0) }
    }
    var choreCompletionCount: Int {
        state.chores.filter(\.done).count
    }
    var trackables: [Trackable] {
        state.items.map {
            Trackable(id: $0.id, name: $0.title, icon: $0.icon, isFun: false)
        } + state.funActivities.map {
            Trackable(id: $0.id, name: $0.name, icon: $0.icon, isFun: true)
        }
    }
    func item(_ id: UUID) -> LoomItem? {
        state.items.first { $0.id == id }
    }
    func routine(_ id: UUID?) -> LoomRoutine? {
        guard let id else { return nil }
        return state.routines.first { $0.id == id }
    }
    func items(in routine: LoomRoutine) -> [LoomItem] {
        routine.order.compactMap(item)
    }
    func isDoneToday(_ id: UUID) -> Bool {
        todayDoneIDs.contains(id)
    }
    func isFunDoneToday(_ id: UUID) -> Bool {
        todayFunDoneIDs.contains(id)
    }
    func toggleItem(_ id: UUID) {
        mutate { state in
            var values = state.completions[todayKey] ?? []
            if let index = values.firstIndex(of: id) {
                values.remove(at: index)
            } else {
                values.append(id)
            }
            state.completions[todayKey] = values
        }
    }
    func toggleFun(_ id: UUID) {
        mutate { state in
            var values = state.funCompletions[todayKey] ?? []
            if let index = values.firstIndex(of: id) {
                values.remove(at: index)
            } else {
                values.append(id)
            }
            state.funCompletions[todayKey] = values
        }
    }
    func upsertItem(
        id: UUID?,
        kind: LoomItemKind,
        behavior: String,
        cue: String,
        identity: String,
        text: String,
        icon: String,
        routineID: UUID?
    ) {
        mutate { state in
            let itemID = id ?? UUID()
            let oldColor = state.items.first(where: { $0.id == itemID })?.colorIndex
            let value = LoomItem(
                id: itemID,
                kind: kind,
                behavior: behavior,
                cue: cue,
                identity: identity,
                text: text,
                icon: icon,
                colorIndex: oldColor ?? state.items.count % LoomPalette.threadColors.count,
                routineID: routineID
            )
            if let index = state.items.firstIndex(where: { $0.id == itemID }) {
                state.items[index] = value
            } else {
                state.items.append(value)
            }
            for index in state.routines.indices {
                state.routines[index].order.removeAll { $0 == itemID }
            }
            if let routineID,
               let index = state.routines.firstIndex(where: { $0.id == routineID }) {
                state.routines[index].order.append(itemID)
            }
        }
    }
    func deleteItem(_ id: UUID) {
        guard let item = state.items.first(where: { $0.id == id }) else { return }
        rememberDeletion(.item, id: id, name: item.title)
        mutate { state in
            state.items.removeAll { $0.id == id }
            for index in state.routines.indices {
                state.routines[index].order.removeAll { $0 == id }
            }
            for key in state.completions.keys {
                state.completions[key]?.removeAll { $0 == id }
            }
            state.growthPins?.removeAll { $0 == "item:" + id.uuidString }
        }
    }
    func upsertRoutine(id: UUID?, name: String, trigger: String, icon: String) {
        mutate { state in
            if let id, let index = state.routines.firstIndex(where: { $0.id == id }) {
                state.routines[index].name = name
                state.routines[index].trigger = trigger
                state.routines[index].icon = icon
            } else {
                state.routines.append(
                    LoomRoutine(id: UUID(), name: name, icon: icon, trigger: trigger, order: [])
                )
            }
        }
    }
    func deleteRoutine(_ id: UUID) {
        guard let routine = state.routines.first(where: { $0.id == id }) else { return }
        rememberDeletion(.routine, id: id, name: routine.name)
        mutate { state in
            for index in state.items.indices where state.items[index].routineID == id {
                state.items[index].routineID = nil
            }
            state.routines.removeAll { $0.id == id }
        }
    }
    func assign(_ itemID: UUID, to routineID: UUID?) {
        mutate { state in
            for index in state.routines.indices {
                state.routines[index].order.removeAll { $0 == itemID }
            }
            if let index = state.items.firstIndex(where: { $0.id == itemID }) {
                state.items[index].routineID = routineID
            }
            if let routineID,
               let index = state.routines.firstIndex(where: { $0.id == routineID }) {
                state.routines[index].order.append(itemID)
            }
        }
    }
    func moveItem(_ itemID: UUID, to routineID: UUID, at destinationIndex: Int) {
        mutate { state in
            guard let itemIndex = state.items.firstIndex(where: { $0.id == itemID }),
                  let destinationRoutineIndex = state.routines.firstIndex(where: { $0.id == routineID }) else { return }
            let sourceRoutineID = state.items[itemIndex].routineID
            let sourceIndex = sourceRoutineID.flatMap { sourceID in
                state.routines
                    .first(where: { $0.id == sourceID })?
                    .order.firstIndex(of: itemID)
            }
            for index in state.routines.indices {
                state.routines[index].order.removeAll { $0 == itemID }
            }
            var insertionIndex = destinationIndex
            if sourceRoutineID == routineID,
               let sourceIndex,
               sourceIndex < destinationIndex {
                insertionIndex -= 1
            }
            let availableCount = state.routines[destinationRoutineIndex].order.count
            insertionIndex = min(max(insertionIndex, 0), availableCount)
            state.routines[destinationRoutineIndex].order.insert(itemID, at: insertionIndex)
            state.items[itemIndex].routineID = routineID
        }
    }
    func upsertActivity(id: UUID?, name: String, icon: String) {
        mutate { state in
            if let id, let index = state.funActivities.firstIndex(where: { $0.id == id }) {
                state.funActivities[index].name = name
                state.funActivities[index].icon = icon
            } else {
                state.funActivities.append(FunActivity(id: UUID(), name: name, icon: icon))
            }
        }
    }
    func deleteActivity(_ id: UUID) {
        guard let activity = state.funActivities.first(where: { $0.id == id }) else { return }
        rememberDeletion(.activity, id: id, name: activity.name)
        mutate { state in
            state.funActivities.removeAll { $0.id == id }
            for key in state.funCompletions.keys {
                state.funCompletions[key]?.removeAll { $0 == id }
            }
            state.growthPins?.removeAll { $0 == "activity:" + id.uuidString }
        }
    }
    func addChore(_ text: String) {
        mutate { $0.chores.append(LoomChore(id: UUID(), text: text, done: false)) }
    }
    func toggleChore(_ id: UUID) {
        mutate { state in
            guard let index = state.chores.firstIndex(where: { $0.id == id }) else { return }
            state.chores[index].done.toggle()
        }
    }
    func deleteChore(_ id: UUID) {
        mutate { $0.chores.removeAll { $0.id == id } }
    }
    func clearCompletedChores() {
        mutate { $0.chores.removeAll { $0.done } }
    }
    func count(_ trackable: Trackable, period: StatPeriod) -> Int {
        let bucket = trackable.isFun ? state.funCompletions : state.completions
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        return bucket.reduce(0) { result, entry in
            guard entry.value.contains(trackable.id), let date = date(from: entry.key) else { return result }
            let matches: Bool
            switch period {
            case .week:
                matches = calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                matches = calendar.isDate(date, equalTo: now, toGranularity: .month)
            case .year:
                matches = calendar.isDate(date, equalTo: now, toGranularity: .year)
            }
            return result + (matches ? 1 : 0)
        }
    }
    func backupData() throws -> Data {
        try encoder.encode(state)
    }
    fileprivate func streak(for trackable: Trackable, now: Date = Date()) -> LoomStreak {
        let bucket = trackable.isFun ? state.funCompletions : state.completions
        return LoomStreak.calculate(days: bucket.filter { $0.value.contains(trackable.id) }.map(\.key), now: now)
    }
    func isPinned(_ trackable: Trackable) -> Bool {
        state.growthPins?.contains(trackable.pinKey) ?? false
    }
    func togglePin(_ trackable: Trackable) {
        mutate { state in
            var pins = state.growthPins ?? []
            if pins.contains(trackable.pinKey) { pins.removeAll { $0 == trackable.pinKey } }
            else { pins.append(trackable.pinKey) }
            state.growthPins = pins
        }
    }
    private func rememberDeletion(_ kind: DeletedEntry.Kind, id: UUID, name: String) {
        deletions.append(DeletedEntry(kind: kind, id: id, name: name, before: state))
        if deletions.count > 20 { deletions.removeFirst() }
        undoMessage = "Deleted “\(name)”"
    }
    func dismissUndo() {
        deletions.removeAll()
        undoMessage = nil
    }
    func undoDeletion() {
        guard let deleted = deletions.popLast() else { return }
        // Restore only the deleted entity and its links, never a whole older state.
        mutate { state in
            func recoverHistory(_ source: [String: [UUID]], into target: inout [String: [UUID]]) {
                for (day, ids) in source where ids.contains(deleted.id) {
                    if !(target[day] ?? []).contains(deleted.id) {
                        target[day, default: []].append(deleted.id)
                    }
                }
            }
            switch deleted.kind {
            case .item:
                guard let originalIndex = deleted.before.items.firstIndex(where: { $0.id == deleted.id }),
                      !state.items.contains(where: { $0.id == deleted.id }) else { return }
                var item = deleted.before.items[originalIndex]
                if let routineID = item.routineID, !state.routines.contains(where: { $0.id == routineID }) {
                    item.routineID = nil
                }
                state.items.insert(item, at: min(originalIndex, state.items.count))
                for prior in deleted.before.routines {
                    guard let oldPosition = prior.order.firstIndex(of: deleted.id),
                          let index = state.routines.firstIndex(where: { $0.id == prior.id }),
                          !state.routines[index].order.contains(deleted.id) else { continue }
                    let insertion = min(oldPosition, state.routines[index].order.count)
                    state.routines[index].order.insert(deleted.id, at: insertion)
                }
                recoverHistory(deleted.before.completions, into: &state.completions)
            case .activity:
                guard let originalIndex = deleted.before.funActivities.firstIndex(where: { $0.id == deleted.id }),
                      !state.funActivities.contains(where: { $0.id == deleted.id }) else { return }
                state.funActivities.insert(deleted.before.funActivities[originalIndex],
                                           at: min(originalIndex, state.funActivities.count))
                recoverHistory(deleted.before.funCompletions, into: &state.funCompletions)
            case .routine:
                guard let originalIndex = deleted.before.routines.firstIndex(where: { $0.id == deleted.id }),
                      !state.routines.contains(where: { $0.id == deleted.id }) else { return }
                let previousMembers = Set(deleted.before.items.filter { $0.routineID == deleted.id }.map(\.id))
                for index in state.items.indices where previousMembers.contains(state.items[index].id) && state.items[index].routineID == nil {
                    state.items[index].routineID = deleted.id
                }
                let restoredMembers = Set(state.items.filter { $0.routineID == deleted.id }.map(\.id))
                var routine = deleted.before.routines[originalIndex]
                routine.order = routine.order.filter { restoredMembers.contains($0) }
                state.routines.insert(routine, at: min(originalIndex, state.routines.count))
            }
            let key = (deleted.kind == .activity ? "activity:" : "item:") + deleted.id.uuidString
            if deleted.kind != .routine, deleted.before.growthPins?.contains(key) == true,
               !(state.growthPins ?? []).contains(key) {
                state.growthPins = (state.growthPins ?? []) + [key]
            }
        }
        undoMessage = deletions.last.map { "Deleted “\($0.name)”" }
    }
    func setProfilePhoto(_ data: Data?) throws {
        var updated = state
        if let data = data {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 512
                  ] as CFDictionary),
                  let jpeg = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.85) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            updated.profilePhoto = jpeg
        } else {
            updated.profilePhoto = nil
        }
        try encoder.encode(updated).write(to: fileURL, options: .atomic)
        state = updated
    }
    func suggestActivityIcons() {
        mutate { state in
            for index in state.funActivities.indices {
                let activity = state.funActivities[index]
                if activity.icon.isEmpty || activity.icon == "✨",
                   let suggestion = LoomIcons.suggestions(for: activity.name).first {
                    state.funActivities[index].icon = suggestion.emoji
                }
            }
        }
    }
    func restore(from data: Data) throws {
        try restoreBackup(LoomBackupCodec.decode(data))
    }
    func restoreBackup(_ candidate: LoomState) throws {
        try LoomBackupCodec.validate(candidate)
        let restoredData = try encoder.encode(candidate)
        let previousData = try encoder.encode(state)
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Keep the current data recoverable and never report success on a failed write.
        let recoveryURL = folder.appendingPathComponent("loom-before-last-restore.json")
        try previousData.write(to: recoveryURL, options: .atomic)
        try restoredData.write(to: fileURL, options: .atomic)
        state = candidate
        dismissUndo()
    }
    func dataBeforeLastRestore() throws -> Data {
        let recoveryURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("loom-before-last-restore.json")
        return try Data(contentsOf: recoveryURL)
    }
    func reset() {
        dismissUndo()
        state = .starter()
        save()
    }
    private func normalize() {
        let validItems = Set(state.items.map(\.id))
        for index in state.routines.indices {
            state.routines[index].order = state.routines[index].order.filter(validItems.contains)
        }
        let validRoutines = Set(state.routines.map(\.id))
        for index in state.items.indices where state.items[index].routineID.map({ !validRoutines.contains($0) }) == true {
            state.items[index].routineID = nil
        }
    }
    private func mutate(_ update: (inout LoomState) -> Void) {
        var copy = state
        update(&copy)
        state = copy
        save()
    }
    private func save() {
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
    private func dateKey(_ date: Date) -> String {
        let components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
    private func date(from key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.autoupdatingCurrent.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
// MARK: - App shell
private enum LoomTab: Hashable {
    case today
    case build
    case wheel
    case growth
}
struct ContentView: View {
    @EnvironmentObject private var store: LoomStore
    @State private var tab: LoomTab = .today
    @State private var showChores = false
    @State private var showSettings = false
    var body: some View {
        ZStack {
            LoomBackground()
            TabView(selection: $tab) {
                NavigationStack {
                    TodayView(tab: $tab, showChores: $showChores, showSettings: $showSettings)
                }
                .tag(LoomTab.today)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                NavigationStack {
                    BuildView(showSettings: $showSettings)
                }
                .tag(LoomTab.build)
                .tabItem { Label("Build", systemImage: "point.3.connected.trianglepath.dotted") }
                NavigationStack {
                    WheelView(showSettings: $showSettings)
                }
                .tag(LoomTab.wheel)
                .tabItem { Label("Wheel", systemImage: "circle.hexagongrid.fill") }
                NavigationStack {
                    GrowthView(showSettings: $showSettings)
                }
                .tag(LoomTab.growth)
                .tabItem { Label("Growth", systemImage: "camera.macro") }
            }
            .tint(LoomPalette.mint)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        }
        .overlay(alignment: .bottom) {
            if let message = store.undoMessage {
                HStack(spacing: 12) {
                    Text(message).font(.subheadline).lineLimit(2)
                    Spacer(minLength: 0)
                    Button("Undo") { store.undoDeletion() }
                        .font(.subheadline.bold()).foregroundStyle(LoomPalette.mint)
                    Button { store.dismissUndo() } label: {
                        Image(systemName: "xmark").frame(width: 32, height: 36)
                    }
                    .accessibilityLabel("Dismiss undo")
                }
                .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12)))
                .padding(.horizontal, 18).padding(.bottom, 66)
            }
        }
        .sheet(isPresented: $showChores) {
            NavigationStack { ChoresView() }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { LoomSettingsView() }
        }
    }
}
// MARK: - Visual language
enum LoomPalette {
    static let ink = Color(hex: 0x10111A)
    static let panel = Color(hex: 0x1B1D2A)
    static let mint = Color(hex: 0x4DE2C4)
    static let coral = Color(hex: 0xFF8A73)
    static let lilac = Color(hex: 0xB58CFF)
    static let gold = Color(hex: 0xFFD56A)
    static let sky = Color(hex: 0x6CC9FF)
    static let threadColors = [mint, coral, lilac, gold, sky]
}
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}
extension String {
    var capitalizingFirstLetter: String {
        self.prefix(1).uppercased() + dropFirst()
    }
}
private extension View {
    func loomListRow() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 18))
    }
    func loomCard(cornerRadius: CGFloat = 26) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}
private struct LoomBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(hex: 0x1C1830), LoomPalette.ink, Color(hex: 0x102B30)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct LoomAvatar: View {
    @EnvironmentObject private var store: LoomStore
    var size: CGFloat = 44
    var body: some View {
        Group {
            if let image = store.profileImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [LoomPalette.lilac, LoomPalette.sky],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: size * 0.62))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))
    }
}

private struct LoomHeader: View {
    let eyebrow: String
    let title: String
    var actionIcon: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.7)
                    .foregroundStyle(LoomPalette.mint)
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let action = action {
                Button(action: action) {
                    LoomAvatar()
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 10, weight: .bold))
                                .padding(4)
                                .background(LoomPalette.panel, in: Circle())
                                .foregroundStyle(.white)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profile and settings")
            }
        }
    }
}

private enum LoomIcons {
    struct Entry: Identifiable, Sendable {
        let emoji: String
        let words: String
        let category: String
        var id: String { emoji }
    }

    static let groups: [(String, [(String, String)])] = [
        ("Movement", [
            ("💪", "strength push pushups push-ups arm arms"),
            ("🏋️", "gym lift lifting workout working out weights"),
            ("🧘", "yoga meditate meditating meditation mindfulness"),
            ("🌿", "stretch stretching mobility recovery"),
            ("🦵", "leg legs hip hips lower squat lunges"),
            ("🧱", "plank core abs abdominal"),
            ("🚶", "walk walking steps"),
            ("🏃", "run running jog cardio"),
            ("🚴", "bike cycling bicycle"),
            ("🏊", "swim swimming pool"),
            ("🥊", "box boxing"),
            ("🧗", "climb climbing"),
            ("⚽️", "football soccer"),
            ("🏓", "ping pong table tennis"),
            ("🏀", "basketball"),
            ("💃", "dance dancing")
        ]),
        ("Mind & faith", [
            ("📖", "read reading book books quran koran قرآن"),
            ("✍️", "journal journaling journalling write writing diary"),
            ("📿", "dhikr zikr tasbih remembrance ذکر"),
            ("🕌", "pray prayer salah salat mosque نماز"),
            ("🤲", "dua supplication gratitude دعا"),
            ("🧠", "learn learning brain think focus"),
            ("🌬️", "breathe breathing breath"),
            ("🕯️", "reflect reflection quiet calm"),
            ("📚", "study studying school research"),
            ("📝", "notes homework plan planning"),
            ("🎓", "class course education exam"),
            ("💭", "ideas thought thinking"),
            ("🎯", "goal goals target intention"),
            ("🧩", "puzzle solve problem"),
            ("🗣️", "language speaking pronunciation"),
            ("🔬", "science experiment lab")
        ]),
        ("Care", [
            ("💧", "water drink drinking hydrate hydration"),
            ("🥗", "salad vegetables nutrition diet"),
            ("🍎", "fruit apple snack food"),
            ("🥣", "breakfast cereal oatmeal"),
            ("🍳", "cook cooking meal prep"),
            ("☕️", "coffee cafe break"),
            ("🍵", "tea"),
            ("💊", "medicine medication supplement vitamins"),
            ("🪥", "brush brushing teeth dental"),
            ("🦷", "floss flossing dentist"),
            ("🚿", "shower wash bath"),
            ("🧴", "skin skincare sunscreen lotion"),
            ("🛏️", "sleep sleeping bedtime bed"),
            ("😴", "nap rest"),
            ("☀️", "morning sunrise sunlight"),
            ("🌙", "evening night")
        ]),
        ("Play & create", [
            ("🎮", "game gaming games dailies daily"),
            ("🎨", "paint painting art drawing"),
            ("🎵", "music listen listening"),
            ("🎹", "piano keyboard"),
            ("🎸", "guitar"),
            ("🎤", "sing singing karaoke"),
            ("🎬", "movie movies film cinema"),
            ("📺", "television tv anime show"),
            ("📷", "photo photography camera"),
            ("🧵", "sew sewing craft"),
            ("🧶", "knit knitting crochet"),
            ("🎲", "board games dice tabletop"),
            ("♟️", "chess"),
            ("🖌️", "sketch sketching"),
            ("🎧", "podcast audio headphones"),
            ("🪴", "plant plants garden gardening")
        ]),
        ("Home & work", [
            ("🏠", "home house"),
            ("🚪", "arrive arriving leave leaving door"),
            ("💼", "work office career"),
            ("💻", "computer code coding programming"),
            ("📅", "calendar schedule appointment"),
            ("📧", "email mail inbox"),
            ("🧹", "clean cleaning sweep chores"),
            ("🧺", "laundry clothes washing"),
            ("🧽", "dishes kitchen wipe"),
            ("🛒", "shop shopping groceries"),
            ("💰", "money budget finance save"),
            ("📦", "organize tidy storage package"),
            ("🗑️", "trash garbage rubbish"),
            ("🔧", "fix repair maintain"),
            ("✅", "check complete task"),
            ("⏰", "alarm wake time")
        ]),
        ("People & outside", [
            ("❤️", "love partner relationship"),
            ("☎️", "call phone"),
            ("👨‍👩‍👦", "family parents"),
            ("🤝", "friend friends meet social"),
            ("🐈", "cat pet"),
            ("🐕", "dog walk pet"),
            ("🏞️", "park nature hike hiking"),
            ("🌊", "beach sea ocean"),
            ("🌳", "outdoors tree forest"),
            ("🚗", "car drive commute"),
            ("🚆", "train transit"),
            ("✈️", "travel flight"),
            ("🎁", "gift birthday"),
            ("⭐️", "star favorite"),
            ("🔥", "fire energy"),
            ("✨", "sparkles other")
        ])
    ]

    static let all: [Entry] = groups.flatMap { group in
        group.1.map { Entry(emoji: $0.0, words: $0.1, category: group.0) }
    }

    static func tokens(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    static func suggestions(for text: String) -> [Entry] {
        let input = Set(tokens(text).filter { !["snack", "for", "the", "a", "my", "minutes"].contains($0) })
        guard !input.isEmpty else { return [] }
        return all.compactMap { entry -> (Entry, Int)? in
            let score = input.intersection(Set(tokens(entry.words))).count
            return score > 0 ? (entry, score) : nil
        }.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0.words < $1.0.words
        }.prefix(8).map { $0.0 }
    }
}

private struct LoomIconPicker: View {
    @Binding var selection: String
    let name: String
    @State private var query = ""
    @State private var category = "All"
    private var matches: [LoomIcons.Entry] {
        LoomIcons.all.filter { entry in
            (category == "All" || entry.category == category)
                && (query.isEmpty || entry.words.localizedCaseInsensitiveContains(query)
                    || entry.emoji == query)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(selection).font(.title)
                TextField("Or type any emoji", text: $selection)
                    .textInputAutocapitalization(.never)
                    .onChange(of: selection) { newValue in
                        if newValue.count > 1 { selection = String(newValue.suffix(1)) }
                    }
            }
            if !LoomIcons.suggestions(for: name).isEmpty {
                Text("Suggested for this name").font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(LoomIcons.suggestions(for: name)) { entry in iconButton(entry) }
                    }
                }
                .scrollIndicators(.hidden)
            }
            TextField("Search icons", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(["All"] + LoomIcons.groups.map { $0.0 }, id: \.self) { title in
                        Button(title) { category = title }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(category == title ? LoomPalette.mint.opacity(0.20) : .white.opacity(0.05), in: Capsule())
                            .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                ForEach(matches) { entry in iconButton(entry) }
            }
        }
        .padding(.vertical, 6)
    }
    private func iconButton(_ entry: LoomIcons.Entry) -> some View {
        Button { selection = entry.emoji } label: {
            Text(entry.emoji).font(.title2)
                .frame(width: 44, height: 44)
                .background(selection == entry.emoji ? LoomPalette.mint.opacity(0.22) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selection == entry.emoji ? LoomPalette.mint : .clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.words)
        .accessibilityAddTraits(selection == entry.emoji ? .isSelected : [])
    }
}
private struct CompletionButton: View {
    let done: Bool
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: done ? "checkmark" : "circle")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(done ? LoomPalette.ink : .white.opacity(0.65))
                .frame(width: 32, height: 32)
                .background(done ? color : .white.opacity(0.06), in: Circle())
                .overlay(Circle().stroke(done ? color : .white.opacity(0.18)))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: done)
    }
}
// MARK: - Today
private struct TodayView: View {
    @EnvironmentObject private var store: LoomStore
    @Binding var tab: LoomTab
    @Binding var showChores: Bool
    @Binding var showSettings: Bool
    private var greeting: String {
        switch Calendar.autoupdatingCurrent.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
    private var standaloneItems: [LoomItem] {
        store.state.items.filter { $0.routineID == nil }
    }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                LoomHeader(
                    eyebrow: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                    title: greeting,
                    actionIcon: "slider.horizontal.3",
                    action: { showSettings = true }
                )
                DayProgressCard()
                ForEach(store.state.routines) { routine in
                    RoutineTodayCard(routine: routine)
                }
                if !standaloneItems.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Loose threads")
                            .font(.headline)
                        ForEach(standaloneItems) { item in
                            TodayItemRow(item: item)
                        }
                    }
                    .padding(18)
                    .loomCard()
                }
                HStack(spacing: 12) {
                    TodayPortal(
                        icon: "circle.hexagongrid.fill",
                        title: "Chance",
                        detail: "\(store.state.funActivities.count - store.todayFunDoneIDs.count) in the wheel",
                        tint: LoomPalette.lilac
                    ) { tab = .wheel }
                    TodayPortal(
                        icon: "sparkles",
                        title: "Chores",
                        detail: "\(store.choreCompletionCount)/\(store.state.chores.count) cleared",
                        tint: LoomPalette.gold
                    ) { showChores = true }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .toolbar(.hidden, for: .navigationBar)
    }
}
private struct DayProgressCard: View {
    @EnvironmentObject private var store: LoomStore
    private var progress: Double {
        guard !store.state.items.isEmpty else { return 0 }
        return Double(store.todayCompletionCount) / Double(store.state.items.count)
    }
    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(.white.opacity(0.08), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [LoomPalette.mint, LoomPalette.sky, LoomPalette.lilac], center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.65, dampingFraction: 0.78), value: progress)
                VStack(spacing: 0) {
                    Text("\(Int(progress * 100))%")
                        .font(.title3.bold())
                    Text("TODAY")
                        .font(.system(size: 8, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 7) {
                Text(progress == 1 ? "Day woven" : "Today's weave")
                    .font(.title3.bold())
                Text("\(store.todayCompletionCount) of \(store.state.items.count) threads complete")
                    .foregroundStyle(.secondary)
                GeometryReader { proxy in
                    Capsule()
                        .fill(.white.opacity(0.08))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(LinearGradient(colors: [LoomPalette.mint, LoomPalette.sky], startPoint: .leading, endPoint: .trailing))
                                .frame(width: proxy.size.width * progress)
                        }
                }
                .frame(height: 7)
            }
        }
        .padding(20)
        .loomCard(cornerRadius: 30)
    }
}
private struct RoutineTodayCard: View {
    @EnvironmentObject private var store: LoomStore
    let routine: LoomRoutine
    private var items: [LoomItem] { store.items(in: routine) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(routine.icon).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.name).font(.headline)
                    if !routine.trigger.isEmpty {
                        Text(routine.trigger).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("\(items.filter { store.isDoneToday($0.id) }.count)/\(items.count)")
                    .font(.caption.bold())
                    .foregroundStyle(LoomPalette.mint)
            }
            if items.isEmpty {
                Text("No steps in this routine")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(LoomPalette.threadColors[item.colorIndex % LoomPalette.threadColors.count])
                                .frame(width: 8, height: 8)
                            if index < items.count - 1 {
                                Rectangle()
                                    .fill(LoomPalette.threadColors[item.colorIndex % LoomPalette.threadColors.count].opacity(0.35))
                                    .frame(width: 2, height: 43)
                            }
                        }
                        .padding(.top, 13)
                        TodayItemRow(item: item)
                    }
                }
            }
        }
        .padding(18)
        .loomCard()
    }
}
private struct TodayItemRow: View {
    @EnvironmentObject private var store: LoomStore
    let item: LoomItem
    private var color: Color {
        LoomPalette.threadColors[item.colorIndex % LoomPalette.threadColors.count]
    }
    var body: some View {
        HStack(spacing: 12) {
            Text(item.icon)
                .font(.title3)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(store.isDoneToday(item.id), color: .secondary)
                if item.kind == .habit {
                    Text(item.sentence)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            CompletionButton(done: store.isDoneToday(item.id), color: color) {
                store.toggleItem(item.id)
            }
        }
    }
}
private struct TodayPortal: View {
    let icon: String
    let title: String
    let detail: String
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                Spacer(minLength: 4)
                Text(title).font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .padding(16)
            .loomCard(cornerRadius: 22)
        }
        .buttonStyle(.plain)
    }
}
// MARK: - Build
private enum BuildSection: String, CaseIterable, Identifiable {
    case habits = "Threads"
    case routines = "Routines"
    var id: String { rawValue }
}
private struct BuildView: View {
    @EnvironmentObject private var store: LoomStore
    @Binding var showSettings: Bool
    @State private var section: BuildSection = .habits
    @State private var itemEditor: ItemEditorRequest?
    @State private var routineEditor: RoutineEditorRequest?
    var body: some View {
        List {
            LoomHeader(eyebrow: "Shape the system", title: "Build", action: { showSettings = true })
                .loomListRow()
            Picker("Build section", selection: $section) {
                ForEach(BuildSection.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .loomListRow()
            if section == .habits {
                Section {
                    HStack {
                        Text("\(store.state.items.count) active").foregroundStyle(.secondary)
                        Spacer()
                        Menu {
                            Button("New habit", systemImage: "repeat") { itemEditor = .new(.habit) }
                            Button("New task", systemImage: "checkmark.square") { itemEditor = .new(.task) }
                        } label: { Label("Add", systemImage: "plus") }
                    }
                    .loomListRow()
                    ForEach(store.state.items) { item in
                        Button { itemEditor = .edit(item) } label: {
                            HStack(spacing: 14) {
                                Text(item.icon).font(.title2)
                                    .frame(width: 46, height: 46)
                                    .background(LoomPalette.threadColors[item.colorIndex % LoomPalette.threadColors.count].opacity(0.14),
                                                in: RoundedRectangle(cornerRadius: 15))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.title).font(.headline).foregroundStyle(.primary)
                                    Text(item.kind == .habit ? item.sentence : (store.routine(item.routineID)?.name ?? "Unassigned"))
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(16).loomCard(cornerRadius: 22)
                        }
                        .buttonStyle(.plain)
                        .loomListRow()
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { store.deleteItem(item.id) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } else {
                Section {
                    HStack {
                        Text("\(store.state.routines.count) routines").foregroundStyle(.secondary)
                        Spacer()
                        Button { routineEditor = .new } label: { Label("Add", systemImage: "plus") }
                    }
                    .loomListRow()
                    ForEach(store.state.routines) { routine in
                        RoutineBuilderCard(routine: routine) { routineEditor = .edit(routine) }
                            .loomListRow()
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { store.deleteRoutine(routine.id) } label: {
                                    Label("Delete routine", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $itemEditor) { request in
            NavigationStack { ItemEditorView(request: request) }
        }
        .sheet(item: $routineEditor) { request in
            NavigationStack { RoutineEditorView(request: request) }
        }
    }
}
private enum ItemEditorRequest: Identifiable {
    case new(LoomItemKind)
    case edit(LoomItem)
    var id: String {
        switch self {
        case .new(let kind): return "new-\(kind.rawValue)"
        case .edit(let item): return item.id.uuidString
        }
    }
}
private struct ItemEditorView: View {
    @EnvironmentObject private var store: LoomStore
    @Environment(\.dismiss) private var dismiss
    let request: ItemEditorRequest
    @State private var kind: LoomItemKind
    @State private var behavior: String
    @State private var cue: String
    @State private var identity: String
    @State private var text: String
    @State private var icon: String
    @State private var routineID: UUID?
    @State private var confirmDelete = false
    init(request: ItemEditorRequest) {
        self.request = request
        switch request {
        case .new(let kind):
            _kind = State(initialValue: kind)
            _behavior = State(initialValue: "")
            _cue = State(initialValue: "")
            _identity = State(initialValue: "")
            _text = State(initialValue: "")
            _icon = State(initialValue: kind == .habit ? "🌿" : "✨")
            _routineID = State(initialValue: nil)
        case .edit(let item):
            _kind = State(initialValue: item.kind)
            _behavior = State(initialValue: item.behavior)
            _cue = State(initialValue: item.cue)
            _identity = State(initialValue: item.identity)
            _text = State(initialValue: item.text)
            _icon = State(initialValue: item.icon)
            _routineID = State(initialValue: item.routineID)
        }
    }
    private var existingID: UUID? {
        if case .edit(let item) = request { return item.id }
        return nil
    }
    private var canSave: Bool {
        kind == .habit
            ? !behavior.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              && !identity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $kind) {
                    Text("Habit").tag(LoomItemKind.habit)
                    Text("Task").tag(LoomItemKind.task)
                }
                .pickerStyle(.segmented)
            }
            Section("Icon") {
                LoomIconPicker(selection: $icon, name: kind == .habit ? behavior : text)
            }
            if kind == .habit {
                Section("Behavior") {
                    TextField("meditate for 5 minutes", text: $behavior)
                }
                Section("Cue") {
                    TextField("when I wake up", text: $cue)
                }
                Section("Identity") {
                    TextField("a mindful person", text: $identity)
                }
            } else {
                Section("Task") {
                    TextField("What needs doing?", text: $text)
                }
            }
            Section("Routine") {
                Picker("Assignment", selection: $routineID) {
                    Text("Loose thread").tag(nil as UUID?)
                    ForEach(store.state.routines) { routine in
                        Text("\(routine.icon) \(routine.name)").tag(routine.id as UUID?)
                    }
                }
            }
            if existingID != nil {
                Section {
                    Button("Delete", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .navigationTitle(existingID == nil ? "New thread" : "Edit thread")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    store.upsertItem(
                        id: existingID,
                        kind: kind,
                        behavior: behavior.trimmingCharacters(in: .whitespacesAndNewlines),
                        cue: cue.trimmingCharacters(in: .whitespacesAndNewlines),
                        identity: identity.trimmingCharacters(in: .whitespacesAndNewlines),
                        text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                        icon: icon,
                        routineID: routineID
                    )
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
        .confirmationDialog("Delete this thread?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let existingID { store.deleteItem(existingID) }
                dismiss()
            }
        }
    }
}
private enum RoutineEditorRequest: Identifiable {
    case new
    case edit(LoomRoutine)
    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let routine): return routine.id.uuidString
        }
    }
}
private struct RoutineBuilderCard: View {
    @EnvironmentObject private var store: LoomStore
    let routine: LoomRoutine
    let edit: () -> Void
    private var items: [LoomItem] { store.items(in: routine) }
    var body: some View {
        VStack(spacing: 0) {
            Button(action: edit) {
                HStack(spacing: 12) {
                    Text(routine.icon).font(.title2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(routine.name).font(.headline)
                        Text(routine.trigger.isEmpty ? "No trigger" : routine.trigger)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            Divider().overlay(.white.opacity(0.07))
            if items.isEmpty {
                RoutineDropZone(routineID: routine.id, destinationIndex: 0, isEmpty: true)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    RoutineDragRow(
                        item: item,
                        number: index + 1,
                        routineID: routine.id,
                        rowIndex: index
                    )
                }
                RoutineDropZone(
                    routineID: routine.id,
                    destinationIndex: items.count,
                    isEmpty: false
                )
            }
        }
        .loomCard()
    }
}
private struct RoutineDragRow: View {
    @EnvironmentObject private var store: LoomStore
    let item: LoomItem
    let number: Int
    let routineID: UUID
    let rowIndex: Int
    @State private var isDropTarget = false
    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption2.bold())
                .foregroundStyle(LoomPalette.mint)
                .frame(width: 24)
            Text(item.icon)
            Text(item.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Spacer()
            Image(systemName: "line.3.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(isDropTarget ? LoomPalette.mint : .secondary)
                .frame(width: 32, height: 32)
            Button { store.assign(item.id, to: nil) } label: {
                Image(systemName: "xmark").frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isDropTarget ? LoomPalette.mint.opacity(0.12) : .clear)
        .contentShape(Rectangle())
        .draggable(item.id.uuidString) {
            HStack(spacing: 10) {
                Text(item.icon)
                Text(item.title).font(.subheadline.weight(.semibold))
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(LoomPalette.mint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .dropDestination(for: String.self) { values, location in
            guard let value = values.first,
                  let draggedID = UUID(uuidString: value) else { return false }
            let dropAfterRow = location.y > 26
            let destination = rowIndex + (dropAfterRow ? 1 : 0)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                store.moveItem(draggedID, to: routineID, at: destination)
            }
            return true
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.16)) {
                isDropTarget = targeted
            }
        }
    }
}
private struct RoutineDropZone: View {
    @EnvironmentObject private var store: LoomStore
    let routineID: UUID
    let destinationIndex: Int
    let isEmpty: Bool
    @State private var isTargeted = false
    var body: some View {
        HStack(spacing: 9) {
            if isEmpty || isTargeted {
                Image(systemName: "arrow.down.to.line.compact")
                Text(isEmpty ? "Drop a thread here" : "Move to end")
                    .font(.caption.weight(.semibold))
            }
        }
        .foregroundStyle(isTargeted ? LoomPalette.mint : .secondary)
        .frame(maxWidth: .infinity, minHeight: isEmpty ? 58 : 18)
        .background(isTargeted ? LoomPalette.mint.opacity(0.10) : .clear)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { values, _ in
            guard let value = values.first,
                  let draggedID = UUID(uuidString: value) else { return false }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                store.moveItem(draggedID, to: routineID, at: destinationIndex)
            }
            return true
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.16)) {
                isTargeted = targeted
            }
        }
    }
}
private struct RoutineEditorView: View {
    @EnvironmentObject private var store: LoomStore
    @Environment(\.dismiss) private var dismiss
    let request: RoutineEditorRequest
    @State private var name: String
    @State private var trigger: String
    @State private var icon: String
    @State private var assigned: Set<UUID>
    @State private var confirmDelete = false
    init(request: RoutineEditorRequest) {
        self.request = request
        switch request {
        case .new:
            _name = State(initialValue: "")
            _trigger = State(initialValue: "")
            _icon = State(initialValue: "✨")
            _assigned = State(initialValue: [])
        case .edit(let routine):
            _name = State(initialValue: routine.name)
            _trigger = State(initialValue: routine.trigger)
            _icon = State(initialValue: routine.icon)
            _assigned = State(initialValue: Set(routine.order))
        }
    }
    private var existingID: UUID? {
        if case .edit(let routine) = request { return routine.id }
        return nil
    }
    var body: some View {
        Form {
            Section("Routine") {
                TextField("Name", text: $name)
                TextField("Trigger", text: $trigger)
            }
            Section("Icon") {
                LoomIconPicker(selection: $icon, name: name)
            }
            Section("Threads") {
                ForEach(store.state.items) { item in
                    Button {
                        if assigned.contains(item.id) { assigned.remove(item.id) }
                        else { assigned.insert(item.id) }
                    } label: {
                        HStack {
                            Text(item.icon)
                            Text(item.title).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: assigned.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(assigned.contains(item.id) ? LoomPalette.mint : .secondary)
                        }
                    }
                }
            }
            if existingID != nil {
                Section { Button("Delete routine", role: .destructive) { confirmDelete = true } }
            }
        }
        .navigationTitle(existingID == nil ? "New routine" : "Edit routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.upsertRoutine(id: existingID, name: trimmed, trigger: trigger.trimmingCharacters(in: .whitespacesAndNewlines), icon: icon)
                    guard let routineID = existingID ?? store.state.routines.last?.id else {
                        dismiss(); return
                    }
                    for item in store.state.items {
                        if assigned.contains(item.id) {
                            store.assign(item.id, to: routineID)
                        } else if item.routineID == routineID {
                            store.assign(item.id, to: nil)
                        }
                    }
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .confirmationDialog("Delete this routine?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let existingID { store.deleteRoutine(existingID) }
                dismiss()
            }
        }
    }
}
// MARK: - Wheel
private enum ChanceMode: String, CaseIterable, Identifiable {
    case halo
    case deck
    case list
    case reel
    case orbit
    var id: String { rawValue }
    var title: String {
        switch self {
        case .halo: return "Halo"
        case .deck: return "Cards"
        case .list: return "Kinetic list"
        case .reel: return "Reel"
        case .orbit: return "Orbit"
        }
    }
    var icon: String {
        switch self {
        case .halo: return "circle.hexagongrid.fill"
        case .deck: return "rectangle.stack.fill"
        case .list: return "list.bullet.rectangle.portrait.fill"
        case .reel: return "infinity"
        case .orbit: return "atom"
        }
    }
    var actionTitle: String {
        switch self {
        case .halo: return "Spin the halo"
        case .deck: return "Draw a card"
        case .list: return "Let one surface"
        case .reel: return "Roll the reel"
        case .orbit: return "Set it in motion"
        }
    }
}
// The endpoint determines both the animation and the winning activity.
private struct ChanceRoll: Identifiable {
    let id = UUID()
    let activities: [FunActivity]
    let start: Date
    let duration: Double
    let from: Double
    let target: Double

    static func wrapped(_ index: Int, count: Int) -> Int {
        ((index % count) + count) % count
    }
    var winner: FunActivity {
        activities[Self.wrapped(Int(target), count: activities.count)]
    }
    func position(at date: Date) -> Double {
        let t = min(1, max(0, date.timeIntervalSince(start) / duration))
        // Continuous deceleration, with zero velocity at the exact endpoint.
        let eased = 1 - pow(1 - t, 3)
        return from + (target - from) * eased
    }
}

private enum PoolSort: String, CaseIterable, Identifiable {
    case available = "Available first"
    case alphabetical = "Name A–Z"
    case reverseAlphabetical = "Name Z–A"
    case added = "Added order"
    var id: String { rawValue }
}

private struct WheelView: View {
    @EnvironmentObject private var store: LoomStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Binding var showSettings: Bool
    @AppStorage("loom.chance.mode") private var modeRaw = ChanceMode.deck.rawValue
    @AppStorage("loom.pool.sort") private var poolSortRaw = PoolSort.available.rawValue
    @State private var roll: ChanceRoll?
    @State private var chosen: FunActivity?
    @State private var editor: FunActivity?
    @State private var addingActivity = false
    @State private var poolExpanded = false
    @State private var poolQuery = ""

    private var mode: ChanceMode { ChanceMode(rawValue: modeRaw) ?? .deck }
    private var poolSort: PoolSort { PoolSort(rawValue: poolSortRaw) ?? .available }
    private var sortedPool: [FunActivity] {
        store.state.funActivities.enumerated().sorted { lhs, rhs in
            if poolSort == .added { return lhs.offset < rhs.offset }
            if poolSort == .available {
                let leftDone = store.isFunDoneToday(lhs.element.id)
                let rightDone = store.isFunDoneToday(rhs.element.id)
                if leftDone != rightDone { return !leftDone }
            }
            let order = lhs.element.name.localizedStandardCompare(rhs.element.name)
            if order != .orderedSame {
                return poolSort == .reverseAlphabetical ? order == .orderedDescending : order == .orderedAscending
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }
    private var available: [FunActivity] {
        sortedPool.filter { !store.isFunDoneToday($0.id) }
    }
    private var isChoosing: Bool { roll != nil && chosen == nil }
    private var poolMatches: [FunActivity] {
        sortedPool.filter {
            poolQuery.isEmpty || $0.name.localizedCaseInsensitiveContains(poolQuery)
        }
    }
    private var visiblePool: [FunActivity] {
        poolExpanded || !poolQuery.isEmpty ? poolMatches : Array(poolMatches.prefix(6))
    }
    var body: some View {
        List {
                LoomHeader(eyebrow: "Make room for a little chance", title: "Chance studio",
                           action: { showSettings = true })
                    .loomListRow()
                ChanceModeStrip(selected: mode, disabled: isChoosing) { newMode in
                    modeRaw = newMode.rawValue
                    roll = nil
                    chosen = nil
                }
                .loomListRow()
                ChanceStage(mode: mode, activities: roll?.activities ?? available,
                            roll: roll, isChoosing: isChoosing, reduceMotion: reduceMotion)
                    .frame(height: 330)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .background(LoomPalette.panel, in: RoundedRectangle(cornerRadius: 30))
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.09)))
                    .loomListRow()
                Button(action: choose) {
                    Label(isChoosing ? "Choosing…" : available.isEmpty ? "Everything is complete" : mode.actionTitle,
                          systemImage: mode.icon)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(LoomPalette.ink)
                        .background(
                            LinearGradient(colors: [LoomPalette.lilac, LoomPalette.sky, LoomPalette.mint],
                                           startPoint: .leading, endPoint: .trailing), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isChoosing || available.isEmpty)
                .loomListRow()
                if let chosen = chosen {
                    ChanceResultCard(activity: chosen, markDone: { complete(chosen) }, chooseAgain: choose)
                        .buttonStyle(.plain)
                        .loomListRow()
                }
                activityPool
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editor) { activity in
            NavigationStack { ActivityEditorView(activity: activity) }
        }
        .sheet(isPresented: $addingActivity) {
            NavigationStack { ActivityEditorView(activity: nil) }
        }
        .task(id: roll?.id) {
            guard let active = roll, chosen == nil else { return }
            let remaining = max(0, active.duration - Date().timeIntervalSince(active.start))
            do {
                try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            } catch { return }
            guard !Task.isCancelled, roll?.id == active.id else { return }
            chosen = active.winner
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active && isChoosing { cancelRoll() }
        }
        .onChange(of: store.state.funActivities) { _ in cancelRoll() }
        .onChange(of: store.state.funCompletions) { _ in cancelRoll() }
        .onChange(of: poolSortRaw) { _ in
            cancelRoll()
            poolExpanded = false
        }
        .onDisappear { if isChoosing { cancelRoll() } }
        .sensoryFeedback(.selection, trigger: chosen?.id)
    }

    private var activityPool: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity pool").font(.headline)
                    Text("\(available.count) available today").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Picker("Activity order", selection: $poolSortRaw) {
                        ForEach(PoolSort.allCases) { option in
                            Text(option.rawValue).tag(option.rawValue)
                        }
                    }
                    Divider()
                    Button("Suggest missing icons", systemImage: "sparkles") { store.suggestActivityIcons() }
                } label: {
                    Label(poolSort.rawValue, systemImage: "arrow.up.arrow.down")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(minHeight: 44)
                }
                .disabled(isChoosing)
                Button { addingActivity = true } label: {
                    Image(systemName: "plus").font(.headline)
                        .frame(width: 44, height: 44)
                        .background(LoomPalette.mint, in: Circle()).foregroundStyle(LoomPalette.ink)
                }
                .buttonStyle(.plain)
                .disabled(isChoosing)
            }
            .loomListRow()
            if store.state.funActivities.count > 6 {
                TextField("Find an activity", text: $poolQuery)
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    .loomListRow()
            }
            ForEach(visiblePool) { activity in
                HStack(spacing: 10) {
                    CompletionButton(done: store.isFunDoneToday(activity.id), color: LoomPalette.mint) {
                        store.toggleFun(activity.id)
                    }
                    .disabled(isChoosing)
                    Text(activity.icon).font(.title3).frame(width: 30)
                    Text(activity.name).font(.subheadline.weight(.medium)).lineLimit(2)
                        .strikethrough(store.isFunDoneToday(activity.id))
                        .foregroundStyle(store.isFunDoneToday(activity.id) ? .secondary : .primary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.vertical, 5)
                .loomListRow()
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !isChoosing {
                        Button(role: .destructive) { store.deleteActivity(activity.id) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { editor = activity } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(Color(hex: 0x356B78))
                    }
                }
            }
            if poolQuery.isEmpty && poolMatches.count > 6 {
                Button(poolExpanded ? "Show fewer" : "Show all \(poolMatches.count) activities") {
                    poolExpanded.toggle()
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity).padding(16)
                .loomListRow()
            }
            if poolMatches.isEmpty { Text("No matching activities").foregroundStyle(.secondary).padding().loomListRow() }
        }
    }

    private func choose() {
        guard !isChoosing else { return }
        let pool = available
        guard !pool.isEmpty else { return }
        let selectedIndex = Int.random(in: 0..<pool.count)
        // Continue from the last displayed winner when the candidate pool is unchanged.
        let startIndex = chosen.flatMap { winner in pool.firstIndex { $0.id == winner.id } } ?? 0
        let distance = ChanceRoll.wrapped(selectedIndex - startIndex, count: pool.count)
        let laps = pool.count == 1 ? 0 : 2 * pool.count
        let target = Double(startIndex + laps + distance)
        chosen = nil
        roll = ChanceRoll(activities: pool, start: Date(),
                          duration: reduceMotion || pool.count == 1 ? 0.2 : 3.2,
                          from: Double(startIndex), target: target)
    }
    private func cancelRoll() {
        roll = nil
        chosen = nil
    }
    private func complete(_ activity: FunActivity) {
        if !store.isFunDoneToday(activity.id) { store.toggleFun(activity.id) }
        cancelRoll()
    }
}
private struct ChanceModeStrip: View {
    let selected: ChanceMode
    let disabled: Bool
    let select: (ChanceMode) -> Void
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(ChanceMode.allCases) { mode in
                    Button { select(mode) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: mode.icon)
                            Text(mode.title)
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selected == mode ? LoomPalette.ink : .white.opacity(0.72))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background {
                            if selected == mode {
                                Capsule()
                                    .fill(LinearGradient(colors: [LoomPalette.mint, LoomPalette.sky], startPoint: .leading, endPoint: .trailing))
                            } else {
                                Capsule().fill(.white.opacity(0.07))
                            }
                        }
                        .overlay(Capsule().stroke(.white.opacity(selected == mode ? 0.28 : 0.08)))
                    }
                    .buttonStyle(.plain)
                    .disabled(disabled)
                }
            }
            .padding(.vertical, 3)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selected)
    }
}
private struct ChanceStage: View {
    let mode: ChanceMode
    let activities: [FunActivity]
    let roll: ChanceRoll?
    let isChoosing: Bool
    let reduceMotion: Bool

    var body: some View {
        Group {
            if activities.isEmpty {
                ChanceEmptyStage(icon: "checkmark.seal.fill", title: "Everything is complete")
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                        paused: !isChoosing || reduceMotion)) { context in
                    let position = displayPosition(at: context.date)
                    Group {
                        switch mode {
                        case .deck: DeckMotionStage(activities: activities, position: position)
                        case .list: KineticMotionStage(activities: activities, position: position)
                        case .reel: ReelMotionStage(activities: activities, position: position)
                        case .orbit: OrbitMotionStage(activities: activities, position: position)
                        case .halo: HaloMotionStage(activities: activities, position: position)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(isChoosing ? "Choosing an activity" :
                        activities[ChanceRoll.wrapped(Int(position.rounded()), count: activities.count)].name)
                }
            }
        }
        // All movement is already interpolated from elapsed time.
        .transaction { $0.animation = nil }
    }
    private func displayPosition(at date: Date) -> Double {
        guard let roll = roll else { return 0 }
        if !isChoosing { return roll.target }
        return reduceMotion ? roll.from : roll.position(at: date)
    }
}

private struct DeckMotionStage: View {
    let activities: [FunActivity]
    let position: Double
    var body: some View {
        GeometryReader { proxy in
            let width = min(215.0, proxy.size.width * 0.67)
            let base = Int(floor(position))
            ZStack {
                ForEach(Array((base - 3)...(base + 3)), id: \.self) { slot in
                    let distance = Double(slot) - position
                    let depth = min(abs(distance), 3)
                    let item = activities[ChanceRoll.wrapped(slot, count: activities.count)]
                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: "sparkle")
                            Spacer()
                            Text("LOOM").font(.caption2.bold()).tracking(2)
                        }
                        .foregroundStyle(.white.opacity(0.55))
                        Spacer(minLength: 0)
                        Text(item.icon).font(.system(size: 54))
                        Text(item.name)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center).lineLimit(3)
                        Spacer(minLength: 0)
                        Capsule().fill(.white.opacity(0.28)).frame(width: 28, height: 3)
                    }
                    .padding(20)
                    .frame(width: width, height: 250)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x514777), Color(hex: 0x22384D)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 25))
                    .overlay(RoundedRectangle(cornerRadius: 25).stroke(.white.opacity(0.3)))
                    .scaleEffect(1 - depth * 0.10)
                    .rotationEffect(.degrees(distance * 7))
                    .offset(x: CGFloat(distance) * width * 0.72, y: CGFloat(depth * 15))
                    .opacity(max(0, 1 - depth * 0.36))
                    .zIndex(-depth)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipped()
    }
}

private struct KineticMotionStage: View {
    let activities: [FunActivity]
    let position: Double
    var body: some View {
        GeometryReader { proxy in
            let base = Int(floor(position))
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LoomPalette.mint.opacity(0.10))
                    .frame(height: 62)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(LoomPalette.mint.opacity(0.55)))
                    .padding(.horizontal, 14)
                ForEach(Array((base - 3)...(base + 3)), id: \.self) { slot in
                    let distance = Double(slot) - position
                    let item = activities[ChanceRoll.wrapped(slot, count: activities.count)]
                    HStack(spacing: 14) {
                        Text(item.icon).font(.title2).frame(width: 36)
                        Text(item.name).font(.system(size: 18, weight: .semibold)).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 28)
                    .frame(width: proxy.size.width, height: 66)
                    .opacity(max(0, 1 - abs(distance) * 0.36))
                    .scaleEffect(1 - min(abs(distance), 3) * 0.055)
                    .offset(y: CGFloat(distance) * 66)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipped()
    }
}

private struct ReelMotionStage: View {
    let activities: [FunActivity]
    let position: Double
    var body: some View {
        GeometryReader { proxy in
            let base = Int(floor(position))
            let spacing = min(136.0, proxy.size.width * 0.4)
            let center = activities[ChanceRoll.wrapped(Int(position.rounded()), count: activities.count)]
            VStack(spacing: 16) {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.caption).foregroundStyle(LoomPalette.mint)
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(LoomPalette.mint.opacity(0.08))
                        .frame(width: spacing - 10, height: 140)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(LoomPalette.mint.opacity(0.55)))
                    ForEach(Array((base - 3)...(base + 3)), id: \.self) { slot in
                        let distance = Double(slot) - position
                        let item = activities[ChanceRoll.wrapped(slot, count: activities.count)]
                        VStack(spacing: 10) {
                            Text(item.icon).font(.system(size: 48))
                            Text(item.name).font(.caption.weight(.medium))
                                .multilineTextAlignment(.center).lineLimit(2)
                        }
                        .frame(width: spacing - 18, height: 124)
                        .scaleEffect(1 - min(abs(distance), 3) * 0.12)
                        .opacity(max(0, 1 - abs(distance) * 0.38))
                        .offset(x: CGFloat(distance) * spacing)
                    }
                }
                .frame(height: 144)
                Text(center.name).font(.title3.weight(.semibold))
                    .lineLimit(2).multilineTextAlignment(.center)
                    .frame(height: 52).padding(.horizontal, 26)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipped()
    }
}

private struct OrbitMotionStage: View {
    let activities: [FunActivity]
    let position: Double
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size * 0.38
            let step = 2 * Double.pi / Double(activities.count)
            let diameter = min(36.0, max(8.0, 2 * radius * sin(Double.pi / Double(max(activities.count, 2))) - 8))
            let selected = ChanceRoll.wrapped(Int(position.rounded()), count: activities.count)
            let angle = position * step - Double.pi / 2
            ZStack {
                Circle().stroke(.white.opacity(0.1), lineWidth: 1)
                    .frame(width: radius * 2, height: radius * 2)
                Circle().stroke(.white.opacity(0.035), lineWidth: 1)
                    .frame(width: radius * 1.48, height: radius * 1.48)
                ForEach(Array(activities.enumerated()), id: \.element.id) { index, item in
                    let theta = Double(index) * step - Double.pi / 2
                    ZStack {
                        Circle().fill(index == selected ? LoomPalette.mint.opacity(0.3) : .white.opacity(0.07))
                        if diameter >= 25 { Text(item.icon).font(.system(size: 18)) }
                        else { Circle().fill(.white.opacity(0.6)).frame(width: 4, height: 4) }
                    }
                    .frame(width: diameter, height: diameter)
                    .offset(x: CGFloat(cos(theta)) * radius, y: CGFloat(sin(theta)) * radius)
                }
                Circle().stroke(LoomPalette.mint, lineWidth: 2)
                    .frame(width: diameter + 7, height: diameter + 7)
                    .offset(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
                VStack(spacing: 10) {
                    Text(activities[selected].icon).font(.system(size: 44))
                    Text(activities[selected].name)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center).lineLimit(3)
                }
                .frame(width: radius * 1.25)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct HaloSlice: Shape {
    let startAngle: Double
    let endAngle: Double
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2,
                    startAngle: .degrees(startAngle), endAngle: .degrees(endAngle), clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct HaloMotionStage: View {
    let activities: [FunActivity]
    let position: Double
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height) - 36
            let step = 360.0 / Double(activities.count)
            let selected = ChanceRoll.wrapped(Int(position.rounded()), count: activities.count)
            ZStack {
                ZStack {
                    ForEach(Array(activities.enumerated()), id: \.element.id) { index, item in
                        let angle = Double(index) * step - 90
                        HaloSlice(startAngle: angle - step / 2, endAngle: angle + step / 2)
                            .fill(index.isMultiple(of: 2) ? LoomPalette.lilac.opacity(0.5) : LoomPalette.sky.opacity(0.4))
                            .overlay(HaloSlice(startAngle: angle - step / 2, endAngle: angle + step / 2)
                                .stroke(.white.opacity(0.12), lineWidth: 1))
                        if activities.count <= 20 {
                            Text(item.icon).font(.system(size: activities.count > 12 ? 17 : 22))
                                .rotationEffect(.degrees(position * step))
                                .offset(x: CGFloat(cos(angle * .pi / 180)) * size * 0.4,
                                        y: CGFloat(sin(angle * .pi / 180)) * size * 0.4)
                        }
                    }
                }
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-position * step))
                Circle().fill(LoomPalette.panel).frame(width: size * 0.62, height: size * 0.62)
                VStack(spacing: 8) {
                    Text(activities[selected].icon).font(.system(size: 38))
                    Text(activities[selected].name).font(.headline)
                        .multilineTextAlignment(.center).lineLimit(3)
                }
                .frame(width: size * 0.50)
                Image(systemName: "arrowtriangle.down.fill").foregroundStyle(LoomPalette.mint)
                    .offset(y: -size / 2 - 4)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
private struct ChanceEmptyStage: View {
    let icon: String
    let title: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(LoomPalette.mint)
            Text(title).font(.headline)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}
private struct ChanceResultCard: View {
    let activity: FunActivity
    let markDone: () -> Void
    let chooseAgain: () -> Void
    var body: some View {
        HStack(spacing: 16) {
            Text(activity.icon)
                .font(.system(size: 42))
                .frame(width: 74, height: 74)
                .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 22))
            VStack(alignment: .leading, spacing: 5) {
                Text("CHOSEN")
                    .font(.system(size: 9, weight: .black))
                    .tracking(2)
                    .foregroundStyle(LoomPalette.gold)
                Text(activity.name)
                    .font(.title3.bold())
                    .lineLimit(2)
                HStack(spacing: 12) {
                    Button("Complete", action: markDone)
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(LoomPalette.mint, in: Capsule())
                        .foregroundStyle(LoomPalette.ink)
                    Button("Again", action: chooseAgain)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(colors: [LoomPalette.lilac.opacity(0.36), LoomPalette.sky.opacity(0.14), .white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(LinearGradient(colors: [.white.opacity(0.45), LoomPalette.mint.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .shadow(color: LoomPalette.lilac.opacity(0.28), radius: 20, y: 10)
    }
}
private struct ActivityEditorView: View {
    @EnvironmentObject private var store: LoomStore
    @Environment(\.dismiss) private var dismiss
    let activity: FunActivity?
    @State private var name: String
    @State private var icon: String
    @State private var confirmDelete = false
    init(activity: FunActivity?) {
        self.activity = activity
        _name = State(initialValue: activity?.name ?? "")
        _icon = State(initialValue: activity?.icon ?? "✨")
    }
    var body: some View {
        Form {
            Section("Activity") { TextField("Name", text: $name) }
            Section("Icon") {
                LoomIconPicker(selection: $icon, name: name)
            }
            if activity != nil {
                Section { Button("Delete activity", role: .destructive) { confirmDelete = true } }
            }
        }
        .navigationTitle(activity == nil ? "New activity" : "Edit activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    store.upsertActivity(id: activity?.id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), icon: icon)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .confirmationDialog("Delete this activity?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let activity { store.deleteActivity(activity.id) }
                dismiss()
            }
        }
    }
}
// MARK: - Growth
private enum GrowthSort: String, CaseIterable, Identifiable {
    case most = "Most completions"
    case least = "Fewest completions"
    case longest = "Longest current streak"
    case shortest = "Shortest current streak"
    case best = "Best streak"
    case alphabetical = "Name A–Z"
    case reverseAlphabetical = "Name Z–A"
    var id: String { rawValue }
}

private struct GrowthView: View {
    @EnvironmentObject private var store: LoomStore
    @Binding var showSettings: Bool
    @State private var period: StatPeriod = .week
    @State private var scope = 0
    @State private var query = ""
    @State private var expanded = false
    @AppStorage("loom.growth.sort") private var sortRaw = GrowthSort.most.rawValue
    private var sort: GrowthSort { GrowthSort(rawValue: sortRaw) ?? .most }

    private struct StatEntry: Identifiable {
        let trackable: Trackable
        let count: Int
        let streak: LoomStreak
        let pinned: Bool
        var id: String { trackable.pinKey }
    }
    private var entries: [StatEntry] {
        store.trackables
            .filter { scope == 0 || (scope == 1 ? !$0.isFun : $0.isFun) }
            .map { StatEntry(trackable: $0, count: store.count($0, period: period),
                             streak: store.streak(for: $0), pinned: store.isPinned($0)) }
            .sorted { lhs, rhs in
                if lhs.pinned != rhs.pinned { return lhs.pinned }
                switch sort {
                case .most:
                    if lhs.count != rhs.count { return lhs.count > rhs.count }
                case .least:
                    if lhs.count != rhs.count { return lhs.count < rhs.count }
                case .longest:
                    if lhs.streak.current != rhs.streak.current { return lhs.streak.current > rhs.streak.current }
                case .shortest:
                    if lhs.streak.current != rhs.streak.current { return lhs.streak.current < rhs.streak.current }
                case .best:
                    if lhs.streak.best != rhs.streak.best { return lhs.streak.best > rhs.streak.best }
                case .alphabetical, .reverseAlphabetical: break
                }
                let nameOrder = lhs.trackable.name.localizedStandardCompare(rhs.trackable.name)
                if nameOrder != .orderedSame {
                    return sort == .reverseAlphabetical ? nameOrder == .orderedDescending : nameOrder == .orderedAscending
                }
                return lhs.trackable.pinKey < rhs.trackable.pinKey
            }
    }
    var body: some View {
        let report = entries
        let matches = report.filter { query.isEmpty || $0.trackable.name.localizedCaseInsensitiveContains(query) }
        let limit = max(6, matches.filter(\.pinned).count)
        let visible = expanded || !query.isEmpty ? matches : Array(matches.prefix(limit))
        let pinned = visible.filter(\.pinned)
        let others = visible.filter { !$0.pinned }
        let maximum = max(report.map(\.count).max() ?? 0, 1)
        List {
            LoomHeader(eyebrow: "Small steps, over time", title: "Growth", action: { showSettings = true })
                .loomListRow()
            Picker("Period", selection: $period) {
                ForEach(StatPeriod.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .loomListRow()
            HStack(spacing: 10) {
                metric("Completions", value: report.reduce(0) { $0 + $1.count })
                metric("Active", value: report.filter { $0.count > 0 }.count)
                metric("Tracked", value: report.count)
            }
            .loomListRow()
            Picker("Show", selection: $scope) {
                Text("All").tag(0)
                Text("Habits & tasks").tag(1)
                Text("Activities").tag(2)
            }
            .pickerStyle(.segmented)
            .loomListRow()
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find a habit or activity", text: $query)
                    .textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .foregroundStyle(.secondary).buttonStyle(.plain)
                }
            }
            .padding(13).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .loomListRow()
            Menu {
                Picker("Sort Growth", selection: $sortRaw) {
                    ForEach(GrowthSort.allCases) { option in Text(option.rawValue).tag(option.rawValue) }
                }
            } label: {
                Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
                    .font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            .loomListRow()
            if !pinned.isEmpty {
                Section("Pinned") {
                    ForEach(pinned) { entry in
                        swipeableGrowthRow(entry, maximum: maximum)
                    }
                }
                .textCase(nil)
            }
            Section {
                ForEach(others) { entry in
                    swipeableGrowthRow(entry, maximum: maximum)
                }
                if matches.isEmpty {
                    Text(query.isEmpty ? "Your habits and activities will appear here." : "No matches")
                        .font(.subheadline).foregroundStyle(.secondary).padding(24)
                        .loomListRow()
                }
                if query.isEmpty && (expanded || matches.count > visible.count) && matches.count > 6 {
                    Button(expanded ? "Show fewer" : "Show all \(matches.count)") { expanded.toggle() }
                        .font(.subheadline.weight(.semibold)).padding(14)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.plain)
                        .loomListRow()
                }
            } header: {
                if !pinned.isEmpty && !others.isEmpty { Text("Other items") }
            }
            .textCase(nil)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: period) { _ in expanded = false }
        .onChange(of: scope) { _ in expanded = false }
        .onChange(of: sortRaw) { _ in expanded = false }
    }
    private func swipeableGrowthRow(_ entry: StatEntry, maximum: Int) -> some View {
        growthRow(entry, maximum: maximum)
            .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(.white.opacity(0.08))
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button { store.togglePin(entry.trackable) } label: {
                    Label(entry.pinned ? "Unpin" : "Pin", systemImage: entry.pinned ? "pin.slash" : "pin")
                }
                .tint(Color(hex: 0x356B78))
            }
    }
    private func metric(_ title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(value)").font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit().foregroundStyle(LoomPalette.mint)
            Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18))
    }
    private func growthRow(_ entry: StatEntry, maximum: Int) -> some View {
        HStack(spacing: 12) {
            Text(entry.trackable.icon).font(.title2)
                .frame(width: 36, height: 42)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.trackable.name).font(.subheadline.weight(.medium)).lineLimit(2)
                    Spacer(minLength: 10)
                    Text("\(entry.count)").font(.subheadline.bold()).monospacedDigit()
                        .foregroundStyle(entry.count > 0 ? LoomPalette.mint : .secondary)
                }
                Text("\(entry.streak.current)-day streak · best \(entry.streak.best)")
                    .font(.caption2).foregroundStyle(.secondary)
                GeometryReader { proxy in
                    Capsule().fill(.white.opacity(0.05))
                        .overlay(alignment: .leading) {
                            Capsule().fill(LoomPalette.mint.opacity(0.65))
                                .frame(width: proxy.size.width * CGFloat(entry.count) / CGFloat(maximum))
                        }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(entry.trackable.name), \(entry.count) completions, current streak \(entry.streak.current) days")
    }
}
// MARK: - Chores
private struct ChoresView: View {
    @EnvironmentObject private var store: LoomStore
    @Environment(\.dismiss) private var dismiss
    @State private var newChore = ""
    var body: some View {
        ZStack {
            LoomBackground()
            List {
                Section {
                    HStack {
                        TextField("Add a chore", text: $newChore)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Button(action: add) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(LoomPalette.gold)
                        }
                        .buttonStyle(.plain)
                        .disabled(newChore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                Section {
                    ForEach(store.state.chores) { chore in
                        HStack(spacing: 12) {
                            CompletionButton(done: chore.done, color: LoomPalette.gold) {
                                store.toggleChore(chore.id)
                            }
                            Text(chore.text)
                                .strikethrough(chore.done, color: .secondary)
                            Spacer()
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.state.chores[$0].id }
                        ids.forEach(store.deleteChore)
                    }
                }
                if store.state.chores.contains(where: \.done) {
                    Section {
                        Button("Clear completed", role: .destructive) {
                            store.clearCompletedChores()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Chores")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
    }
    private func add() {
        let trimmed = newChore.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addChore(trimmed)
        newChore = ""
    }
}
// MARK: - Settings and backup
private struct LoomBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
// Both file and pasted-text imports pass through this decoder.
private enum LoomBackupCodec {
    struct Failure: LocalizedError {
        let reason: String
        var errorDescription: String? { reason }
    }

    static func decode(_ data: Data) throws -> LoomState {
        var input = data
        if var text = String(data: data, encoding: .utf8) {
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // Accept a complete JSON code block as well as plain JSON.
            let fence = String(repeating: "\u{0060}", count: 3)
            if text.hasPrefix(fence), text.hasSuffix(fence),
               let firstLine = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: firstLine)...].dropLast(3))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard !text.isEmpty else {
                throw Failure(reason: "The backup is empty. Paste the complete JSON or choose another file.")
            }
            input = Data(text.utf8)
        }

        var object: Any
        do {
            object = try JSONSerialization.jsonObject(with: input, options: [.fragmentsAllowed])
            if let encodedText = object as? String {
                object = try JSONSerialization.jsonObject(with: Data(encodedText.utf8))
            }
        } catch {
            throw Failure(reason: "This is not complete, valid JSON. Copy the whole backup, including its opening and closing braces.")
        }
        guard let root = object as? [String: Any] else {
            throw Failure(reason: "A Loom backup must contain a JSON object.")
        }

        // Native exports contain the state itself; also accept a state envelope.
        let payload: [String: Any]
        if root["items"] != nil {
            payload = root
        } else if let wrappedState = root["state"] as? [String: Any] {
            payload = wrappedState
        } else {
            payload = root
        }
        guard payload["items"] != nil else {
            let keys = payload.keys.sorted().prefix(12).joined(separator: ", ")
            throw Failure(reason: "This backup uses a different format: the Loom 'items' section is missing. Found sections: \(keys.isEmpty ? "(none)" : keys). Your current data has not changed. Share the backup JSON so its format can be supported.")
        }

        let encoded = try JSONSerialization.data(withJSONObject: payload)
        let result: LoomState
        do {
            result = try JSONDecoder().decode(LoomState.self, from: encoded)
        } catch let error as DecodingError {
            throw Failure(reason: decodingMessage(error))
        }
        try validate(result)
        return result
    }

    static func validate(_ state: LoomState) throws {
        guard Set(state.items.map(\.id)).count == state.items.count,
              Set(state.routines.map(\.id)).count == state.routines.count,
              Set(state.funActivities.map(\.id)).count == state.funActivities.count,
              Set(state.chores.map(\.id)).count == state.chores.count else {
            throw Failure(reason: "The backup contains duplicate IDs. Your current data has not changed.")
        }
        guard state.items.allSatisfy({ $0.colorIndex >= 0 }) else {
            throw Failure(reason: "The backup contains an invalid item color. Your current data has not changed.")
        }
        let itemIDs = Set(state.items.map(\.id))
        let routineIDs = Set(state.routines.map(\.id))
        guard state.items.allSatisfy({ item in
            item.routineID.map { routineIDs.contains($0) } ?? true
        }), state.routines.allSatisfy({ routine in
            routine.order.allSatisfy { itemIDs.contains($0) }
                && Set(routine.order).count == routine.order.count
        }) else {
            throw Failure(reason: "A routine in this backup contains a missing or duplicate item reference. Your current data has not changed.")
        }
    }

    static func summary(_ state: LoomState) -> String {
        let habits = state.items.filter { $0.kind == .habit }.count
        let tasks = state.items.filter { $0.kind == .task }.count
        let completions = state.completions.values.reduce(0) { $0 + $1.count }
            + state.funCompletions.values.reduce(0) { $0 + $1.count }
        return "\(habits) habits, \(tasks) tasks, \(state.routines.count) routines, \(state.funActivities.count) wheel activities, \(state.chores.count) chores, and \(completions) completions."
    }

    private static func decodingMessage(_ error: DecodingError) -> String {
        func field(_ path: [CodingKey]) -> String {
            path.map(\.stringValue).joined(separator: ".")
        }
        let detail: String
        switch error {
        case .keyNotFound(let key, let context):
            detail = "Missing field '\(field(context.codingPath + [key]))'."
        case .typeMismatch(_, let context):
            detail = "Unexpected value type at '\(field(context.codingPath))'."
        case .valueNotFound(_, let context):
            detail = "Missing value at '\(field(context.codingPath))'."
        case .dataCorrupted(let context):
            detail = "Invalid value at '\(field(context.codingPath))': \(context.debugDescription)"
        @unknown default:
            detail = "The data could not be decoded."
        }
        return "The JSON was read, but it does not match this Loom backup format. \(detail) Your current data has not changed."
    }
}

private struct LoomSettingsView: View {
    @EnvironmentObject private var store: LoomStore
    @Environment(\.dismiss) private var dismiss
    @State private var exportDocument: LoomBackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var confirmReset = false
    @State private var message: String?
    @State private var pastedBackup = ""
    @State private var backupPreview: LoomState?
    @State private var backupSource = ""
    @State private var photoSelection: PhotosPickerItem?
    @State private var photoTask: Task<Void, Never>?
    @State private var loadingPhoto = false
    @FocusState private var pasteFocused: Bool

    var body: some View {
        ZStack {
            LoomBackground()
            ScrollViewReader { scroll in
                List {
                    Color.clear
                        .frame(height: 0)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .environment(\.defaultMinListRowHeight, 0)
                        .id("restore-top")
                    if let message = message {
                        Section("Result") {
                            Text(message)
                                .font(.callout)
                                .textSelection(.enabled)
                        }
                    }
                    if let candidate = backupPreview {
                        Section("Ready to restore") {
                            Text(backupSource).font(.caption).foregroundStyle(.secondary)
                            Text(LoomBackupCodec.summary(candidate))
                            ForEach(Array(candidate.items.prefix(5))) { item in
                                Label(item.title, systemImage: item.kind == .habit ? "repeat" : "checkmark.circle")
                            }
                            Text("Restoring replaces the current data with this backup.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button("Restore this backup") {
                                applyBackup(candidate)
                            }
                            .fontWeight(.semibold)
                            Button("Cancel", role: .cancel) {
                                backupPreview = nil
                            }
                        }
                    }
                    Section("Profile") {
                        HStack(spacing: 18) {
                            LoomAvatar(size: 76)
                            VStack(alignment: .leading, spacing: 10) {
                                PhotosPicker(selection: $photoSelection, matching: .images) {
                                    Label(store.profileImage == nil ? "Add profile photo" : "Change photo", systemImage: "photo")
                                }
                                if loadingPhoto { ProgressView("Loading photo…") }
                                if store.profileImage != nil {
                                    Button("Remove photo", role: .destructive) {
                                        photoTask?.cancel()
                                        loadingPhoto = false
                                        do { try store.setProfilePhoto(nil) }
                                        catch { message = "The photo could not be removed: " + error.localizedDescription }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    Section("Backup") {
                        Button {
                            do {
                                exportDocument = LoomBackupDocument(data: try store.backupData())
                                exporting = true
                            } catch {
                                message = "The backup could not be created: " + error.localizedDescription
                            }
                        } label: {
                            Label("Export backup", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            pasteFocused = false
                            backupPreview = nil
                            message = nil
                            importing = true
                        } label: {
                            Label("Restore from file", systemImage: "doc.badge.arrow.up")
                        }
                        Button {
                            do {
                                let data = try store.dataBeforeLastRestore()
                                stageBackup(data, source: "Data saved before the last restore")
                            } catch {
                                message = "No recovery copy could be opened: " + error.localizedDescription
                            }
                        } label: {
                            Label("Recover data before last restore", systemImage: "arrow.uturn.backward")
                        }
                    }
                    Section("Paste backup JSON") {
                        TextEditor(text: $pastedBackup)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 150, maxHeight: 230)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($pasteFocused)
                            .accessibilityLabel("Paste the complete backup JSON")
                        Button("Review pasted backup") {
                            pasteFocused = false
                            stageBackup(Data(pastedBackup.utf8), source: "Pasted JSON")
                        }
                        .disabled(pastedBackup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Section("Storage") {
                        LabeledContent("Location", value: "On this iPhone")
                        LabeledContent("Format", value: "JSON")
                    }
                    Section {
                        Button(role: .destructive) { confirmReset = true } label: {
                            Label("Reset all data", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .onChange(of: backupPreview) { _ in
                    withAnimation { scroll.scrollTo("restore-top", anchor: .top) }
                }
                .onChange(of: message) { _ in
                    withAnimation { scroll.scrollTo("restore-top", anchor: .top) }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoSelection) { item in
            photoTask?.cancel()
            guard let item = item else { return }
            loadingPhoto = true
            photoTask = Task { @MainActor in
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    guard !Task.isCancelled else { return }
                    try store.setProfilePhoto(data)
                    loadingPhoto = false
                } catch {
                    guard !Task.isCancelled else { return }
                    loadingPhoto = false
                    message = "The photo could not be loaded: " + error.localizedDescription
                }
            }
        }
        .onDisappear { photoTask?.cancel() }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { pasteFocused = false }
            }
        }
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "Loom Backup"
        ) { result in
            switch result {
            case .success: message = "Backup exported."
            case .failure(let error): message = "The backup was not exported: " + error.localizedDescription
            }
        }
        .sheet(isPresented: $importing) {
            LoomBackupPicker { result in
                // Consume the delegate result directly. onDismiss is not a data callback.
                if let result = result {
                    switch result {
                    case .success(let data):
                        stageBackup(data, source: "Selected file")
                    case .failure(let error):
                        backupPreview = nil
                        message = "The file could not be read: " + error.localizedDescription
                    }
                }
                importing = false
            }
        }
        .confirmationDialog("Reset Loom?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset all data", role: .destructive) {
                backupPreview = nil
                store.reset()
                message = "Loom was reset."
            }
        } message: {
            Text("This replaces habits, routines, completions, wheel activities, and chores with the starter set.")
        }
    }

    private func stageBackup(_ data: Data, source: String) {
        backupPreview = nil
        message = nil
        do {
            backupPreview = try LoomBackupCodec.decode(data)
            backupSource = source
        } catch {
            message = error.localizedDescription
        }
    }

    private func applyBackup(_ candidate: LoomState) {
        do {
            try store.restoreBackup(candidate)
            backupPreview = nil
            pastedBackup = ""
            message = "Restored and saved: " + LoomBackupCodec.summary(store.state)
        } catch {
            message = "The backup was not restored: " + error.localizedDescription
        }
    }
}

// Imports a copy instead of asking SwiftUI's fileImporter to open the original.
// A broad file type avoids excluding JSON based on a provider's type metadata.
private struct LoomBackupPicker: UIViewControllerRepresentable {
    let onFinish: (Result<Data, Error>?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item],
            asCopy: true
        )
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ controller: UIDocumentPickerViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onFinish: (Result<Data, Error>?) -> Void
        private var finished = false

        init(onFinish: @escaping (Result<Data, Error>?) -> Void) {
            self.onFinish = onFinish
        }

        private func finish(_ result: Result<Data, Error>?) {
            guard !finished else { return }
            finished = true
            onFinish(result)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            finish(nil)
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            guard let url = urls.first else {
                finish(nil)
                return
            }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }

            var coordinationError: NSError?
            var readResult: Result<Data, Error>?
            NSFileCoordinator().coordinate(
                readingItemAt: url,
                options: [],
                error: &coordinationError
            ) { localURL in
                readResult = Result { try Data(contentsOf: localURL) }
            }
            if let error = coordinationError {
                finish(.failure(error))
            } else if let result = readResult {
                finish(result)
            } else {
                finish(.failure(CocoaError(.fileReadUnknown)))
            }
        }
    }
}
