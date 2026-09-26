import SwiftUI

struct AchievementsView: View {
    @Environment(HydrationStore.self) private var store
    @State private var selected: HydrationAchievement?
    private var earnedCount: Int { HydrationAchievement.allCases.filter { store.snapshot.unlockedAchievementIDs.contains($0.id) }.count }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Small acts. Lasting marks.").font(.system(.title2, design: .rounded, weight: .medium))
                        Text("\(earnedCount) of \(HydrationAchievement.allCases.count) collected").font(.subheadline).foregroundStyle(store.activeTheme.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 14)], spacing: 14) {
                        ForEach(HydrationAchievement.allCases) { award in
                            AchievementTile(achievement: award) { selected = award }
                        }
                    }
                    Text("Glass finishes unlock at 3, 7, and 30 consecutive goal days. All color themes are available from the start.")
                        .font(.footnote).foregroundStyle(store.activeTheme.secondary)
                }.padding(20)
            }.background { AquaBackground() }.navigationTitle("Awards")
                .sheet(item: $selected) { award in AchievementDetail(achievement: award).environment(\.hydroTheme, store.activeTheme) }
        }
    }
}

struct AchievementTile: View {
    @Environment(HydrationStore.self) private var store
    let achievement: HydrationAchievement
    let action: () -> Void
    private var earned: Bool { store.snapshot.unlockedAchievementIDs.contains(achievement.id) }
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                AwardBadge(achievement: achievement, earned: earned).frame(height: 110).frame(maxWidth: .infinity)
                Text(achievement.title).font(.subheadline.bold()).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                if let reward = achievement.reward {
                    Label(reward, systemImage: "sparkles").font(.caption2.weight(.medium)).foregroundStyle(store.activeTheme.control)
                } else {
                    Text(achievement.meaning).font(.caption).foregroundStyle(store.activeTheme.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                if earned {
                    Label("Collected", systemImage: "checkmark").font(.caption.bold()).foregroundStyle(store.activeTheme.control)
                } else {
                    let progress = achievement.progress(in: store.snapshot)
                    ProgressPill(progress: progress.fraction)
                    Text(progress.label).font(.caption2).foregroundStyle(store.activeTheme.secondary)
                }
            }.frame(maxWidth: .infinity, minHeight: 222, alignment: .leading).padding(16)
                .background(store.activeTheme.surface, in: RoundedRectangle(cornerRadius: 26))
                .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(earned ? store.activeTheme.control.opacity(0.25) : store.activeTheme.border) }
        }.buttonStyle(PressableScale()).accessibilityElement(children: .combine)
            .accessibilityHint("Opens the award requirements and reward")
    }
}

