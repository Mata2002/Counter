import SwiftUI
import Combine
import WatchConnectivity

@main
struct HydrationWatchApp: App {
    @StateObject private var store = WatchHydrationStore()

    var body: some Scene {
        WindowGroup {
            WatchHomeView().environmentObject(store)
        }
    }
}

@MainActor
final class WatchHydrationStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot = HydrationStorage.load()
    /// Set only on a local tap (not on a remote sync merge), so the haptic
    /// below fires for "I just tapped this" and not for background updates.
    @Published private(set) var lastLocalAdd: UUID?

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    var current: Int { HydrationMath.hydrated(on: .now, from: snapshot.entries) }
    var caffeine: Int { HydrationMath.caffeine(on: .now, from: snapshot.entries) }
    var pours: Int { HydrationMath.entries(on: .now, from: snapshot.entries).count }
    var goal: Int { snapshot.settings.dailyGoalML }
    var progress: Double { min(Double(current) / Double(max(goal, 1)), 1) }

    func add(_ amount: Int) {
        snapshot.entries.append(HydrationEntry(amountML: amount, drink: .water, vessel: amount >= 450 ? .bottle : .glass))
        snapshot.lastModified = Date()
        HydrationStorage.save(snapshot)
        lastLocalAdd = UUID()
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["quickAmount": amount], replyHandler: nil)
        } else if let data = try? JSONEncoder().encode(snapshot) {
            try? WCSession.default.updateApplicationContext(["snapshot": data])
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["snapshot"] as? Data else { return }
        Task { @MainActor in
            guard let received = try? JSONDecoder().decode(HydrationSnapshot.self, from: data) else { return }
            if received.lastModified > snapshot.lastModified {
                snapshot = received
                HydrationStorage.save(received)
            }
        }
    }
}

struct WatchHomeView: View {
    @EnvironmentObject private var store: WatchHydrationStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    WatchVessel(progress: store.progress, themeID: store.snapshot.settings.activeThemeID)
                        .frame(height: 130)
                    Text("\(store.pours) drinks logged").font(.caption2).foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Label(store.current.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces), systemImage: "drop.fill")
                            .foregroundStyle(CompanionPalette(id: store.snapshot.settings.activeThemeID).top)
                        Label("\(store.caffeine) mg", systemImage: "bolt.fill")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption2.bold())

                    HStack {
                        QuickWatchButton(amount: 250)
                        QuickWatchButton(amount: 500)
                    }
                    NavigationLink {
                        WatchAmountList()
                    } label: {
                        Label("More amounts", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Hydration")
            .sensoryFeedback(.selection, trigger: store.lastLocalAdd) { _, new in new != nil && store.snapshot.settings.haptics }
        }
    }
}

private struct WatchVessel: View {
    let progress: Double
    let themeID: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let palette = CompanionPalette(id: themeID)
        ZStack {
            Circle().fill(palette.background)
            CompanionWave(progress: progress).fill(LinearGradient(colors: [palette.top, palette.bottom], startPoint: .top, endPoint: .bottom)).clipShape(Circle())
            Circle().strokeBorder(.white.opacity(progress >= 1 ? 0.8 : 0.3), lineWidth: 1.5)
            VStack(spacing: 3) {
                Image(systemName: progress >= 1 ? "checkmark" : "drop.fill")
                Text("\(Int(progress * 100))%").font(.system(.title2, design: .rounded, weight: .bold)).contentTransition(.numericText())
            }.foregroundStyle(.white)
        }.aspectRatio(1, contentMode: .fit).animation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.85), value: progress)
    }
}

struct QuickWatchButton: View {
    @EnvironmentObject private var store: WatchHydrationStore
    let amount: Int

    var body: some View {
        Button { store.add(amount) } label: {
            VStack(spacing: 3) {
                Image(systemName: amount >= 450 ? "waterbottle.fill" : "drop.fill")
                Text(amount.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces)).font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(CompanionPalette(id: store.snapshot.settings.activeThemeID).bottom)
    }
}

struct WatchAmountList: View {
    @EnvironmentObject private var store: WatchHydrationStore

    var body: some View {
        List([150, 200, 250, 330, 350, 500, 590, 750], id: \.self) { amount in
            Button { store.add(amount) } label: {
                HStack {
                    Image(systemName: amount >= 450 ? "waterbottle.fill" : "drop.fill")
                    Text(amount.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces))
                }
            }
        }
        .navigationTitle("Add water")
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
