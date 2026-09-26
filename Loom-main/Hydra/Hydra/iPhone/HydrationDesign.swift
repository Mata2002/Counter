import SwiftUI
import UIKit

enum AquaPalette {
    static let ink = Color(red: 0.025, green: 0.075, blue: 0.13)
}

private struct HydroThemeKey: EnvironmentKey {
    static let defaultValue = HydroThemeCatalog.theme(for: .ocean)
}

extension EnvironmentValues {
    var hydroTheme: HydroTheme {
        get { self[HydroThemeKey.self] }
        set { self[HydroThemeKey.self] = newValue }
    }
}

extension HydroTheme {
    var hue: Double {
        switch id {
        case .ocean: 0.55
        case .sunrise: 0.025
        case .citrus: 0.12
        case .midnight: 0.64
        case .amethyst: 0.76
        case .coffee: 0.075
        case .christmas: 0.40
        case .halloween: 0.075
        }
    }
    private func adaptive(light: (Double, Double), dark: (Double, Double)) -> Color {
        let hue = hue
        return Color(uiColor: UIColor { traits in
            let pair = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(hue: hue, saturation: pair.0, brightness: pair.1, alpha: 1)
        })
    }
    var background: Color { adaptive(light: (0.055, 0.98), dark: (0.48, 0.095)) }
    var surface: Color { adaptive(light: (0.045, 1), dark: (0.34, 0.16)) }
    var raised: Color { adaptive(light: (0.12, 0.96), dark: (0.38, 0.23)) }
    var control: Color { adaptive(light: (0.85, id == .citrus ? 0.40 : 0.48), dark: (0.37, 0.95)) }
    var secondary: Color { adaptive(light: (0.38, 0.43), dark: (0.15, 0.72)) }
    var border: Color { control.opacity(0.13) }
    func drinkColor(_ drink: DrinkKind) -> Color {
        let index = DrinkKind.allCases.firstIndex(of: drink) ?? 0
        let offsets = [0.0, 0.025, 0.08, 0.13, -0.10, -0.05, 0.18, -0.16]
        let hue = (hue + offsets[index] + 1).truncatingRemainder(dividingBy: 1)
        return Color(uiColor: UIColor { traits in
            UIColor(hue: hue, saturation: traits.userInterfaceStyle == .dark ? 0.42 : 0.78,
                    brightness: traits.userInterfaceStyle == .dark ? 0.90 : 0.52, alpha: 1)
        })
    }
}

struct AquaBackground: View {
    @Environment(\.hydroTheme) private var environmentTheme
    var theme: HydroTheme? = nil
    var body: some View {
        let theme = theme ?? environmentTheme
        ZStack {
            theme.background
            Ellipse().fill(theme.liquidTop.opacity(0.10))
                .frame(width: 400, height: 350).blur(radius: 70).offset(x: 120, y: -300)
            Ellipse().fill(theme.accent.opacity(0.07))
                .frame(width: 340, height: 450).blur(radius: 80).offset(x: -160, y: 340)
        }.ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    @Environment(\.hydroTheme) private var theme
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(18)
            .background(theme.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: 28))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            .overlay { RoundedRectangle(cornerRadius: 28).strokeBorder(theme.border) }
            .shadow(color: theme.vesselBase.opacity(0.06), radius: 16, y: 8)
    }
}

struct HydraFormStyle: ViewModifier {
    @Environment(\.hydroTheme) private var theme
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden).background { AquaBackground() }
            .tint(theme.control)
            .toolbarBackground(theme.background, for: .navigationBar)
    }
}

extension View {
    func hydraForm() -> some View { modifier(HydraFormStyle()) }
}

