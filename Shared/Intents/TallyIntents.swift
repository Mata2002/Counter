import AppIntents
import Foundation

/// A tally as Shortcuts, widgets and controls see it.
struct TallyEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tally"
    static var defaultQuery = TallyEntityQuery()

    var id: UUID
    var name: String
    var emoji: String

    init(id: UUID, name: String, emoji: String) {
        self.id = id
        self.name = name
        self.emoji = emoji
    }

    init(_ tally: Tally) {
        self.init(id: tally.id, name: tally.displayName, emoji: tally.emoji)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji.isEmpty ? "" : emoji + " ")\(name)")
    }
}

struct TallyEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [TallyEntity] {
        let data = TallyFileStore.load()
        return identifiers.compactMap { id in data.tally(id).map(TallyEntity.init) }
    }

    func suggestedEntities() async throws -> [TallyEntity] {
        TallyFileStore.load().tallies
            .filter { $0.isActive && !$0.hidden }
            .sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
            .map(TallyEntity.init)
    }

    func defaultResult() async -> TallyEntity? {
        try? await suggestedEntities().first
    }
}

/// Counts a tally once: up for a count-up tally, down for a countdown. "Take one back" reverses it.
struct CountTallyIntent: AppIntent {
    static var title: LocalizedStringResource = "Count a Tally"
    static var description = IntentDescription("Counts a tally by its step. A countdown goes down; a count-up goes up.")

    @Parameter(title: "Tally")
    var tally: TallyEntity

    @Parameter(title: "Take one back", default: false)
    var reverse: Bool

    init() {}

    init(tallyID: UUID, reverse: Bool) {
        self.tally = TallyEntity(id: tallyID, name: "", emoji: "")
        self.reverse = reverse
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Count \(\.$tally)") {
            \.$reverse
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        guard let outcome = TallyCounter.count(tally.id, reverse: reverse) else {
            return .result(value: 0, dialog: "That tally is gone.")
        }
        let t = outcome.tally
        if outcome.reachedGoal {
            return .result(value: t.value, dialog: "Tallyho! \(t.displayName) reached \(t.value).")
        }
        let tail = t.remaining.map { $0 == 0 ? "Goal reached." : "\($0) to go." } ?? ""
        return .result(value: t.value, dialog: "\(t.displayName): \(t.value). \(tail)")
    }
}

/// Picks which tally a widget shows.
struct TallyWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose a Tally"
    static var description = IntentDescription("Pick the tally this widget counts.")

    @Parameter(title: "Tally")
    var tally: TallyEntity?

    init() {}
    init(tally: TallyEntity?) { self.tally = tally }
}

/// Picks which tally a Control Center control counts.
@available(iOS 18.0, *)
struct TallyControlConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Choose a Tally"

    @Parameter(title: "Tally")
    var tally: TallyEntity?

    init() {}
}
