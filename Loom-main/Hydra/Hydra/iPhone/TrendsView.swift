import Charts
import SwiftUI

struct DayHydration: Identifiable {
    let day: Date
    let value: Int
    let goal: Int
    var id: Date { day }
}

struct DrinkShare: Identifiable {
    let drink: DrinkKind
    let amount: Int
    var id: DrinkKind { drink }
}

struct TrendsView: View {
    @Environment(HydrationStore.self) private var store
    @State private var range = TrendRange.week

    private var days: [DayHydration] {
        let count = range == .week ? 7 : 30
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayHydration(day: day, value: HydrationMath.hydrated(on: day, from: store.snapshot.entries), goal: store.goalML)
        }
    }

    private var shares: [DrinkShare] {
        let allowed = Set(days.map { Calendar.current.startOfDay(for: $0.day) })
        let grouped = Dictionary(grouping: store.snapshot.entries.filter {
            allowed.contains(Calendar.current.startOfDay(for: $0.date))
        }, by: \.drink)
        return grouped.map { DrinkShare(drink: $0.key, amount: $0.value.reduce(0) { $0 + $1.amountML }) }
            .sorted { $0.amount > $1.amount }
    }

    private var average: Int { days.isEmpty ? 0 : days.reduce(0) { $0 + $1.value } / days.count }
    private var goalDays: Int { days.filter { $0.value >= $0.goal }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                AquaBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        Picker("Range", selection: $range) {
                            ForEach(TrendRange.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        HStack(spacing: 12) {
                            MetricCard(title: "Average", value: average.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces), symbol: "chart.bar.fill", color: store.activeTheme.control)
                            MetricCard(title: "Goal days", value: "\(goalDays)/\(days.count)", symbol: "checkmark.seal.fill", color: store.activeTheme.liquidTop)
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Hydration").font(.headline)
                                Chart {
                                    ForEach(days) { item in
                                    BarMark(
                                        x: .value("Day", item.day, unit: .day),
                                        y: .value("Hydration", item.value)
                                    )
                                    .foregroundStyle(item.value >= item.goal ? store.activeTheme.liquidTop.gradient : store.activeTheme.control.gradient)
                                    .cornerRadius(5)

                                }
                                    RuleMark(y: .value("Goal", store.goalML))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                        .foregroundStyle(store.activeTheme.secondary.opacity(0.55))
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading) { value in
                                        AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                                        AxisValueLabel {
                                            if let ml = value.as(Int.self) { Text(ml.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces)) }
                                        }
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 5)) {
                                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                                    }
                                }
                                .frame(height: 220)
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Drink mix").font(.headline)
                                if shares.isEmpty {
                                    Text("No drinks in this range").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 130)
                                } else {
                                    Chart(shares) { item in
                                        SectorMark(angle: .value("Amount", item.amount), innerRadius: .ratio(0.63), angularInset: 2)
                                            .cornerRadius(5)
                                            .foregroundStyle(store.activeTheme.drinkColor(item.drink))
                                    }
                                    .frame(height: 190)
                                    VStack(spacing: 10) {
                                        ForEach(shares.prefix(5)) { item in
                                            HStack {
                                                Circle().fill(store.activeTheme.drinkColor(item.drink)).frame(width: 9, height: 9)
                                                Text(item.drink.title).font(.subheadline)
                                                Spacer()
                                                Text(item.amount.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces)).font(.subheadline.bold())
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label("Caffeine", systemImage: "bolt.fill").font(.headline)
                                    Spacer()
                                    Text("\(rangeCaffeine) mg").font(.title3.bold())
                                }
                                Text("Average \(rangeCaffeine / max(days.count, 1)) mg per day")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var rangeCaffeine: Int {
        let allowed = Set(days.map { Calendar.current.startOfDay(for: $0.day) })
        return store.snapshot.entries.filter { allowed.contains(Calendar.current.startOfDay(for: $0.date)) }
            .reduce(0) { $0 + $1.caffeineMG }
    }
}

enum TrendRange: String, CaseIterable, Identifiable {
    case week, month
    var id: String { rawValue }
    var title: String { self == .week ? "7 days" : "30 days" }
}

struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol).foregroundStyle(color)
                Text(value).font(.system(.title3, design: .rounded, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
