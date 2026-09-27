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
}

struct TallyProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TallyEntry {
        TallyEntry(date: Date(), tally: Self.sample, theme: currentTheme())
    }

    func snapshot(for configuration: TallyWidgetConfiguration, in context: Context) async -> TallyEntry {
        let entry = makeEntry(for: configuration)
        return entry.tally == nil && context.isPreview ? TallyEntry(date: Date(), tally: Self.sample, theme: entry.theme) : entry
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
        return TallyEntry(date: Date(), tally: chosen ?? fallback, theme: currentTheme())
    }

    private func currentTheme() -> TallyTheme {
        TallyTheme.named(TallyFileStore.sharedDefaults.string(forKey: "theme.active")) ?? .fallback
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
                .environment(\.theme, entry.theme)
        }
        .configurationDisplayName("Tally")
        .description("Count a tally without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

struct TallyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.theme) private var theme
    let entry: TallyEntry

    var body: some View {
        Group {
            if let tally = entry.tally {
                switch family {
                case .systemSmall: SmallTally(tally: tally)
                case .systemMedium: MediumTally(tally: tally)
                case .accessoryCircular: CircularTally(tally: tally)
                case .accessoryRectangular: RectangularTally(tally: tally)
                case .accessoryInline: Text("\(tally.emoji) \(tally.displayName) \(tally.value)\(tally.target.map { "/\($0)" } ?? "")")
                default: SmallTally(tally: tally)
                }
            } else {
                EmptyTally()
            }
        }
        .widgetURL(entry.tally.map { URL(string: "tallyho://tally/\($0.id.uuidString)")! } ?? URL(string: "tallyho://new"))
        .containerBackground(for: .widget) {
            if let tally = entry.tally, family == .systemSmall || family == .systemMedium {
                StaticStage(tally: tally)
            } else {
                theme.backgroundColor
            }
        }
    }
}

/// The stage, frozen: the unfilled color and the liquid at its current level.
private struct StaticStage: View {
    @Environment(\.theme) private var theme
    let tally: Tally
    var body: some View {
        ZStack {
            theme.tallyBase(tally.colorIndex)
            LiquidFill(level: tally.fillLevel, phase: 0, amplitude: 0)
                .fill(theme.tally(tally.colorIndex))
        }
    }
}

/// Text drawn in the right ink on both sides of the liquid line.
private struct InkText<Content: View>: View {
    @Environment(\.theme) private var theme
    let tally: Tally
    @ViewBuilder let content: (Color) -> Content

    var body: some View {
        ZStack {
            content(theme.onTallyBase(tally.colorIndex))
            content(theme.onTally(tally.colorIndex))
                .mask(LiquidFill(level: tally.fillLevel, phase: 0, amplitude: 0).ignoresSafeArea())
        }
    }
}

private struct CountButton: View {
    @Environment(\.theme) private var theme
    let tally: Tally
    let reverse: Bool
    let size: CGFloat

    var body: some View {
        let isPlus = (tally.direction == .up) != reverse
        Button(intent: CountTallyIntent(tallyID: tally.id, reverse: reverse)) {
            Image(systemName: isPlus ? "plus" : "minus")
                .font(.system(size: size * 0.42, weight: .heavy))
                .foregroundStyle(reverse ? theme.textColor : theme.onActionColor)
                .frame(width: size, height: size)
                .background(reverse ? theme.surfaceColor : theme.actionColor, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlus ? "Add \(reverse ? tally.undoStep : tally.step)" : "Take away \(reverse ? tally.undoStep : tally.step)")
    }
}

private struct SmallTally: View {
    @Environment(\.theme) private var theme
    let tally: Tally

    var body: some View {
        ZStack(alignment: .bottom) {
            InkText(tally: tally) { ink in
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(tally.emoji) \(tally.displayName)")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(tally.value)")
                        .font(theme.numeralFont(size: 46))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .contentTransition(.numericText(value: Double(tally.value)))
                    Text(tally.goalText ?? tally.statusText)
                        .font(.caption2.weight(.semibold))
                        .opacity(0.85)
                    Spacer(minLength: 46)
                }
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(14)
            }
            HStack {
                CountButton(tally: tally, reverse: true, size: 34)
                Spacer()
                CountButton(tally: tally, reverse: false, size: 44)
            }
            .padding(10)
        }
    }
}

private struct MediumTally: View {
    @Environment(\.theme) private var theme
    let tally: Tally

    var body: some View {
        HStack(spacing: 0) {
            InkText(tally: tally) { ink in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(tally.emoji) \(tally.displayName)")
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(tally.value)")
                            .font(theme.numeralFont(size: 58))
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .contentTransition(.numericText(value: Double(tally.value)))
                        if let target = tally.target {
                            Text("/ \(target)")
                                .font(theme.numeralFont(.title3, weight: .bold))
                                .opacity(0.8)
                        }
                    }
                    Text(tally.statusText)
                        .font(.caption.weight(.semibold))
                        .opacity(0.9)
                }
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(16)
            }
            VStack(spacing: 10) {
                CountButton(tally: tally, reverse: false, size: 64)
                CountButton(tally: tally, reverse: true, size: 40)
            }
            .padding(.trailing, 16)
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
            Text("\(tally.value)\(tally.target.map { " of \($0)" } ?? "") · \(tally.statusText)")
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
