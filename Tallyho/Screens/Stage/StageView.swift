import SwiftUI
import UIKit

/// The counting stage. The whole screen is the button, except the few controls floating on it.
/// Count-ups fill with color toward the goal; countdowns drain toward it. Swipe down to close.
struct StageView: View {
    let tallyID: UUID

    @Environment(TallyStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppSettings.keepAwake) private var keepAwake = true
    @AppStorage(AppSettings.celebrate) private var celebrate = true

    @State private var ripples: [Ripple] = []
    @State private var celebrationStart: Date?
    @State private var confirmReset = false
    @State private var dragOffset: CGFloat = 0
    @State private var showHint = true

    private var tally: Tally? { store.tally(tallyID) }

    var body: some View {
        Group {
            if let tally {
                stage(tally)
            } else {
                Color.clear.onAppear { close() }
            }
        }
        .statusBarHidden()
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = keepAwake
            Haptics.prepare()
            if router.celebrateOnOpen {
                router.celebrateOnOpen = false
                // Screenshot path: start the confetti mid-flight so a still frame shows it.
                celebrationStart = Date().addingTimeInterval(-0.9)
            }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func stage(_ tally: Tally) -> some View {
        // The outer reader keeps the real safe area (Dynamic Island, home indicator) so the controls
        // stay clear of them; the inner one ignores it so the liquid fills the whole screen.
        GeometryReader { outer in
            let safeArea = outer.safeAreaInsets
            stageBody(tally, safeArea: safeArea)
        }
        .offset(y: dragOffset)
        .scaleEffect(1 - min(dragOffset, 300) / 3000)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: tally.direction == .up ? "Add \(tally.step)" : "Take away \(tally.step)") {
            count(tally, at: CGPoint(x: 200, y: 400))
        }
        .confirmationDialog("Reset “\(tally.displayName)” to \(tally.start)?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset to \(tally.start)", role: .destructive) {
                withAnimation(Motion.standard) { store.reset(tally.id) }
                Haptics.light()
            }
        }
    }

    private func stageBody(_ tally: Tally, safeArea: EdgeInsets) -> some View {
        GeometryReader { geo in
            ZStack {
                LiquidStage(colorIndex: tally.colorIndex, level: tally.fillLevel) { ink in
                    StageNumeral(tally: tally, ink: ink, size: geo.size, showHint: showHint && tally.taps == 0)
                }
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.6, bounce: 0.28), value: tally.fillLevel)
                .animation(Motion.quick, value: tally.value)

                RippleLayer(ripples: ripples, ink: theme.onTally(tally.colorIndex), numeralDesign: theme.numeralDesign)

                controls(tally, safeArea: safeArea)

                if let start = celebrationStart {
                    CelebrationView(tally: tally, start: start) {
                        store.complete(tally.id)
                        close()
                    } keepGoing: {
                        withAnimation(Motion.standard) { celebrationStart = nil }
                    }
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in count(tally, at: value.location) }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onChanged { value in
                        guard celebrationStart == nil, value.translation.height > 0,
                              abs(value.translation.height) > abs(value.translation.width) else { return }
                        dragOffset = value.translation.height * 0.7
                    }
                    .onEnded { value in
                        if dragOffset > 110 {
                            close()
                        } else {
                            withAnimation(Motion.bouncy) { dragOffset = 0 }
                        }
                    }
            )
        }
        .ignoresSafeArea()
    }

    // MARK: Controls

    private func controls(_ tally: Tally, safeArea: EdgeInsets) -> some View {
        // Each row of controls takes the ink of whatever it sits on: the liquid or the empty part.
        let ink = tally.fillLevel > 0.86 ? theme.onTally(tally.colorIndex) : theme.onTallyBase(tally.colorIndex)
        let bottomInk = tally.fillLevel > 0.1 ? theme.onTally(tally.colorIndex) : theme.onTallyBase(tally.colorIndex)
        return VStack {
            HStack(spacing: Space.m) {
                GlassIconButton(systemImage: "chevron.down", tint: ink, label: "Close") { close() }
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    Text(tally.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    if let folder = store.folder(tally.folderID) {
                        Text("\(folder.emoji) \(folder.displayName)")
                            .font(.caption.weight(.semibold))
                            .opacity(0.8)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(ink)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .allowsHitTesting(false)
                Spacer(minLength: 0)
                Menu {
                    TallyActions(tally: tally, includeOpen: false)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel("More")
                GlassIconButton(systemImage: "slider.horizontal.3", tint: ink, label: "Tally settings") {
                    router.editor = .editTally(tally)
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.top, max(safeArea.top, Space.l) + Space.xs)

            Spacer()

            HStack(alignment: .bottom, spacing: Space.m) {
                Button {
                    let reached = store.count(tally.id, reverse: true)
                    Haptics.count(reverse: true)
                    if reached { goalReached() }
                } label: {
                    Text(tally.direction == .up ? "−\(tally.undoStep)" : "+\(tally.undoStep)")
                        .font(theme.numeralFont(.title3, weight: .heavy))
                        .foregroundStyle(bottomInk)
                        .frame(minWidth: 64, minHeight: 56)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Capsule())
                .accessibilityLabel(tally.direction == .up ? "Take back \(tally.undoStep)" : "Add back \(tally.undoStep)")

                Spacer(minLength: 0)

                if tally.isGoalReached && celebrationStart == nil {
                    Button {
                        withAnimation(Motion.standard) { store.complete(tally.id) }
                        close()
                    } label: {
                        Label("Finish", systemImage: "flag.checkered")
                            .font(.headline)
                            .foregroundStyle(bottomInk)
                            .padding(.horizontal, Space.l)
                            .frame(minHeight: 56)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
                    Spacer(minLength: 0)
                }

                Button { confirmReset = true } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(bottomInk)
                        .frame(width: 56, height: 56)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel("Reset")
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, max(safeArea.bottom, Space.l) + Space.xs)
            .animation(Motion.bouncy, value: tally.isGoalReached)
        }
        .opacity(celebrationStart == nil ? 1 : 0)
    }

    // MARK: Actions

    private func count(_ tally: Tally, at point: CGPoint) {
        guard celebrationStart == nil else { return }
        let reached = store.count(tally.id)
        Haptics.count()
        showHint = false
        let ripple = Ripple(location: point, date: Date(), label: tally.direction == .up ? "+\(tally.step)" : "−\(tally.step)")
        ripples.append(ripple)
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            ripples.removeAll { $0.id == ripple.id }
        }
        if reached { goalReached() }
    }

    private func goalReached() {
        Haptics.goalReached()
        AccessibilityNotification.Announcement("Tallyho! Goal reached.").post()
        if celebrate {
            withAnimation(Motion.standard) { celebrationStart = Date() }
        }
    }

    private func close() {
        UIApplication.shared.isIdleTimerDisabled = false
        router.stageTallyID = nil
    }
}

/// The big number and what it means, drawn in whichever ink the liquid gives it.
private struct StageNumeral: View {
    @Environment(\.theme) private var theme
    let tally: Tally
    let ink: Color
    let size: CGSize
    let showHint: Bool

    var body: some View {
        let numeralSize = min(size.width * 0.62, size.height * 0.36)
        VStack(spacing: Space.s) {
            Spacer()
            ZStack {
                if theme.stage == .riso {
                    // Risograph misregistration: a second ink, slightly off.
                    numeral(numeralSize)
                        .foregroundStyle(theme.tally(tally.colorIndex + 1).opacity(0.55))
                        .offset(x: numeralSize * 0.025, y: numeralSize * 0.02)
                }
                numeral(numeralSize).foregroundStyle(ink)
            }
            .padding(.horizontal, Space.l)
            if let target = tally.target {
                Text(tally.goalText ?? "\(target)")
                    .font(theme.numeralFont(.title2, weight: .bold))
                    .foregroundStyle(ink.opacity(0.85))
                Text(tally.statusText)
                    .font(.headline)
                    .foregroundStyle(ink)
                    .contentTransition(.numericText())
            } else {
                // No goal: the taps pile up as tally marks, one mark per tap, twenty to a row.
                let taps = abs(tally.value - tally.start) / max(tally.step, 1)
                TallyMarks(total: 20, filled: Double(taps == 0 ? 0 : (taps - 1) % 20 + 1),
                           color: ink, empty: ink.opacity(0.22), lineWidth: 4)
                    .frame(width: min(size.width - Space.xl * 2, 280), height: 40)
                    .animation(Motion.quick, value: taps)
                Text(tally.statusText)
                    .font(.headline)
                    .foregroundStyle(ink.opacity(0.85))
            }
            Spacer()
            Text(showHint ? "Tap anywhere to count · swipe down to close" : " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ink.opacity(0.75))
                .padding(.bottom, 110)
        }
        .frame(width: size.width, height: size.height)
        .accessibilityElement(children: .combine)
    }

    private func numeral(_ size: CGFloat) -> some View {
        Text("\(tally.value)")
            .font(theme.numeralFont(size: size))
            .monospacedDigit()
            .minimumScaleFactor(0.2)
            .lineLimit(1)
            .contentTransition(.numericText(value: Double(tally.value)))
    }
}
