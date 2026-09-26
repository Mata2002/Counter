import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(HydrationStore.self) private var store
    @State private var showReminders = false
    @State private var backupError: String?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showDeleteConfirmation = false
    @State private var exportDocument = JSONBackupDocument(data: Data())

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        HStack {
                            Label("Theme", systemImage: "paintpalette.fill")
                            Spacer()
                            Text(store.activeTheme.name).foregroundStyle(.secondary)
                        }
                    }
                }.listRowBackground(store.activeTheme.surface)

                Section("Reminders") {
                    Button { showReminders = true } label: { Label("Manage reminders", systemImage: "bell.badge") }
                }.listRowBackground(store.activeTheme.surface)

                Section("Daily goal") {
                    Stepper(value: goalBinding, in: 500...6_000, step: 100) {
                        HStack {
                            Label("Target", systemImage: "scope")
                            Spacer()
                            Text(store.goalML.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces)).foregroundStyle(.secondary)
                        }
                    }
                    Picker("Units", selection: unitBinding) {
                        Text("Milliliters").tag(false)
                        Text("Fluid ounces").tag(true)
                    }
                }.listRowBackground(store.activeTheme.surface)

                Section("Quick pours") {
                    ForEach(Array(store.snapshot.settings.quickDrinks.enumerated()), id: \.element.id) { index, quick in
                        NavigationLink {
                            QuickDrinkEditor(index: index, quick: quick)
                        } label: {
                            HStack {
                                Image(systemName: quick.vessel.symbol).foregroundStyle(store.activeTheme.drinkColor(quick.drink)).frame(width: 28)
                                VStack(alignment: .leading) {
                                    Text(quick.drink.title)
                                    Text(quick.vessel.title).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(quick.amountML.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if store.snapshot.settings.quickDrinks.count < 8 {
                        Button {
                            store.updateSettings { $0.quickDrinks.append(QuickDrink(drink: .water, vessel: .glass, amountML: 250)) }
                        } label: { Label("Add quick pour", systemImage: "plus") }
                    }
                }.listRowBackground(store.activeTheme.surface)

                Section("Feedback") {
                    Toggle("Haptics", isOn: hapticsBinding)
                    Toggle("Milestone celebrations", isOn: celebrationBinding)
                }.listRowBackground(store.activeTheme.surface)

                Section("Data") {
                    Button {
                        exportDocument = JSONBackupDocument(data: store.exportData() ?? Data())
                        showingExporter = true
                    } label: { Label("Export backup", systemImage: "square.and.arrow.up") }
                    Button { showingImporter = true } label: { Label("Restore backup", systemImage: "square.and.arrow.down") }
                    Button("Delete all hydration data", role: .destructive) { showDeleteConfirmation = true }
                }.listRowBackground(store.activeTheme.surface)
            }
            .hydraForm()
            .navigationTitle("Settings")
            .sheet(isPresented: $showReminders) { RemindersView().environment(\.hydroTheme, store.activeTheme) }
            .alert("Backup", isPresented: Binding(get: { backupError != nil }, set: { if !$0 { backupError = nil } })) {
                Button("OK") { backupError = nil }
            } message: { Text(backupError ?? "") }
            .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .json, defaultFilename: "Hydration-Backup") { result in if case let .failure(error) = result { backupError = error.localizedDescription } }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                guard case let .success(url) = result else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do { try store.restore(from: Data(contentsOf: url)) }
                catch { backupError = "This backup could not be restored. Your current data has been kept. " + error.localizedDescription }
            }
            .confirmationDialog("Delete all hydration data?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { store.deleteAllData() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var goalBinding: Binding<Int> {
        Binding(get: { store.goalML }, set: { value in store.updateSettings { $0.dailyGoalML = value } })
    }
    private var unitBinding: Binding<Bool> {
        Binding(get: { store.snapshot.settings.unitIsOunces }, set: { value in store.updateSettings { $0.unitIsOunces = value } })
    }
    private var hapticsBinding: Binding<Bool> {
        Binding(get: { store.snapshot.settings.haptics }, set: { value in store.updateSettings { $0.haptics = value } })
    }
    private var celebrationBinding: Binding<Bool> {
        Binding(get: { store.snapshot.settings.celebration }, set: { value in store.updateSettings { $0.celebration = value } })
    }
}

struct QuickDrinkEditor: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let index: Int
    @State var quick: QuickDrink

    var body: some View {
        Form {
            Picker("Drink", selection: $quick.drink) {
                ForEach(DrinkKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }
            Picker("Container", selection: $quick.vessel) {
                ForEach(VesselKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }
            Stepper("\(quick.amountML) ml", value: $quick.amountML, in: 50...1_500, step: 10)
            Button("Delete quick pour", role: .destructive) {
                store.updateSettings { settings in
                    guard let position = settings.quickDrinks.firstIndex(where: { $0.id == quick.id }) else { return }
                    settings.quickDrinks.remove(at: position)
                }
                dismiss()
            }
        }
        .hydraForm()
        .navigationTitle("Quick pour")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    store.updateSettings { settings in
                        guard let position = settings.quickDrinks.firstIndex(where: { $0.id == quick.id }) else { return }
                        settings.quickDrinks[position] = quick
                    }
                    dismiss()
                }
                .fontWeight(.bold)
            }
        }
    }
}

