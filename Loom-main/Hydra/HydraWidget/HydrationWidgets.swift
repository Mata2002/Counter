import AppIntents
import SwiftUI
import WidgetKit

struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Add water"
    static var description = IntentDescription("Adds water without opening the app.")
    static var openAppWhenRun = false

    @Parameter(title: "Amount") var amount: Int

    init() { amount = 250 }
    init(amount: Int) { self.amount = amount }

    func perform() async throws -> some IntentResult {
        var snapshot = HydrationStorage.load()
        snapshot.entries.append(
            HydrationEntry(amountML: amount,
                           drink: .water,
                           vessel: amount >= 450 ? .bottle : .glass)
        )
        snapshot.lastModified = Date()
        for achievement in HydrationAchievement.allCases where achievement.isEarned(in: snapshot) {
            snapshot.unlockedAchievementIDs.insert(achievement.id)
        }
        HydrationStorage.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct HydrationWidgetEntry: TimelineEntry {
    let date: Date
    let currentML: Int
    let goalML: Int
    let caffeineMG: Int
    let pours: Int
    let streak: Int
    var themeID = "ocean"
    var ounces = false

    var waterProgress: Double { min(Double(currentML) / Double(max(goalML, 1)), 1) }
}

struct HydrationProvider: TimelineProvider {
    func placeholder(in context: Context) -> HydrationWidgetEntry {
        HydrationWidgetEntry(date: .now,
                             currentML: 1_250,
                             goalML: 2_000,
                             caffeineMG: 120,
                             pours: 4,
                             streak: 6)
    }

    func getSnapshot(in context: Context, completion: @escaping (HydrationWidgetEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HydrationWidgetEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3_600)
        completion(Timeline(entries: [entry()], policy: .after(midnight)))
    }

    private func entry() -> HydrationWidgetEntry {
        let snapshot = HydrationStorage.load()
        let today = HydrationMath.entries(on: .now, from: snapshot.entries)
        return HydrationWidgetEntry(
            date: .now,
            currentML: today.reduce(0) { $0 + $1.hydratedML },
            goalML: snapshot.settings.dailyGoalML,
            caffeineMG: today.reduce(0) { $0 + $1.caffeineMG },
            pours: today.count,
            streak: HydrationMath.streak(snapshot: snapshot),
            themeID: snapshot.settings.activeThemeID,
            ounces: snapshot.settings.unitIsOunces
        )
    }
}

struct HydrationWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HydrationWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.waterProgress) {
                Image(systemName: "drop.fill")
            } currentValueLabel: {
                Text("\(Int(entry.waterProgress * 100))")
            }
            .gaugeStyle(.accessoryCircularCapacity)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Label("Water", systemImage: "drop.fill")
                    Spacer()
                    Text("\(Int(entry.waterProgress * 100))%")
                }
                .font(.headline)
                ProgressView(value: entry.waterProgress)
                Text("\(entry.currentML.hydrationAmount(ounces: entry.ounces)) of \(entry.goalML.hydrationAmount(ounces: entry.ounces))")
                    .font(.caption2)
            }

        case .systemMedium:
            medium

        default:
            small
        }
    }

    private var small: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Today").font(.caption.bold())
                Spacer()
                Label("\(entry.streak)", systemImage: "flame.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.72))
            }
            WidgetVessel(entry: entry)
                .frame(width: 72, height: 72)
            WidgetAddButton(amount: 250, title: "+" + 250.hydrationAmount(ounces: entry.ounces))
        }
        .foregroundStyle(.white)
    }

    private var medium: some View {
        HStack(spacing: 20) {
            WidgetVessel(entry: entry)
                .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Today")
                        .font(.headline.bold())
                    Spacer()
                    Image(systemName: "drop.fill")
                        .foregroundStyle(CompanionPalette(id: entry.themeID).top)
                }
                Text("\(entry.currentML.hydrationAmount(ounces: entry.ounces)) of \(entry.goalML.hydrationAmount(ounces: entry.ounces))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))

                HStack(spacing: 12) {
                    Label("\(entry.caffeineMG) mg", systemImage: "bolt.fill")
                        .foregroundStyle(.white.opacity(0.8))
                    Label("\(entry.pours) drinks", systemImage: "circle.grid.2x2.fill")
                        .foregroundStyle(.white.opacity(0.8))
                }
                .font(.caption2.bold())

                HStack(spacing: 8) {
                    WidgetAddButton(amount: 250, title: "+" + 250.hydrationAmount(ounces: entry.ounces))
                    WidgetAddButton(amount: 500, title: "+" + 500.hydrationAmount(ounces: entry.ounces))
                }
            }
            .foregroundStyle(.white)
        }
    }
}

