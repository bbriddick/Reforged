import SwiftUI
import FamilyControls

// MARK: - Scheduled Blocking UI
//
// The "Blocking Schedules" card, its own screen, and the editor sheet for
// creating/editing one time window. Disabling or deleting a schedule lowers
// protection, so those paths route through the `guardedReduce` closure the
// parent passes in (PIN-gated when the accountability lock is on).

/// Dedicated screen — schedules are set-once config, so they live one push off
/// the shield's main scroll rather than expanded inline on it.
struct SchedulesListView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var scheduleService: ScheduledBlockingService
    let guardedReduce: (@escaping () -> Void) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                SchedulesCard(scheduleService: scheduleService, guardedReduce: guardedReduce)

                Text("Windows shorter than \(ScheduledBlockingKeys.minWindowMinutes) minutes aren't supported by iOS, and you can keep up to \(ScheduledBlockingKeys.maxSchedules) schedules.")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Schedules")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SchedulesCard: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var scheduleService: ScheduledBlockingService
    /// Parent's PIN gate for protection-lowering actions.
    let guardedReduce: (@escaping () -> Void) -> Void

    @State private var editingSchedule: BlockSchedule?
    @State private var showingNewSchedule = false

    private static let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.14))
                        .frame(width: 50, height: 50)
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.indigo)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Blocking Schedules")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Shield chosen apps during set hours — like bedtime or morning devotion.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            ForEach(scheduleService.schedules) { schedule in
                scheduleRow(schedule)
            }

            if scheduleService.canAddSchedule {
                Button {
                    HapticManager.shared.buttonTap()
                    showingNewSchedule = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text(scheduleService.schedules.isEmpty ? "Add a Schedule" : "Add Another")
                            .font(.subheadline).fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.reforgedGold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
        .sheet(item: $editingSchedule) { schedule in
            ScheduleEditorSheet(schedule: schedule, isNew: false, guardedReduce: guardedReduce)
        }
        .sheet(isPresented: $showingNewSchedule) {
            ScheduleEditorSheet(schedule: BlockSchedule(), isNew: true, guardedReduce: guardedReduce)
        }
    }

    private func scheduleRow(_ schedule: BlockSchedule) -> some View {
        Button {
            HapticManager.shared.buttonTap()
            editingSchedule = schedule
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(schedule.label)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        if scheduleService.activeIds.contains(schedule.id) {
                            Text("Active")
                                .font(.caption2).fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Capsule().fill(Color.green))
                        }
                    }
                    Text("\(timeText(schedule.startHour, schedule.startMinute)) – \(timeText(schedule.endHour, schedule.endMinute)) · \(weekdaySummary(schedule.weekdays))")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { schedule.isEnabled },
                    set: { newValue in
                        HapticManager.shared.selectionChanged()
                        if newValue {
                            scheduleService.setEnabled(true, id: schedule.id)
                        } else {
                            guardedReduce {
                                AccountabilityPartnerService.shared.record(.scheduleDisabled, detail: "\"\(schedule.label)\" schedule turned off.")
                                scheduleService.setEnabled(false, id: schedule.id)
                            }
                        }
                    }
                ))
                .labelsHidden()
                .tint(Color.reforgedGold)
                .accessibilityLabel("\(schedule.label) schedule")
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func timeText(_ hour: Int, _ minute: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func weekdaySummary(_ weekdays: Set<Int>) -> String {
        if weekdays.count == 7 { return "Every day" }
        if weekdays == Set([2, 3, 4, 5, 6]) { return "Weekdays" }
        if weekdays == Set([1, 7]) { return "Weekends" }
        return weekdays.sorted().map { Self.weekdaySymbols[$0 - 1] }.joined(separator: " ")
    }
}

// MARK: - Editor Sheet

