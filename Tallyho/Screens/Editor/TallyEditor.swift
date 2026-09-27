import SwiftUI

/// Routes an editor request to the right sheet.
struct EditorSheet: View {
    @Environment(TallyStore.self) private var store
    let editor: Router.Editor

    var body: some View {
        switch editor {
        case .newTally(let folderID, let template):
            TallyEditor(original: nil, folderID: folderID, template: template)
        case .editTally(let tally):
            TallyEditor(original: tally, folderID: tally.folderID, template: nil)
        case .newFolder:
            FolderEditor(original: nil)
        case .newFolderHolding(let tallyID):
            FolderEditor(original: nil) { folder in
                withAnimation(Motion.standard) { store.move(tallyID, to: folder.id) }
            }
        case .editFolder(let folder):
            FolderEditor(original: folder)
        }
    }
}

/// Create or edit a tally. The setup reads as a sentence: "Count up from 20 to 70, 1 per tap."
struct TallyEditor: View {
    @Environment(TallyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    let original: Tally?
    @State private var draft: Tally
    @State private var hasGoal: Bool
    @State private var goal: Int
    @State private var newTag = ""
    @State private var pickingEmoji = false
    @State private var confirmDelete = false
    @State private var creatingFolder = false
    @FocusState private var nameFocused: Bool

    init(original: Tally?, folderID: UUID?, template: Tally?) {
        self.original = original
        var start: Tally
        if let original {
            start = original
        } else if let template {
            start = template.makeAgain(in: folderID ?? template.folderID)
        } else {
            start = Tally(name: "", colorIndex: Int.random(in: 0..<TallyTheme.tallyColorCount), folderID: folderID, target: 10)
        }
        _draft = State(initialValue: start)
        _hasGoal = State(initialValue: start.target != nil)
        _goal = State(initialValue: start.target ?? (start.direction == .up ? start.start + 10 : 0))
    }

    private var isNew: Bool { original == nil }

    private var goalProblem: String? {
        guard hasGoal else { return nil }
        if draft.direction == .up && goal <= draft.start { return "Counting up needs a goal above \(draft.start)." }
        if draft.direction == .down && goal >= draft.start { return "Counting down needs a goal below \(draft.start)." }
        return nil
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && goalProblem == nil
    }

    /// The draft as it would be saved, for the live preview.
    private var preview: Tally {
        var t = draft
        t.target = hasGoal ? goal : nil
        if isNew { t.value = t.start }
        return t
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    previewCard
                    if isNew && !store.recentTemplates.isEmpty { againChips }
                    nameAndEmoji
                    colorPicker
                    sentence
                    if !isNew { currentCount }
                    folderAndTags
                    options
                    if !isNew { deleteButton }
                }
                .padding(.horizontal, Space.l)
                .padding(.bottom, Space.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(theme.backgroundColor.ignoresSafeArea())
            .navigationTitle(isNew ? "New tally" : "Edit tally")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Start" : "Save") { save() }
                        .fontWeight(.bold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $pickingEmoji) {
                EmojiPicker(selection: $draft.emoji)
                    .themedSheet(theme)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $creatingFolder) {
                FolderEditor(original: nil) { folder in draft.folderID = folder.id }
                    .environment(store)
                    .themedSheet(theme)
            }
            .confirmationDialog("Delete “\(draft.displayName)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.delete(draft.id)
                    Router.shared.stageTallyID = nil
                    dismiss()
                }
            }
            .onAppear { if isNew && draft.name.isEmpty { nameFocused = true } }
        }
    }

    // MARK: Sections

    private var previewCard: some View {
        LiquidStage(colorIndex: draft.colorIndex, level: preview.fillLevel, amplitude: 5, texture: false) { ink in
            HStack(alignment: .center, spacing: Space.m) {
                Text(preview.emojiOrInitial)
                    .font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text(preview.name.isEmpty ? "Your tally" : preview.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(preview.hasGoal ? "\(preview.rangeText) · \(preview.statusText)" : preview.statusText)
                        .font(.subheadline.weight(.semibold))
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
                Text("\(preview.value)")
                    .font(theme.numeralFont(size: 56))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: Double(preview.value)))
            }
            .foregroundStyle(ink)
            .padding(.horizontal, Space.l)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .animation(Motion.standard, value: preview.fillLevel)
        .animation(Motion.standard, value: draft.colorIndex)
        .padding(.top, Space.s)
        .accessibilityHidden(true)
    }

    private var againChips: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("Again?")
            ScrollView(.horizontal) {
                HStack(spacing: Space.s) {
                    ForEach(store.recentTemplates) { template in
                        Button {
                            withAnimation(Motion.standard) { apply(template) }
                        } label: {
                            HStack(spacing: 6) {
                                Text(template.emojiOrInitial)
                                Text(template.displayName).font(.subheadline.weight(.semibold))
                                Text(template.rangeText).font(.caption).foregroundStyle(theme.text2Color)
                            }
                            .foregroundStyle(theme.textColor)
                            .padding(.horizontal, Space.m)
                            .frame(minHeight: 40)
                            .background(theme.surfaceColor, in: Capsule())
                            .overlay(Capsule().strokeBorder(theme.tally(template.colorIndex), lineWidth: 1.5))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var nameAndEmoji: some View {
        HStack(spacing: Space.m) {
            Button { pickingEmoji = true } label: {
                TallySwatch(text: draft.emojiOrInitial, colorIndex: draft.colorIndex, size: 56)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "face.smiling")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.onActionColor)
                            .padding(4)
                            .background(theme.actionColor, in: Circle())
                            .offset(x: 4, y: 4)
                    }
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Choose an emoji")
            TextField("Name this tally", text: $draft.name)
                .font(.system(.title2, design: theme.numeralDesign, weight: .bold))
                .foregroundStyle(theme.textColor)
                .focused($nameFocused)
                .submitLabel(.done)
        }
    }

    private var colorPicker: some View {
        HStack(spacing: Space.m) {
            ForEach(0..<TallyTheme.tallyColorCount, id: \.self) { index in
                let selected = draft.colorIndex == index
                Button {
                    withAnimation(Motion.quick) { draft.colorIndex = index }
                } label: {
                    Circle()
                        .fill(theme.tally(index))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(theme.backgroundColor, lineWidth: selected ? 3 : 0).padding(2))
                        .overlay(Circle().strokeBorder(theme.textColor, lineWidth: selected ? 2 : 0))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Color \(index + 1)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    /// "Count up · from 20 · to 70 · 1 per tap"
    private var sentence: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("How it counts")
            VStack(spacing: 0) {
                SentenceRow(lead: "Count") {
                    Picker("Direction", selection: Binding(
                        get: { draft.direction },
                        set: { setDirection($0) }
                    )) {
                        Label("Up", systemImage: "arrow.up").tag(CountDirection.up)
                        Label("Down", systemImage: "arrow.down").tag(CountDirection.down)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }
                Divider().overlay(theme.dividerColor)
                SentenceRow(lead: "from") {
                    NumberStepper(value: $draft.start, step: draft.step)
                }
                Divider().overlay(theme.dividerColor)
                SentenceRow(lead: "to") {
                    if hasGoal {
                        NumberStepper(value: $goal, step: draft.step)
                    } else {
                        Text("No goal · keeps counting")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.text2Color)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                Toggle("Set a goal", isOn: $hasGoal.animation(Motion.standard))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textColor)
                    .padding(.horizontal, Space.l)
                    .frame(minHeight: 48)
                Divider().overlay(theme.dividerColor)
                SentenceRow(lead: draft.direction == .up ? "each tap adds" : "each tap takes") {
                    NumberStepper(value: $draft.step, step: 1, minimum: 1)
                }
                Divider().overlay(theme.dividerColor)
                SentenceRow(lead: "the undo button") {
                    NumberStepper(value: $draft.undoStep, step: 1, minimum: 1)
                }
            }
            .background(theme.surfaceColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            if let goalProblem {
                Label(goalProblem, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.actionColor)
            }
        }
    }

    private var currentCount: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Right now")
            SentenceRow(lead: "current count") {
                NumberStepper(value: $draft.value, step: draft.step)
            }
            .background(theme.surfaceColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var folderAndTags: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Organize")
            VStack(spacing: 0) {
                HStack {
                    Text("Folder").foregroundStyle(theme.textColor)
                    Spacer()
                    Menu {
                        Button { draft.folderID = nil } label: {
                            if draft.folderID == nil { Label("No folder", systemImage: "checkmark") } else { Text("No folder") }
                        }
                        ForEach(store.activeFolders) { folder in
                            Button { draft.folderID = folder.id } label: {
                                if draft.folderID == folder.id {
                                    Label("\(folder.emoji) \(folder.displayName)", systemImage: "checkmark")
                                } else {
                                    Text("\(folder.emoji) \(folder.displayName)")
                                }
                            }
                        }
                        Divider()
                        Button { creatingFolder = true } label: { Label("New folder…", systemImage: "folder.badge.plus") }
                    } label: {
                        HStack(spacing: 4) {
                            Text(store.folder(draft.folderID).map { "\($0.emoji) \($0.displayName)" } ?? "None")
                            Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.bold))
                        }
                        .foregroundStyle(theme.actionColor)
                        .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, Space.l)
                Divider().overlay(theme.dividerColor)
                VStack(alignment: .leading, spacing: Space.s) {
                    if !draft.tags.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 6) {
                                ForEach(draft.tags, id: \.self) { tag in
                                    Button {
                                        withAnimation(Motion.quick) { draft.tags.removeAll { $0 == tag } }
                                    } label: {
                                        HStack(spacing: 3) {
                                            TagChip(text: tag, selected: true)
                                            Image(systemName: "xmark").font(.caption2.weight(.bold)).foregroundStyle(theme.text2Color)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove tag \(tag)")
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                    HStack {
                        Image(systemName: "number").foregroundStyle(theme.text2Color)
                        TextField("Add a tag", text: $newTag)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit(addTag)
                        if !newTag.isEmpty {
                            Button("Add", action: addTag).fontWeight(.semibold)
                        }
                    }
                    .frame(minHeight: 44)
                    let suggestions = store.allTags.filter { !draft.tags.contains($0) }
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 6) {
                                ForEach(suggestions, id: \.self) { tag in
                                    Button { withAnimation(Motion.quick) { draft.tags.append(tag) } } label: { TagChip(text: tag) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .padding(.bottom, Space.s)
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
            }
            .background(theme.surfaceColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Options")
            VStack(spacing: 0) {
                Toggle(isOn: $draft.notifyAtGoal) {
                    Label("Tell me when I reach the goal", systemImage: "bell.badge")
                }
                .disabled(!hasGoal)
                .padding(.horizontal, Space.l)
                .frame(minHeight: 52)
                Divider().overlay(theme.dividerColor)
                Toggle(isOn: $draft.hidden) {
                    Label("Hide from the main list", systemImage: "eye.slash")
                }
                .padding(.horizontal, Space.l)
                .frame(minHeight: 52)
            }
            .foregroundStyle(theme.textColor)
            .background(theme.surfaceColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) { confirmDelete = true } label: {
            Label("Delete tally", systemImage: "trash")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    // MARK: Actions

    private func apply(_ template: Tally) {
        let folderID = draft.folderID ?? template.folderID
        var fresh = template.makeAgain(in: store.folder(folderID) == nil ? nil : folderID)
        fresh.id = draft.id
        draft = fresh
        hasGoal = fresh.target != nil
        goal = fresh.target ?? goal
    }

    private func setDirection(_ direction: CountDirection) {
        withAnimation(Motion.standard) {
            guard direction != draft.direction else { return }
            draft.direction = direction
            // Keep the setup sensible: a countdown starts high and ends low.
            if direction == .down && (!hasGoal || goal >= draft.start) {
                let top = max(draft.start, hasGoal ? goal : 10, 1)
                draft.start = top
                goal = 0
                hasGoal = true
            } else if direction == .up && hasGoal && goal <= draft.start {
                let low = min(draft.start, goal)
                let high = max(draft.start, goal)
                draft.start = low
                goal = high == low ? low + 10 : high
            }
            if isNew { draft.value = draft.start }
        }
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: ",", with: "")
        if !tag.isEmpty && !draft.tags.contains(tag) {
            withAnimation(Motion.quick) { draft.tags.append(tag) }
        }
        newTag = ""
    }

    private func save() {
        var tally = draft
        tally.name = tally.name.trimmingCharacters(in: .whitespacesAndNewlines)
        tally.target = hasGoal ? goal : nil
        if isNew {
            tally.value = tally.start
            tally.createdAt = Date()
        }
        if !tally.isGoalReached { tally.goalReachedAt = nil }
        store.save(tally)
        if tally.hasGoal && tally.notifyAtGoal { GoalNotifier.requestPermission() }
        dismiss()
    }
}

// MARK: - Pieces

struct SectionLabel: View {
    @Environment(\.theme) private var theme
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(theme.text2Color)
    }
}

/// "from [ − 20 + ]" — a leading word and a control.
private struct SentenceRow<Control: View>: View {
    @Environment(\.theme) private var theme
    let lead: String
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(spacing: Space.m) {
            Text(lead)
                .font(.system(.body, design: theme.numeralDesign, weight: .semibold))
                .foregroundStyle(theme.textColor)
            Spacer(minLength: Space.s)
            control()
        }
        .padding(.horizontal, Space.l)
        .frame(minHeight: 56)
    }
}

/// − [ number ] +, with direct typing.
struct NumberStepper: View {
    @Environment(\.theme) private var theme
    @Binding var value: Int
    var step: Int = 1
    var minimum: Int = Int.min

    var body: some View {
        HStack(spacing: 0) {
            Button {
                value = max(minimum, value - max(1, step))
            } label: {
                Image(systemName: "minus").font(.body.weight(.bold)).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Decrease")
            TextField("0", value: Binding(get: { value }, set: { value = max(minimum, $0) }), format: .number)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.center)
                .font(theme.numeralFont(.title3, weight: .heavy))
                .monospacedDigit()
                .frame(minWidth: 56, maxWidth: 96)
            Button {
                value = value + max(1, step)
            } label: {
                Image(systemName: "plus").font(.body.weight(.bold)).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Increase")
        }
        .foregroundStyle(theme.textColor)
        .background(theme.raisedColor, in: Capsule())
    }
}
