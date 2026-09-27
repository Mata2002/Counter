import SwiftUI
import WatchKit

@main
struct TallyhoWatchApp: App {
    @State private var store = WatchStore.shared

    var body: some Scene {
        WindowGroup {
            WatchHome()
                .environment(store)
                .environment(\.theme, store.theme)
        }
    }
}

/// Your active tallies, most recently used first.
struct WatchHome: View {
    @Environment(WatchStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.tallies.isEmpty {
                    ScrollView {
                        VStack(spacing: 10) {
                            TallyMarks(total: 5, filled: 4, color: theme.tally(0), empty: .gray.opacity(0.4), lineWidth: 4)
                                .frame(width: 70, height: 40)
                            Text("No tallies yet")
                                .font(.headline)
                            Text("Add one in Tallyho on your iPhone. It shows up here in a moment.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Refresh") { store.requestRefresh() }
                        }
                        .padding(.top, 6)
                    }
                } else {
                    List(store.tallies) { tally in
                        NavigationLink(value: tally.id) {
                            WatchRow(tally: tally)
                        }
                        .swipeActions(edge: .trailing) {
                            Button { store.count(tally.id) } label: {
                                Label("Count", systemImage: tally.direction == .up ? "plus" : "minus")
                            }
                            .tint(theme.tally(tally.colorIndex))
                        }
                    }
                }
            }
            .navigationTitle("Tallyho")
            .navigationDestination(for: UUID.self) { id in
                WatchCounter(tallyID: id)
            }
        }
        .onAppear {
            // Screenshots: `-demo -open` starts on the first tally.
            if ProcessInfo.processInfo.arguments.contains("-open"), let first = store.tallies.first {
                path = [first.id]
            }
        }
    }
}

private struct WatchRow: View {
    @Environment(\.theme) private var theme
    let tally: WatchTally

    var body: some View {
        let t = tally.asTally
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(theme.tally(tally.colorIndex).opacity(0.3), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: t.hasGoal ? t.progress : 1)
                    .stroke(theme.tally(tally.colorIndex), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(tally.emoji.isEmpty ? String(tally.name.prefix(1)) : tally.emoji)
                    .font(.system(size: 16))
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(tally.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(t.hasGoal ? "\(tally.value) of \(tally.target ?? 0)" : "\(tally.value)")
                    .font(.system(.body, design: theme.numeralDesign, weight: .bold))
                    .foregroundStyle(theme.tally(tally.colorIndex))
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

/// Tap anywhere to count. Turn the Digital Crown to count faster. The small button takes one back.
struct WatchCounter: View {
    @Environment(WatchStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let tallyID: UUID

    @State private var crown: Double = 0
    @State private var appliedCrown: Int = 0
    @State private var celebrating = false

    var body: some View {
        if let wt = store.tally(tallyID) {
            let tally = wt.asTally
            GeometryReader { geo in
                ZStack {
                    TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
                        let phase = timeline.date.timeIntervalSinceReferenceDate * 1.4
                        let fill = LiquidFill(level: tally.fillLevel, phase: phase, amplitude: 5)
                        ZStack {
                            theme.tallyBase(tally.colorIndex)
                            fill.fill(theme.tally(tally.colorIndex))
                            numeral(tally, ink: theme.onTallyBase(tally.colorIndex), size: geo.size)
                            numeral(tally, ink: theme.onTally(tally.colorIndex), size: geo.size)
                                .mask(fill)
                        }
                    }
                    .animation(.spring(duration: 0.5, bounce: 0.25), value: tally.fillLevel)

                    VStack {
                        Spacer()
                        HStack {
                            Button {
                                if store.count(tallyID, reverse: true) { celebrate() }
                            } label: {
                                Text(tally.direction == .up ? "−\(tally.undoStep)" : "+\(tally.undoStep)")
                                    .font(.system(.footnote, design: theme.numeralDesign, weight: .heavy))
                                    .frame(width: 44, height: 32)
                            }
                            .buttonStyle(.plain)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundStyle(theme.onTallyBase(tally.colorIndex))
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 6)
                    }

                    if celebrating {
                        WatchCelebration(tally: tally) {
                            store.finish(tallyID)
                            dismiss()
                        } keepGoing: {
                            withAnimation { celebrating = false }
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !celebrating else { return }
                    if store.count(tallyID) { celebrate() }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(tally.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .focusable()
            .digitalCrownRotation($crown, from: -100_000, through: 100_000, by: 1, sensitivity: .medium,
                                  isContinuous: true, isHapticFeedbackEnabled: true)
            .onChange(of: crown) { _, newValue in
                let target = Int(newValue.rounded())
                guard !celebrating, target != appliedCrown else { return }
                let forward = target > appliedCrown
                // Turning up the crown counts forward; turning down takes back.
                var reached = false
                for _ in 0..<min(abs(target - appliedCrown), 20) {
                    reached = store.count(tallyID, reverse: !forward) || reached
                }
                appliedCrown = target
                if reached { celebrate() }
            }
        } else {
            Text("This tally is finished or gone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func numeral(_ tally: Tally, ink: Color, size: CGSize) -> some View {
        VStack(spacing: 0) {
            Text("\(tally.value)")
                .font(.system(size: min(size.width * 0.5, 80), weight: .black, design: theme.numeralDesign))
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(tally.value)))
            Text(tally.target.map { "of \($0) · \(tally.statusText)" } ?? tally.statusText)
                .font(.system(.caption2, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(ink)
        .frame(width: size.width, height: size.height)
        .animation(.snappy(duration: 0.25), value: tally.value)
    }

    private func celebrate() {
        WKInterfaceDevice.current().play(.success)
        withAnimation(.spring(duration: 0.5, bounce: 0.4)) { celebrating = true }
    }
}

private struct WatchCelebration: View {
    @Environment(\.theme) private var theme
    let tally: Tally
    let finish: () -> Void
    let keepGoing: () -> Void
    @State private var landed = false

    var body: some View {
        let ink = theme.onTally(tally.colorIndex)
        ZStack {
            theme.tally(tally.colorIndex).ignoresSafeArea()
            ForEach(0..<14, id: \.self) { i in
                let angle = Double(i) / 14 * .pi * 2
                Capsule()
                    .fill(theme.tally(i % TallyTheme.tallyColorCount == tally.colorIndex ? i + 1 : i))
                    .frame(width: 4, height: 14)
                    .rotationEffect(.radians(angle + .pi / 2))
                    .offset(x: landed ? CGFloat(cos(angle)) * 80 : 0, y: landed ? CGFloat(sin(angle)) * 80 : 0)
                    .opacity(landed ? 0 : 1)
            }
            ScrollView {
                VStack(spacing: 6) {
                    Text("Tallyho!")
                        .font(.system(.title2, design: theme.numeralDesign, weight: .black))
                        .scaleEffect(landed ? 1 : 0.3)
                        .rotationEffect(.degrees(landed ? -5 : -30))
                    Text("\(tally.value)")
                        .font(.system(size: 44, weight: .black, design: theme.numeralDesign))
                    Button("Finish", action: finish)
                        .foregroundStyle(theme.tally(tally.colorIndex))
                        .background(ink, in: Capsule())
                    Button("Keep going", action: keepGoing)
                        .foregroundStyle(ink)
                }
                .foregroundStyle(ink)
                .padding(.top, 8)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.5)) { landed = true }
        }
    }
}
