import SwiftUI

/// The home list: loose tallies first, then folders. Things-style: type and space, not boxes.
struct HomeView: View {
    @Environment(TallyStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme

    @AppStorage(AppSettings.homeSort) private var sortRaw = TallySort.lastUsed.rawValue
    @AppStorage(AppSettings.homeDirection) private var directionRaw = "all"
    @AppStorage(AppSettings.homePane) private var paneRaw = "up"
    @AppStorage(AppSettings.homeTags) private var tagsRaw = ""
    @AppStorage(AppSettings.homeGoalOnly) private var goalOnly = false
    @AppStorage(AppSettings.homeShowHidden) private var showHidden = false
    @AppStorage(AppSettings.splitPanes) private var splitPanes = false

    @State private var searching = false
    @State private var query = ""
    @State private var folderToDelete: TallyFolder?

    private var sort: TallySort { TallySort(rawValue: sortRaw) ?? .lastUsed }
    private var selectedTags: Set<String> {
        Set(tagsRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    /// Active tallies after every filter, sorted.
    private var visibleTallies: [Tally] {
        let base = store.homeTallies(showHidden: showHidden).filter { tally in
            if splitPanes {
                if tally.direction.rawValue != paneRaw { return false }
            } else if directionRaw != "all" && tally.direction.rawValue != directionRaw {
                return false
            }
            if goalOnly && !tally.hasGoal { return false }
            if !selectedTags.isEmpty && selectedTags.isDisjoint(with: tally.tags) { return false }
            if !query.isEmpty {
                let q = query.lowercased()
                let inName = tally.displayName.lowercased().contains(q)
                let inTags = tally.tags.contains { $0.lowercased().contains(q) }
                if !inName && !inTags { return false }
            }
            return true
        }
        return store.sorted(base, by: sort)
    }

    private var visibleFolders: [TallyFolder] {
        store.activeFolders.filter { showHidden || !$0.hidden }
    }

    private var isFiltering: Bool {
        !query.isEmpty || goalOnly || !selectedTags.isEmpty || (!splitPanes && directionRaw != "all")
    }

    var body: some View {
        let tallies = visibleTallies
        let loose = tallies.filter { tally in tally.folderID == nil || store.folder(tally.folderID) == nil }
        List {
            HomeHeader(searching: $searching, query: $query, counting: tallies.count)
                .homeRow()

            if splitPanes {
                PaneSwitcher(pane: $paneRaw)
                    .homeRow()
            }

            if isFiltering {
                FilterSummary(query: query, tags: selectedTags, goalOnly: goalOnly, direction: splitPanes ? "all" : directionRaw) {
                    query = ""; tagsRaw = ""; goalOnly = false; directionRaw = "all"
                }
                .homeRow()
            }

            if store.homeTallies(showHidden: true).isEmpty && store.activeFolders.isEmpty {
                EmptyHome()
                    .homeRow()
            } else if tallies.isEmpty && isFiltering {
                Text("Nothing matches. Try another filter.")
                    .font(.subheadline)
                    .foregroundStyle(theme.text2Color)
                    .padding(.vertical, Space.xl)
                    .homeRow()
            }

            ForEach(loose) { tally in
                TallyRow(tally: tally)
                    .homeRow(vertical: 2)
            }

            ForEach(visibleFolders) { folder in
                let inside = tallies.filter { $0.folderID == folder.id }
                FolderHeader(folder: folder, count: inside.count, onDelete: { folderToDelete = folder })
                    .homeRow(vertical: 0)
                    .padding(.top, Space.m)
                if !folder.collapsed {
                    ForEach(inside) { tally in
                        TallyRow(tally: tally)
                            .homeRow(vertical: 2)
                    }
                    if inside.isEmpty && !isFiltering {
                        if let last = store.lastFinished(in: folder.id) {
                            AgainRow(tally: last)
                                .homeRow(vertical: 2)
                        } else {
                            Button {
                                router.editor = .newTally(folderID: folder.id, template: nil)
                            } label: {
                                Label("Add a tally to \(folder.displayName)", systemImage: "plus")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(theme.text2Color)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .padding(.leading, 56)
                            }
                            .buttonStyle(.plain)
                            .homeRow(vertical: 0)
                        }
                    }
                }
            }

            Color.clear.frame(height: 110)
                .homeRow(vertical: 0)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ThemeBackground())
        .toolbar(.hidden, for: .navigationBar)
        .animation(Motion.standard, value: tallies.map(\.id))
        .animation(Motion.standard, value: store.data.folders)
        .overlay(alignment: .bottomTrailing) {
            NewButton()
                .padding(.trailing, Space.xl)
                .padding(.bottom, Space.l)
        }
        .confirmationDialog(
            "Delete “\(folderToDelete?.displayName ?? "")”?",
            isPresented: Binding(get: { folderToDelete != nil }, set: { if !$0 { folderToDelete = nil } }),
            titleVisibility: .visible
        ) {
            if let folder = folderToDelete {
                Button("Delete folder, keep its tallies") { store.deleteFolder(folder.id, keepTallies: true) }
                Button("Delete folder and its tallies", role: .destructive) { store.deleteFolder(folder.id, keepTallies: false) }
            }
        } message: {
            Text("Finished tallies from this folder stay in Finished either way.")
        }
    }
}

private extension View {
    func homeRow(vertical: CGFloat = 0) -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: vertical, leading: Space.l, bottom: vertical, trailing: Space.l))
    }
}

