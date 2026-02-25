import SwiftUI

struct MemorySettingsSection: View {
    @StateObject private var settings = SettingsManager.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showManageVerses = false
    @State private var showDeleteConfirmation = false
    @State private var verseToDelete: MemoryVerse?

    var body: some View {
        VStack(spacing: 0) {
            // Enable Spaced Repetition
            SettingsToggleRow(
                title: "Spaced Repetition",
                subtitle: "Use scientifically-proven spacing to optimize memorization",
                isOn: $settings.enableSpacedRepetition
            )

            SettingsDivider()

            // Daily Memory Reminders
            SettingsToggleRow(
                title: "Daily Memory Reminders",
                subtitle: "Get notified when verses are due for review",
                isOn: $settings.dailyMemoryReminders
            )

            SettingsDivider()

            // Memory Stats
            VStack(alignment: .leading, spacing: 12) {
                Text("Memory Progress")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                HStack(spacing: 16) {
                    MemorySettingStatCard(
                        value: "\(appState.memoryVerses.count)",
                        label: "Total Verses",
                        icon: "number",
                        color: .reforgedNavy
                    )

                    MemorySettingStatCard(
                        value: "\(masteredCount)",
                        label: "Mastered",
                        icon: "number",
                        color: .reforgedGold
                    )

                    MemorySettingStatCard(
                        value: "\(dueCount)",
                        label: "Due Today",
                        icon: "number",
                        color: .reforgedCoral
                    )
                }
            }
            .padding(.vertical, 10)

            SettingsDivider()

            // Manage Memory Verses
            SettingsNavigationRow(
                title: "Manage Memory Verses",
                subtitle: "View and delete verses from your collection",
                value: "\(appState.memoryVerses.count) verses"
            ) {
                showManageVerses = true
            }

            SettingsDivider()

            // Reset Button
            SettingsButtonRow(
                title: "Reset Memory Settings",
                icon: "arrow.counterclockwise",
                color: .reforgedCoral
            ) {
                withAnimation {
                    settings.resetMemorySettings()
                }
            }
        }
        .sheet(isPresented: $showManageVerses) {
            ManageMemoryVersesView()
        }
    }

    var masteredCount: Int {
        appState.memoryVerses.filter { $0.level >= 4 }.count
    }

    var dueCount: Int {
        appState.memoryVerses.filter { $0.isDueForReview }.count
    }
}

// MARK: - Memory Setting Stat Card

struct MemorySettingStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Manage Memory Verses View

struct ManageMemoryVersesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @State private var verseToDelete: MemoryVerse?
    @State private var showDeleteConfirmation = false
    @State private var searchText = ""

    var filteredVerses: [MemoryVerse] {
        if searchText.isEmpty {
            return appState.memoryVerses.sorted { $0.reference < $1.reference }
        }
        return appState.memoryVerses.filter {
            $0.reference.localizedCaseInsensitiveContains(searchText) ||
            $0.text.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.reference < $1.reference }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if appState.memoryVerses.isEmpty {
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.adaptiveNavyText(colorScheme).opacity(0.3))

                        Text("No Memory Verses")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Text("Add verses from the Bible view to start memorizing")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                        TextField("Search verses...", text: $searchText)
                            .font(.subheadline)
                    }
                    .padding(12)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()

                    // Verses List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredVerses) { verse in
                                MemoryVerseRow(verse: verse) {
                                    verseToDelete = verse
                                    showDeleteConfirmation = true
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Memory Verses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                }
            }
            .alert("Delete Verse?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    verseToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let verse = verseToDelete {
                        withAnimation {
                            appState.removeMemoryVerse(verse.id)
                        }
                    }
                    verseToDelete = nil
                }
            } message: {
                if let verse = verseToDelete {
                    Text("Are you sure you want to remove \(verse.reference) from your memory verses? This action cannot be undone.")
                }
            }
        }
    }
}

// MARK: - Memory Verse Row

struct MemoryVerseRow: View {
    let verse: MemoryVerse
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(verse.reference)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))

                Spacer()

                // Level indicator
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(index < verse.level ? Color.reforgedGold : Color.adaptiveBorder(colorScheme))
                            .frame(width: 6, height: 6)
                    }
                }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(Color.reforgedCoral)
                        .padding(8)
                        .background(Color.reforgedCoral.opacity(0.1))
                        .clipShape(Circle())
                }
            }

            Text(verse.text)
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .lineLimit(2)

            HStack {
                if verse.isDueForReview {
                    Label("Due for review", systemImage: "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.reforgedCoral)
                } else {
                    Label("Next review: \(verse.nextReviewDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Spacer()

                Text("Level \(verse.level)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.reforgedGold)
            }
        }
        .padding()
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }
}

#Preview {
    ScrollView {
        MemorySettingsSection()
            .padding()
    }
    .environmentObject(AppState.shared)
}