/// Each milestone has its own outline, engraving, and central composition.
struct AwardBadge: View {
    let achievement: HydrationAchievement
    var earned = true
    private var index: Int { HydrationAchievement.allCases.firstIndex(of: achievement) ?? 0 }
    private var colors: [Color] {
        switch achievement {
        case .firstPour: [.cyan, Color(red: 0.05, green: 0.33, blue: 0.72)]
        case .goalDay: [Color(red: 1, green: 0.79, blue: 0.37), Color(red: 0.64, green: 0.31, blue: 0.1)]
        case .threeDay: [Color(red: 0.72, green: 0.73, blue: 1), .indigo]
        case .sevenDay: [.mint, Color(red: 0.02, green: 0.4, blue: 0.37)]
        case .thirtyDay: [Color(red: 0.66, green: 0.52, blue: 0.9), Color(red: 0.17, green: 0.1, blue: 0.35)]
        case .earlyBird: [Color(red: 1, green: 0.74, blue: 0.42), Color(red: 0.83, green: 0.31, blue: 0.31)]
        case .balanced: [Color(red: 0.97, green: 0.63, blue: 0.73), Color(red: 0.56, green: 0.2, blue: 0.38)]
        case .ocean: [Color(red: 0.27, green: 0.7, blue: 0.92), Color(red: 0.07, green: 0.2, blue: 0.49)]
        case .steadyRhythm: [Color(red: 0.86, green: 0.83, blue: 0.47), Color(red: 0.4, green: 0.43, blue: 0.16)]
        case .freshStart: [Color(red: 0.68, green: 0.86, blue: 0.55), Color(red: 0.2, green: 0.44, blue: 0.24)]
        }
    }
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                BadgeOutline(kind: index).fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                BadgeOutline(kind: index).stroke(LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0.08), .white.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                BadgeOutline(kind: index).stroke(.white.opacity(0.28), lineWidth: 1).padding(7)
                decoration.padding(14)
                Image(systemName: achievement.symbol).font(.system(size: side * 0.30, weight: .medium)).symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white).shadow(color: colors[1].opacity(0.7), radius: 3, y: 2)
                    .offset(y: achievement == .ocean || achievement == .earlyBird ? -5 : 0)
                if [.threeDay, .sevenDay, .thirtyDay].contains(achievement) {
                    Text(achievement == .threeDay ? "III" : achievement == .sevenDay ? "VII" : "XXX")
                        .font(.system(size: side * 0.105, weight: .bold, design: .serif)).tracking(2)
                        .foregroundStyle(.white.opacity(0.85)).offset(y: side * 0.30)
                }
            }.frame(width: side, height: side).saturation(earned ? 1 : 0.18).opacity(earned ? 1 : 0.48)
                .shadow(color: colors[1].opacity(earned ? 0.22 : 0.04), radius: 8, y: 5)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }.accessibilityHidden(true)
    }
    private var decoration: some View {
        Canvas { context, size in
            switch achievement {
            case .firstPour, .sevenDay, .ocean:
                for i in 0..<4 {
                    let y = size.height * (0.64 + Double(i) * 0.095)
                    var p = Path()
                    p.move(to: CGPoint(x: 4, y: y))
                    p.addCurve(to: CGPoint(x: size.width - 4, y: y), control1: CGPoint(x: size.width * 0.35, y: y - 12), control2: CGPoint(x: size.width * 0.65, y: y + 12))
                    context.stroke(p, with: .color(.white.opacity(0.45)), lineWidth: 1.2)
                }
            case .threeDay:
                var p = Path()
                p.move(to: CGPoint(x: size.width / 2, y: 0)); p.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                p.move(to: CGPoint(x: 0, y: size.height / 2)); p.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                context.stroke(p, with: .color(.white.opacity(0.30)), lineWidth: 1)
            case .thirtyDay:
                for i in 0..<8 {
                    let x = size.width * Double((i * 37 + 11) % 100) / 100
                    let y = size.height * Double((i * 51 + 5) % 100) / 100
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.5, height: 2.5)), with: .color(.white.opacity(0.8)))
                }
            default:
                let count = achievement == .earlyBird ? 12 : achievement == .steadyRhythm ? 3 : 8
                for i in 0..<count {
                    let angle = Double(i) / Double(count) * 2 * .pi - .pi / 2
                    let x = size.width / 2 + cos(angle) * size.width * 0.43
                    let y = size.height / 2 + sin(angle) * size.height * 0.43
                    context.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)), with: .color(.white.opacity(0.65)))
                }
            }
        }
    }
}

struct BadgeOutline: Shape {
    let kind: Int
    func path(in rect: CGRect) -> Path {
        // SwiftUI can propose a nonzero origin when stroking a custom shape.
        // Build every variant in local coordinates, then apply that origin once.
        localPath(in: CGRect(origin: .zero, size: rect.size))
            .offsetBy(dx: rect.minX, dy: rect.minY)
    }

