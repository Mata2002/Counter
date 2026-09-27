import SwiftUI

/// A full-bleed stage: the unfilled color, the liquid, and content drawn twice so its ink flips where the
/// liquid covers it. `content` receives the ink color to use.
struct LiquidStage<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let colorIndex: Int
    let level: Double
    var amplitude: CGFloat = 10
    var texture = true
    @ViewBuilder let content: (Color) -> Content

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * 1.4
            let fill = LiquidFill(level: level, phase: phase, amplitude: reduceMotion ? 0 : amplitude)
            ZStack {
                theme.tallyBase(colorIndex)
                fill.fill(theme.tally(colorIndex))
                if texture { StageTexture(style: theme.stage, ink: theme.onTallyBase(colorIndex)) }
                content(theme.onTallyBase(colorIndex))
                content(theme.onTally(colorIndex))
                    .mask(fill)
            }
        }
    }
}

/// Optional theme texture: a drafting grid for Blueprint, halftone grain for Riso.
struct StageTexture: View {
    let style: TallyTheme.Stage
    let ink: Color

    var body: some View {
        switch style {
        case .none:
            EmptyView()
        case .grid:
            Canvas { context, size in
                let step: CGFloat = 24
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += step }
                var y: CGFloat = 0
                while y <= size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += step }
                context.stroke(path, with: .color(ink.opacity(0.08)), lineWidth: 1)
            }
            .allowsHitTesting(false)
        case .riso:
            Canvas { context, size in
                // Deterministic halftone speckle.
                var seed: UInt64 = 0x9E3779B97F4A7C15
                for _ in 0..<Int(size.width * size.height / 900) {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let x = CGFloat(seed >> 40 & 0xFFFF) / 65535 * size.width
                    let y = CGFloat(seed >> 16 & 0xFFFF) / 65535 * size.height
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(ink.opacity(0.10)))
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// Ripples that spread from wherever you tap.
struct Ripple: Identifiable {
    let id = UUID()
    let location: CGPoint
    let date: Date
    let label: String
}

struct RippleLayer: View {
    let ripples: [Ripple]
    let ink: Color
    var numeralDesign: Font.Design = .rounded

    var body: some View {
        TimelineView(.animation) { timeline in
            ZStack {
                ForEach(ripples) { ripple in
                    let t = min(1, timeline.date.timeIntervalSince(ripple.date) / 0.7)
                    let eased = 1 - pow(1 - t, 3)
                    Circle()
                        .stroke(ink.opacity(0.35 * (1 - t)), lineWidth: 3 * (1 - t) + 1)
                        .frame(width: 40 + 220 * eased, height: 40 + 220 * eased)
                        .position(ripple.location)
                    Text(ripple.label)
                        .font(.system(.title2, design: numeralDesign, weight: .heavy))
                        .foregroundStyle(ink.opacity(1 - t))
                        .position(x: ripple.location.x, y: ripple.location.y - 30 - 60 * eased)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
