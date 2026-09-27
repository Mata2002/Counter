import AppIntents
import SwiftUI
import WidgetKit

@main
struct TallyhoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TallyWidget()
        TallyCountControl()
    }
}

// MARK: - Timeline

struct TallyEntry: TimelineEntry {
    let date: Date
    let tally: Tally?
    let theme: TallyTheme
    let appearance: ThemeAppearance
}

struct TallyProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TallyEntry {
        TallyEntry(date: Date(), tally: Self.sample, theme: currentTheme(), appearance: currentAppearance())
    }

    func snapshot(for configuration: TallyWidgetConfiguration, in context: Context) async -> TallyEntry {
        let entry = makeEntry(for: configuration)
        return entry.tally == nil && context.isPreview
            ? TallyEntry(date: Date(), tally: Self.sample, theme: entry.theme, appearance: entry.appearance)
            : entry
    }

    func timeline(for configuration: TallyWidgetConfiguration, in context: Context) async -> Timeline<TallyEntry> {
        // Counts only change when someone taps, and every tap reloads the widget, so no schedule is needed.
        Timeline(entries: [makeEntry(for: configuration)], policy: .never)
    }

    private func makeEntry(for configuration: TallyWidgetConfiguration) -> TallyEntry {
        let data = TallyFileStore.load()
        let chosen = configuration.tally.flatMap { data.tally($0.id) }
        let fallback = data.tallies
            .filter { $0.isActive && !$0.hidden }
            .max { ($0.lastUsedAt ?? $0.createdAt) < ($1.lastUsedAt ?? $1.createdAt) }
        return TallyEntry(date: Date(), tally: chosen ?? fallback, theme: currentTheme(), appearance: currentAppearance())
    }

    private func currentTheme() -> TallyTheme {
        TallyTheme.named(TallyFileStore.sharedDefaults.string(forKey: "theme.active")) ?? .fallback
    }

    private func currentAppearance() -> ThemeAppearance {
        ThemeAppearance(rawValue: TallyFileStore.sharedDefaults.string(forKey: ThemeAppearance.storageKey) ?? "") ?? .system
    }

    static var sample: Tally {
        var t = Tally(name: "Push-ups", emoji: "💪", colorIndex: 0, start: 20, target: 70, step: 5)
        t.value = 45
        return t
    }
}

// MARK: - Widget

struct TallyWidget: Widget {
    let kind = "MMT.Tallyho.Tally"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TallyWidgetConfiguration.self, provider: TallyProvider()) { entry in
            TallyWidgetView(entry: entry)
        }
        .configurationDisplayName("Tally")
        .description("Count a tally without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

struct TallyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var deviceScheme
    let entry: TallyEntry

    var body: some View {
        // The container background doesn't inherit environment values, so it gets the theme passed in directly.
        let theme = entry.theme.resolved(entry.appearance.colorScheme ?? deviceScheme)
        Group {
            if let tally = entry.tally {
                switch family {
                case .systemSmall: WidgetSmallTally(tally: tally)
                case .systemMedium: WidgetMediumTally(tally: tally)
                case .accessoryCircular: CircularTally(tally: tally)
                case .accessoryRectangular: RectangularTally(tally: tally)
                case .accessoryInline: Text("\(tally.emoji) \(tally.displayName) \(tally.value)\(tally.target.map { "/\($0)" } ?? "")")
                default: WidgetSmallTally(tally: tally)
                }
            } else {
                EmptyTally()
            }
        }
        .environment(\.theme, theme)
        .widgetURL(entry.tally.map { URL(string: "tallyho://tally/\($0.id.uuidString)")! } ?? URL(string: "tallyho://new"))
        .containerBackground(for: .widget) {
            if let tally = entry.tally, family == .systemSmall || family == .systemMedium {
                WidgetStage(tally: tally, theme: theme)
            } else {
                theme.backgroundColor
            }
        }
    }
}

private struct CircularTally: View {
    let tally: Tally
    var body: some View {
        if tally.hasGoal {
            Gauge(value: tally.progress) {
                Text(tally.emoji)
            } currentValueLabel: {
                Text("\(tally.value)").minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircular)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(tally.emoji).font(.caption2)
                    Text("\(tally.value)").font(.headline).minimumScaleFactor(0.5)
                }
            }
        }
    }
}

private struct RectangularTally: View {
    let tally: Tally
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(tally.emoji) \(tally.displayName)")
                .font(.headline)
                .lineLimit(1)
            Text("\(tally.value)\(tally.goalText.map { " \($0)" } ?? "") · \(tally.statusText)")
                .font(.caption)
                .lineLimit(1)
            if tally.hasGoal {
                Gauge(value: tally.progress) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EmptyTally: View {
    @Environment(\.theme) private var theme
    @Environment(\.widgetFamily) private var family
    var body: some View {
        if family == .accessoryInline {
            Text("Add a tally")
        } else {
            VStack(spacing: 6) {
                TallyMarks(total: 5, filled: 4, color: theme.actionColor, empty: theme.text2Color.opacity(0.4), lineWidth: 3)
                    .frame(width: 48, height: 28)
                Text("Add a tally in Tallyho")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textColor)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

// MARK: - Control Center

struct TallyControlValue {
    let id: UUID?
    let title: String
}

@available(iOS 18.0, *)
struct TallyControlProvider: AppIntentControlValueProvider {
    func previewValue(configuration: TallyControlConfiguration) -> TallyControlValue {
        TallyControlValue(id: nil, title: configuration.tally?.name ?? "Count a Tally")
    }

    func currentValue(configuration: TallyControlConfiguration) async throws -> TallyControlValue {
        let data = TallyFileStore.load()
        let tally = configuration.tally.flatMap { data.tally($0.id) }
            ?? data.tallies.filter { $0.isActive && !$0.hidden }
                .max { ($0.lastUsedAt ?? $0.createdAt) < ($1.lastUsedAt ?? $1.createdAt) }
        guard let tally else { return TallyControlValue(id: nil, title: "No tallies yet") }
        let target = tally.target.map { "/\($0)" } ?? ""
        return TallyControlValue(id: tally.id, title: "\(tally.emoji) \(tally.displayName) \(tally.value)\(target)")
    }
}

@available(iOS 18.0, *)
struct TallyCountControl: ControlWidget {
    static let kind = "MMT.Tallyho.CountControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind, provider: TallyControlProvider()) { value in
            ControlWidgetButton(action: CountTallyIntent(tallyID: value.id ?? UUID(), reverse: false)) {
                Label(value.title, systemImage: "plus.circle.fill")
            }
        }
        .displayName("Count a Tally")
        .description("Counts your chosen tally once. Put it in Control Center or on the Action button.")
    }
}
