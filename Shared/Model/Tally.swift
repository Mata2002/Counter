import Foundation

/// Which way a tally moves when you tap it.
enum CountDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case up
    case down

    var id: String { rawValue }
    var title: String { self == .up ? "Count up" : "Count down" }
    var shortTitle: String { self == .up ? "Up" : "Down" }
    var symbol: String { self == .up ? "arrow.up" : "arrow.down" }
}

/// One counter. A tally counts from `start` toward an optional `target`, `step` at a time.
struct Tally: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var emoji: String
    var colorIndex: Int
    var tags: [String]
    var folderID: UUID?
    var direction: CountDirection
    var start: Int
    var target: Int?
    /// Amount the main tap moves the tally (always positive; direction decides the sign).
    var step: Int
    /// Amount the secondary button moves it back.
    var undoStep: Int
    var value: Int
    var notifyAtGoal: Bool
    var hidden: Bool
    var archived: Bool
    var notes: String
    var createdAt: Date
    var lastUsedAt: Date?
    var firstCountAt: Date?
    var goalReachedAt: Date?
    var completedAt: Date?
    /// The folder's name when the tally was finished, so Finished can group it even if the folder is gone.
    var folderNameSnapshot: String?
    var taps: Int

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "",
        colorIndex: Int = 0,
        tags: [String] = [],
        folderID: UUID? = nil,
        direction: CountDirection = .up,
        start: Int = 0,
        target: Int? = nil,
        step: Int = 1,
        undoStep: Int = 1,
        notifyAtGoal: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorIndex = colorIndex
        self.tags = tags
        self.folderID = folderID
        self.direction = direction
        self.start = start
        self.target = target
        self.step = max(1, step)
        self.undoStep = max(1, undoStep)
        self.value = start
        self.notifyAtGoal = notifyAtGoal
        self.hidden = false
        self.archived = false
        self.notes = ""
        self.createdAt = createdAt
        self.lastUsedAt = nil
        self.firstCountAt = nil
        self.goalReachedAt = nil
        self.completedAt = nil
        self.folderNameSnapshot = nil
        self.taps = 0
    }

    // Tolerant decoding: new fields in future versions never break old files.
    enum CodingKeys: String, CodingKey {
        case id, name, emoji, colorIndex, tags, folderID, direction, start, target, step, undoStep, value
        case notifyAtGoal, hidden, archived, notes, createdAt, lastUsedAt, firstCountAt, goalReachedAt
        case completedAt, folderNameSnapshot, taps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Tally"
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? ""
        colorIndex = try c.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        folderID = try c.decodeIfPresent(UUID.self, forKey: .folderID)
        direction = try c.decodeIfPresent(CountDirection.self, forKey: .direction) ?? .up
        start = try c.decodeIfPresent(Int.self, forKey: .start) ?? 0
        target = try c.decodeIfPresent(Int.self, forKey: .target)
        step = max(1, try c.decodeIfPresent(Int.self, forKey: .step) ?? 1)
        undoStep = max(1, try c.decodeIfPresent(Int.self, forKey: .undoStep) ?? 1)
        value = try c.decodeIfPresent(Int.self, forKey: .value) ?? start
        notifyAtGoal = try c.decodeIfPresent(Bool.self, forKey: .notifyAtGoal) ?? true
        hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        lastUsedAt = try c.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        firstCountAt = try c.decodeIfPresent(Date.self, forKey: .firstCountAt)
        goalReachedAt = try c.decodeIfPresent(Date.self, forKey: .goalReachedAt)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        folderNameSnapshot = try c.decodeIfPresent(String.self, forKey: .folderNameSnapshot)
        taps = try c.decodeIfPresent(Int.self, forKey: .taps) ?? 0
    }
}

// MARK: - Counting rules

extension Tally {
    var hasGoal: Bool { target != nil }
    var isFinished: Bool { completedAt != nil }
    /// Counting now: not finished and not archived.
    var isActive: Bool { completedAt == nil && !archived }

    /// Signed change for the main tap.
    var primaryDelta: Int { direction == .up ? step : -step }
    /// Signed change for the secondary ("take one back") button.
    var secondaryDelta: Int { direction == .up ? -undoStep : undoStep }

