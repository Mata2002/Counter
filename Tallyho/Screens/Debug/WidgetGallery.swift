import SwiftUI

/// Screenshots only (`-screen widgets`): the Home Screen widgets drawn by the app, at Home Screen sizes,
/// so their design can be checked without a real Home Screen.
struct WidgetGallery: View {
    @Environment(TallyStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        let tallies = store.sorted(store.homeTallies(showHidden: false), by: .lastUsed)
        let upward = tallies.first { $0.direction == .up && $0.hasGoal && !$0.isGoalReached }
        let down = tallies.first { $0.direction == .down }
        let free = tallies.first { !$0.hasGoal }
        let reached: Tally? = upward.map { var t = $0; t.value = t.target ?? t.value; return t }
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    if let upward { small(upward) }
                    if let down { small(down) }
                }
                HStack(spacing: 20) {
                    if let free { small(free) }
                    if let reached { small(reached) }
                }
                if let upward { medium(upward) }
                if let reached { medium(reached) }
            }
            .padding(.top, 70)
            .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(colors: [theme.tally(1).opacity(0.5), theme.tally(3).opacity(0.5), .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
                .background(theme.backgroundColor)
                .ignoresSafeArea()
        )
    }

    private func small(_ tally: Tally) -> some View {
        WidgetSmallTally(tally: tally)
            .background(WidgetStage(tally: tally, theme: theme))
            .frame(width: 170, height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func medium(_ tally: Tally) -> some View {
        WidgetMediumTally(tally: tally)
            .background(WidgetStage(tally: tally, theme: theme))
            .frame(width: 360, height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
