import Foundation

/// What the iPhone sends the watch: the active tallies and the current theme.
struct WatchSnapshot: Codable, Equatable, Sendable {
    var themeID: String
    var tallies: [WatchTally]
    var sentAt: Date

    static let contextKey = "snapshot"
    /// Watch → iPhone message keys.
    static let countKey = "count"
    static let reverseKey = "reverse"
    static let completeKey = "complete"
    static let requestKey = "requestSnapshot"
}

/// A tally as the watch needs it.
struct WatchTally: Codable, Equatable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var emoji: String
    var colorIndex: Int
    var folderName: String?
    var direction: CountDirection
    var start: Int
    var target: Int?
    var step: Int
    var undoStep: Int
    var value: Int

    init(_ tally: Tally, folderName: String?) {
        id = tally.id
        name = tally.displayName
        emoji = tally.emoji
        colorIndex = tally.colorIndex
        self.folderName = folderName
        direction = tally.direction
        start = tally.start
        target = tally.target
        step = tally.step
        undoStep = tally.undoStep
        value = tally.value
    }

    /// Reuses the iPhone's counting rules so the watch behaves identically.
    var asTally: Tally {
        var t = Tally(id: id, name: name, emoji: emoji, colorIndex: colorIndex, direction: direction,
                      start: start, target: target, step: step, undoStep: undoStep)
        t.value = value
        return t
    }
}
