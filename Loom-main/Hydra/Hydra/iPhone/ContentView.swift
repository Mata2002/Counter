import Combine
import SwiftUI

enum AppSection: Hashable { case today, history, trends, achievements, settings }

struct HydrationRootView: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: AppSection = .today
    @State private var logSheetClosed = true
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var store = store
        TabView(selection: $selection) {
            Tab("Today", systemImage: "drop.fill", value: AppSection.today) { TodayView() }
            Tab("History", systemImage: "clock", value: AppSection.history) { HistoryView() }
            Tab("Trends", systemImage: "chart.xyaxis.line", value: AppSection.trends) { TrendsView() }
            Tab("Awards", systemImage: "seal", value: AppSection.achievements) { AchievementsView() }
            Tab("Settings", systemImage: "slider.horizontal.3", value: AppSection.settings) { SettingsView() }
        }
        .tint(store.activeTheme.control)
        .toolbarBackground(store.activeTheme.background, for: .tabBar)
        .environment(\.hydroTheme, store.activeTheme)
        .preferredColorScheme(store.snapshot.settings.appearance == "dark" ? .dark : store.snapshot.settings.appearance == "light" ? .light : nil)
        .sheet(isPresented: $store.isLoggingDrink, onDismiss: { logSheetClosed = true }) {
            LogDrinkSheet().environment(\.hydroTheme, store.activeTheme)
        }
        .onChange(of: store.isLoggingDrink) { _, value in if value { logSheetClosed = false } }
        .sheet(item: Binding(get: { logSheetClosed ? store.celebration : nil }, set: { if $0 == nil { store.dismissCelebration() } })) { moment in
            CelebrationSheet(moment: moment).environment(\.hydroTheme, store.activeTheme)
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchQuickAdd)) { notification in
            guard let amount = notification.object as? Int else { return }
            store.add(drink: .water, vessel: .glass, amountML: amount)
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchSnapshot)) { notification in
            guard let snapshot = notification.object as? HydrationSnapshot else { return }
            store.mergeFromWatch(snapshot)
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.refreshFromDisk() } }
        .onReceive(clock) { _ in if scenePhase == .active { store.refreshFromDisk() } }
        .sensoryFeedback(.impact(weight: .light), trigger: store.pourFeedback) { _, _ in store.snapshot.settings.haptics }
        .sensoryFeedback(.selection, trigger: selection) { _, _ in store.snapshot.settings.haptics }
        .sensoryFeedback(.selection, trigger: store.snapshot.settings.activeThemeID) { _, _ in store.snapshot.settings.haptics }
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.9), value: store.snapshot.settings.activeThemeID)
    }
}