    private func localPath(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        if kind == 0 {
            var p = Path()
            p.move(to: CGPoint(x: w * 0.5, y: 1))
            p.addCurve(to: CGPoint(x: w * 0.5, y: h - 1), control1: CGPoint(x: w * 1.18, y: h * 0.55), control2: CGPoint(x: w * 0.97, y: h))
            p.addCurve(to: CGPoint(x: w * 0.5, y: 1), control1: CGPoint(x: w * 0.03, y: h), control2: CGPoint(x: -w * 0.18, y: h * 0.55))
            p.closeSubpath(); return p
        }
        if kind == 3 || kind == 9 {
            var p = Path()
            p.move(to: CGPoint(x: w * 0.12, y: h * 0.09))
            p.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.09), control: CGPoint(x: w * 0.5, y: -h * 0.06))
            p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.55))
            p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.98), control: CGPoint(x: w * 0.85, y: h * 0.84))
            p.addQuadCurve(to: CGPoint(x: w * 0.12, y: h * 0.55), control: CGPoint(x: w * 0.15, y: h * 0.84))
            p.closeSubpath(); return p
        }
        if kind == 4 { return Path(ellipseIn: rect.insetBy(dx: 1, dy: 1)) }
        if kind == 8 {
            // Use the same explicit outline for fill and strokes. The optimized
            // rounded-rect Path fill renders its inset differently on iOS.
            let box = rect.insetBy(dx: w * 0.09, dy: 1)
            let r = min(w * 0.39, box.width / 2, box.height / 2)
            let k = r * 0.5522847498
            var p = Path()
            p.move(to: CGPoint(x: box.minX + r, y: box.minY))
            p.addLine(to: CGPoint(x: box.maxX - r, y: box.minY))
            p.addCurve(to: CGPoint(x: box.maxX, y: box.minY + r), control1: CGPoint(x: box.maxX - r + k, y: box.minY), control2: CGPoint(x: box.maxX, y: box.minY + r - k))
            p.addLine(to: CGPoint(x: box.maxX, y: box.maxY - r))
            p.addCurve(to: CGPoint(x: box.maxX - r, y: box.maxY), control1: CGPoint(x: box.maxX, y: box.maxY - r + k), control2: CGPoint(x: box.maxX - r + k, y: box.maxY))
            p.addLine(to: CGPoint(x: box.minX + r, y: box.maxY))
            p.addCurve(to: CGPoint(x: box.minX, y: box.maxY - r), control1: CGPoint(x: box.minX + r - k, y: box.maxY), control2: CGPoint(x: box.minX, y: box.maxY - r + k))
            p.addLine(to: CGPoint(x: box.minX, y: box.minY + r))
            p.addCurve(to: CGPoint(x: box.minX + r, y: box.minY), control1: CGPoint(x: box.minX, y: box.minY + r - k), control2: CGPoint(x: box.minX + r - k, y: box.minY))
            p.closeSubpath()
            return p
        }
        let points = kind == 2 ? 4 : kind == 7 ? 6 : kind == 6 ? 8 : 24
        var p = Path()
        for i in 0..<points {
            let angle = Double(i) / Double(points) * 2 * .pi - .pi / 2
            let radius = points == 24 && i % 2 == 1 ? 0.44 : 0.49
            let point = CGPoint(x: w / 2 + cos(angle) * w * radius, y: h / 2 + sin(angle) * h * radius)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath(); return p
    }
}