    var isGoalReached: Bool {
        guard let target else { return false }
        return direction == .up ? value >= target : value <= target
    }

    /// 0...1 progress from start toward the goal.
    var progress: Double {
        guard let target, target != start else { return isGoalReached ? 1 : 0 }
        let p = Double(value - start) / Double(target - start)
        return min(max(p, 0), 1)
    }

    /// How full the counting stage is: rises as you count up, drains as you count down.
    var fillLevel: Double {
        guard hasGoal else { return 1 }
        return direction == .up ? progress : 1 - progress
    }

    /// Steps still needed to reach the goal (0 when reached).
    var remaining: Int? {
        guard let target else { return nil }
        return direction == .up ? max(0, target - value) : max(0, value - target)
    }

    var displayName: String { name.isEmpty ? "Untitled" : name }
    var emojiOrInitial: String {
        if !emoji.isEmpty { return emoji }
        return name.first.map { String($0).uppercased() } ?? "#"
    }

    /// "20 → 70", "70 → 0", or "from 20".
    var rangeText: String {
        guard let target else { return start == 0 ? "No goal" : "From \(start)" }
        return "\(start) → \(target)"
    }

    /// "38 to go", "Goal reached", or "32 counted".
    var statusText: String {
        if let remaining {
            return remaining == 0 ? "Goal reached" : "\(remaining) to go"
        }
        let counted = abs(value - start)
        return "\(counted) counted"
    }

    /// Applies a signed change. Returns true when this change crossed the goal.
    @discardableResult
    mutating func apply(_ delta: Int, at date: Date = Date()) -> Bool {
        let wasReached = isGoalReached
        value += delta
        taps += 1
        lastUsedAt = date
        if firstCountAt == nil { firstCountAt = date }
        let nowReached = isGoalReached
        if nowReached && !wasReached {
            goalReachedAt = date
            return true
        }
        if !nowReached { goalReachedAt = nil }
        return false
    }

    mutating func reset() {
        value = start
        goalReachedAt = nil
        lastUsedAt = Date()
    }

    /// A fresh copy of this tally's setup, ready to count again.
    func makeAgain(in folderID: UUID?) -> Tally {
        var copy = Tally(
            name: name, emoji: emoji, colorIndex: colorIndex, tags: tags, folderID: folderID,
            direction: direction, start: start, target: target, step: step, undoStep: undoStep,
            notifyAtGoal: notifyAtGoal
        )
        copy.notes = notes
        return copy
    }

    /// How long a finished tally took, from creation (or first count) to finish.
    var duration: TimeInterval? {
        guard let completedAt else { return nil }
        return completedAt.timeIntervalSince(firstCountAt ?? createdAt)
    }
}

/// A folder groups tallies. Archiving or hiding a folder applies to everything inside it.
struct TallyFolder: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var emoji: String
    var colorIndex: Int
    var hidden: Bool
    var archived: Bool
    var collapsed: Bool
    var createdAt: Date

    init(id: UUID = UUID(), name: String, emoji: String = "", colorIndex: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorIndex = colorIndex
        self.hidden = false
        self.archived = false
        self.collapsed = false
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, colorIndex, hidden, archived, collapsed, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Folder"
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? ""
        colorIndex = try c.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
        hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        collapsed = try c.decodeIfPresent(Bool.self, forKey: .collapsed) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    var displayName: String { name.isEmpty ? "Untitled folder" : name }
}

/// Everything the app stores.
struct TallyData: Codable, Equatable, Sendable {
    var version: Int
    var tallies: [Tally]
    var folders: [TallyFolder]

    init(version: Int = 1, tallies: [Tally] = [], folders: [TallyFolder] = []) {
        self.version = version
        self.tallies = tallies
        self.folders = folders
    }

    enum CodingKeys: String, CodingKey { case version, tallies, folders }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        tallies = try c.decodeIfPresent([Tally].self, forKey: .tallies) ?? []
        folders = try c.decodeIfPresent([TallyFolder].self, forKey: .folders) ?? []
    }

    func folder(_ id: UUID?) -> TallyFolder? {
        guard let id else { return nil }
        return folders.first { $0.id == id }
    }

    func tally(_ id: UUID) -> Tally? {
        tallies.first { $0.id == id }
    }
}
