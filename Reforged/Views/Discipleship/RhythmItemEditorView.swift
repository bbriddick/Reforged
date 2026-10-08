import SwiftUI

/// Create or edit one daily-rhythm checklist item: a habit to keep or a
/// temptation to avoid, on chosen weekdays, with an optional real daily reminder.
struct RhythmItemEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @StateObject private var store = RhythmStorageManager.shared

    private let isEditing: Bool
    @State private var item: RhythmItem

    // Deletion is intentionally guarded behind two explicit confirmations — a discipline is a
    // spiritual goal the member set for themselves, and losing it (with its history and
    // reminders) should never happen by accident.
    @State private var showDeleteConfirm1 = false
    @State private var showDeleteConfirm2 = false

    /// SF Symbols offered for the icon picker.
    private let iconChoices = [
        "checkmark.circle.fill", "book.fill", "hands.and.sparkles.fill", "heart.fill",
        "figure.walk", "sun.max.fill", "moon.stars.fill", "drop.fill",
        "hand.raised.fill", "eye.slash.fill", "iphone.slash", "xmark.octagon.fill"
    ]

    private static let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    init() {
        self.isEditing = false
        _item = State(initialValue: RhythmItem(title: ""))
    }

    init(editing item: RhythmItem) {
        self.isEditing = true
        _item = State(initialValue: item)
    }

    private var canSave: Bool {
        !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents(); c.hour = item.reminderHour; c.minute = item.reminderMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                item.reminderHour = c.hour ?? 8
                item.reminderMinute = c.minute ?? 0
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                kindSection
                appearanceSection
                daysSection
                reminderSection
                if isEditing { deleteSection }
            }
            .scrollContentBackground(.hidden)
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Item" : "New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            // First gate.
            .alert("Delete this discipline?", isPresented: $showDeleteConfirm1) {
                Button("Cancel", role: .cancel) {}
                Button("Continue", role: .destructive) {
                    HapticManager.shared.warning()
                    showDeleteConfirm2 = true
                }
            } message: {
                Text("“\(displayTitle)” is one of your spiritual goals. Deleting it removes the discipline, its reminders, and your daily history for it.")
            }
            // Second gate — deliberately worded so it can't be dismissed on autopilot.
            .alert("Are you absolutely sure?", isPresented: $showDeleteConfirm2) {
                Button("Keep my goal", role: .cancel) {}
                Button("Delete forever", role: .destructive) { performDelete() }
            } message: {
                Text("This permanently deletes “\(displayTitle)”. Your progress on this goal will be lost and there is no undo.")
            }
        }
    }

    private var displayTitle: String {
        let t = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "this discipline" : t
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                HapticManager.shared.buttonTap()
                showDeleteConfirm1 = true
            } label: {
                Label("Delete Discipline", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
        } footer: {
            Text("Removing a discipline can't be undone. We'll ask you to confirm twice.")
        }
        .listRowBackground(Color.adaptiveCardBackground(colorScheme))
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section {
            TextField(item.kind == .avoid ? "What to stay clear of (e.g. Pornography)"
                                          : "What to do (e.g. Read the Bible)",
                      text: $item.title)
            TextField("Note (optional)", text: $item.note, axis: .vertical)
                .lineLimit(1...3)
        }
        .listRowBackground(Color.adaptiveCardBackground(colorScheme))
    }

    private var kindSection: some View {
        Section {
            Picker("Type", selection: $item.kind) {
                Text("Habit to keep").tag(RhythmKind.doHabit)
                Text("Avoid").tag(RhythmKind.avoid)
            }
            .pickerStyle(.segmented)
        } footer: {
            Text(item.kind == .avoid
                 ? "You'll check this off each day you stayed faithful."
                 : "You'll check this off each day you do it.")
        }
        .listRowBackground(Color.adaptiveCardBackground(colorScheme))
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(iconChoices, id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(item.iconName == icon
                                         ? item.accent.color(colorScheme)
                                         : Color.adaptiveTextSecondary(colorScheme))
                        .frame(width: 40, height: 40)
                        .background(item.iconName == icon
                                    ? item.accent.color(colorScheme).opacity(0.15)
                                    : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture {
                            HapticManager.shared.buttonTap()
                            item.iconName = icon
                        }
                }
            }
            .padding(.vertical, 4)

            HStack(spacing: 12) {
                Text("Color")
                Spacer()
                ForEach(PlanAccent.allCases) { accent in
                    Circle()
                        .fill(accent.color(colorScheme))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(Color.adaptiveText(colorScheme),
                                                       lineWidth: item.accent == accent ? 2.5 : 0))
                        .onTapGesture {
                            HapticManager.shared.buttonTap()
                            item.accent = accent
                        }
                }
            }
        }
        .listRowBackground(Color.adaptiveCardBackground(colorScheme))
    }

    private var daysSection: some View {
        Section("Repeat on") {
            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { weekday in
                    let on = item.weekdays.contains(weekday)
                    Text(Self.weekdaySymbols[weekday - 1])
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(on ? item.accent.color(colorScheme) : Color.adaptiveBackground(colorScheme))
                        .foregroundStyle(on ? .white : Color.adaptiveTextSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .onTapGesture {
                            HapticManager.shared.buttonTap()
                            if on { item.weekdays.remove(weekday) } else { item.weekdays.insert(weekday) }
                        }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.adaptiveCardBackground(colorScheme))
    }

    private var reminderSection: some View {
        Section {
            Toggle("Daily reminder", isOn: $item.reminderEnabled.animation())
                .onChange(of: item.reminderEnabled) { enabled in
                    if enabled { NotificationManager.shared.requestAuthorization() }
                }
            if item.reminderEnabled {
                DatePicker("Time", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
            }
        } footer: {
            if item.reminderEnabled {
                Text("A notification will remind you at \(item.reminderTimeLabel) on the days you picked.")
            }
        }
        .listRowBackground(Color.adaptiveCardBackground(colorScheme))
    }

    // MARK: - Save

    private func save() {
        HapticManager.shared.success()
        var toSave = item
        toSave.title = toSave.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if toSave.weekdays.isEmpty { toSave.weekdays = Set(1...7) }
        store.upsert(toSave)
        dismiss()
    }

    private func performDelete() {
        HapticManager.shared.error()
        store.delete(item)
        dismiss()
    }
}
