import SwiftUI
import UserNotifications

/// Settings, with Finished, Archive and Hidden inside it.
struct SettingsRoot: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.settingsPath) {
            SettingsView()
                .navigationDestination(for: Router.SettingsPage.self) { page in
                    switch page {
                    case .themes: ThemePickerView()
                    case .finished: FinishedView()
                    case .archive: ArchiveView()
                    case .hidden: HiddenView()
                    }
                }
        }
        .onDisappear { router.settingsPath = [] }
    }
}

struct SettingsView: View {
    @Environment(TallyStore.self) private var store
    @Environment(ThemeManager.self) private var themes
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettings.hapticEachTap) private var hapticEachTap = true
    @AppStorage(AppSettings.vibrateAtGoal) private var vibrateAtGoal = true
    @AppStorage(AppSettings.tapSound) private var tapSound = false
    @AppStorage(AppSettings.keepAwake) private var keepAwake = true
    @AppStorage(AppSettings.splitPanes) private var splitPanes = false
    @AppStorage(AppSettings.showMarks) private var showMarks = true
    @AppStorage(AppSettings.celebrate) private var celebrate = true

    @State private var notificationsAllowed: Bool?
    @State private var confirmErase = false

    var body: some View {
        List {
            Section {
                NavigationLink(value: Router.SettingsPage.themes) {
                    HStack(spacing: Space.m) {
                        ThemeSwatchStack(theme: theme)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Theme").foregroundStyle(theme.textColor)
                            Text(themes.activeHolidayID == nil ? theme.name : "\(theme.name) · holiday")
                                .font(.subheadline)
                                .foregroundStyle(theme.text2Color)
                        }
                    }
                    .padding(.vertical, 4)
                }
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Appearance").foregroundStyle(theme.textColor)
                    AppearancePicker()
                }
                .padding(.vertical, 4)
            }
            .themedRow(theme)

            Section {
                NavigationLink(value: Router.SettingsPage.finished) {
                    CountLabel(title: "Finished tallies", symbol: "flag.checkered.2.crossed", count: store.finishedTallies.count)
                }
                NavigationLink(value: Router.SettingsPage.archive) {
                    CountLabel(title: "Archive", symbol: "archivebox", count: store.archivedTallies.count + store.archivedFolders.count)
                }
                NavigationLink(value: Router.SettingsPage.hidden) {
                    CountLabel(title: "Hidden", symbol: "eye.slash", count: store.hiddenTallies.count + store.hiddenFolders.count)
                }
            } header: {
                Text("Your tallies")
            }
            .themedRow(theme)

            Section {
                Toggle(isOn: $hapticEachTap) { Label("Haptic on every count", systemImage: "hand.tap") }
                Toggle(isOn: $vibrateAtGoal) { Label("Vibrate hard at the goal", systemImage: "iphone.radiowaves.left.and.right") }
                Toggle(isOn: $tapSound) { Label("Click sound", systemImage: "speaker.wave.2") }
                Toggle(isOn: $keepAwake) { Label("Keep the screen on while counting", systemImage: "sun.max") }
                Toggle(isOn: $celebrate) { Label("Celebrate reaching a goal", systemImage: "party.popper") }
            } header: {
                Text("Counting")
            } footer: {
                Text("“Vibrate hard” uses a long, strong buzz you can feel in a pocket, for when you’re not looking at the screen.")
            }
            .themedRow(theme)

            Section {
                Toggle(isOn: $splitPanes.animation(Motion.standard)) { Label("Separate counting up and down", systemImage: "rectangle.split.2x1") }
                Toggle(isOn: $showMarks) { Label("Tally marks in the list", systemImage: "chart.bar.xaxis") }
            } header: {
                Text("Layout")
            } footer: {
                Text("Separating puts count-ups and countdowns in two panes on the home screen.")
            }
            .themedRow(theme)

            Section {
                HStack {
                    Label("Goal notifications", systemImage: "bell.badge")
                    Spacer()
                    switch notificationsAllowed {
                    case .some(true):
                        Text("On").foregroundStyle(theme.text2Color)
                    case .some(false):
                        Button("Turn on") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    case .none:
                        Button("Allow") {
                            GoalNotifier.requestPermission()
                            Task { try? await Task.sleep(for: .seconds(1)); await refreshNotifications() }
                        }
                    }
                }
                HStack {
                    Label("Apple Watch", systemImage: "applewatch")
                    Spacer()
                    Text(PhoneSync.shared.isWatchAppInstalled ? "Connected" : "Open Tallyho on your watch")
                        .font(.subheadline)
                        .foregroundStyle(theme.text2Color)
                }
            } header: {
                Text("Everywhere else")
            } footer: {
                Text("Widgets: touch and hold your Home Screen, tap Edit › Add Widget › Tallyho, then pick a tally. There’s also a Tallyho control for Control Center and the Action button.")
            }
            .themedRow(theme)

            Section {
                Button(role: .destructive) { confirmErase = true } label: {
                    Label("Erase everything", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Tallyho \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") · Count anything.")
            }
            .themedRow(theme)
        }
        .themedForm(theme)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.bold) }
        }
        .task { await refreshNotifications() }
        .confirmationDialog("Erase every tally and folder?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) { store.eraseEverything() }
        } message: {
            Text("You can undo right after, but not later.")
        }
    }

    private func refreshNotifications() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: notificationsAllowed = true
        case .denied: notificationsAllowed = false
        default: notificationsAllowed = nil
        }
    }
}

