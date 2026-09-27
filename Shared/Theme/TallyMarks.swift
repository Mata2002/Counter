import SwiftUI

/// Hand-drawn tally marks: four strokes and a slash, grouped in fives.
/// `filled` marks are drawn in `color`; the rest are faint, showing what's left.
struct TallyMarks: View {
    var total: Int
    var filled: Double
    var color: Color
    var empty: Color
    var lineWidth: CGFloat = 2.2

    var body: some View {
        Canvas { context, size in
            let groups = max(1, Int(ceil(Double(total) / 5)))
            let groupGap = size.height * 0.55
            let groupWidth = (size.width - groupGap * CGFloat(groups - 1)) / CGFloat(groups)
            let strokeGap = groupWidth / 4.6
            let filledCount = Int(filled.rounded())
            var index = 0
            for g in 0..<groups {
                let x0 = CGFloat(g) * (groupWidth + groupGap)
                for s in 0..<5 where index < total {
                    let isFilled = index < filledCount
                    var path = Path()
                    // Deterministic wobble so the marks look hand-drawn, not printed.
                    let wobble = CGFloat(((index * 37) % 7) - 3) * 0.35
                    if s < 4 {
                        let x = x0 + strokeGap * (CGFloat(s) + 0.3)
                        path.move(to: CGPoint(x: x + wobble * 0.4, y: size.height * 0.1))
                        path.addLine(to: CGPoint(x: x - wobble * 0.3, y: size.height * 0.92))
                    } else {
                        path.move(to: CGPoint(x: x0 - strokeGap * 0.15, y: size.height * 0.78 + wobble))
                        path.addLine(to: CGPoint(x: x0 + strokeGap * 3.7, y: size.height * 0.22 - wobble))
                    }
                    context.stroke(path, with: .color(isFilled ? color : empty),
                                   style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    index += 1
                }
            }
        }
        .accessibilityHidden(true)
    }
}

extension TallyMarks {
    /// Marks for a tally in a list row: 20 marks show progress toward the goal;
    /// a tally without a goal shows its count within the current group of 20.
    init(tally: Tally, theme: TallyTheme, total: Int = 20) {
        let color = theme.tally(tally.colorIndex)
        let filled: Double
        if tally.hasGoal {
            filled = tally.progress * Double(total)
        } else {
            let counted = abs(tally.value - tally.start)
            filled = counted == 0 ? 0 : Double((counted - 1) % total + 1)
        }
        self.init(total: total, filled: filled, color: color, empty: theme.text2Color.opacity(0.22))
    }
}
