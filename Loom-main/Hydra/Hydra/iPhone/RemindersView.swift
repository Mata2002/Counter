import SwiftUI

struct RemindersView: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editingReminder: HydrationReminder?

    var body: some View {
        NavigationStack {
            ZStack {
                AquaBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        if store.snapshot.reminders.isEmpty {
                            GlassCard {
                                VStack(spacing: 14) {
                                    Image(systemName: "bell.slash.fill")
                                        .font(.system(size: 34))
                                        .foregroundStyle(store.activeTheme.control)
                                    Text("No reminders").font(.headline)
                                }
                                .frame(maxWidth: .infinity, minHeight: 150)
                            }
                        }
                        ForEach(store.snapshot.reminders) { reminder in
                            GlassCard {
                                HStack(spacing: 14) {
                                    Button { editingReminder = reminder } label: {
                                        HStack(spacing: 14) {
                                            Image(systemName: reminder.schedule == .fixed ? "clock.fill" : "repeat.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(reminder.enabled ? store.activeTheme.control : .secondary)
                                                .frame(width: 44, height: 44)
                                                .background(store.activeTheme.control.opacity(0.11), in: Circle())
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(reminder.name).font(.headline).foregroundStyle(.primary)
                                                Text(reminder.summary).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    Toggle("", isOn: Binding(
                                        get: { reminder.enabled },
                                        set: { value in update(reminder) { $0.enabled = value } }
                                    ))
                                    .labelsHidden()
                                }
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button {
                    editingReminder = HydrationReminder()
                } label: { Image(systemName: "plus") } }
            }
            .sheet(item: $editingReminder) { reminder in
                ReminderEditor(reminder: reminder)
            }
        }
    }

    private func update(_ reminder: HydrationReminder, mutate: (inout HydrationReminder) -> Void) {
        var reminders = store.snapshot.reminders
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        mutate(&reminders[index])
        store.replaceReminders(reminders)
    }
}

struct ReminderEditor: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var reminder: HydrationReminder

    private var fixedTime: Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: reminder.hour, minute: reminder.minute)) ?? Date()
        } set: { date in
            reminder.hour = Calendar.current.component(.hour, from: date)
            reminder.minute = Calendar.current.component(.minute, from: date)
        }
    }

    private func windowTime(start: Bool) -> Binding<Date> {
        Binding {
            let hour = start ? reminder.startHour : reminder.endHour
            let minute = start ? reminder.startMinute : reminder.endMinute
            return Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        } set: { date in
            if start {
                reminder.startHour = Calendar.current.component(.hour, from: date)
                reminder.startMinute = Calendar.current.component(.minute, from: date)
            } else {
                reminder.endHour = Calendar.current.component(.hour, from: date)
                reminder.endMinute = Calendar.current.component(.minute, from: date)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $reminder.name)
                    Toggle("Enabled", isOn: $reminder.enabled)
                    Picker("Schedule", selection: $reminder.schedule) {
                        ForEach(ReminderSchedule.allCases) { Text($0.title).tag($0) }
                    }
                }.listRowBackground(store.activeTheme.surface)
                Section(reminder.schedule == .fixed ? "Time" : "Window") {
                    if reminder.schedule == .fixed {
                        DatePicker("Time", selection: fixedTime, displayedComponents: .hourAndMinute)
                    } else {
                        DatePicker("From", selection: windowTime(start: true), displayedComponents: .hourAndMinute)
                        DatePicker("Until", selection: windowTime(start: false), displayedComponents: .hourAndMinute)
                        Picker("Repeat", selection: $reminder.intervalMinutes) {
                            Text("Every 30 minutes").tag(30)
                            Text("Every hour").tag(60)
                            Text("Every 90 minutes").tag(90)
                            Text("Every 2 hours").tag(120)
                            Text("Every 3 hours").tag(180)
                        }
                    }
                }.listRowBackground(store.activeTheme.surface)
                Section("Days") {
                    WeekdaySelector(selection: $reminder.weekdays)
                }.listRowBackground(store.activeTheme.surface)
                if store.snapshot.reminders.contains(where: { $0.id == reminder.id }) {
                    Section {
                        Button("Delete reminder", role: .destructive) {
                            store.replaceReminders(store.snapshot.reminders.filter { $0.id != reminder.id })
                            dismiss()
                        }
                    }.listRowBackground(store.activeTheme.surface)
                }
            }
            .hydraForm()
            .navigationTitle("Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var reminders = store.snapshot.reminders
                        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                            reminders[index] = reminder
                        } else {
                            reminders.append(reminder)
                        }
                        store.replaceReminders(reminders)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(reminder.weekdays.isEmpty || reminder.name.trimmingCharacters(in: .whitespaces).isEmpty || (reminder.schedule == .interval && reminder.endHour * 60 + reminder.endMinute < reminder.startHour * 60 + reminder.startMinute))
                }
            }
        }
    }
}

struct WeekdaySelector: View {
    @Environment(HydrationStore.self) private var store
    @Binding var selection: Set<Int>
    private let symbols = Calendar.current.veryShortWeekdaySymbols

    var body: some View {
        HStack {
            ForEach(1...7, id: \.self) { weekday in
                Button {
                    if selection.contains(weekday) { selection.remove(weekday) } else { selection.insert(weekday) }
                } label: {
                    Text(symbols[weekday - 1])
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .foregroundStyle(selection.contains(weekday) ? .white : .primary)
                        .background(selection.contains(weekday) ? store.activeTheme.control : Color.secondary.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension HydrationReminder {
    var summary: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        func time(_ hour: Int, _ minute: Int) -> String {
            formatter.string(from: Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date())
        }
        if schedule == .fixed { return time(hour, minute) }
        let intervalText = intervalMinutes % 60 == 0 ? "\(intervalMinutes / 60)h" : "\(intervalMinutes)m"
        return "Every \(intervalText) · \(time(startHour, startMinute))–\(time(endHour, endMinute))"
    }
}
