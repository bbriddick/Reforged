import SwiftUI

struct JournalView: View {
    @State private var entries: [JournalEntry] = []
    @State private var showNewEntry = false
    @State private var showPromptEntry = false
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var showPrivacyInfo = false
    @ObservedObject private var readingState = BibleReadingState.shared
    @Environment(\.colorScheme) var colorScheme

    var filteredEntries: [JournalEntry] {
        if searchText.isEmpty {
            return entries
        }
        return entries.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredBibleNotes: [VerseNote] {
        if searchText.isEmpty {
            return readingState.allNotes
        }
        return readingState.allNotes.filter {
            $0.content.localizedCaseInsensitiveContains(searchText) ||
            $0.reference.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ReforgedTheme.spacingL) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Journal")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))

                            Spacer()

                            // Privacy indicator button
                            Button(action: { showPrivacyInfo = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                    Text("Private")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(Color.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }

                        Text("Reflect on your journey with God's Word")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Privacy notice banner
                    PrivacyNoticeBanner()

                    // Search bar
                    HStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                            TextField("Search entries...", text: $searchText)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                        .overlay(
                            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                        )
                    }

                    // Entry type buttons
                    HStack(spacing: 12) {
                        JournalTypeButton(
                            icon: "pencil.line",
                            title: "Free Write",
                            color: .reforgedNavy
                        ) {
                            showNewEntry = true
                        }

                        JournalTypeButton(
                            icon: "lightbulb.fill",
                            title: "With Prompt",
                            color: .reforgedGold
                        ) {
                            showPromptEntry = true
                        }
                    }

                    // Entries section
                    VStack(alignment: .leading, spacing: 14) {
                        // Always show tabs (include Bible Notes tab)
                        HStack(spacing: 0) {
                            JournalTab(title: "All", isSelected: selectedTab == 0) {
                                HapticManager.shared.selectionChanged()
                                selectedTab = 0
                            }
                            JournalTab(title: "Reflections", isSelected: selectedTab == 1) {
                                HapticManager.shared.selectionChanged()
                                selectedTab = 1
                            }
                            JournalTab(title: "Bible Notes", isSelected: selectedTab == 2) {
                                HapticManager.shared.selectionChanged()
                                selectedTab = 2
                            }
                        }
                        .padding(4)
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)

                        // Content based on selected tab
                        if selectedTab == 2 {
                            // Bible Notes tab
                            if filteredBibleNotes.isEmpty {
                                EmptyBibleNotesView()
                            } else {
                                ForEach(filteredBibleNotes) { note in
                                    BibleNoteRow(note: note, onDelete: {
                                        readingState.removeNote(reference: note.reference)
                                    })
                                }
                            }
                        } else {
                            // Journal entries tabs
                            if entries.isEmpty {
                                EmptyJournalView(onAdd: { showNewEntry = true })
                            } else {
                                ForEach(filteredEntries) { entry in
                                    JournalEntryRow(entry: entry, onDelete: {
                                        deleteEntry(entry)
                                    })
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showNewEntry) {
                NewJournalEntrySheet(entries: $entries, usePrompt: false, onSave: saveEntries)
            }
            .sheet(isPresented: $showPromptEntry) {
                NewJournalEntrySheet(entries: $entries, usePrompt: true, onSave: saveEntries)
            }
            .sheet(isPresented: $showPrivacyInfo) {
                JournalPrivacySheet()
            }
            .onAppear {
                loadEntries()
            }
        }
    }

    private func loadEntries() {
        entries = JournalStorageManager.shared.loadEntries()
    }

    private func saveEntries() {
        JournalStorageManager.shared.saveEntries(entries)
    }

    private func deleteEntry(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        JournalStorageManager.shared.deleteEntry(id: entry.id)
    }
}

// MARK: - Privacy Notice Banner

struct PrivacyNoticeBanner: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.title3)
                .foregroundStyle(Color.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Your journal is private & secure")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("Entries are encrypted and stored only on this device")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            Spacer()
        }
        .padding(14)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Journal Privacy Sheet

struct JournalPrivacySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header icon
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.12))
                                .frame(width: 80, height: 80)

                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.green)
                        }
                        Spacer()
                    }

                    // Title
                    Text("Your Journal is Private")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Privacy points
                    VStack(alignment: .leading, spacing: 16) {
                        PrivacyPoint(
                            icon: "iphone",
                            title: "Stored Locally Only",
                            description: "Your journal entries are stored exclusively on this device. They are never uploaded to our servers or any cloud service."
                        )

                        PrivacyPoint(
                            icon: "lock.fill",
                            title: "Encrypted Storage",
                            description: "All entries are encrypted using AES-256 encryption with a unique key stored securely in your device's Keychain."
                        )

                        PrivacyPoint(
                            icon: "eye.slash.fill",
                            title: "No One Can Read Them",
                            description: "Not even Reforged developers can access your journal entries. Your thoughts and prayers remain completely private."
                        )

                        PrivacyPoint(
                            icon: "trash.fill",
                            title: "You're in Control",
                            description: "You can delete individual entries or all entries at any time. Deleted entries are permanently removed."
                        )

                        PrivacyPoint(
                            icon: "arrow.triangle.2.circlepath",
                            title: "No Sync or Backup",
                            description: "Journal entries do not sync across devices and are not included in cloud backups. If you switch devices, entries will not transfer."
                        )
                    }

                    // Important note
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.orange)
                            Text("Important")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                        }

                        Text("Because your journal is stored only on this device, it will be lost if you uninstall the app or reset your device. Consider keeping a separate backup of important reflections if needed.")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                }
                .padding()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Privacy & Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                }
            }
        }
    }
}