private struct CountLabel: View {
    @Environment(\.theme) private var theme
    let title: String
    let symbol: String
    let count: Int

    var body: some View {
        HStack {
            Label(title, systemImage: symbol).foregroundStyle(theme.textColor)
            Spacer()
            Text("\(count)").monospacedDigit().foregroundStyle(theme.text2Color)
        }
    }
}

/// Three overlapping dots in the theme's colors.
struct ThemeSwatchStack: View {
    let theme: TallyTheme
    var body: some View {
        HStack(spacing: -8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(theme.tally(i))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(theme.surfaceColor, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Finished

/// Every finished tally, grouped by the folder it came from, sortable and filterable by tag.
struct FinishedView: View {
    @Environment(TallyStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme
    @AppStorage(AppSettings.finishedSort) private var sortRaw = FinishedSort.recent.rawValue
    @State private var tag: String?
    @State private var detail: Tally?

    private var sort: FinishedSort { FinishedSort(rawValue: sortRaw) ?? .recent }

    private var groups: [(String, [Tally])] {
        let finished = store.finishedTallies.filter { tag == nil || $0.tags.contains(tag!) }
        let grouped = Dictionary(grouping: finished) { tally -> String in
            store.folder(tally.folderID)?.displayName ?? tally.folderNameSnapshot ?? "No folder"
        }
        return grouped
            .map { ($0.key, store.sortedFinished($0.value, by: sort)) }
            .sorted { a, b in
                if a.0 == "No folder" { return false }
                if b.0 == "No folder" { return true }
                return a.0.localizedCaseInsensitiveCompare(b.0) == .orderedAscending
            }
    }

    var body: some View {
        let tags = Array(Set(store.finishedTallies.flatMap(\.tags))).sorted()
        List {
            if !tags.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        Button { tag = nil } label: { chip("All", selected: tag == nil) }.buttonStyle(.plain)
                        ForEach(tags, id: \.self) { t in
                            Button { tag = (tag == t ? nil : t) } label: { TagChip(text: t, selected: tag == t) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            if groups.isEmpty {
                VStack(alignment: .leading, spacing: Space.s) {
                    TallyMarks(total: 5, filled: 5, color: theme.actionColor, empty: theme.text2Color, lineWidth: 5)
                        .frame(width: 90, height: 50)
                    Text("No finished tallies yet.")
                        .font(.system(.title3, design: theme.numeralDesign, weight: .bold))
                    Text("When you finish one, it lands here, filed under the folder it came from.")
                        .font(.subheadline)
                        .foregroundStyle(theme.text2Color)
                }
                .padding(.vertical, Space.xl)
                .listRowBackground(Color.clear)
            }
            ForEach(groups, id: \.0) { group in
                Section {
                    ForEach(group.1) { tally in
                        FinishedRow(tally: tally)
                            .contentShape(Rectangle())
                            .onTapGesture { detail = tally }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button { store.startAgain(from: tally.id) } label: {
                                    Label("Again", systemImage: "arrow.clockwise")
                                }
                                .tint(theme.actionColor)
                                Button(role: .destructive) { store.delete(tally.id) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button { store.startAgain(from: tally.id) } label: { Label("Start again", systemImage: "arrow.clockwise") }
                                Button { store.reopen(tally.id) } label: { Label("Move back to counting", systemImage: "arrow.uturn.backward") }
                                Button(role: .destructive) { store.delete(tally.id) } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                } header: {
                    Text(group.0)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.text2Color)
                        .textCase(nil)
                }
                .themedRow(theme)
            }
        }
        .themedForm(theme)
        .navigationTitle("Finished")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Sort by", selection: $sortRaw) {
                        ForEach(FinishedSort.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .sheet(item: $detail) { tally in
            FinishedDetail(tally: tally)
                .environment(store)
                .environment(router)
                .themedSheet(theme)
                .presentationDetents([.medium, .large])
        }
    }

    private func chip(_ text: String, selected: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(selected ? theme.onActionColor : theme.text2Color)
            .padding(.horizontal, Space.s)
            .padding(.vertical, 3)
            .background(selected ? theme.actionColor : theme.raisedColor, in: Capsule())
    }
}

private struct FinishedRow: View {
    @Environment(\.theme) private var theme
    let tally: Tally

    var body: some View {
        HStack(spacing: Space.m) {
            TallySwatch(text: tally.emojiOrInitial, colorIndex: tally.colorIndex, size: 40, finished: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(tally.displayName).font(.body.weight(.semibold)).foregroundStyle(theme.textColor)
                Text(detail).font(.caption).foregroundStyle(theme.text2Color).lineLimit(1)
                if !tally.tags.isEmpty {
                    HStack(spacing: 4) { ForEach(tally.tags.prefix(3), id: \.self) { TagChip(text: $0) } }
                }
            }
            Spacer(minLength: 0)
            Text("\(tally.value)")
                .font(theme.numeralFont(.title3, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(theme.textColor)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        var parts = [tally.rangeText]
        if let d = tally.duration { parts.append(Format.duration(d)) }
        if let done = tally.completedAt { parts.append(done.formatted(date: .abbreviated, time: .omitted)) }
        return parts.joined(separator: " · ")
    }
}

private struct FinishedDetail: View {
    @Environment(TallyStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let tally: Tally

    var body: some View {
        VStack(spacing: Space.l) {
            LiquidStage(colorIndex: tally.colorIndex, level: 1, amplitude: 0, texture: false) { ink in
                VStack(spacing: 4) {
                    Text("\(tally.emoji) \(tally.displayName)").font(.headline)
                    Text("\(tally.value)")
                        .font(theme.numeralFont(size: 80))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                    Text("Finished \(tally.completedAt?.formatted(date: .long, time: .omitted) ?? "")")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(ink)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            Grid(alignment: .leading, horizontalSpacing: Space.l, verticalSpacing: Space.s) {
                GridRow { stat("Range", tally.rangeText); stat("Taps", "\(tally.taps)") }
                GridRow {
                    stat("Took", tally.duration.map(Format.duration) ?? "—")
                    stat("Folder", store.folder(tally.folderID)?.displayName ?? tally.folderNameSnapshot ?? "None")
                }
            }
            Spacer(minLength: 0)
            Button {
                if let fresh = store.startAgain(from: tally.id) {
                    dismiss()
                    router.showSettings = false
                    Task { try? await Task.sleep(for: .milliseconds(450)); router.openTally(fresh.id) }
                }
            } label: {
                Label("Start again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Space.l)
        .background(theme.backgroundColor.ignoresSafeArea())
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(theme.text2Color)
            Text(value).font(.body.weight(.semibold)).foregroundStyle(theme.textColor).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Archive and hidden

struct ArchiveView: View {
    @Environment(TallyStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        List {
            if store.archivedFolders.isEmpty && store.archivedTallies.isEmpty {
                Text("Nothing archived. Swipe left on a tally or folder to archive it.")
                    .font(.subheadline)
                    .foregroundStyle(theme.text2Color)
                    .listRowBackground(Color.clear)
            }
            if !store.archivedFolders.isEmpty {
                Section("Folders") {
                    ForEach(store.archivedFolders) { folder in
                        let inside = store.data.tallies.filter { $0.folderID == folder.id && !$0.isFinished }.count
                        HStack {
                            Text("\(folder.emoji) \(folder.displayName)").foregroundStyle(theme.textColor)
                            Spacer()
                            Text("\(inside) tall\(inside == 1 ? "y" : "ies")").font(.subheadline).foregroundStyle(theme.text2Color)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button { store.setFolderArchived(folder.id, false) } label: { Label("Restore", systemImage: "tray.and.arrow.up") }
                                .tint(theme.actionColor)
                            Button(role: .destructive) { store.deleteFolder(folder.id, keepTallies: false) } label: { Label("Delete", systemImage: "trash") }
                        }
                        .contextMenu {
                            Button { store.setFolderArchived(folder.id, false) } label: { Label("Restore folder and its tallies", systemImage: "tray.and.arrow.up") }
                            Button(role: .destructive) { store.deleteFolder(folder.id, keepTallies: false) } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
                .themedRow(theme)
            }
            if !store.archivedTallies.isEmpty {
                Section("Tallies") {
                    ForEach(store.archivedTallies) { tally in
                        HStack(spacing: Space.m) {
                            TallySwatch(text: tally.emojiOrInitial, colorIndex: tally.colorIndex, size: 36)
                            VStack(alignment: .leading) {
                                Text(tally.displayName).foregroundStyle(theme.textColor)
                                Text("\(tally.value) · \(tally.rangeText)").font(.caption).foregroundStyle(theme.text2Color)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button { restore(tally) } label: { Label("Restore", systemImage: "tray.and.arrow.up") }
                                .tint(theme.actionColor)
                            Button(role: .destructive) { store.delete(tally.id) } label: { Label("Delete", systemImage: "trash") }
                        }
                        .contextMenu {
                            Button { restore(tally) } label: { Label("Restore", systemImage: "tray.and.arrow.up") }
                            Button(role: .destructive) { store.delete(tally.id) } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
                .themedRow(theme)
            }
        }
        .themedForm(theme)
        .navigationTitle("Archive")
    }

    /// Restoring a tally from an archived folder moves it out of that folder so it shows up again.
    private func restore(_ tally: Tally) {
        if let folder = store.folder(tally.folderID), folder.archived {
            store.move(tally.id, to: nil)
        }
        store.setArchived(tally.id, false)
    }
}

struct HiddenView: View {
    @Environment(TallyStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        List {
            if store.hiddenFolders.isEmpty && store.hiddenTallies.isEmpty {
                Text("Nothing hidden. Swipe right on a tally, or touch and hold a folder, to hide it.")
                    .font(.subheadline)
                    .foregroundStyle(theme.text2Color)
                    .listRowBackground(Color.clear)
            }
            if !store.hiddenFolders.isEmpty {
                Section("Folders") {
                    ForEach(store.hiddenFolders) { folder in
                        HStack {
                            Text("\(folder.emoji) \(folder.displayName)").foregroundStyle(theme.textColor)
                            Spacer()
                            Button("Unhide") { store.setFolderHidden(folder.id, false) }.fontWeight(.semibold)
                        }
                    }
                }
                .themedRow(theme)
            }
            if !store.hiddenTallies.isEmpty {
                Section("Tallies") {
                    ForEach(store.hiddenTallies) { tally in
                        HStack(spacing: Space.m) {
                            TallySwatch(text: tally.emojiOrInitial, colorIndex: tally.colorIndex, size: 36)
                            Text(tally.displayName).foregroundStyle(theme.textColor)
                            Spacer()
                            Button("Unhide") { store.setHidden(tally.id, false) }.fontWeight(.semibold)
                        }
                    }
                }
                .themedRow(theme)
            }
            Section {
                Text("Hidden tallies keep their counts. They stay off the home list, your watch and widget suggestions until you unhide them. To see them in place, turn on “Show hidden” in the home screen’s filter menu.")
                    .font(.footnote)
                    .foregroundStyle(theme.text2Color)
                    .listRowBackground(Color.clear)
            }
        }
        .themedForm(theme)
        .navigationTitle("Hidden")
    }
}