// MARK: - Header

private struct HomeHeader: View {
    @Environment(TallyStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme
    @Binding var searching: Bool
    @Binding var query: String
    let counting: Int
    @FocusState private var focused: Bool

    private var reachedCount: Int {
        store.homeTallies(showHidden: false).filter(\.isGoalReached).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .center, spacing: Space.s) {
                Text("Tallies")
                    .font(.system(.largeTitle, design: theme.numeralDesign, weight: .heavy))
                    .foregroundStyle(theme.textColor)
                Spacer()
                GlassIconButton(systemImage: "magnifyingglass", label: "Search") {
                    withAnimation(Motion.standard) { searching.toggle() }
                    if !searching { query = "" } else { focused = true }
                }
                SortFilterMenu()
                GlassIconButton(systemImage: "gearshape", label: "Settings") {
                    router.showSettings = true
                }
            }
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.text2Color)
                .contentTransition(.numericText())
            if searching {
                HStack(spacing: Space.s) {
                    Image(systemName: "magnifyingglass").foregroundStyle(theme.text2Color)
                    TextField("Search names and tags", text: $query)
                        .focused($focused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(theme.textColor)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(theme.text2Color)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, Space.m)
                .frame(minHeight: 44)
                .background(theme.raisedColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, Space.s)
        .padding(.bottom, Space.s)
    }

    private var subtitle: String {
        let date = Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        if counting == 0 { return date }
        let counts = "\(counting) counting"
        return reachedCount > 0 ? "\(date) · \(counts) · \(reachedCount) at goal" : "\(date) · \(counts)"
    }
}

private struct SortFilterMenu: View {
    @Environment(TallyStore.self) private var store
    @Environment(Router.self) private var router
    @AppStorage(AppSettings.homeSort) private var sortRaw = TallySort.lastUsed.rawValue
    @AppStorage(AppSettings.homeDirection) private var directionRaw = "all"
    @AppStorage(AppSettings.homeTags) private var tagsRaw = ""
    @AppStorage(AppSettings.homeGoalOnly) private var goalOnly = false
    @AppStorage(AppSettings.homeShowHidden) private var showHidden = false
    @AppStorage(AppSettings.splitPanes) private var splitPanes = false

    private var selected: Set<String> { Set(tagsRaw.split(separator: ",").map(String.init)) }