struct JSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// The theme chooser. Behavior switches based on "Randomize each launch":
/// off → tapping a theme sets it as the single active theme; on → tapping
/// toggles that theme's membership in the pool the random pick draws from.
struct AppearanceSettingsView: View {
    @Environment(HydrationStore.self) private var store

    private var randomize: Bool { store.snapshot.settings.randomizeThemeEachLaunch }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Mode", selection: Binding(get: { store.snapshot.settings.appearance }, set: { value in store.updateSettings { $0.appearance = value } })) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }.pickerStyle(.segmented)
            }.listRowBackground(store.activeTheme.surface)
            Section("Your glass") {
                Picker("Finish", selection: Binding(get: { store.activeFinish }, set: { value in store.updateSettings { $0.vesselFinish = value } })) {
                    Text("Clear glass").tag("clear")
                    ForEach(HydrationAchievement.allCases.filter { $0.finishID != nil && store.snapshot.unlockedAchievementIDs.contains($0.id) }) { award in
                        Text(award.reward ?? "Glass").tag(award.finishID ?? "clear")
                    }
                }
                Text("Collect 3, 7, and 30 consecutive goal days to earn new finishes in Awards.").font(.caption).foregroundStyle(.secondary)
            }.listRowBackground(store.activeTheme.surface)
            Section {
                Toggle("Randomize each launch", isOn: Binding(
                    get: { randomize },
                    set: { value in store.updateSettings { $0.randomizeThemeEachLaunch = value } }
                ))
            } footer: {
                Text(randomize
                     ? "A new theme from your enabled set below is picked each time you open the app."
                     : "Tap a theme below to make it the active one.")
            }.listRowBackground(store.activeTheme.surface)

            Section(randomize ? "Enabled themes" : "Theme") {
                themeGrid(for: .core)
            }.listRowBackground(store.activeTheme.surface)

            Section("Seasonal") {
                themeGrid(for: .seasonal)
            }.listRowBackground(store.activeTheme.surface)

            Section {
                Picker("Pattern intensity", selection: Binding(
                    get: { store.snapshot.settings.patternIntensity },
                    set: { value in store.updateSettings { $0.patternIntensity = value } }
                )) {
                    ForEach(PatternIntensity.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Controls how visible each theme's texture is inside the water.")
            }.listRowBackground(store.activeTheme.surface)
        }
        .hydraForm()
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeGrid(for category: HydroTheme.Category) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 14) {
            ForEach(HydroThemeCatalog.all.filter { $0.category == category }) { theme in
                ThemeSwatch(
                    theme: theme,
                    isOn: randomize
                        ? store.snapshot.settings.enabledThemeIDs.contains(theme.id.rawValue)
                        : store.snapshot.settings.activeThemeID == theme.id.rawValue
                ) {
                    store.updateSettings { settings in
                        if settings.randomizeThemeEachLaunch {
                            if settings.enabledThemeIDs.contains(theme.id.rawValue) {
                                // Always leave at least one theme enabled.
                                if settings.enabledThemeIDs.count > 1 {
                                    settings.enabledThemeIDs.remove(theme.id.rawValue)
                                }
                            } else {
                                settings.enabledThemeIDs.insert(theme.id.rawValue)
                            }
                        } else {
                            settings.activeThemeID = theme.id.rawValue
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ThemeSwatch: View {
    let theme: HydroTheme
    let isOn: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(theme.background)
                    VStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Circle().fill(theme.control).frame(width: 5, height: 5)
                            Capsule().fill(theme.control.opacity(0.4)).frame(width: 26, height: 3)
                        }
                        Circle().fill(LinearGradient(colors: [theme.liquidTop, theme.liquidBottom], startPoint: .top, endPoint: .bottom))
                            .frame(width: 34, height: 34).overlay(Circle().stroke(.white.opacity(0.6)))
                        HStack(spacing: 4) { ForEach(0..<3) { _ in RoundedRectangle(cornerRadius: 4).fill(theme.raised).frame(height: 12) } }.padding(.horizontal, 10)
                    }.padding(.vertical, 9)
                }.frame(height: 85).overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(isOn ? theme.control : theme.border, lineWidth: isOn ? 2 : 1))
                HStack(spacing: 4) {
                    Text(theme.name).font(.caption.weight(.semibold))
                    if isOn { Image(systemName: "checkmark").font(.caption2.bold()) }
                }.foregroundStyle(theme.control)
            }
        }.buttonStyle(PressableScale()).accessibilityLabel(theme.name).accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
