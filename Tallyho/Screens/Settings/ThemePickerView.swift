import SwiftUI

/// Every theme as a tiny live counting stage. Shuffle is the one primary action.
struct ThemePickerView: View {
    @Environment(ThemeManager.self) private var themes
    @Environment(\.theme) private var theme
    @State private var favoritesOnly = false
    @State private var holidayLabels: [String: String] = [:]

    private let columns = [GridItem(.flexible(), spacing: Space.m), GridItem(.flexible(), spacing: Space.m)]

    var body: some View {
        let everyday = TallyTheme.everyday.filter { !favoritesOnly || themes.favorites.contains($0.id) }
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                HStack(spacing: Space.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(themes.activeHolidayID == nil ? "Wearing" : "Holiday theme")
                            .font(.subheadline)
                            .foregroundStyle(theme.text2Color)
                        Text(theme.name)
                            .font(.system(.title, design: theme.numeralDesign, weight: .heavy))
                            .foregroundStyle(theme.textColor)
                        Text(theme.mood)
                            .font(.footnote)
                            .foregroundStyle(theme.text2Color)
                            .lineLimit(2)
                    }
                    Spacer(minLength: Space.s)
                    Button {
                        ThemeCrossfade.perform { themes.shuffle() }
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .fixedSize()
                    .sensoryFeedback(.selection, trigger: themes.active.id)
                }

                VStack(alignment: .leading, spacing: Space.m) {
                    Text("Appearance").foregroundStyle(theme.textColor)
                    AppearancePicker()
                    Text("Every theme has a light and a dark version.")
                        .font(.footnote)
                        .foregroundStyle(theme.text2Color)
                }
                .padding(Space.l)
                .background(theme.surfaceColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: Space.m) {
                    Text("Shuffle automatically").foregroundStyle(theme.textColor)
                    Picker("Shuffle automatically", selection: Binding(get: { themes.shuffleMode }, set: { themes.shuffleMode = $0 })) {
                        ForEach(ThemeManager.ShuffleMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(themes.favorites.isEmpty
                         ? "Picks from every theme. Heart a few to shuffle only those."
                         : "Picks from your \(themes.favorites.count) favorites.")
                        .font(.footnote)
                        .foregroundStyle(theme.text2Color)
                }
                .padding(Space.l)
                .background(theme.surfaceColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: Space.m) {
                    HStack {
                        Text("Everyday")
                            .font(.system(.title3, design: theme.numeralDesign, weight: .bold))
                            .foregroundStyle(theme.textColor)
                        Spacer()
                        Picker("Show", selection: $favoritesOnly) {
                            Text("All").tag(false)
                            Text("Favorites").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 190)
                    }
                    if everyday.isEmpty {
                        Text("No favorites yet. Tap a heart to add one.")
                            .font(.subheadline)
                            .foregroundStyle(theme.text2Color)
                    }
                    LazyVGrid(columns: columns, spacing: Space.m) {
                        ForEach(everyday) { ThemeTile(tileTheme: $0, detail: nil) }
                    }
                }

                VStack(alignment: .leading, spacing: Space.m) {
                    Text("Holidays")
                        .font(.system(.title3, design: theme.numeralDesign, weight: .bold))
                        .foregroundStyle(theme.textColor)
                    Toggle(isOn: Binding(get: { themes.holidaysEnabled },
                                         set: { value in ThemeCrossfade.perform { themes.holidaysEnabled = value } })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Switch for holidays").foregroundStyle(theme.textColor)
                            Text("Tallyho dresses up for the day, then goes back to your theme.")
                                .font(.footnote)
                                .foregroundStyle(theme.text2Color)
                        }
                    }
                    .padding(Space.l)
                    .background(theme.surfaceColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    LazyVGrid(columns: columns, spacing: Space.m) {
                        ForEach(TallyTheme.holidays) { holiday in
                            ThemeTile(tileTheme: holiday, detail: detail(for: holiday))
                                .contextMenu {
                                    Toggle("Switch automatically", isOn: Binding(
                                        get: { themes.isHolidayEnabled(holiday.id) },
                                        set: { value in ThemeCrossfade.perform { themes.setHoliday(holiday.id, enabled: value) } }
                                    ))
                                }
                        }
                    }
                    Text("Touch and hold a holiday to stop it switching on its own. Easter, Thanksgiving and Nowruz move each year and are worked out for you.")
                        .font(.footnote)
                        .foregroundStyle(theme.text2Color)
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxxl)
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            var labels: [String: String] = [:]
            for holiday in TallyTheme.holidays { labels[holiday.id] = HolidayCalendar.label(for: holiday.id) }
            holidayLabels = labels
        }
    }

    private func detail(for holiday: TallyTheme) -> String {
        let label = holidayLabels[holiday.id] ?? " "
        return themes.holidaysEnabled && themes.isHolidayEnabled(holiday.id) ? label : label + " · off"
    }
}

private struct ThemeTile: View {
    @Environment(ThemeManager.self) private var themes
    @Environment(\.theme) private var theme
    let tileTheme: TallyTheme
    let detail: String?

    var body: some View {
        let selected = themes.active.id == tileTheme.id
        let favorite = themes.favorites.contains(tileTheme.id)
        // Tiles preview each theme in the appearance you're using now.
        let shown = tileTheme.resolved(theme.colorScheme)
        VStack(alignment: .leading, spacing: Space.s) {
            ZStack(alignment: .bottomLeading) {
                LiquidStage(colorIndex: 0, level: 0.62, amplitude: 4, texture: true) { ink in
                    Text("42")
                        .font(shown.numeralFont(size: 54))
                        .foregroundStyle(ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .environment(\.theme, shown)
                HStack(spacing: 4) {
                    ForEach(1..<TallyTheme.tallyColorCount, id: \.self) { i in
                        Circle().fill(shown.tally(i)).frame(width: 10, height: 10)
                    }
                }
                .padding(6)
                .background(shown.backgroundColor, in: Capsule())
                .padding(8)
            }
            .frame(height: 118)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(tileTheme.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textColor)
                        .lineLimit(1)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(theme.text2Color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 0)
                Button { themes.toggleFavorite(tileTheme.id) } label: {
                    Image(systemName: favorite ? "heart.fill" : "heart")
                        .foregroundStyle(favorite ? theme.actionColor : theme.text2Color)
                        .frame(width: 44, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(favorite ? "Remove \(tileTheme.name) from favorites" : "Add \(tileTheme.name) to favorites")
            }
            .padding(.leading, Space.xs)
        }
        .padding(6)
        .background(theme.surfaceColor, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(selected ? theme.actionColor : theme.dividerColor, lineWidth: selected ? 3 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            ThemeCrossfade.perform { themes.select(tileTheme.id) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(tileTheme.name) theme\(selected ? ", selected" : "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { ThemeCrossfade.perform { themes.select(tileTheme.id) } }
    }
}

/// Device, Light or Dark, switched with the same crossfade as a theme change.
struct AppearancePicker: View {
    @Environment(ThemeManager.self) private var themes

    var body: some View {
        Picker("Appearance", selection: Binding(
            get: { themes.appearance },
            set: { value in ThemeCrossfade.perform { themes.appearance = value } }
        )) {
            ForEach(ThemeAppearance.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }
}
