import SwiftUI

/// Themed confetti, drawn by physics from a seed so every frame is computed, never stored.
struct Confetti: View {
    let style: TallyTheme.Particles
    let colors: [Color]
    let start: Date
    var origin: CGPoint? = nil
    var count = 140

    private struct Particle {
        let x: CGFloat, y: CGFloat          // launch point (0...1)
        let vx: CGFloat, vy: CGFloat        // launch velocity (points/s)
        let spin: Double, rotation: Double
        let size: CGFloat
        let color: Int
        let shape: Int
        let delay: Double
    }

    private var particles: [Particle] {
        var seed: UInt64 = 0xC0FFEE
        func rand() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
        }
        return (0..<count).map { i in
            let burst = i < count / 2
            let angle = burst ? rand() * .pi * 2 : .pi / 2 + (rand() - 0.5) * 0.6
            let speed = burst ? 260 + rand() * 520 : 40 + rand() * 120
            return Particle(
                x: burst ? 0.5 : rand(), y: burst ? 0.45 : -0.05,
                vx: cos(angle) * speed, vy: burst ? -abs(sin(angle)) * speed - 120 : sin(angle) * speed,
                spin: Double(rand() - 0.5) * 12, rotation: Double(rand()) * .pi * 2,
                size: 10 + rand() * 16,
                color: Int(rand() * 97),
                shape: Int(rand() * 97),
                delay: burst ? Double(rand()) * 0.15 : 0.2 + Double(rand()) * 1.4
            )
        }
    }

    var body: some View {
        let parts = particles
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                let gravity: CGFloat = 520
                for p in parts {
                    let t = CGFloat(elapsed - p.delay)
                    guard t > 0 else { continue }
                    let ox = (origin?.x ?? size.width * p.x)
                    let oy = p.y < 0 ? size.height * p.y : (origin?.y ?? size.height * p.y)
                    let drag: CGFloat = 0.55
                    let x = ox + p.vx * t * drag + CGFloat(sin(Double(t) * 3 + p.rotation)) * 14
                    let y = oy + p.vy * t * drag + 0.5 * gravity * t * t * 0.55
                    guard y < size.height + 40, x > -40, x < size.width + 40 else { continue }
                    let fade = max(0, min(1, 3.4 - Double(t) * 0.9))
                    var ctx = context
                    ctx.opacity = fade
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(p.rotation + p.spin * Double(t)))
                    let color = colors.isEmpty ? Color.white : colors[p.color % colors.count]
                    draw(&ctx, p.shape, p.size, color)
                }
                if style == .fireworks || style == .stars {
                    drawFireworks(context, size, CGFloat(elapsed))
                }
            } symbols: {
                ForEach(Array(symbolNames.enumerated()), id: \.offset) { index, name in
                    Image(systemName: name)
                        .font(.system(size: 26, weight: .bold))
                        .tag(index)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var symbolNames: [String] {
        switch style {
        case .hearts: return ["heart.fill"]
        case .clovers: return ["suit.club.fill", "sparkle"]
        case .stars: return ["star.fill", "sparkle"]
        case .leaves: return ["leaf.fill"]
        case .snow: return ["snowflake", "sparkle"]
        case .spring: return ["fish.fill", "camera.macro", "leaf.fill"]
        case .bats: return ["moon.fill", "sparkle"]
        case .fireworks: return ["sparkle", "star.fill"]
        case .tally, .eggs: return []
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ shape: Int, _ size: CGFloat, _ color: Color) {
        switch style {
        case .tally:
            // A tally stroke, sometimes a little group of five.
            if shape % 5 == 0 {
                for i in 0..<4 {
                    let x = CGFloat(i) * size * 0.28 - size * 0.42
                    ctx.stroke(Path { p in p.move(to: CGPoint(x: x, y: -size * 0.5)); p.addLine(to: CGPoint(x: x, y: size * 0.5)) },
                               with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                ctx.stroke(Path { p in p.move(to: CGPoint(x: -size * 0.6, y: size * 0.35)); p.addLine(to: CGPoint(x: size * 0.55, y: -size * 0.35)) },
                           with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            } else {
                ctx.fill(Path(roundedRect: CGRect(x: -2.5, y: -size * 0.5, width: 5, height: size), cornerRadius: 2.5), with: .color(color))
            }
        case .eggs:
            let rect = CGRect(x: -size * 0.38, y: -size * 0.5, width: size * 0.76, height: size)
            ctx.fill(Path(ellipseIn: rect), with: .color(color))
            ctx.stroke(Path { p in p.move(to: CGPoint(x: rect.minX + 2, y: 0)); p.addLine(to: CGPoint(x: rect.maxX - 2, y: 0)) },
                       with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [3, 3]))
        case .bats where shape % 3 != 0:
            ctx.fill(batPath(size), with: .color(color))
        default:
            let names = symbolNames
            guard !names.isEmpty, let symbol = ctx.resolveSymbol(id: shape % names.count) else {
                ctx.fill(Path(ellipseIn: CGRect(x: -size / 4, y: -size / 4, width: size / 2, height: size / 2)), with: .color(color))
                return
            }
            var shaded = ctx
            shaded.addFilter(.colorMultiply(color))
            shaded.scaleBy(x: size / 26, y: size / 26)
            shaded.draw(symbol, at: .zero)
        }
    }

    private func batPath(_ size: CGFloat) -> Path {
        let s = size * 0.6
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -s * 0.15))
        p.addQuadCurve(to: CGPoint(x: s, y: -s * 0.35), control: CGPoint(x: s * 0.5, y: -s * 0.6))
        p.addQuadCurve(to: CGPoint(x: s * 0.55, y: s * 0.2), control: CGPoint(x: s * 0.9, y: s * 0.1))
        p.addQuadCurve(to: CGPoint(x: 0, y: s * 0.3), control: CGPoint(x: s * 0.25, y: s * 0.05))
        p.addQuadCurve(to: CGPoint(x: -s * 0.55, y: s * 0.2), control: CGPoint(x: -s * 0.25, y: s * 0.05))
        p.addQuadCurve(to: CGPoint(x: -s, y: -s * 0.35), control: CGPoint(x: -s * 0.9, y: s * 0.1))
        p.addQuadCurve(to: CGPoint(x: 0, y: -s * 0.15), control: CGPoint(x: -s * 0.5, y: -s * 0.6))
        p.closeSubpath()
        return p
    }

    /// Three staggered bursts of sparks.
    private func drawFireworks(_ context: GraphicsContext, _ size: CGSize, _ t: CGFloat) {
        let bursts: [(CGFloat, CGFloat, CGFloat)] = [(0.25, 0.28, 0.1), (0.72, 0.22, 0.55), (0.5, 0.15, 1.0)]
        for (index, burst) in bursts.enumerated() {
            let local = t - burst.2
            guard local > 0, local < 1.8 else { continue }
            let center = CGPoint(x: size.width * burst.0, y: size.height * burst.1)
            let radius = 140 * (1 - pow(1 - min(local / 1.1, 1), 3))
            let alpha = Double(max(0, 1 - local / 1.8))
            let color = colors.isEmpty ? Color.white : colors[index % colors.count]
            for k in 0..<18 {
                let angle = Double(k) / 18 * .pi * 2
                let p = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius + local * local * 30)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(color.opacity(alpha)))
            }
        }
    }
}