private struct WidgetVessel: View {
    let entry: HydrationWidgetEntry
    var body: some View {
        let palette = CompanionPalette(id: entry.themeID)
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(.white.opacity(0.07))
                CompanionWave(progress: entry.waterProgress)
                    .fill(LinearGradient(colors: [palette.top, palette.bottom], startPoint: .top, endPoint: .bottom)).clipShape(Circle())
                Circle().strokeBorder(.white.opacity(entry.waterProgress >= 1 ? 0.9 : 0.25), lineWidth: 1.5)
                VStack(spacing: 2) {
                    Image(systemName: entry.waterProgress >= 1 ? "checkmark" : "drop.fill").font(.system(size: size * 0.15))
                    Text("\(Int(entry.waterProgress * 100))%").font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                }.foregroundStyle(.white).shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            }.frame(width: size, height: size).frame(width: proxy.size.width, height: proxy.size.height)
        }.accessibilityLabel("Hydration \(Int(entry.waterProgress * 100)) percent")
    }
}

private struct WidgetAddButton: View {
    let amount: Int
    let title: String

    var body: some View {
        Button(intent: AddWaterIntent(amount: amount)) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.white.opacity(0.13), in: Capsule())
                .overlay { Capsule().stroke(.white.opacity(0.14), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}

struct HydrationWidget: Widget {
    let kind = "HydrationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HydrationProvider()) { entry in
            HydrationWidgetView(entry: entry)
                .environment(\.colorScheme, .dark)
                .containerBackground(for: .widget) {
                    ZStack {
                        LinearGradient(
                            colors: [
                                CompanionPalette(id: entry.themeID).background,
                                CompanionPalette(id: entry.themeID).bottom.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Circle()
                            .fill(CompanionPalette(id: entry.themeID).top.opacity(0.12))
                            .frame(width: 180)
                            .blur(radius: 26)
                            .offset(x: 100, y: -70)
                    }
                }
        }
        .configurationDisplayName("Hydra")
        .description("Water, caffeine, pours, and quick logging.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct HydrationWidgetBundle: WidgetBundle {
    var body: some Widget {
        HydrationWidget()
    }
}

private struct CompanionWave: Shape {
    var progress: Double
    var animatableData: Double { get { progress } set { progress = newValue } }
    func path(in rect: CGRect) -> Path {
        let fill = min(max(progress, 0), 1)
        let y = rect.height * (1 - fill)
        let a = 4 * min(fill * 12, (1 - fill) * 12, 1)
        var p = Path()
        p.move(to: CGPoint(x: 0, y: y))
        p.addCurve(to: CGPoint(x: rect.width, y: y), control1: CGPoint(x: rect.width * 0.33, y: y - a), control2: CGPoint(x: rect.width * 0.66, y: y + a))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath(); return p
    }
}

private struct CompanionPalette {
    let id: String
    var hue: Double {
        switch id {
        case "sunrise": 0.025
        case "citrus": 0.12
        case "midnight": 0.64
        case "amethyst": 0.76
        case "coffee", "halloween": 0.075
        case "christmas": 0.4
        default: 0.55
        }
    }
    var top: Color { Color(hue: hue, saturation: 0.65, brightness: 0.95) }
    var bottom: Color { Color(hue: hue + 0.04, saturation: 0.8, brightness: 0.56) }
    var background: Color { Color(hue: hue, saturation: 0.5, brightness: 0.12) }
}