struct TodayView: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showDetail = false
    @State private var showReminders = false
    @State private var editingEntry: HydrationEntry?
    @Namespace private var heroSpace

    var body: some View {
        NavigationStack {
            ZStack {
                AquaBackground()
                List {
                    header.listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 16, trailing: 20))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    hero.listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    quickAdds.listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 22, trailing: 20))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    Section {
                        if store.todayEntries.isEmpty {
                            Label("Your day starts with a first pour", systemImage: "drop")
                                .font(.subheadline).foregroundStyle(store.activeTheme.secondary).padding(.vertical, 16)
                                .listRowBackground(store.activeTheme.surface)
                        }
                        ForEach(store.todayEntries) { entry in
                            DrinkRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture { editingEntry = entry }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button("Delete", role: .destructive) { store.delete(entry) }
                                    Button("Edit") { editingEntry = entry }.tint(store.activeTheme.control)
                                }
                                .accessibilityAction(named: "Delete") { store.delete(entry) }
                                .accessibilityAction(named: "Edit") { editingEntry = entry }
                                .listRowBackground(store.activeTheme.surface)
                        }
                    } header: {
                        HStack {
                            Text("Today’s pours").font(.title3.bold()).foregroundStyle(.primary)
                            Spacer()
                            Text("\(store.todayEntries.count) \(store.todayEntries.count == 1 ? "drink" : "drinks")").font(.caption).foregroundStyle(store.activeTheme.secondary)
                        }.textCase(nil).padding(.bottom, 8)
                    }
                }
                .listStyle(.insetGrouped).listSectionSpacing(0).contentMargins(.top, 0)
                .scrollContentBackground(.hidden).scrollIndicators(.hidden)
                .accessibilityHidden(showDetail)
                if showDetail { detail.zIndex(5) }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { UndoPourBar() }
            .sheet(isPresented: $showReminders) { RemindersView().environment(\.hydroTheme, store.activeTheme) }
            .sheet(item: $editingEntry) { EntryEditor(entry: $0).environment(\.hydroTheme, store.activeTheme) }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.today.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.caption.weight(.medium)).foregroundStyle(store.activeTheme.secondary)
                Text("Today").font(.system(.largeTitle, design: .rounded, weight: .bold))
            }
            Spacer()
            Button { showReminders = true } label: {
                Image(systemName: "bell").font(.title3).frame(width: 46, height: 46)
                    .background(store.activeTheme.surface, in: Circle())
                    .overlay(Circle().strokeBorder(store.activeTheme.border))
            }.buttonStyle(PressableScale()).accessibilityLabel("Reminders")
        }
    }

    private var hero: some View {
        GlassCard {
            VStack(spacing: 20) {
                HStack {
                    Text(store.progress >= 1 ? "A full day" : "A little, often")
                        .font(.system(.title3, design: .rounded, weight: .medium))
                    Spacer()
                    if store.streak > 0 {
                        Label("\(store.streak)d", systemImage: "flame.fill")
                            .font(.caption.bold()).foregroundStyle(store.activeTheme.control)
                            .accessibilityLabel("\(store.streak) day goal streak")
                    }
                }
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85)) { showDetail = true }
                } label: {
                    Group {
                        if !showDetail {
                            orb.matchedGeometryEffect(id: "vessel", in: heroSpace)
                        } else { Color.clear }
                    }.frame(width: 210, height: 210)
                }.buttonStyle(PressableScale()).accessibilityLabel("Show hydration details")
                VStack(spacing: 5) {
                    Text(store.todayHydratedML.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces))
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.86), value: store.todayHydratedML)
                    Text(store.progress >= 1 ? "Daily goal reached" : "\(max(store.goalML - store.todayHydratedML, 0).hydrationAmount(ounces: store.snapshot.settings.unitIsOunces)) to your goal")
                        .font(.subheadline).foregroundStyle(store.activeTheme.secondary)
                }
                Rectangle().fill(store.activeTheme.border).frame(height: 1)
                HStack(alignment: .top) {
                    HydroLegend(symbol: "drop", title: "Goal", value: store.goalML.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces))
                    HydroLegend(symbol: "mug", title: "Drinks", value: "\(store.todayEntries.count) logged")
                    HydroLegend(symbol: "bolt", title: "Caffeine", value: "\(store.todayCaffeineMG) mg")
                }
            }
        }
    }

    private var orb: some View {
        HydroOrb(progress: store.progress, theme: store.activeTheme, caffeineMG: store.todayCaffeineMG, patternIntensity: store.snapshot.settings.patternIntensity, finish: store.activeFinish, trigger: store.pourFeedback)
    }

    private var quickAdds: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick pour").font(.title3.bold())
                Spacer()
                Button { store.isLoggingDrink = true } label: { Label("Add drink", systemImage: "plus").font(.subheadline.bold()) }
                    .padding(.vertical, 7)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(store.snapshot.settings.quickDrinks) { quick in
                        QuickAddTile(quick: quick, ounces: store.snapshot.settings.unitIsOunces) { store.add(quick) }
                    }
                }.padding(.vertical, 3)
            }.scrollIndicators(.hidden)
        }
    }

    private var detail: some View {
        ZStack {
            store.activeTheme.background.opacity(0.98).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    HStack {
                        Text("Your hydration").font(.title2.bold())
                        Spacer()
                        Button(action: closeDetail) { Image(systemName: "xmark").frame(width: 44, height: 44).background(store.activeTheme.raised, in: Circle()) }
                            .accessibilityLabel("Close hydration details")
                    }
                    orb.matchedGeometryEffect(id: "vessel", in: heroSpace).frame(maxWidth: 290).padding(.vertical, 12)
                    Text("\(store.todayHydratedML.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces)) of \(store.goalML.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces))")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("\(store.todayEntries.count) drinks logged", systemImage: "mug")
                            Text("Drinks counts entries. The liquid level follows the hydration credited by each drink.")
                            Divider()
                            Label("\(store.todayCaffeineMG) mg estimated caffeine", systemImage: "bolt")
                            Text("The outer arc shows caffeine on a 0–400 mg display scale. This is a tracking reference, not a target. The label continues showing the full estimate above 400 mg.")
                        }.font(.subheadline)
                    }
                    Button("Done", action: closeDetail).buttonStyle(.borderedProminent).controlSize(.large)
                }.padding(24)
            }
        }.accessibilityAddTraits(.isModal).accessibilityAction(.escape, closeDetail)
    }

    private func closeDetail() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85)) { showDetail = false }
    }
}