    var body: some View {
        Menu {
            Section("Sort by") {
                Picker("Sort by", selection: $sortRaw) {
                    ForEach(TallySort.allCases) { sort in
                        Label(sort.title, systemImage: sort.symbol).tag(sort.rawValue)
                    }
                }
                .pickerStyle(.inline)
            }
            Section("Show") {
                if !splitPanes {
                    Picker("Direction", selection: $directionRaw) {
                        Label("Everything", systemImage: "arrow.up.arrow.down").tag("all")
                        Label("Counting up", systemImage: "arrow.up").tag("up")
                        Label("Counting down", systemImage: "arrow.down").tag("down")
                    }
                    .pickerStyle(.menu)
                }
                Toggle(isOn: $goalOnly) { Label("Only with a goal", systemImage: "flag.checkered") }
                Toggle(isOn: $showHidden) { Label("Show hidden", systemImage: "eye") }
                if !store.allTags.isEmpty {
                    Menu {
                        ForEach(store.allTags, id: \.self) { tag in
                            Button {
                                var set = selected
                                if set.contains(tag) { set.remove(tag) } else { set.insert(tag) }
                                tagsRaw = set.sorted().joined(separator: ",")
                            } label: {
                                if selected.contains(tag) {
                                    Label("#\(tag)", systemImage: "checkmark")
                                } else {
                                    Text("#\(tag)")
                                }
                            }
                        }
                        if !selected.isEmpty {
                            Divider()
                            Button("Clear tags") { tagsRaw = "" }
                        }
                    } label: {
                        Label(selected.isEmpty ? "Tags" : "Tags (\(selected.count))", systemImage: "number")
                    }
                }
            }
            Section {
                Button { router.settingsPath = [.finished]; router.showSettings = true } label: {
                    Label("Finished tallies", systemImage: "flag.checkered.2.crossed")
                }
                Button { router.settingsPath = [.archive]; router.showSettings = true } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 16.7, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel("Sort and filter")
    }
}

/// Counting up | Counting down, when the two are split into panes.
private struct PaneSwitcher: View {
    @Environment(TallyStore.self) private var store
    @Environment(\.theme) private var theme
    @Binding var pane: String
    @Namespace private var namespace

    var body: some View {
        let all = store.homeTallies(showHidden: false)
        HStack(spacing: 0) {
            segment("up", title: "Counting up", symbol: "arrow.up", count: all.filter { $0.direction == .up }.count)
            segment("down", title: "Counting down", symbol: "arrow.down", count: all.filter { $0.direction == .down }.count)
        }
        .padding(4)
        .background(theme.raisedColor, in: Capsule())
        .padding(.bottom, Space.s)
    }

    private func segment(_ value: String, title: String, symbol: String, count: Int) -> some View {
        let selected = pane == value
        return Button {
            withAnimation(Motion.bouncy) { pane = value }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.footnote.weight(.bold))
                Text(title).font(.subheadline.weight(.semibold))
                Text("\(count)").font(.footnote.weight(.bold)).monospacedDigit()
                    .foregroundStyle(selected ? theme.onActionColor.opacity(0.8) : theme.text2Color)
            }
            .foregroundStyle(selected ? theme.onActionColor : theme.textColor)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background {
                if selected {
                    Capsule().fill(theme.actionColor).matchedGeometryEffect(id: "pane", in: namespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct FilterSummary: View {
    @Environment(\.theme) private var theme
    let query: String
    let tags: Set<String>
    let goalOnly: Bool
    let direction: String
    let clear: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.s) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(theme.text2Color)
                if !query.isEmpty { chip("“\(query)”") }
                if direction != "all" { chip(direction == "up" ? "Counting up" : "Counting down") }
                if goalOnly { chip("With a goal") }
                ForEach(tags.sorted(), id: \.self) { TagChip(text: $0, selected: true) }
                Button("Clear", action: clear)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.actionColor)
                    .frame(minHeight: 32)
            }
        }
        .scrollIndicators(.hidden)
        .padding(.bottom, Space.xs)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.onActionColor)
            .padding(.horizontal, Space.s)
            .padding(.vertical, 3)
            .background(theme.actionColor, in: Capsule())
    }
}

// MARK: - Folders

private struct FolderHeader: View {
    @Environment(TallyStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme
    let folder: TallyFolder
    let count: Int
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Space.m) {
            ZStack {
                Circle().fill(theme.tally(folder.colorIndex).opacity(0.22))
                Text(folder.emoji.isEmpty ? "📁" : folder.emoji).font(.system(size: 15))
            }
            .frame(width: 30, height: 30)
            .padding(.leading, 8)
            Text(folder.displayName)
                .font(.system(.title3, design: theme.numeralDesign, weight: .bold))
                .foregroundStyle(theme.textColor)
                .lineLimit(2)
            if folder.hidden {
                Image(systemName: "eye.slash").font(.footnote).foregroundStyle(theme.text2Color)
            }
            Text("\(count)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(theme.text2Color)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.footnote.weight(.bold))
                .foregroundStyle(theme.text2Color)
                .rotationEffect(.degrees(folder.collapsed ? -90 : 0))
            Button {
                router.editor = .newTally(folderID: folder.id, template: nil)
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.actionColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a tally to \(folder.displayName)")
        }
        .frame(minHeight: 48)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.dividerColor).frame(height: 1).padding(.leading, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(Motion.standard) { store.toggleCollapsed(folder.id) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(folder.displayName) folder, \(count) tallies, \(folder.collapsed ? "collapsed" : "expanded")")
        .accessibilityAddTraits(.isButton)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button { store.setFolderArchived(folder.id, true) } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(.indigo)
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
        .swipeActions(edge: .leading) {
            Button { store.setFolderHidden(folder.id, !folder.hidden) } label: {
                Label(folder.hidden ? "Unhide" : "Hide", systemImage: folder.hidden ? "eye" : "eye.slash")
            }
            .tint(.gray)
        }
        .contextMenu {
            Button { router.editor = .newTally(folderID: folder.id, template: nil) } label: {
                Label("New tally here", systemImage: "plus")
            }
            Button { router.editor = .editFolder(folder) } label: {
                Label("Edit folder", systemImage: "pencil")
            }
            Button { store.toggleCollapsed(folder.id) } label: {
                Label(folder.collapsed ? "Expand" : "Collapse", systemImage: folder.collapsed ? "chevron.down" : "chevron.up")
            }
            Button { store.setFolderHidden(folder.id, !folder.hidden) } label: {
                Label(folder.hidden ? "Unhide folder" : "Hide folder", systemImage: folder.hidden ? "eye" : "eye.slash")
            }
            Divider()
            Button { store.setFolderArchived(folder.id, true) } label: {
                Label("Archive folder and its tallies", systemImage: "archivebox")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete folder…", systemImage: "trash")
            }
        }
    }
}

/// A faded copy of the last finished tally in an empty folder: "Start again?"
private struct AgainRow: View {
    @Environment(TallyStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme
    let tally: Tally

    var body: some View {
        HStack(spacing: Space.m) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.tally(tally.colorIndex), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                Text(tally.emojiOrInitial).font(.system(size: 20)).opacity(0.6)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Start again?")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.text2Color)
                Text(tally.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.textColor.opacity(0.6))
                Text("Last time \(tally.rangeText)\(tally.completedAt.map { " · finished " + Format.relative($0) } ?? "")")
                    .font(.caption)
                    .foregroundStyle(theme.text2Color)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                router.editor = .newTally(folderID: tally.folderID, template: tally)
            } label: {
                Text("Again")
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.actionColor)
                    .padding(.horizontal, Space.m)
                    .frame(minHeight: 36)
                    .overlay(Capsule().strokeBorder(theme.actionColor, lineWidth: 1.5))
                    .frame(minHeight: 44)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.vertical, Space.s)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Starts a new tally like this one")
    }
}

// MARK: - New

private struct NewButton: View {
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme

