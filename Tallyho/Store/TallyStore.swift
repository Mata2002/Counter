import Foundation
import Observation
import SwiftUI

/// Sort orders for the home list.
enum TallySort: String, CaseIterable, Identifiable {
    case lastUsed, closest, farthest, name, newest, oldest, highest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lastUsed: return "Last used"
        case .closest: return "Closest to goal"
        case .farthest: return "Farthest from goal"
        case .name: return "Name"
        case .newest: return "Newest first"
        case .oldest: return "Oldest first"
        case .highest: return "Highest count"
        }
    }
    var symbol: String {
        switch self {
        case .lastUsed: return "clock.arrow.circlepath"
        case .closest: return "scope"
        case .farthest: return "arrow.up.right.and.arrow.down.left"
        case .name: return "textformat"
        case .newest: return "sparkles"
        case .oldest: return "hourglass"
        case .highest: return "number"
        }
    }
}

/// Sort orders for finished tallies.
enum FinishedSort: String, CaseIterable, Identifiable {
    case recent, oldest, name, count, longest, fastest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .recent: return "Recently finished"
        case .oldest: return "First finished"
        case .name: return "Name"
        case .count: return "Final count"
        case .longest: return "Took longest"
        case .fastest: return "Took shortest"
        }
    }
}

/// The app's source of truth. Every change is saved, pushed to widgets, and sent to the watch.
@MainActor
@Observable
final class TallyStore {
    static let shared = TallyStore()

    private(set) var data: TallyData
    /// A short message with an undo button after something disruptive.
    private(set) var undoMessage: String?
    @ObservationIgnored private var undoSnapshot: TallyData?
    @ObservationIgnored var onChange: (() -> Void)?

    private init() {
        data = TallyFileStore.load()
    }

    // MARK: Loading

    /// Picks up changes made by widgets, controls or Shortcuts.
    func reload() {
        let fresh = TallyFileStore.load()
        if fresh != data { data = fresh }
    }

    func replaceAll(with newData: TallyData) {
        data = newData
        persist()
    }

    private func persist() {
        TallyFileStore.save(data)
        TallyFileStore.reloadWidgets()
        onChange?()
    }

    private func mutate(_ change: (inout TallyData) -> Void) {
        var copy = data
        change(&copy)
        data = copy
        persist()
    }

    private func mutateTally(_ id: UUID, _ change: (inout Tally) -> Void) {
        mutate { data in
            guard let index = data.tallies.firstIndex(where: { $0.id == id }) else { return }
            change(&data.tallies[index])
        }
    }

    private func rememberForUndo(_ message: String) {
        undoSnapshot = data
        undoMessage = message
    }

    func undo() {
        guard let snapshot = undoSnapshot else { return }
        data = snapshot
        persist()
        dismissUndo()
    }

    func dismissUndo() {
        undoSnapshot = nil
        undoMessage = nil
    }

    // MARK: Lookups

    func tally(_ id: UUID?) -> Tally? {
        guard let id else { return nil }
        return data.tally(id)
    }

    func folder(_ id: UUID?) -> TallyFolder? { data.folder(id) }

    var activeFolders: [TallyFolder] {
        data.folders.filter { !$0.archived }.sorted { $0.createdAt < $1.createdAt }
    }