struct LiquidWaveShape: Shape {
    var progress: Double
    var phase: Double
    var amplitude: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let fill = min(max(progress, 0), 1)
        let level = rect.height * (1 - fill)
        let height = amplitude * min(fill * 12, (1 - fill) * 12, 1)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: level))
        for x in stride(from: 0.0, through: Double(rect.width) + 3, by: 3) {
            let wave = sin(x / max(rect.width, 1) * 2 * .pi + phase)
            path.addLine(to: CGPoint(x: x, y: level + wave * height))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

enum PatternStyle {
    case none, diagonalCut, hatch, bubbles, sparkle
}

/// A named color + pattern set. `accent` is deliberately chosen from a
/// different hue family than the liquid gradient in every theme — that's the
/// direct fix for the old mint-ring-on-blue-liquid clash, where the accent and
/// the fill were too close in hue to read as a separate signal.
struct HydroTheme: Identifiable {
    enum Category: String, CaseIterable { case core, seasonal }

    let id: HydroThemeID
    let name: String
    let category: Category
    let liquidTop: Color
    let liquidBottom: Color
    let accent: Color
    let vesselBase: Color
    let pattern: PatternStyle
}

enum HydroThemeCatalog {
    static let all: [HydroTheme] = [
        HydroTheme(id: .ocean, name: "Ocean", category: .core,
                   liquidTop: Color(red: 0.12, green: 0.78, blue: 0.94),
                   liquidBottom: Color(red: 0.07, green: 0.34, blue: 0.92),
                   accent: Color(red: 1.00, green: 0.73, blue: 0.20),
                   vesselBase: AquaPalette.ink,
                   pattern: .diagonalCut),
        HydroTheme(id: .sunrise, name: "Sunrise", category: .core,
                   liquidTop: Color(red: 1.00, green: 0.78, blue: 0.52),
                   liquidBottom: Color(red: 0.95, green: 0.35, blue: 0.42),
                   accent: Color(red: 0.20, green: 0.86, blue: 0.94),
                   vesselBase: Color(red: 0.18, green: 0.07, blue: 0.06),
                   pattern: .hatch),
        HydroTheme(id: .citrus, name: "Citrus", category: .core,
                   liquidTop: Color(red: 1.00, green: 0.85, blue: 0.30),
                   liquidBottom: Color(red: 0.98, green: 0.55, blue: 0.12),
                   accent: Color(red: 0.30, green: 0.32, blue: 0.92),
                   vesselBase: Color(red: 0.14, green: 0.09, blue: 0.02),
                   pattern: .bubbles),
        HydroTheme(id: .midnight, name: "Midnight", category: .core,
                   liquidTop: Color(red: 0.20, green: 0.24, blue: 0.32),
                   liquidBottom: Color(red: 0.04, green: 0.05, blue: 0.08),
                   accent: Color(red: 0.30, green: 0.88, blue: 1.00),
                   vesselBase: Color(red: 0.02, green: 0.02, blue: 0.03),
                   pattern: .none),
        HydroTheme(id: .amethyst, name: "Amethyst", category: .core,
                   liquidTop: Color(red: 0.45, green: 0.32, blue: 0.78),
                   liquidBottom: Color(red: 0.16, green: 0.08, blue: 0.30),
                   accent: Color(red: 1.00, green: 0.78, blue: 0.30),
                   vesselBase: Color(red: 0.06, green: 0.03, blue: 0.10),
                   pattern: .sparkle),
        HydroTheme(id: .coffee, name: "Coffee", category: .seasonal,
                   liquidTop: Color(red: 0.62, green: 0.44, blue: 0.30),
                   liquidBottom: Color(red: 0.28, green: 0.17, blue: 0.10),
                   accent: Color(red: 0.94, green: 0.80, blue: 0.55),
                   vesselBase: Color(red: 0.10, green: 0.06, blue: 0.04),
                   pattern: .bubbles),
        HydroTheme(id: .christmas, name: "Christmas", category: .seasonal,
                   liquidTop: Color(red: 0.20, green: 0.62, blue: 0.38),
                   liquidBottom: Color(red: 0.55, green: 0.08, blue: 0.14),
                   accent: Color(red: 1.00, green: 0.82, blue: 0.35),
                   vesselBase: Color(red: 0.04, green: 0.10, blue: 0.07),
                   pattern: .sparkle),
        HydroTheme(id: .halloween, name: "Halloween", category: .seasonal,
                   liquidTop: Color(red: 1.00, green: 0.52, blue: 0.10),
                   liquidBottom: Color(red: 0.22, green: 0.06, blue: 0.30),
                   accent: Color(red: 0.62, green: 1.00, blue: 0.40),
                   vesselBase: Color(red: 0.03, green: 0.02, blue: 0.05),
                   pattern: .hatch)
    ]

    static func theme(for id: HydroThemeID) -> HydroTheme {
        all.first { $0.id == id } ?? all[0]
    }
}

private struct PatternOverlay: View {
    let style: PatternStyle
    let intensity: PatternIntensity

    private var opacity: Double {
        switch intensity {
        case .off: 0
        case .subtle: 0.16
        case .bold: 0.34
        }
    }

    var body: some View {
        Canvas { context, size in
            switch style {
            case .none:
                break
            case .diagonalCut:
                var path = Path()
                var x = -size.height
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += 14
                }
                context.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: 1.2)
            case .hatch:
                var path = Path()
                var x = -size.height
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += 10
                }
                var y: CGFloat = 0
                while y < size.width + size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y - size.width))
                    y += 10
                }
                context.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: 1)
            case .bubbles:
                for index in 0..<22 {
                    let seed = Double(index) * 0.618
                    let x = size.width * CGFloat((seed * 7).truncatingRemainder(dividingBy: 1))
                    let y = size.height * CGFloat((seed * 13).truncatingRemainder(dividingBy: 1))
                    let radius = 2 + CGFloat((seed * 5).truncatingRemainder(dividingBy: 1)) * 3
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                                 with: .color(.white.opacity(opacity)))
                }
            case .sparkle:
                for index in 0..<14 {
                    let seed = Double(index) * 0.618
                    let x = size.width * CGFloat((seed * 11).truncatingRemainder(dividingBy: 1))
                    let y = size.height * CGFloat((seed * 17).truncatingRemainder(dividingBy: 1))
                    var mark = Path()
                    mark.move(to: CGPoint(x: x - 4, y: y))
                    mark.addLine(to: CGPoint(x: x + 4, y: y))
                    mark.move(to: CGPoint(x: x, y: y - 4))
                    mark.addLine(to: CGPoint(x: x, y: y + 4))
                    context.stroke(mark, with: .color(.white.opacity(opacity)), lineWidth: 1)
                }
            }
        }
    }
}


