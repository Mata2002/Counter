import AppIntents
import SwiftUI

// The Home Screen widget's views. They live in Shared so the app can render them for screenshots
// (`-screen widgets`); the widget extension wraps them in its container background.

/// The widget's liquid sits still, so the wave is frozen mid-swell rather than flat.
func widgetFill(_ tally: Tally) -> LiquidFill {
    LiquidFill(level: tally.fillLevel, phase: 1.1, amplitude: CGFloat(5))
}

/// The stage, frozen: the unfilled color, the liquid at its current level, and confetti once the goal is reached.
struct WidgetStage: View {
    let tally: Tally
    let theme: TallyTheme

    var body: some View {
        ZStack {
            theme.tallyBase(tally.colorIndex)
            widgetFill(tally).fill(theme.tally(tally.colorIndex))
            if tally.isGoalReached {
                WidgetConfetti(colorIndex: tally.colorIndex, theme: theme)
            }
        }
    }
}

/// A handful of tally sticks scattered where they landed, in the theme's other colors.
struct WidgetConfetti: View {
    let colorIndex: Int
    let theme: TallyTheme

    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x7A11
            func rand() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
            }
            for i in 0..<22 {
                let x = rand() * size.width, y = rand() * size.height
                let length = 8 + rand() * 9
                let angle = Double(rand()) * .pi
                // Skip the tally's own color: it would vanish into the liquid.
                let color = theme.tally(colorIndex + 1 + i % (TallyTheme.tallyColorCount - 1))
                var ctx = context
                ctx.translateBy(x: x, y: y)
                ctx.rotate(by: .radians(angle))
                ctx.fill(Path(roundedRect: CGRect(x: -2, y: -length / 2, width: 4, height: length), cornerRadius: 2),
                         with: .color(color.opacity(0.85)))
            }
        }
    }
}

/// Text drawn in the right ink on both sides of the liquid line.
struct WidgetInkText<Content: View>: View {
    @Environment(\.theme) private var theme
    let tally: Tally
    @ViewBuilder let content: (Color) -> Content

    var body: some View {
        ZStack {
            content(theme.onTallyBase(tally.colorIndex))
            content(theme.onTally(tally.colorIndex))
                .mask(widgetFill(tally).ignoresSafeArea())
        }
    }
}

/// Round count buttons in the ink of whatever they sit on, so they read on the liquid and above it.
struct WidgetCountButton: View {
    @Environment(\.theme) private var theme
    let tally: Tally
    let reverse: Bool
    let size: CGFloat
    /// Whether the liquid covers the spot where this button sits.
    let onLiquid: Bool

    var body: some View {
        let isPlus = (tally.direction == .up) != reverse
        let ink = onLiquid ? theme.onTally(tally.colorIndex) : theme.onTallyBase(tally.colorIndex)
        let under = onLiquid ? theme.tally(tally.colorIndex) : theme.tallyBase(tally.colorIndex)
        Button(intent: CountTallyIntent(tallyID: tally.id, reverse: reverse)) {
            Image(systemName: isPlus ? "plus" : "minus")
                .font(.system(size: size * 0.42, weight: .heavy))
                .foregroundStyle(reverse ? ink : under)
                .frame(width: size, height: size)
                .background(reverse ? ink.opacity(0.16) : ink, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlus ? "Add \(reverse ? tally.undoStep : tally.step)" : "Take away \(reverse ? tally.undoStep : tally.step)")
    }
}

/// Twenty marks toward the goal; a tally without a goal shows its taps in the current twenty.
func widgetMarks(_ tally: Tally, ink: Color) -> some View {
    let filled: Double
    if tally.hasGoal {
        filled = tally.progress * 20
    } else {
        let taps = abs(tally.value - tally.start) / max(tally.step, 1)
        filled = taps == 0 ? 0 : Double((taps - 1) % 20 + 1)
    }
    return TallyMarks(total: 20, filled: filled, color: ink, empty: ink.opacity(0.25), lineWidth: 2.2)
}

func widgetHeadline(_ tally: Tally) -> String {
    tally.isGoalReached ? "Tallyho!" : tally.statusText
}

struct WidgetSmallTally: View {
    @Environment(\.theme) private var theme
    let tally: Tally

    var body: some View {
        ZStack(alignment: .bottom) {
            WidgetInkText(tally: tally) { ink in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        if !tally.emoji.isEmpty { Text(tally.emoji).font(.caption) }
                        Text(tally.displayName)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(tally.value)")
                            .font(theme.numeralFont(size: 44))
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .contentTransition(.numericText(value: Double(tally.value)))
                        if let goal = tally.goalText {
                            Text(goal)
                                .font(theme.numeralFont(.caption, weight: .bold))
                                .opacity(0.8)
                                .lineLimit(1)
                        }
                    }
                    widgetMarks(tally, ink: ink)
                        .frame(width: 96, height: 10)
                    Text(widgetHeadline(tally))
                        .font(.caption2.weight(.bold))
                        .opacity(0.9)
                        .lineLimit(1)
                    Spacer(minLength: 44)
                }
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(14)
            }
            HStack {
                WidgetCountButton(tally: tally, reverse: true, size: 34, onLiquid: tally.fillLevel > 0.18)
                Spacer()
                WidgetCountButton(tally: tally, reverse: false, size: 44, onLiquid: tally.fillLevel > 0.22)
            }
            .padding(10)
        }
    }
}

struct WidgetMediumTally: View {
    @Environment(\.theme) private var theme
    let tally: Tally

    var body: some View {
        HStack(spacing: 0) {
            WidgetInkText(tally: tally) { ink in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if !tally.emoji.isEmpty { Text(tally.emoji).font(.subheadline) }
                        Text(tally.displayName)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(tally.value)")
                            .font(theme.numeralFont(size: 58))
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .contentTransition(.numericText(value: Double(tally.value)))
                        if let goal = tally.goalText {
                            Text(goal)
                                .font(theme.numeralFont(.title3, weight: .bold))
                                .opacity(0.8)
                        }
                    }
                    widgetMarks(tally, ink: ink)
                        .frame(width: 150, height: 12)
                    Text(widgetHeadline(tally))
                        .font(.caption.weight(.bold))
                        .opacity(0.9)
                }
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(16)
            }
            VStack(spacing: 10) {
                WidgetCountButton(tally: tally, reverse: false, size: 64, onLiquid: tally.fillLevel > 0.62)
                WidgetCountButton(tally: tally, reverse: true, size: 40, onLiquid: tally.fillLevel > 0.3)
            }
            .padding(.trailing, 16)
        }
    }
}