    var allTags: [String] {
        Array(Set(data.tallies.flatMap(\.tags))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Active tallies that belong on the home list (a folder's archive state hides its tallies).
    func homeTallies(showHidden: Bool) -> [Tally] {
        data.tallies.filter { tally in
            guard tally.isActive else { return false }
            if let folder = data.folder(tally.folderID) {
                if folder.archived { return false }
                if folder.hidden && !showHidden { return false }
            }
            return showHidden || !tally.hidden
        }
    }

    var finishedTallies: [Tally] { data.tallies.filter(\.isFinished) }
    var archivedTallies: [Tally] { data.tallies.filter { $0.archived && !$0.isFinished } }
    var archivedFolders: [TallyFolder] { data.folders.filter(\.archived) }
    var hiddenTallies: [Tally] { data.tallies.filter { $0.hidden && $0.isActive } }
    var hiddenFolders: [TallyFolder] { data.folders.filter { $0.hidden && !$0.archived } }

    /// The most recent finished tally from a folder, offered as "start again".
    func lastFinished(in folderID: UUID?) -> Tally? {
        data.tallies
            .filter { $0.isFinished && $0.folderID == folderID }
            .max { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
    }

    /// Recent finished setups for the "again?" chips in the editor (one per name).
    var recentTemplates: [Tally] {
        var seen = Set<String>()
        return data.tallies
            .filter(\.isFinished)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .filter { seen.insert($0.displayName.lowercased()).inserted }
            .prefix(8)
            .map { $0 }
    }

    func sorted(_ tallies: [Tally], by sort: TallySort) -> [Tally] {
        tallies.sorted { a, b in
            switch sort {
            case .lastUsed:
                return (a.lastUsedAt ?? a.createdAt) > (b.lastUsedAt ?? b.createdAt)
            case .closest, .farthest:
                // Tallies without a goal always sort last.
                let pa = a.hasGoal ? a.progress : -1
                let pb = b.hasGoal ? b.progress : -1
                if (pa < 0) != (pb < 0) { return pa >= 0 }
                if pa != pb { return sort == .closest ? pa > pb : pa < pb }
                return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
            case .name:
                return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
            case .newest:
                return a.createdAt > b.createdAt
            case .oldest:
                return a.createdAt < b.createdAt
            case .highest:
                return a.value > b.value
            }
        }
    }

    func sortedFinished(_ tallies: [Tally], by sort: FinishedSort) -> [Tally] {
        tallies.sorted { a, b in
            switch sort {
            case .recent: return (a.completedAt ?? .distantPast) > (b.completedAt ?? .distantPast)
            case .oldest: return (a.completedAt ?? .distantPast) < (b.completedAt ?? .distantPast)
            case .name: return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
            case .count: return a.value > b.value
            case .longest: return (a.duration ?? 0) > (b.duration ?? 0)
            case .fastest: return (a.duration ?? 0) < (b.duration ?? 0)
            }
        }
    }

    // MARK: Counting

    /// Counts once. Returns true when this tap reached the goal.
    @discardableResult
    func count(_ id: UUID, reverse: Bool = false) -> Bool {
        var reached = false
        mutateTally(id) { tally in
            reached = tally.apply(reverse ? tally.secondaryDelta : tally.primaryDelta)
        }
        return reached
    }

    /// Applies a raw delta (from the watch's crown, for example).
    @discardableResult
    func adjust(_ id: UUID, by delta: Int) -> Bool {
        guard delta != 0 else { return false }
        var reached = false
        mutateTally(id) { tally in reached = tally.apply(delta) }
        return reached
    }

    func reset(_ id: UUID) {
        guard let tally = tally(id) else { return }
        rememberForUndo("Reset “\(tally.displayName)”")
        mutateTally(id) { $0.reset() }
    }

    // MARK: Tallies

    func save(_ tally: Tally) {
        mutate { data in
            if let index = data.tallies.firstIndex(where: { $0.id == tally.id }) {
                data.tallies[index] = tally
            } else {
                data.tallies.append(tally)
            }
        }
    }

    func delete(_ id: UUID) {
        guard let tally = tally(id) else { return }
        rememberForUndo("Deleted “\(tally.displayName)”")
        mutate { $0.tallies.removeAll { $0.id == id } }
    }

    func complete(_ id: UUID) {
        guard let tally = tally(id) else { return }
        rememberForUndo("Finished “\(tally.displayName)”")
        let folderName = folder(tally.folderID)?.displayName
        mutateTally(id) { t in
            t.completedAt = Date()
            t.folderNameSnapshot = folderName
            if t.goalReachedAt == nil && t.isGoalReached { t.goalReachedAt = Date() }
        }
    }

    /// Brings a finished tally back to the home list.
    func reopen(_ id: UUID) {
        mutateTally(id) { t in
            t.completedAt = nil
            t.archived = false
            if let folderID = t.folderID, self.data.folder(folderID) == nil { t.folderID = nil }
        }
    }

    func setArchived(_ id: UUID, _ archived: Bool) {
        if archived, let tally = tally(id) { rememberForUndo("Archived “\(tally.displayName)”") }
        mutateTally(id) { $0.archived = archived }
    }

    func setHidden(_ id: UUID, _ hidden: Bool) {
        if hidden, let tally = tally(id) { rememberForUndo("Hid “\(tally.displayName)”") }
        mutateTally(id) { $0.hidden = hidden }
    }

    func move(_ id: UUID, to folderID: UUID?) {
        mutateTally(id) { $0.folderID = folderID }
    }

    @discardableResult
    func duplicate(_ id: UUID) -> Tally? {
        guard let original = tally(id) else { return nil }
        var copy = original.makeAgain(in: original.folderID)
        copy.name = original.displayName + " copy"
        save(copy)
        return copy
    }

    /// Starts a new tally from a finished one, in the same folder if it still exists.
    @discardableResult
    func startAgain(from id: UUID) -> Tally? {
        guard let original = tally(id) else { return nil }
        let folderID = folder(original.folderID).map(\.id) ?? folderNamed(original.folderNameSnapshot)?.id
        let fresh = original.makeAgain(in: folderID)
        save(fresh)
        return fresh
    }

    private func folderNamed(_ name: String?) -> TallyFolder? {
        guard let name else { return nil }
        return data.folders.first { !$0.archived && $0.displayName.caseInsensitiveCompare(name) == .orderedSame }
    }

    // MARK: Folders

    func save(_ folder: TallyFolder) {
        mutate { data in
            if let index = data.folders.firstIndex(where: { $0.id == folder.id }) {
                data.folders[index] = folder
            } else {
                data.folders.append(folder)
            }
        }
    }

    func toggleCollapsed(_ id: UUID) {
        mutate { data in
            guard let index = data.folders.firstIndex(where: { $0.id == id }) else { return }
            data.folders[index].collapsed.toggle()
        }
    }

    /// Archiving a folder archives it with everything inside; unarchiving brings them all back.
    func setFolderArchived(_ id: UUID, _ archived: Bool) {
        guard let folder = folder(id) else { return }
        if archived { rememberForUndo("Archived “\(folder.displayName)”") }
        mutate { data in
            guard let index = data.folders.firstIndex(where: { $0.id == id }) else { return }
            data.folders[index].archived = archived
            for i in data.tallies.indices where data.tallies[i].folderID == id && !data.tallies[i].isFinished {
                data.tallies[i].archived = archived
            }
        }
    }

    func setFolderHidden(_ id: UUID, _ hidden: Bool) {
        guard let folder = folder(id) else { return }
        if hidden { rememberForUndo("Hid “\(folder.displayName)”") }
        mutate { data in
            guard let index = data.folders.firstIndex(where: { $0.id == id }) else { return }
            data.folders[index].hidden = hidden
        }
    }

    /// Deletes a folder. Its tallies either move out of the folder or are deleted too.
    func deleteFolder(_ id: UUID, keepTallies: Bool) {
        guard let folder = folder(id) else { return }
        rememberForUndo("Deleted “\(folder.displayName)”")
        mutate { data in
            data.folders.removeAll { $0.id == id }
            if keepTallies {
                for i in data.tallies.indices where data.tallies[i].folderID == id {
                    if data.tallies[i].isFinished {
                        data.tallies[i].folderNameSnapshot = data.tallies[i].folderNameSnapshot ?? folder.displayName
                    } else {
                        data.tallies[i].folderID = nil
                        data.tallies[i].archived = false
                    }
                }
            } else {
                data.tallies.removeAll { $0.folderID == id && !$0.isFinished }
            }
        }
    }

    func eraseEverything() {
        rememberForUndo("Erased everything")
        replaceAll(with: TallyData())
    }
}