private struct PourRipple: View {
    let trigger: UUID
    let color: Color
    var body: some View {
        PhaseAnimator([0, 1, 2], trigger: trigger) { phase in
            Circle().stroke(color.opacity(phase == 1 ? 0.40 : 0), lineWidth: 1.5)
                .scaleEffect(phase == 0 ? 0.9 : phase == 1 ? 1.03 : 1.20)
        } animation: { _ in .spring(response: 0.6, dampingFraction: 0.85) }
        .allowsHitTesting(false)
    }
}

/// One liquid level is the hydration signal. The seal only appears at the goal.
struct HydroOrb: View {
    let progress: Double
    let theme: HydroTheme
    var caffeineMG = 0
    var patternIntensity: PatternIntensity = .subtle
    var finish = "clear"
    var trigger = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false

    var body: some View {
        ZStack {
            Circle().fill(theme.vesselBase.gradient)
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !visible || scenePhase != .active)) { timeline in
                let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * 1.15
                let wave = LiquidWaveShape(progress: progress, phase: phase, amplitude: reduceMotion ? 0 : 5)
                ZStack {
                    LiquidWaveShape(progress: progress, phase: phase + 1.6, amplitude: reduceMotion ? 0 : 5)
                        .fill(theme.liquidTop.opacity(0.32))
                    wave.fill(LinearGradient(colors: [theme.liquidTop, theme.liquidBottom], startPoint: .top, endPoint: .bottom))
                    PatternOverlay(style: theme.pattern, intensity: patternIntensity).clipShape(wave).opacity(0.55)
                }
            }
            .clipShape(Circle())
            .animation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.86), value: progress)

            VesselFinishArt(finish: finish, color: theme.accent).clipShape(Circle())
            Circle().fill(LinearGradient(colors: [.white.opacity(0.16), .clear, .black.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.06), .white.opacity(0.23)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            Circle().trim(from: 0.54, to: 0.78).stroke(.white.opacity(0.25), style: StrokeStyle(lineWidth: 4, lineCap: .round)).padding(12)
            if progress >= 1 {
                Circle().stroke(theme.accent.opacity(0.85), lineWidth: 2).padding(-7)
            }
            VStack(spacing: 6) {
                Image(systemName: "drop.fill").font(.title3)
                    .symbolEffect(.bounce, value: reduceMotion ? nil : trigger)
                Text("\(Int(max(progress, 0) * 100))%")
                    .font(.system(size: 46, weight: .medium, design: .rounded))
                    .contentTransition(.numericText())
                Text(progress >= 1 ? "GOAL REACHED" : "OF YOUR DAILY GOAL")
                    .font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.4)
            }
            .foregroundStyle(.white)
            .animation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.86), value: progress)
            .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
            if !reduceMotion { PourRipple(trigger: trigger, color: theme.liquidTop) }
        }
        .overlay {
            CaffeineOrbit(amountMG: caffeineMG, color: theme.accent)
                .padding(-14)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            if progress >= 1 {
                Image(systemName: "checkmark.seal.fill").font(.title2)
                    .foregroundStyle(theme.accent, theme.vesselBase).offset(y: 8)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: theme.liquidBottom.opacity(0.18), radius: 20, y: 14)
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hydration")
        .accessibilityValue("\(Int(max(progress, 0) * 100)) percent of daily goal; \(caffeineMG) milligrams estimated caffeine")
    }
}

