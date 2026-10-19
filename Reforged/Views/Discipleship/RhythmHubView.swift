import SwiftUI

/// "My Rhythm" — the member's self-built rule of life. A daily checklist they
/// design (habits to keep, temptations to avoid, with real reminders), plus
/// build-your-own reading plans and social-media time-off windows. Reached from
/// the Discipleship hub.
struct RhythmHubView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var store = RhythmStorageManager.shared
    @StateObject private var planStore = CustomReadingPlanStore.shared
    @StateObject private var scheduleService = ScheduledBlockingService.shared

    @State private var showItemEditor = false
    @State private var editingItem: RhythmItem?
    @State private var showPlanBuilder = false
    /// Edit mode shows a delete button on every checklist item and custom plan.
    @State private var isEditing = false
    @State private var itemToDelete: RhythmItem?
    @State private var planToDelete: CustomReadingPlanSpec?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                checklistSection
                allDisciplinesSection
                readingSection
                timeOffSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("My Disciplines")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !store.items.isEmpty || !planStore.specs.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Done" : "Edit") {
                        HapticManager.shared.buttonTap()
                        withAnimation(.easeInOut(duration: 0.2)) { isEditing.toggle() }
                    }
                    .fontWeight(isEditing ? .semibold : .regular)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { HapticManager.shared.buttonTap(); showItemEditor = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Delete this discipline?", isPresented: Binding(
            get: { itemToDelete != nil }, set: { if !$0 { itemToDelete = nil } }
        ), presenting: itemToDelete) { item in
            Button("Delete", role: .destructive) {
                HapticManager.shared.mediumImpact()
                withAnimation { store.delete(item) }
                if store.items.isEmpty && planStore.specs.isEmpty { isEditing = false }
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("\u{201C}\(item.title)\u{201D} and its reminder will be removed.")
        }
        .alert("Delete this reading plan?", isPresented: Binding(
            get: { planToDelete != nil }, set: { if !$0 { planToDelete = nil } }
        ), presenting: planToDelete) { spec in
            Button("Delete", role: .destructive) {
                HapticManager.shared.mediumImpact()
                ReadingPlanService.shared.resetPlan(spec.id)
                withAnimation { planStore.delete(id: spec.id) }
                if store.items.isEmpty && planStore.specs.isEmpty { isEditing = false }
            }
            Button("Cancel", role: .cancel) {}
        } message: { spec in
            Text("\u{201C}\(spec.name)\u{201D} and your progress in it will be removed.")
        }
        .sheet(isPresented: $showItemEditor) {
            RhythmItemEditorView().environmentObject(appState)
        }
        .sheet(item: $editingItem) { item in
            RhythmItemEditorView(editing: item).environmentObject(appState)
        }
        .sheet(isPresented: $showPlanBuilder) {
            CustomReadingPlanBuilderView()
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 16) {
            progressRing
            VStack(alignment: .leading, spacing: 4) {
                Text(store.todayDueCount == 0 ? "Build your daily disciplines"
                                              : "Today's disciplines")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(store.todayDueCount == 0
                     ? "Build a checklist of habits to keep and things to avoid."
                     : "\(store.todayCompletedCount) of \(store.todayDueCount) done today")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, y: 3)
    }

    private var progressRing: some View {
        ZStack {
            Circle().stroke(Color.reforgedGold.opacity(0.18), lineWidth: 7)
            Circle()
                .trim(from: 0, to: max(0.001, store.todayProgress))
                .stroke(Color.reforgedGold, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((store.todayProgress * 100).rounded()))%")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.adaptiveText(colorScheme))
        }
        .frame(width: 56, height: 56)
        .animation(.easeInOut, value: store.todayProgress)
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Today's Checklist")

            if store.itemsDueToday.isEmpty {
                emptyChecklist
            } else {
                VStack(spacing: 10) {
                    ForEach(store.itemsDueToday) { item in
                        checklistRow(item)
                    }
                }
            }

            Button { HapticManager.shared.buttonTap(); showItemEditor = true } label: {
                Label("Add to checklist", systemImage: "plus.circle.fill")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
            }
            .padding(.top, 2)
        }
    }

    private func checklistRow(_ item: RhythmItem) -> some View {
        let done = store.isCompletedToday(item.id)
        return HStack(spacing: 12) {
            Button {
                HapticManager.shared.buttonTap()
                store.toggleToday(item.id)
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(done ? item.accent.color(colorScheme)
                                          : Color.adaptiveTextSecondary(colorScheme))
            }
            .buttonStyle(.plain)

            Image(systemName: item.iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(item.accent.color(colorScheme))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    if item.kind == .avoid {
                        Text("AVOID")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.reforgedCoral)
                    }
                    Text(item.title)
                        .font(.subheadline).fontWeight(.medium)
                        .strikethrough(done, color: Color.adaptiveTextSecondary(colorScheme))
                        .foregroundStyle(done ? Color.adaptiveTextSecondary(colorScheme)
                                              : Color.adaptiveText(colorScheme))
                }
                if item.reminderEnabled {
                    Label(item.reminderTimeLabel, systemImage: "bell.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }

            Spacer()

            Button {
                HapticManager.shared.buttonTap()
                if isEditing { itemToDelete = item } else { editingItem = item }
            } label: {
                Image(systemName: isEditing ? "trash" : "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isEditing ? Color.red : Color.adaptiveTextSecondary(colorScheme))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isEditing ? "Delete \(item.title)" : "Edit \(item.title)")
        }
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05), radius: 6, y: 2)
        .contextMenu {
            Button { editingItem = item } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { itemToDelete = item } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // MARK: - All disciplines (manage / edit / delete)

    /// Every discipline the member has created — including ones not scheduled for today — so
    /// they can always reach one to edit or delete it. The checklist above shows only today's.
    @ViewBuilder
    private var allDisciplinesSection: some View {
        if !store.items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("All Disciplines")
                VStack(spacing: 10) {
                    ForEach(store.items) { item in
                        manageRow(item)
                    }
                }
                Text(isEditing ? "Tap a discipline to delete it." : "Tap a discipline to edit it, or press and hold to delete it.")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
    }

    private func manageRow(_ item: RhythmItem) -> some View {
        Button {
            HapticManager.shared.buttonTap()
            if isEditing { itemToDelete = item } else { editingItem = item }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(item.accent.color(colorScheme))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        if item.kind == .avoid {
                            Text("AVOID")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.reforgedCoral)
                        }
                        Text(item.title)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .lineLimit(1)
                    }
                    Text(item.weekdays.count >= 7 ? "Every day"
                                                  : "\(item.weekdays.count) day\(item.weekdays.count == 1 ? "" : "s")/week")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
                Image(systemName: isEditing ? "trash" : "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isEditing ? Color.red : Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(14)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { editingItem = item } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { itemToDelete = item } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private var emptyChecklist: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 28))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            Text("No items for today yet.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Reading

    private var readingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Bible Reading")

            ForEach(planStore.specs) { spec in
                Group {
                    if isEditing {
                        Button {
                            HapticManager.shared.buttonTap()
                            planToDelete = spec
                        } label: { planRow(spec) }
                    } else {
                        NavigationLink {
                            ReadingPlanDetailView(plan: BibleReadingPlan(spec: spec))
                        } label: { planRow(spec) }
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) { planToDelete = spec } label: {
                        Label("Delete Plan", systemImage: "trash")
                    }
                }
            }

            Button { HapticManager.shared.buttonTap(); showPlanBuilder = true } label: {
                tile(icon: "plus.circle.fill", title: "Create your own reading plan",
                     subtitle: "Pick books and a daily pace", accent: .teal)
            }
            .buttonStyle(.plain)

            NavigationLink { ReadingPlansView() } label: {
                tile(icon: "calendar.badge.checkmark", title: "Browse reading plans",
                     subtitle: "Foundation, Character, Bible in a Year & more", accent: .blue)
            }
            .buttonStyle(.plain)
        }
    }

    private func planRow(_ spec: CustomReadingPlanSpec) -> some View {
        let progress = ReadingPlanService.shared.progress(for: spec.id)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(spec.accent.color(colorScheme).opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: spec.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(spec.accent.color(colorScheme))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(spec.name).font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme)).lineLimit(1)
                if progress > 0 {
                    ProgressView(value: progress).tint(spec.accent.color(colorScheme))
                } else {
                    Text("\(spec.totalDays) days · yours")
                        .font(.caption2).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            Spacer()
            Image(systemName: isEditing ? "trash" : "chevron.right")
                .font(isEditing ? .system(size: 14, weight: .semibold) : .caption)
                .foregroundStyle(isEditing ? Color.red : Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05), radius: 6, y: 2)
    }

    // MARK: - Social media time-off

    private var timeOffSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Social Media Time-Off")

            NavigationLink {
                // Reuse the Shield's proven schedule editor (real Screen Time
                // blocks). The passthrough guard means adding/adjusting a window
                // here doesn't require the shield PIN; disabling protection still
                // routes through the shield itself.
                SchedulesListView(scheduleService: scheduleService,
                                  guardedReduce: { $0() })
            } label: {
                tile(icon: "moon.zzz.fill",
                     title: "Schedule time away from apps",
                     subtitle: timeOffSubtitle, accent: .purple)
            }
            .buttonStyle(.plain)
        }
    }

    private var timeOffSubtitle: String {
        let count = scheduleService.schedules.count
        if count == 0 { return "Block distracting apps during set hours" }
        let enabled = scheduleService.schedules.filter { $0.isEnabled }.count
        return "\(count) window\(count == 1 ? "" : "s") · \(enabled) on"
    }

    // MARK: - Shared bits

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.0)
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tile(icon: String, title: String, subtitle: String, accent: PlanAccent) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(accent.color(colorScheme).opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent.color(colorScheme))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(subtitle).font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05), radius: 6, y: 2)
    }
}

#if DEBUG
struct RhythmHubView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            RhythmHubView().environmentObject(AppState.shared)
        }
    }
}
#endif