struct DrinkRow: View {
    let entry: HydrationEntry
    @Environment(HydrationStore.self) private var store
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.drink.symbol).font(.title3)
                .foregroundStyle(store.activeTheme.control)
                .frame(width: 42, height: 46).background(store.activeTheme.raised, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.drink.title).font(.subheadline.weight(.semibold))
                Text("\(entry.vessel.title) · \(entry.date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(store.activeTheme.secondary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.amountML.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces)).font(.subheadline.bold())
                if entry.caffeineMG > 0 { Text("\(entry.caffeineMG) mg caffeine").font(.caption2).foregroundStyle(store.activeTheme.secondary) }
            }
        }.padding(.vertical, 6).accessibilityElement(children: .combine)
    }
}

struct QuickAddTile: View {
    let quick: QuickDrink
    let ounces: Bool
    let action: () -> Void
    @Environment(\.hydroTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmation = 0
    @State private var confirmed = false
    var body: some View {
        Button {
            action()
            confirmed = true
            confirmation += 1
        } label: {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: quick.vessel.symbol).font(.title2).symbolRenderingMode(.hierarchical)
                        .symbolEffect(.bounce, value: reduceMotion ? 0 : confirmation)
                    Spacer()
                    if confirmed { Image(systemName: "checkmark").font(.caption.bold()).transition(.scale.combined(with: .opacity)) }
                }.foregroundStyle(theme.control)
                VStack(alignment: .leading, spacing: 3) {
                    Text(quick.amountML.hydrationAmount(ounces: ounces)).font(.system(.headline, design: .rounded))
                    Text(quick.drink.title).font(.caption).foregroundStyle(theme.secondary)
                }
            }.frame(width: 105, alignment: .leading).padding(15)
                .background(confirmed ? theme.raised : theme.surface, in: RoundedRectangle(cornerRadius: 23))
                .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(theme.border))
        }.buttonStyle(PressableScale())
        .accessibilityLabel("Add \(quick.amountML.hydrationAmount(ounces: ounces)) \(quick.drink.title)")
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.78), value: confirmed)
        .task(id: confirmation) {
            guard confirmed else { return }
            do { try await Task.sleep(for: .seconds(1.2)); confirmed = false } catch { }
        }
    }
}

struct UndoPourBar: View {
    @Environment(HydrationStore.self) private var store
    var body: some View {
        if store.lastDeletedEntry != nil || store.lastAddedEntry != nil {
            HStack {
                Image(systemName: store.lastDeletedEntry != nil ? "trash" : "checkmark.circle.fill").foregroundStyle(store.activeTheme.control)
                Text(store.lastDeletedEntry != nil ? "Drink deleted" : "Drink added").font(.subheadline.weight(.medium))
                Spacer()
                Button("Undo") {
                    if store.lastDeletedEntry != nil { store.undoDelete() } else { store.undoLastAdd() }
                }.font(.subheadline.bold()).padding(.vertical, 10)
                Button {
                    store.lastDeletedEntry = nil
                    store.lastAddedEntry = nil
                } label: { Image(systemName: "xmark").font(.caption.bold()).frame(width: 32, height: 40) }
                    .accessibilityLabel("Dismiss confirmation")
            }.padding(.leading, 16).padding(.trailing, 6)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(store.activeTheme.border))
                .padding(.horizontal, 20).padding(.bottom, 8)
        }
    }
}

struct HistoryView: View {
    @Environment(HydrationStore.self) private var store
    @State private var date = Date()
    @State private var editingEntry: HydrationEntry?
    private var entries: [HydrationEntry] {
        HydrationMath.entries(on: date, from: store.snapshot.entries).sorted { $0.date > $1.date }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Day", selection: $date, in: ...Date(), displayedComponents: .date)
                    HStack {
                        Button { changeDay(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 36) }.accessibilityLabel("Previous day")
                        Spacer()
                        Button("Today") { date = Date() }.disabled(Calendar.current.isDateInToday(date))
                        Spacer()
                        Button { changeDay(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 36) }.accessibilityLabel("Next day").disabled(Calendar.current.isDateInToday(date))
                    }.buttonStyle(.borderless)
                }.listRowBackground(store.activeTheme.surface)
                Section {
                    HStack {
                        HydroLegend(symbol: "drop", title: "Hydration", value: entries.reduce(0) { $0 + $1.hydratedML }.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces))
                        HydroLegend(symbol: "mug", title: "Drinks", value: "\(entries.count)")
                        HydroLegend(symbol: "bolt", title: "Caffeine", value: "\(entries.reduce(0) { $0 + $1.caffeineMG }) mg")
                    }.padding(.vertical, 8)
                }.listRowBackground(store.activeTheme.surface)
                Section(date.formatted(date: .complete, time: .omitted)) {
                    if entries.isEmpty { Text("No drinks recorded on this day").foregroundStyle(.secondary).padding(.vertical, 12) }
                    ForEach(entries) { entry in
                        DrinkRow(entry: entry).contentShape(Rectangle()).onTapGesture { editingEntry = entry }
                            .swipeActions {
                                Button("Delete", role: .destructive) { store.delete(entry) }
                                Button("Edit") { editingEntry = entry }.tint(store.activeTheme.control)
                            }
                            .accessibilityAction(named: "Edit") { editingEntry = entry }
                            .accessibilityAction(named: "Delete") { store.delete(entry) }
                    }
                }.listRowBackground(store.activeTheme.surface)
            }.hydraForm().navigationTitle("History")
                .toolbar { Button { store.isLoggingDrink = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add drink") }
                .safeAreaInset(edge: .bottom) { UndoPourBar() }
                .sheet(item: $editingEntry) { EntryEditor(entry: $0).environment(\.hydroTheme, store.activeTheme) }
        }
    }
    private func changeDay(_ amount: Int) {
        date = Calendar.current.date(byAdding: .day, value: amount, to: date) ?? date
    }
}

