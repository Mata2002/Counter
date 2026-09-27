import SwiftUI

/// One tally in the list. Tap to open the counting stage; the round button counts without opening it.
/// Swipe left: Complete (full swipe), Archive, Delete. Swipe right: Reset, Hide. Touch and hold: preview and every action.
struct TallyRow: View {
    @Environment(TallyStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme
    @AppStorage(AppSettings.showMarks) private var showMarks = true
    let tally: Tally

    var body: some View {
        HStack(spacing: Space.m) {
            TallySwatch(text: tally.emojiOrInitial, colorIndex: tally.colorIndex, size: 46, finished: tally.isGoalReached)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(tally.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.textColor)
                        .lineLimit(1)
                    if tally.hidden {
                        Image(systemName: "eye.slash").font(.caption).foregroundStyle(theme.text2Color)
                    }
                    if tally.direction == .down {
                        Image(systemName: "arrow.down").font(.caption2.weight(.heavy)).foregroundStyle(theme.text2Color)
                            .accessibilityLabel("Counts down")
                    }
                }
                if showMarks {
                    TallyMarks(tally: tally, theme: theme)
                        .frame(maxWidth: 176, alignment: .leading)
                        .frame(height: 13)
                }
                HStack(spacing: 6) {
                    Text(tally.statusText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(tally.isGoalReached ? theme.actionColor : theme.text2Color)
                    ForEach(tally.tags.prefix(2), id: \.self) { TagChip(text: $0) }
                }
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(tally.value)")
                    .font(tally.value.magnitude > 9999 ? theme.numeralFont(.title3, weight: .heavy) : theme.numeralFont(.title2, weight: .heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(tally.value)))
                    .foregroundStyle(theme.textColor)
                if let target = tally.target {
                    Text("of \(target)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.text2Color)
                }
            }
            QuickCountButton(tally: tally)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { router.openTally(tally.id) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tally.displayName), \(tally.value)\(tally.target.map { " of \($0)" } ?? ""), \(tally.statusText)")
        .accessibilityAction(named: "Count") { count() }
        .accessibilityAction(named: "Open") { router.openTally(tally.id) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button { withAnimation(Motion.standard) { store.complete(tally.id) } } label: {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(theme.actionColor)
            Button { withAnimation(Motion.standard) { store.setArchived(tally.id, true) } } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(.indigo)
            Button(role: .destructive) { withAnimation(Motion.standard) { store.delete(tally.id) } } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button { store.reset(tally.id) } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .tint(.orange)
            Button { withAnimation(Motion.standard) { store.setHidden(tally.id, !tally.hidden) } } label: {
                Label(tally.hidden ? "Unhide" : "Hide", systemImage: tally.hidden ? "eye" : "eye.slash")
            }
            .tint(.gray)
        }
        .contextMenu {
            TallyActions(tally: tally)
        } preview: {
            TallyPreviewCard(tally: tally)
                .environment(\.theme, theme)
        }
    }

    private func count() {
        let reached = store.count(tally.id)
        Haptics.count()
        if reached { celebrate() }
    }

    private func celebrate() {
        Haptics.goalReached()
        if UserDefaults.standard.bool(forKey: AppSettings.celebrate) {
            router.celebrateOnOpen = true
            router.openTally(tally.id)
        }
    }
}

/// The round button that counts without opening the stage.
private struct QuickCountButton: View {
    @Environment(TallyStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme
    let tally: Tally
    @State private var bumps = 0

    var body: some View {
        Button {
            bumps += 1
            let reached = store.count(tally.id)
            Haptics.count()
            if reached {
                Haptics.goalReached()
                if UserDefaults.standard.bool(forKey: AppSettings.celebrate) {
                    router.celebrateOnOpen = true
                    router.openTally(tally.id)
                }
            }
        } label: {
            Image(systemName: tally.direction == .up ? "plus" : "minus")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(theme.onTally(tally.colorIndex))
                .frame(width: 40, height: 40)
                .background(theme.tally(tally.colorIndex), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .symbolEffect(.bounce, value: bumps)
        }
        .buttonStyle(PressableStyle(scale: 0.86))
        .accessibilityLabel(tally.direction == .up ? "Add \(tally.step)" : "Take away \(tally.step)")
    }
}

/// Every action for a tally, shared by the long-press menu and the stage's menu.
struct TallyActions: View {
    @Environment(TallyStore.self) private var store
    @Environment(Router.self) private var router
    let tally: Tally
    var includeOpen = true

    var body: some View {
        if includeOpen {
            Button { router.openTally(tally.id) } label: {
                Label("Open", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            Button { store.count(tally.id); Haptics.count() } label: {
                Label(tally.direction == .up ? "Add \(tally.step)" : "Take away \(tally.step)",
                      systemImage: tally.direction == .up ? "plus" : "minus")
            }
        }
        Button { router.editor = .editTally(tally) } label: {
            Label("Edit", systemImage: "slider.horizontal.3")
        }
        Menu {
            Button { store.move(tally.id, to: nil) } label: {
                if tally.folderID == nil { Label("No folder", systemImage: "checkmark") } else { Text("No folder") }
            }
            ForEach(store.activeFolders) { folder in
                Button { store.move(tally.id, to: folder.id) } label: {
                    if tally.folderID == folder.id {
                        Label("\(folder.emoji) \(folder.displayName)", systemImage: "checkmark")
                    } else {
                        Text("\(folder.emoji) \(folder.displayName)")
                    }
                }
            }
        } label: {
            Label("Move to folder", systemImage: "folder")
        }
        Button { store.duplicate(tally.id) } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        Button { store.setHidden(tally.id, !tally.hidden) } label: {
            Label(tally.hidden ? "Unhide" : "Hide", systemImage: tally.hidden ? "eye" : "eye.slash")
        }
        Button { store.reset(tally.id) } label: {
            Label("Reset to \(tally.start)", systemImage: "arrow.counterclockwise")
        }
        Divider()
        Button { store.complete(tally.id); router.stageTallyID = nil } label: {
            Label("Complete", systemImage: "checkmark.circle")
        }
        Button { store.setArchived(tally.id, true); router.stageTallyID = nil } label: {
            Label("Archive", systemImage: "archivebox")
        }
        Button(role: .destructive) { store.delete(tally.id); router.stageTallyID = nil } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

/// The long-press preview: a small counting stage.
struct TallyPreviewCard: View {
    @Environment(\.theme) private var theme
    let tally: Tally

    var body: some View {
        LiquidStage(colorIndex: tally.colorIndex, level: tally.fillLevel, amplitude: 6, texture: false) { ink in
            VStack(spacing: 4) {
                Text("\(tally.emoji) \(tally.displayName)")
                    .font(.headline)
                    .lineLimit(1)
                Text("\(tally.value)")
                    .font(theme.numeralFont(size: 88))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(tally.hasGoal ? "\(tally.rangeText) · \(tally.statusText)" : tally.statusText)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(ink)
            .padding(Space.l)
        }
        .frame(width: 300, height: 240)
    }
}