struct AchievementDetail: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let achievement: HydrationAchievement
    private var earned: Bool { store.snapshot.unlockedAchievementIDs.contains(achievement.id) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AwardBadge(achievement: achievement, earned: earned).frame(width: 180, height: 190)
                    VStack(spacing: 8) {
                        Text(achievement.title).font(.system(.title, design: .rounded, weight: .bold))
                        Text(achievement.meaning).foregroundStyle(store.activeTheme.secondary)
                    }.multilineTextAlignment(.center)
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label(earned ? "Collected" : "In progress", systemImage: earned ? "checkmark.seal.fill" : "lock.open")
                                .font(.headline).foregroundStyle(store.activeTheme.control)
                            Text(achievement.detail).font(.subheadline)
                            if !earned {
                                let progress = achievement.progress(in: store.snapshot)
                                ProgressPill(progress: progress.fraction)
                                Text(progress.label).font(.caption).foregroundStyle(store.activeTheme.secondary)
                            }
                            if [.threeDay, .sevenDay, .thirtyDay].contains(achievement) {
                                Text("Based on your best recorded streak and current daily goal. Earned awards stay in your collection.")
                                    .font(.caption).foregroundStyle(store.activeTheme.secondary)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let reward = achievement.reward, let finish = achievement.finishID {
                        HydroOrb(progress: 0.65, theme: store.activeTheme, finish: finish).frame(width: 105)
                        Text("Reward · \(reward)").font(.headline)
                        Button(store.activeFinish == finish ? "In use" : earned ? "Use this glass" : "Earn this award to unlock") {
                            store.updateSettings { $0.vesselFinish = finish }
                        }.buttonStyle(.borderedProminent).controlSize(.large).disabled(!earned || store.activeFinish == finish)
                    }
                }.padding(24)
            }.background { AquaBackground() }.navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(store.activeTheme.control).presentationDragIndicator(.visible)
    }
}

struct CelebrationSheet: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let moment: PourCelebration
    @State private var appeared = false
    private struct Motion { var scale = 0.8; var rotation = -8.0 }
    private var featured: HydrationAchievement { moment.awards.last ?? .goalDay }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if reduceMotion {
                        AwardBadge(achievement: featured).frame(width: 150, height: 160)
                    } else {
                        KeyframeAnimator(initialValue: Motion(), trigger: appeared) { value in
                            AwardBadge(achievement: featured).frame(width: 150, height: 160).scaleEffect(value.scale).rotationEffect(.degrees(value.rotation))
                        } keyframes: { _ in
                            KeyframeTrack(\.scale) {
                                SpringKeyframe(1.10, duration: 0.30, spring: .bouncy)
                                SpringKeyframe(1, duration: 0.30, spring: .smooth)
                            }
                            KeyframeTrack(\.rotation) {
                                SpringKeyframe(5, duration: 0.25, spring: .bouncy)
                                SpringKeyframe(0, duration: 0.35, spring: .smooth)
                            }
                        }
                    }
                    VStack(spacing: 8) {
                        Text(moment.reachedGoal ? "Your day is full." : featured.title).font(.system(.title, design: .rounded, weight: .bold))
                        Text(featured.meaning).foregroundStyle(store.activeTheme.secondary)
                    }.multilineTextAlignment(.center)
                    ForEach(moment.awards.count > 1 ? moment.awards : []) { award in
                        HStack(spacing: 15) {
                            AwardBadge(achievement: award).frame(width: 52, height: 58)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(award.title).font(.headline)
                                Text(award.reward.map { "Unlocked \($0)" } ?? award.detail).font(.caption).foregroundStyle(store.activeTheme.secondary)
                            }
                            Spacer(minLength: 0)
                        }.padding(14).background(store.activeTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                    if moment.awards.count == 1 { Text(featured.detail).font(.subheadline).foregroundStyle(store.activeTheme.secondary).multilineTextAlignment(.center) }
                    if let award = moment.awards.last(where: { $0.finishID != nil }), let finish = award.finishID {
                        Button("Use \(award.reward ?? "glass")") {
                            store.updateSettings { $0.vesselFinish = finish }; close()
                        }.buttonStyle(.borderedProminent).controlSize(.large)
                    }
                    Button("Done", action: close).font(.headline).frame(maxWidth: .infinity).padding(14)
                        .background(store.activeTheme.raised, in: Capsule()).buttonStyle(PressableScale())
                }.padding(24)
            }.background { AquaBackground() }
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close", action: close) } }
        }.tint(store.activeTheme.control).presentationDragIndicator(.visible).onAppear { appeared = true }
            .sensoryFeedback(.success, trigger: appeared) { _, value in value && store.snapshot.settings.haptics }
    }
    private func close() { store.dismissCelebration(); dismiss() }
}
