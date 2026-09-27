import SwiftUI

/// "Tallyho!" — the goal is reached. The color floods the screen, themed confetti bursts, and the
/// numbers of the journey land one after another.
struct CelebrationView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tally: Tally
    let start: Date
    let finish: () -> Void
    let keepGoing: () -> Void

    @State private var flooded = false
    @State private var landed = false
    @State private var details = false

    var body: some View {
        let ink = theme.onTally(tally.colorIndex)
        ZStack {
            GeometryReader { geo in
                Circle()
                    .fill(theme.tally(tally.colorIndex))
                    .frame(width: 60, height: 60)
                    .scaleEffect(flooded ? max(geo.size.width, geo.size.height) / 20 : 0.1)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.45)
            }
            .ignoresSafeArea()

            if !reduceMotion {
                Confetti(style: theme.particles, colors: confettiColors, start: start)
                    .ignoresSafeArea()
            }

            VStack(spacing: Space.l) {
                Spacer()
                Text("Tallyho!")
                    .font(theme.numeralFont(size: 64))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .rotationEffect(.degrees(landed ? -5 : -30))
                    .scaleEffect(landed ? 1 : 0.2)
                    .opacity(landed ? 1 : 0)
                Text("\(tally.value)")
                    .font(theme.numeralFont(size: 132))
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .monospacedDigit()
                    .scaleEffect(landed ? 1 : 1.6)
                    .opacity(landed ? 1 : 0)
                VStack(spacing: Space.xs) {
                    Text("\(tally.emoji) \(tally.displayName)")
                        .font(.title3.weight(.bold))
                    Text(journey)
                        .font(.body.weight(.medium))
                        .multilineTextAlignment(.center)
                        .opacity(0.9)
                }
                .opacity(details ? 1 : 0)
                .offset(y: details ? 0 : 20)
                Spacer()
                VStack(spacing: Space.m) {
                    Button(action: finish) {
                        Label("Finish tally", systemImage: "flag.checkered")
                            .font(.headline)
                            .foregroundStyle(theme.tally(tally.colorIndex))
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(ink, in: Capsule())
                    }
                    .buttonStyle(PressableStyle(scale: 0.97))
                    Button(action: keepGoing) {
                        Text("Keep counting")
                            .font(.headline)
                            .foregroundStyle(ink)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .overlay(Capsule().strokeBorder(ink.opacity(0.7), lineWidth: 2))
                    }
                    .buttonStyle(PressableStyle(scale: 0.97))
                }
                .opacity(details ? 1 : 0)
                .padding(.bottom, Space.xl)
            }
            .foregroundStyle(ink)
            .padding(.horizontal, Space.xl)
        }
        .contentShape(Rectangle())
        .onTapGesture {} // Taps here never count.
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.55)) { flooded = true }
            withAnimation(.spring(duration: 0.7, bounce: 0.5).delay(reduceMotion ? 0 : 0.25)) { landed = true }
            withAnimation(Motion.standard.delay(reduceMotion ? 0 : 0.7)) { details = true }
        }
    }

    private var confettiColors: [Color] {
        (0..<TallyTheme.tallyColorCount)
            .filter { $0 != tally.colorIndex }
            .map { theme.tally($0) } + [theme.onTally(tally.colorIndex)]
    }

    /// "From 20 to 70 in 3 days · 11 taps"
    private var journey: String {
        var parts: [String] = []
        if let target = tally.target {
            parts.append("From \(tally.start) to \(target)")
        }
        if let first = tally.firstCountAt {
            parts.append("in " + Format.duration(Date().timeIntervalSince(first)))
        }
        let head = parts.joined(separator: " ")
        let taps = "\(tally.taps) tap\(tally.taps == 1 ? "" : "s")"
        return head.isEmpty ? taps : "\(head) · \(taps)"
    }
}