    var body: some View {
        Menu {
            Button { router.editor = .newTally(folderID: nil, template: nil) } label: {
                Label("New tally", systemImage: "plus")
            }
            Button { router.editor = .newFolder } label: {
                Label("New folder", systemImage: "folder.badge.plus")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(theme.onActionColor)
                .frame(width: 62, height: 62)
                .contentShape(Circle())
        } primaryAction: {
            router.editor = .newTally(folderID: nil, template: nil)
        }
        .glassEffect(.regular.tint(theme.actionColor).interactive(), in: Circle())
        .accessibilityLabel("New tally")
        .accessibilityHint("Touch and hold for a new folder")
    }
}

// MARK: - Empty

private struct EmptyHome: View {
    @Environment(TallyStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme

    private var starters: [Tally] {
        [
            Tally(name: "Glasses of water", emoji: "💧", colorIndex: 1, tags: ["health"], target: 8),
            Tally(name: "Push-ups", emoji: "💪", colorIndex: 0, target: 100, step: 5, undoStep: 5),
            Tally(name: "Days to go", emoji: "⏳", colorIndex: 4, direction: .down, start: 30, target: 0),
            Tally(name: "Pages read", emoji: "📖", colorIndex: 3, target: 300, step: 10, undoStep: 10),
            Tally(name: "Movie clichés", emoji: "🍿", colorIndex: 5),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            TallyMarks(total: 5, filled: 4, color: theme.actionColor, empty: theme.text2Color.opacity(0.3), lineWidth: 6)
                .frame(width: 120, height: 70)
                .padding(.top, Space.xl)
            Text("Nothing to count yet.")
                .font(.system(.title, design: theme.numeralDesign, weight: .heavy))
                .foregroundStyle(theme.textColor)
            Text("Tap + to start a tally, or pick one of these. You can count up to a goal, down to zero, or just keep counting.")
                .font(.body)
                .foregroundStyle(theme.text2Color)
            let recent = store.recentTemplates
            FlowChips(items: (recent.isEmpty ? starters : recent)) { tally in
                router.editor = .newTally(folderID: nil, template: tally)
            }
        }
        .padding(.bottom, Space.xl)
    }
}

/// Wrapping chips for starter templates.
private struct FlowChips: View {
    @Environment(\.theme) private var theme
    let items: [Tally]
    let pick: (Tally) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            ForEach(items) { tally in
                Button { pick(tally) } label: {
                    HStack(spacing: Space.s) {
                        Text(tally.emojiOrInitial)
                        Text(tally.displayName).font(.subheadline.weight(.semibold))
                        Text(tally.rangeText).font(.caption).foregroundStyle(theme.text2Color)
                    }
                    .foregroundStyle(theme.textColor)
                    .padding(.horizontal, Space.m)
                    .frame(minHeight: 44)
                    .background(theme.surfaceColor, in: Capsule())
                    .overlay(Capsule().strokeBorder(theme.tally(tally.colorIndex), lineWidth: 1.5))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}