struct EntryEditor: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var entry: HydrationEntry
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Drink", selection: $entry.drink) { ForEach(DrinkKind.allCases) { Text($0.title).tag($0) } }
                    Picker("Container", selection: $entry.vessel) { ForEach(VesselKind.allCases) { Text($0.title).tag($0) } }
                    Stepper(entry.amountML.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces), value: $entry.amountML, in: 10...3_000, step: 10)
                    DatePicker("When", selection: $entry.date, in: ...Date())
                }.listRowBackground(store.activeTheme.surface)
            }.hydraForm().navigationTitle("Edit pour").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { store.updateEntry(entry); dismiss() }.bold() }
                }
        }.presentationDetents([.medium, .large])
    }
}

struct LogDrinkSheet: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var drink: DrinkKind = .water
    @State private var vessel: VesselKind = .glass
    @State private var amountML = 250
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                AquaBackground(theme: store.activeTheme)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        DatePicker("When", selection: $date, in: ...Date())
                        Text("Drink").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 145 : 92))], spacing: 12) {
                            ForEach(DrinkKind.allCases) { option in
                                SelectionTile(title: option.title, symbol: option.symbol, selected: drink == option, color: store.activeTheme.drinkColor(option)) {
                                    drink = option
                                }
                            }
                        }
                        Text("Container").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 145 : 92))], spacing: 12) {
                            ForEach(VesselKind.allCases) { option in
                                SelectionTile(title: option.title, symbol: option.symbol, selected: vessel == option, color: store.activeTheme.control) {
                                    vessel = option
                                    amountML = option.defaultML
                                }
                            }
                        }
                        GlassCard {
                            VStack(spacing: 14) {
                                HStack {
                                    Text("Amount").font(.headline)
                                    Spacer()
                                    Text(amountML.hydrationAmount(ounces: store.snapshot.settings.unitIsOunces))
                                        .font(.title3.bold())
                                }
                                Slider(value: Binding(get: { Double(amountML) }, set: { amountML = Int($0 / 10) * 10 }), in: 50...1_500, step: 10)
                                HStack {
                                    Button("− 50") { amountML = max(50, amountML - 50) }
                                    Spacer()
                                    Button("+ 50") { amountML = min(1_500, amountML + 50) }
                                }
                                .buttonStyle(.bordered)
                                HStack {
                                    Label("\(Int(Double(amountML) * drink.hydrationFactor).hydrationAmount(ounces: store.snapshot.settings.unitIsOunces)) hydration", systemImage: "drop.fill")
                                    Spacer()
                                    if drink.caffeinePer100ML > 0 {
                                        Label("\(Int(Double(amountML) / 100 * drink.caffeinePer100ML)) mg", systemImage: "bolt.fill")
                                    }
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("New pour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.add(drink: drink, vessel: vessel, amountML: amountML, date: date)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
        .tint(store.activeTheme.control)
    }
}

struct SelectionTile: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let symbol: String
    let selected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.title2)
                Text(title).font(.caption.weight(.semibold)).lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 78)
            .foregroundStyle(selected ? store.activeTheme.background : color)
            .background(selected ? color : Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(color.opacity(selected ? 0 : 0.2)) }
        }
        .buttonStyle(PressableScale())
        .sensoryFeedback(.selection, trigger: selected) { _, value in value && store.snapshot.settings.haptics }
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: selected)
    }
}
