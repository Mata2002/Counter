import SwiftUI

/// Create or edit a folder: a name, an emoji and a color.
struct FolderEditor: View {
    @Environment(TallyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    let original: TallyFolder?
    var onCreate: ((TallyFolder) -> Void)? = nil
    @State private var draft: TallyFolder
    @State private var pickingEmoji = false
    @FocusState private var nameFocused: Bool

    init(original: TallyFolder?, onCreate: ((TallyFolder) -> Void)? = nil) {
        self.original = original
        self.onCreate = onCreate
        _draft = State(initialValue: original ?? TallyFolder(name: "", emoji: "📁", colorIndex: Int.random(in: 0..<TallyTheme.tallyColorCount)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    HStack(spacing: Space.m) {
                        Button { pickingEmoji = true } label: {
                            ZStack {
                                Circle().fill(theme.tally(draft.colorIndex).opacity(0.25))
                                Text(draft.emoji.isEmpty ? "📁" : draft.emoji).font(.system(size: 30))
                            }
                            .frame(width: 60, height: 60)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Choose an emoji")
                        TextField("Folder name", text: $draft.name)
                            .font(.system(.title2, design: theme.numeralDesign, weight: .bold))
                            .foregroundStyle(theme.textColor)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onSubmit(save)
                    }
                    .padding(.top, Space.l)
                    SectionLabel("Color")
                    HStack(spacing: Space.m) {
                        ForEach(0..<TallyTheme.tallyColorCount, id: \.self) { index in
                            Button { draft.colorIndex = index } label: {
                                Circle()
                                    .fill(theme.tally(index))
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().strokeBorder(theme.textColor, lineWidth: draft.colorIndex == index ? 2 : 0))
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel("Color \(index + 1)")
                            .accessibilityAddTraits(draft.colorIndex == index ? .isSelected : [])
                        }
                    }
                    Text("Archiving a folder archives every tally in it. Hiding it hides them from the main list.")
                        .font(.footnote)
                        .foregroundStyle(theme.text2Color)
                }
                .padding(.horizontal, Space.l)
            }
            .background(theme.backgroundColor.ignoresSafeArea())
            .navigationTitle(original == nil ? "New folder" : "Edit folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.bold)
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $pickingEmoji) {
                EmojiPicker(selection: $draft.emoji)
                    .themedSheet(theme)
                    .presentationDetents([.medium, .large])
            }
            .onAppear { if original == nil { nameFocused = true } }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard !draft.name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var folder = draft
        folder.name = folder.name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.save(folder)
        if original == nil { onCreate?(folder) }
        dismiss()
    }
}

/// A curated emoji grid plus "type any emoji".
struct EmojiPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Binding var selection: String
    @State private var typed = ""

    private static let groups: [(String, [String])] = [
        ("Body", ["💧", "🥤", "☕️", "🍵", "🍎", "🥗", "💪", "🏃", "🚶", "🏊", "🚴", "🧘", "🦵", "🏋️", "🤸", "😴"]),
        ("Mind", ["📖", "📚", "✍️", "🧠", "🎯", "🧩", "🙏", "📿", "🕌", "🌬️", "🎓", "💡"]),
        ("Fun", ["🎮", "🎬", "🍿", "🎵", "🎸", "🎨", "📷", "🎲", "♟️", "🏀", "⚽️", "🎳"]),
        ("Life", ["🏠", "🧹", "🧺", "🛒", "💰", "💼", "📞", "✉️", "🚗", "✈️", "🐶", "🐱", "🌱", "🐦", "⭐️", "🔥"]),
        ("Countdowns", ["⏳", "📅", "🎂", "🎁", "🎄", "🎃", "❤️", "🎉", "🏁", "🚀", "🌙", "☀️"]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    HStack {
                        TextField("Type any emoji", text: $typed)
                            .font(.title2)
                            .onChange(of: typed) { _, newValue in
                                if let last = newValue.last {
                                    selection = String(last)
                                    dismiss()
                                }
                            }
                        if !selection.isEmpty {
                            Button("Remove") { selection = ""; dismiss() }
                                .foregroundStyle(theme.actionColor)
                        }
                    }
                    .padding(.horizontal, Space.m)
                    .frame(minHeight: 48)
                    .background(theme.raisedColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    ForEach(Self.groups, id: \.0) { group in
                        SectionLabel(group.0)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Space.s) {
                            ForEach(group.1, id: \.self) { emoji in
                                Button {
                                    selection = emoji
                                    dismiss()
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 30))
                                        .frame(width: 48, height: 48)
                                        .background(selection == emoji ? theme.raisedColor : .clear,
                                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
                .padding(Space.l)
            }
            .background(theme.backgroundColor.ignoresSafeArea())
            .navigationTitle("Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