/// Caffeine uses a reference scale; its arc never represents a goal to reach.
struct CaffeineOrbit: View {
    let amountMG: Int
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let referenceMG = 400
    static let startDegrees = 110.0
    static let sweepDegrees = 320.0
    var fraction: Double { min(max(Double(amountMG) / Double(Self.referenceMG), 0), 1) }

    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: Self.sweepDegrees / 360)
                .stroke(color.opacity(0.18), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(Self.startDegrees))
                .padding(4)
            Circle().trim(from: 0, to: fraction * Self.sweepDegrees / 360)
                .stroke(color.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(Self.startDegrees))
                .padding(4)
            CaffeineOrbitMarker(fraction: fraction)
                .fill(color).opacity(amountMG > 0 ? 1 : 0)
                .shadow(color: color.opacity(0.30), radius: 3)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.90), value: amountMG)
        .accessibilityHidden(true)
    }
}

struct CaffeineOrbitMarker: Shape {
    var fraction: Double
    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let radius = max(min(rect.width, rect.height) / 2 - 4, 0)
        let angle = (CaffeineOrbit.startDegrees + min(max(fraction, 0), 1) * CaffeineOrbit.sweepDegrees) * .pi / 180
        let center = CGPoint(x: rect.midX + cos(angle) * radius, y: rect.midY + sin(angle) * radius)
        return Path(ellipseIn: CGRect(x: center.x - 3.5, y: center.y - 3.5, width: 7, height: 7))
    }
}

struct VesselFinishArt: View {
    let finish: String
    let color: Color
    var body: some View {
        Canvas { context, size in
            switch finish {
            case "prism":
                for i in 0..<8 {
                    let x = size.width * Double(i) / 7
                    var path = Path()
                    path.move(to: CGPoint(x: size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: 1)
                }
            case "etched":
                for i in 1..<9 {
                    let y = size.height * Double(i) / 9
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addQuadCurve(to: CGPoint(x: size.width, y: y), control: CGPoint(x: size.width / 2, y: y + 25))
                    context.stroke(path, with: .color(.white.opacity(0.22)), lineWidth: 1)
                }
            case "starlight":
                for i in 0..<24 {
                    let x = size.width * Double((i * 37 + 13) % 100) / 100
                    let y = size.height * Double((i * 61 + 9) % 100) / 100
                    let r = i % 4 == 0 ? 3.0 : 1.4
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(color.opacity(0.75)))
                }
            default: break
            }
        }.allowsHitTesting(false)
    }
}

struct HydroLegend: View {
    @Environment(\.hydroTheme) private var theme
    let symbol: String
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 6) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(theme.secondary)
            Text(value).font(.system(.subheadline, design: .rounded, weight: .semibold))
                .contentTransition(.numericText()).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct ProgressPill: View {
    @Environment(\.hydroTheme) private var theme
    let progress: Double
    var body: some View {
        ProgressView(value: min(max(progress, 0), 1)).tint(theme.control)
    }
}

struct PressableScale: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

#Preview("Liquid vessel") {
    HydroOrb(progress: 0.62, theme: HydroThemeCatalog.theme(for: .ocean))
        .frame(width: 240).padding(40).background(AquaPalette.ink)
}
