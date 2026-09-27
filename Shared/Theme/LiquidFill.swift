import SwiftUI

/// The tally's color rising (or draining) like liquid in a glass, with a gently moving surface.
struct LiquidFill: Shape {
    var level: Double
    var phase: Double
    var amplitude: CGFloat

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(level, phase) }
        set { level = newValue.first; phase = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let clamped = min(max(level, 0), 1)
        guard clamped > 0 else { return path }
        let surface = rect.maxY - rect.height * clamped
        // Calm the wave near empty and full so the edges don't look torn.
        let amp = amplitude * CGFloat(min(clamped, 1 - clamped) * 4).clamped(to: 0...1)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        let steps = max(12, Int(rect.width / 6))
        for i in 0...steps {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(steps)
            let t = Double(i) / Double(steps)
            let y = surface
                + amp * CGFloat(sin(t * .pi * 2.6 + phase))
                + amp * 0.45 * CGFloat(sin(t * .pi * 5.1 - phase * 1.3))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