struct PrivacyPoint: View {
    let icon: String
    let title: String
    let description: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(Color.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Journal Type Button

struct JournalTypeButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(ReforgedTheme.spacingM)
            .frame(maxWidth: .infinity)
            .reforgedCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Journal Tab

struct JournalTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.adaptiveNavyText(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.reforgedNavy.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty Journal View

struct EmptyJournalView: View {
    let onAdd: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.reforgedGold.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "book.closed.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.reforgedGold)
            }

            VStack(spacing: 8) {
                Text("Your journal is empty")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("Start writing reflections on your Bible study journey")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
            }

            Button(action: onAdd) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.callout.bold())
                    Text("Write Your First Entry")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.reforgedNavy)
                .clipShape(Capsule())
                .shadow(color: Color.reforgedNavy.opacity(0.3), radius: 8, y: 4)
            }
        }
        .padding(ReforgedTheme.spacingXL)
        .frame(maxWidth: .infinity)
        .reforgedCard(elevated: true)
    }
}

// MARK: - Empty Bible Notes View

struct EmptyBibleNotesView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.reforgedNavy.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "note.text.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
            }

            VStack(spacing: 8) {
                Text("No Bible notes yet")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("When you add notes to verses while reading, they'll appear here")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .font(.caption)
                Text("Long-press a verse to add a note")
                    .font(.caption)
            }
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(Capsule())
        }
        .padding(ReforgedTheme.spacingXL)
        .frame(maxWidth: .infinity)
        .reforgedCard(elevated: true)
    }
}

// MARK: - Bible Note Row

struct BibleNoteRow: View {
    let note: VerseNote
    var onDelete: (() -> Void)?
    @Environment(\.colorScheme) var colorScheme
    @State private var showDeleteConfirmation = false

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"

        if let date = ISO8601DateFormatter().date(from: note.updatedAt) {
            return formatter.string(from: date)
        }
        return note.updatedAt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.reforgedNavy.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: "book.fill")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.reference)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedGold)

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Spacer()

                // Delete button
                if onDelete != nil {
                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }
            }

            // Note content
            Text(note.content)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineLimit(4)

            // Bible note badge
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 10))
                Text("Bible Note")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.reforgedNavy.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(ReforgedTheme.spacingM)
        .reforgedCard()
        .confirmationDialog("Delete Note", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                HapticManager.shared.lightImpact()
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This note will be permanently deleted.")
        }
    }
}