struct ScheduleEditorSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State var schedule: BlockSchedule
    let isNew: Bool
    let guardedReduce: (@escaping () -> Void) -> Void

    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var selection = FamilyActivitySelection()
    @State private var showAppPicker = false
    @State private var showDeleteConfirm = false

    private static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// Window length in minutes, accounting for overnight wrap.
    private var windowMinutes: Int {
        let cal = Calendar.current
        let start = cal.component(.hour, from: startTime) * 60 + cal.component(.minute, from: startTime)
        let end = cal.component(.hour, from: endTime) * 60 + cal.component(.minute, from: endTime)
        return end > start ? end - start : (24 * 60 - start) + end
    }

    private var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
        || !selection.categoryTokens.isEmpty
        || !selection.webDomainTokens.isEmpty
    }

    private var canSave: Bool {
        hasSelection
        && !schedule.weekdays.isEmpty
        && windowMinutes >= ScheduledBlockingKeys.minWindowMinutes
        && !schedule.label.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Bedtime)", text: $schedule.label)
                } header: {
                    Text("Name")
                }

                Section {
                    DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $endTime, displayedComponents: .hourAndMinute)
                    if windowMinutes < ScheduledBlockingKeys.minWindowMinutes {
                        Text("Windows must be at least \(ScheduledBlockingKeys.minWindowMinutes) minutes.")
                            .font(.caption)
                            .foregroundStyle(Color.reforgedCoral)
                    }
                } header: {
                    Text("Hours")
                } footer: {
                    Text("End earlier than start runs overnight (e.g. 9:00 PM – 6:00 AM).")
                }

                Section {
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { day in
                            let isOn = schedule.weekdays.contains(day)
                            Button {
                                HapticManager.shared.selectionChanged()
                                if isOn {
                                    schedule.weekdays.remove(day)
                                } else {
                                    schedule.weekdays.insert(day)
                                }
                            } label: {
                                Text(Self.weekdayNames[day - 1])
                                    .font(.caption).fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(isOn ? Color.reforgedGold : Color.adaptiveTextSecondary(colorScheme).opacity(0.12))
                                    .foregroundStyle(isOn ? .white : Color.adaptiveText(colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Days")
                }

                Section {
                    Button {
                        HapticManager.shared.buttonTap()
                        showAppPicker = true
                    } label: {
                        HStack {
                            Text("Apps to block")
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Spacer()
                            Text(selectionSummary)
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                    }
                } footer: {
                    if !hasSelection {
                        Text("Pick at least one app or category.")
                    }
                }

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete Schedule")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Schedule" : "Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .familyActivityPicker(isPresented: $showAppPicker, selection: $selection)
            .confirmationDialog("Delete this schedule?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    let id = schedule.id
                    let label = schedule.label
                    // Deleting removes protection → PIN-gated when locked.
                    guardedReduce {
                        AccountabilityPartnerService.shared.record(.scheduleDisabled, detail: "\"\(label)\" schedule deleted.")
                        ScheduledBlockingService.shared.delete(id: id)
                    }
                    dismiss()
                }
            }
            .onAppear {
                var comps = DateComponents()
                comps.hour = schedule.startHour
                comps.minute = schedule.startMinute
                startTime = Calendar.current.date(from: comps) ?? Date()
                comps.hour = schedule.endHour
                comps.minute = schedule.endMinute
                endTime = Calendar.current.date(from: comps) ?? Date()
                selection = schedule.selection
            }
        }
    }

    private var selectionSummary: String {
        let apps = selection.applicationTokens.count
        let cats = selection.categoryTokens.count
        if apps == 0 && cats == 0 { return "Choose" }
        var parts: [String] = []
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }

    private func save() {
        let cal = Calendar.current
        schedule.startHour = cal.component(.hour, from: startTime)
        schedule.startMinute = cal.component(.minute, from: startTime)
        schedule.endHour = cal.component(.hour, from: endTime)
        schedule.endMinute = cal.component(.minute, from: endTime)
        if let data = try? JSONEncoder().encode(selection) {
            schedule.selectionData = data
        }
        HapticManager.shared.success()
        let updated = schedule
        if isNew {
            // Adding a schedule only raises protection — no gate.
            ScheduledBlockingService.shared.save(updated)
        } else {
            // Edits can narrow the window or drop apps → PIN-gated when locked.
            guardedReduce {
                ScheduledBlockingService.shared.save(updated)
            }
        }
        dismiss()
    }
}