// MARK: - Journal Entry Row

struct JournalEntryRow: View {
    let entry: JournalEntry
    var onDelete: (() -> Void)?
    @Environment(\.colorScheme) var colorScheme
    @State private var showDeleteConfirmation = false

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"

        if let date = ISO8601DateFormatter().date(from: entry.date) {
            return formatter.string(from: date)
        }
        return entry.date
    }

    var entryIcon: String {
        if entry.prompt != nil {
            return "lightbulb.fill"
        }
        return "pencil.line"
    }

    var iconColor: Color {
        if entry.prompt != nil {
            return .reforgedGold
        }
        return .reforgedNavy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: entryIcon)
                        .font(.caption)
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedDate)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    if let verse = entry.linkedVerse {
                        Text(verse)
                            .font(.caption)
                            .foregroundStyle(Color.reforgedGold)
                    }
                }

                Spacer()

                // Delete button
                if onDelete != nil {
                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }
            }

            // Content preview
            Text(entry.content)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .lineLimit(3)

            // Tags
            if !entry.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entry.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.reforgedNavy.opacity(0.1))
                            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(ReforgedTheme.spacingM)
        .reforgedCard()
        .confirmationDialog("Delete Entry", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This journal entry will be permanently deleted from your device.")
        }
    }
}

// MARK: - New Journal Entry Sheet

struct NewJournalEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Binding var entries: [JournalEntry]
    var usePrompt: Bool = false
    var onSave: (() -> Void)?
    @State private var content = ""
    @State private var linkedVerse = ""
    @State private var selectedPrompt: String?
    @State private var displayedPrompts: [String] = randomJournalPrompts()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Privacy reminder
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Color.green)
                        Text("This entry will be stored securely on your device only")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))

                    // Prompt Suggestions (show if usePrompt or always show)
                    if usePrompt {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Choose a Prompt")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(displayedPrompts, id: \.self) { prompt in
                                        PromptChip(
                                            prompt: prompt,
                                            isSelected: selectedPrompt == prompt
                                        ) {
                                            selectedPrompt = prompt
                                            if content.isEmpty {
                                                content = prompt + "\n\n"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your Reflection")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        TextEditor(text: $content)
                            .frame(minHeight: 220)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                            .overlay(
                                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                                    .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                            )
                    }

                    // Linked Verse
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Link a Verse (optional)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        HStack(spacing: 10) {
                            Image(systemName: "book.fill")
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                            TextField("e.g., John 3:16", text: $linkedVerse)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                        .overlay(
                            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                        )
                    }

                    // XP reward info
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.reforgedGold)
                        Text("Earn +15 XP for journaling")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding(ReforgedTheme.spacingM)
                    .frame(maxWidth: .infinity)
                    .background(Color.reforgedGold.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                }
                .padding()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle(usePrompt ? "Prompted Entry" : "Free Write")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .disabled(content.isEmpty)
                }
            }
        }
    }

    func saveEntry() {
        // Haptic feedback for saving
        HapticManager.shared.journalSaved()

        let entry = JournalEntry(
            id: UUID().uuidString,
            date: ISO8601DateFormatter().string(from: Date()),
            content: content,
            tags: [],
            linkedVerse: linkedVerse.isEmpty ? nil : linkedVerse,
            linkedLesson: nil,
            linkedInsight: nil,
            prompt: selectedPrompt
        )
        entries.insert(entry, at: 0)
        JournalStorageManager.shared.addEntry(entry)
        appState.addXP(20, source: "reflection")
        onSave?()
    }
}

struct PromptChip: View {
    let prompt: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Text(prompt)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: 160)
                .background(isSelected ? Color.reforgedNavy : Color.adaptiveCardBackground(colorScheme))
                .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                        .stroke(isSelected ? Color.clear : Color.adaptiveBorder(colorScheme), lineWidth: 1)
                )
                .shadow(color: isSelected ? Color.reforgedNavy.opacity(0.2) : Color.clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    JournalView()
        .environmentObject(AppState.shared)
}
