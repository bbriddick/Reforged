import SwiftUI

// MARK: - Note Accent → Color

extension NoteAccent {
    /// Solid accent color (adaptive for navy so it stays visible in dark mode).
    func color(_ scheme: ColorScheme?) -> Color {
        switch self {
        case .gold:   return .reforgedGold
        case .coral:  return .reforgedCoral
        case .navy:   return Color.adaptiveNavyText(scheme)
        case .blue:   return Color(red: 0.20, green: 0.48, blue: 0.86)
        case .green:  return Color(red: 0.16, green: 0.62, blue: 0.38)
        case .purple: return Color(red: 0.52, green: 0.36, blue: 0.80)
        case .orange: return Color(red: 0.95, green: 0.55, blue: 0.20)
        case .pink:   return Color(red: 0.93, green: 0.42, blue: 0.63)
        }
    }

    /// Literal tint used for translucent backgrounds (never adapts).
    var tint: Color {
        switch self {
        case .gold:   return .reforgedGold
        case .coral:  return .reforgedCoral
        case .navy:   return .reforgedNavy
        case .blue:   return Color(red: 0.20, green: 0.48, blue: 0.86)
        case .green:  return Color(red: 0.16, green: 0.62, blue: 0.38)
        case .purple: return Color(red: 0.52, green: 0.36, blue: 0.80)
        case .orange: return Color(red: 0.95, green: 0.55, blue: 0.20)
        case .pink:   return Color(red: 0.93, green: 0.42, blue: 0.63)
        }
    }
}

// MARK: - Notes Library

struct JournalView: View {
    @State private var entries: [JournalEntry] = []
    @State private var showNewEntry = false
    @State private var showPromptEntry = false
    @State private var showTemplateEntry = false
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var showPrivacyInfo = false
    @State private var showExport = false
    @State private var entryToEdit: JournalEntry? = nil
    @State private var showFolderEditor = false
    @State private var folderToEdit: NoteFolder? = nil
    @State private var itemToMove: MovableItem? = nil
    @ObservedObject private var readingState = BibleReadingState.shared
    @ObservedObject private var org = NoteOrganizationStore.shared
    @Environment(\.colorScheme) var colorScheme

    var filteredEntries: [JournalEntry] {
        let base = searchText.isEmpty ? entries : entries.filter {
            $0.content.localizedCaseInsensitiveContains(searchText) ||
            $0.displayTitle.localizedCaseInsensitiveContains(searchText)
        }
        return base.sorted { $0.updatedAt > $1.updatedAt }
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

    /// Pinned items across both note types (only shown on the "All" tab, no search).
    private var pinnedEntries: [JournalEntry] { filteredEntries.filter(\.isPinned) }
    private var pinnedBibleNotes: [VerseNote] { filteredBibleNotes.filter { org.isBibleNotePinned($0.id) } }
    private var hasPinned: Bool { !pinnedEntries.isEmpty || !pinnedBibleNotes.isEmpty }

    private func noteCount(for folder: NoteFolder) -> Int {
        entries.filter { $0.folderId == folder.id }.count +
        readingState.allNotes.filter { org.folderId(forBibleNote: $0.id) == folder.id }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ReforgedTheme.spacingL) {
                    header
                    PrivacyNoticeBanner()
                    searchBar
                    entryTypeButtons
                    foldersSection

                    if selectedTab == 0 && hasPinned && searchText.isEmpty {
                        pinnedSection
                    }

                    notesSection
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
            .sheet(isPresented: $showTemplateEntry) {
                NewJournalEntrySheet(entries: $entries, templateMode: true, onSave: saveEntries)
            }
            .sheet(isPresented: $showPrivacyInfo) {
                JournalPrivacySheet()
            }
            .sheet(isPresented: $showExport) {
                ExportNotesSheet(journalEntries: entries, bibleNotes: readingState.allNotes)
            }
            .sheet(item: $entryToEdit) { entry in
                NewJournalEntrySheet(
                    entries: $entries,
                    usePrompt: entry.prompt != nil,
                    templateMode: entry.reflectionMethod != nil,
                    entryToEdit: entry,
                    onSave: saveEntries
                )
            }
            .sheet(isPresented: $showFolderEditor) {
                FolderEditorSheet(folder: nil)
            }
            .sheet(item: $folderToEdit) { folder in
                FolderEditorSheet(folder: folder)
            }
            .sheet(item: $itemToMove) { item in
                MoveToFolderSheet(item: item) { folderId in
                    move(item, to: folderId)
                }
            }
            .onAppear { loadEntries() }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notes")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Spacer()

                Button(action: { showFolderEditor = true }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.callout)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        .frame(width: 36, height: 36)
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(Circle())
                }

                Button(action: { showExport = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.callout)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        .frame(width: 36, height: 36)
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(Circle())
                }

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
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            TextField("Search notes...", text: $searchText)
                .font(.subheadline)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
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

    private var entryTypeButtons: some View {
        HStack(spacing: 12) {
            JournalEntryTypeCard(icon: "pencil.line", title: "Free Write",
                                 tint: .reforgedNavy, adaptiveIcon: true) { showNewEntry = true }
            JournalEntryTypeCard(icon: "lightbulb.fill", title: "With Prompt",
                                 tint: .reforgedGold) { showPromptEntry = true }
            JournalEntryTypeCard(icon: "list.bullet.clipboard.fill", title: "Guided Method",
                                 tint: .reforgedCoral) { showTemplateEntry = true }
        }
    }

    @ViewBuilder
    private var foldersSection: some View {
        if !org.folders.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Folders")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    Text("\(org.folders.count)")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(org.folders) { folder in
                        NavigationLink {
                            FolderDetailView(folder: folder, entries: $entries, onSave: saveEntries)
                        } label: {
                            FolderCard(folder: folder, count: noteCount(for: folder))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { folderToEdit = folder } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) { deleteFolder(folder) } label: {
                                Label("Delete Folder", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(Color.reforgedGold)
                Text("Pinned")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }

            ForEach(pinnedEntries) { entry in journalRow(entry) }
            ForEach(pinnedBibleNotes) { note in bibleRow(note) }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 0) {
                JournalTab(title: "All", isSelected: selectedTab == 0) { selectTab(0) }
                JournalTab(title: "Reflections", isSelected: selectedTab == 1) { selectTab(1) }
                JournalTab(title: "Bible Notes", isSelected: selectedTab == 2) { selectTab(2) }
            }
            .padding(4)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)

            if selectedTab == 2 {
                if filteredBibleNotes.isEmpty {
                    EmptyBibleNotesView()
                } else {
                    ForEach(filteredBibleNotes) { note in bibleRow(note) }
                }
            } else {
                // Reflections tab (1) and All tab (0) show journal entries.
                // On "All", pinned entries already appear above.
                let items = selectedTab == 0 && searchText.isEmpty
                    ? filteredEntries.filter { !$0.isPinned }
                    : filteredEntries
                if entries.isEmpty {
                    EmptyJournalView(onAdd: { showNewEntry = true })
                } else if items.isEmpty && !hasPinned {
                    EmptyJournalView(onAdd: { showNewEntry = true })
                } else {
                    ForEach(items) { entry in journalRow(entry) }
                }
            }
        }
    }

    // MARK: Rows (with swipe + context menu)

    private func journalRow(_ entry: JournalEntry) -> some View {
        SwipeToDeleteContainer(
            confirmTitle: "Delete Note",
            confirmMessage: "This note will be permanently deleted from your device.",
            onDelete: { deleteEntry(entry) }
        ) {
            JournalEntryRow(
                entry: entry,
                folderName: org.folder(id: entry.folderId)?.name,
                onEdit: { entryToEdit = entry }
            )
            .contextMenu {
                Button { togglePin(entry) } label: {
                    Label(entry.isPinned ? "Unpin" : "Pin", systemImage: entry.isPinned ? "pin.slash" : "pin")
                }
                Button { itemToMove = .journal(entry) } label: {
                    Label("Move to Folder", systemImage: "folder")
                }
                Button { entryToEdit = entry } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) { deleteEntry(entry) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func bibleRow(_ note: VerseNote) -> some View {
        SwipeToDeleteContainer(
            confirmTitle: "Delete Note",
            confirmMessage: "This note will be permanently deleted.",
            onDelete: { readingState.removeNote(reference: note.reference) }
        ) {
            BibleNoteRow(note: note, folderName: org.folder(id: org.folderId(forBibleNote: note.id))?.name)
                .contextMenu {
                    Button { org.toggleBibleNotePinned(note.id) } label: {
                        Label(org.isBibleNotePinned(note.id) ? "Unpin" : "Pin",
                              systemImage: org.isBibleNotePinned(note.id) ? "pin.slash" : "pin")
                    }
                    Button { itemToMove = .bible(note) } label: {
                        Label("Move to Folder", systemImage: "folder")
                    }
                    Button(role: .destructive) { readingState.removeNote(reference: note.reference) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
    }

    // MARK: Actions

    private func selectTab(_ tab: Int) {
        HapticManager.shared.selectionChanged()
        selectedTab = tab
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

    private func togglePin(_ entry: JournalEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx].isPinned.toggle()
        HapticManager.shared.selectionChanged()
        saveEntries()
    }

    private func move(_ item: MovableItem, to folderId: String?) {
        switch item {
        case .journal(let entry):
            guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
            entries[idx].folderId = folderId
            saveEntries()
        case .bible(let note):
            org.setFolder(folderId, forBibleNote: note.id)
        }
        HapticManager.shared.success()
    }

    private func deleteFolder(_ folder: NoteFolder) {
        // Detach any journal entries that lived in this folder.
        for idx in entries.indices where entries[idx].folderId == folder.id {
            entries[idx].folderId = nil
        }
        saveEntries()
        org.deleteFolder(id: folder.id)
    }
}

// MARK: - Movable Item

/// A note being moved between folders (unifies both note kinds for the sheet).
enum MovableItem: Identifiable {
    case journal(JournalEntry)
    case bible(VerseNote)

    var id: String {
        switch self {
        case .journal(let e): return "journal-\(e.id)"
        case .bible(let n):   return "bible-\(n.id)"
        }
    }
}

// MARK: - Folder Card

struct FolderCard: View {
    let folder: NoteFolder
    let count: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(folder.accent.tint.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: folder.icon)
                    .font(.title3)
                    .foregroundStyle(folder.accent.color(colorScheme))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineLimit(1)
                Text("\(count) \(count == 1 ? "note" : "notes")")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(ReforgedTheme.spacingM)
        .reforgedCard()
    }
}

// MARK: - Folder Detail

struct FolderDetailView: View {
    let folder: NoteFolder
    @Binding var entries: [JournalEntry]
    var onSave: () -> Void

    @ObservedObject private var readingState = BibleReadingState.shared
    @ObservedObject private var org = NoteOrganizationStore.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var entryToEdit: JournalEntry? = nil
    @State private var itemToMove: MovableItem? = nil

    private var folderEntries: [JournalEntry] {
        entries.filter { $0.folderId == folder.id }.sorted { $0.updatedAt > $1.updatedAt }
    }
    private var folderBibleNotes: [VerseNote] {
        readingState.allNotes.filter { org.folderId(forBibleNote: $0.id) == folder.id }
    }
    private var isEmpty: Bool { folderEntries.isEmpty && folderBibleNotes.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: ReforgedTheme.spacingL) {
                if isEmpty {
                    emptyState
                } else {
                    ForEach(folderEntries) { entry in
                        SwipeToDeleteContainer(
                            confirmTitle: "Delete Note",
                            confirmMessage: "This note will be permanently deleted.",
                            onDelete: { deleteEntry(entry) }
                        ) {
                            JournalEntryRow(entry: entry, folderName: nil, onEdit: { entryToEdit = entry })
                                .contextMenu {
                                    Button { itemToMove = .journal(entry) } label: {
                                        Label("Move to Folder", systemImage: "folder")
                                    }
                                    Button { removeFromFolder(entry) } label: {
                                        Label("Remove from Folder", systemImage: "folder.badge.minus")
                                    }
                                    Button(role: .destructive) { deleteEntry(entry) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    ForEach(folderBibleNotes) { note in
                        SwipeToDeleteContainer(
                            confirmTitle: "Delete Note",
                            confirmMessage: "This note will be permanently deleted.",
                            onDelete: { readingState.removeNote(reference: note.reference) }
                        ) {
                            BibleNoteRow(note: note, folderName: nil)
                                .contextMenu {
                                    Button { itemToMove = .bible(note) } label: {
                                        Label("Move to Folder", systemImage: "folder")
                                    }
                                    Button { org.setFolder(nil, forBibleNote: note.id) } label: {
                                        Label("Remove from Folder", systemImage: "folder.badge.minus")
                                    }
                                }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $entryToEdit) { entry in
            NewJournalEntrySheet(
                entries: $entries,
                usePrompt: entry.prompt != nil,
                templateMode: entry.reflectionMethod != nil,
                entryToEdit: entry,
                onSave: onSave
            )
        }
        .sheet(item: $itemToMove) { item in
            MoveToFolderSheet(item: item) { folderId in
                move(item, to: folderId)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(folder.accent.tint.opacity(0.12)).frame(width: 90, height: 90)
                Image(systemName: folder.icon)
                    .font(.system(size: 34))
                    .foregroundStyle(folder.accent.color(colorScheme))
            }
            Text("This folder is empty")
                .font(.title3).fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text("Move notes here from the Notes list to keep them organized.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(ReforgedTheme.spacingXL)
        .frame(maxWidth: .infinity)
        .reforgedCard(elevated: true)
    }

    private func deleteEntry(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        JournalStorageManager.shared.deleteEntry(id: entry.id)
    }

    private func removeFromFolder(_ entry: JournalEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx].folderId = nil
        onSave()
    }

    private func move(_ item: MovableItem, to folderId: String?) {
        switch item {
        case .journal(let entry):
            guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
            entries[idx].folderId = folderId
            onSave()
        case .bible(let note):
            org.setFolder(folderId, forBibleNote: note.id)
        }
        HapticManager.shared.success()
    }
}

// MARK: - Folder Editor

struct FolderEditorSheet: View {
    let folder: NoteFolder?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var org = NoteOrganizationStore.shared

    @State private var name = ""
    @State private var icon = "folder.fill"
    @State private var accent: NoteAccent = .navy

    private let iconChoices = ["folder.fill", "book.closed.fill", "heart.fill", "star.fill",
                               "sparkles", "hands.sparkles.fill", "sun.max.fill", "leaf.fill",
                               "flame.fill", "cross.fill", "bookmark.fill", "quote.bubble.fill"]

    private var isEditing: Bool { folder != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Preview
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(accent.tint.opacity(0.14))
                                    .frame(width: 76, height: 76)
                                Image(systemName: icon)
                                    .font(.system(size: 34))
                                    .foregroundStyle(accent.color(colorScheme))
                            }
                            Text(name.isEmpty ? "New Folder" : name)
                                .font(.headline)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                        }
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name").font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        TextField("Folder name", text: $name)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                            .overlay(
                                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                                    .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icon").font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        let cols = [GridItem(.adaptive(minimum: 52), spacing: 10)]
                        LazyVGrid(columns: cols, spacing: 10) {
                            ForEach(iconChoices, id: \.self) { symbol in
                                Button { icon = symbol } label: {
                                    Image(systemName: symbol)
                                        .font(.title3)
                                        .foregroundStyle(icon == symbol ? .white : accent.color(colorScheme))
                                        .frame(width: 52, height: 52)
                                        .background(icon == symbol ? accent.tint : Color.adaptiveCardBackground(colorScheme))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Color").font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        HStack(spacing: 12) {
                            ForEach(NoteAccent.allCases) { option in
                                Button { accent = option } label: {
                                    Circle()
                                        .fill(option.tint)
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Circle().stroke(Color.adaptiveText(colorScheme),
                                                            lineWidth: accent == option ? 2.5 : 0)
                                                .padding(-3)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if isEditing {
                        Button(role: .destructive) {
                            if let folder { org.deleteFolder(id: folder.id) }
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Folder")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                        }
                    }
                }
                .padding()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Folder" : "New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let folder {
                    name = folder.name
                    icon = folder.icon
                    accent = folder.accent
                }
            }
        }
    }

    private func save() {
        if var folder {
            folder.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            folder.icon = icon
            folder.accent = accent
            org.updateFolder(folder)
        } else {
            _ = org.addFolder(name: name, icon: icon, accent: accent)
        }
        HapticManager.shared.success()
        dismiss()
    }
}

// MARK: - Move To Folder

struct MoveToFolderSheet: View {
    let item: MovableItem
    var onMove: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var org = NoteOrganizationStore.shared
    @State private var showFolderEditor = false

    private var currentFolderId: String? {
        switch item {
        case .journal(let e): return e.folderId
        case .bible(let n):   return org.folderId(forBibleNote: n.id)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    folderRow(id: nil, name: "None (All Notes)", icon: "tray.full",
                              accent: .navy, isSelected: currentFolderId == nil)

                    ForEach(org.folders) { folder in
                        folderRow(id: folder.id, name: folder.name, icon: folder.icon,
                                  accent: folder.accent, isSelected: currentFolderId == folder.id)
                    }

                    Button { showFolderEditor = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.badge.plus")
                                .font(.title3)
                                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                .frame(width: 44, height: 44)
                                .background(Color.reforgedNavy.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Text("New Folder…")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Spacer()
                        }
                        .padding(ReforgedTheme.spacingM)
                        .reforgedCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                }
            }
            .sheet(isPresented: $showFolderEditor) {
                FolderEditorSheet(folder: nil)
            }
        }
    }

    private func folderRow(id: String?, name: String, icon: String,
                           accent: NoteAccent, isSelected: Bool) -> some View {
        Button {
            onMove(id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(accent.color(colorScheme))
                    .frame(width: 44, height: 44)
                    .background(accent.tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(name)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.reforgedGold)
                }
            }
            .padding(ReforgedTheme.spacingM)
            .reforgedCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Chip

struct NoteCategoryChip: View {
    let category: NoteCategory
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: category.icon)
                .font(.system(size: 10))
            Text(category.title)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(category.accent.color(colorScheme))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(category.accent.tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

/// Selectable category chip used in the new-entry sheet.
struct CategorySelectChip: View {
    let category: NoteCategory
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                Text(category.title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(isSelected ? .white : category.accent.color(colorScheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? category.accent.tint : category.accent.tint.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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

// MARK: - Journal Entry Type Card

/// Compact vertical card used for the three ways to start an entry
/// (Free Write, With Prompt, Guided Method).
struct JournalEntryTypeCard: View {
    let icon: String
    let title: String
    let tint: Color
    /// When true the glyph flips to an off-white in dark mode (for navy/charcoal tints).
    var adaptiveIcon: Bool = false
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var iconColor: Color {
        adaptiveIcon ? Color.adaptiveNavyText(colorScheme) : tint
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(iconColor)
                }

                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ReforgedTheme.spacingM)
            .padding(.horizontal, 6)
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

// MARK: - Swipe To Delete Container

struct SwipeToDeleteContainer<Content: View>: View {
    let confirmTitle: String
    let confirmMessage: String
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var dragStarted = false
    @State private var startOffset: CGFloat = 0
    @State private var showConfirmation = false

    private let actionWidth: CGFloat = 80
    private let revealThreshold: CGFloat = 40

    var body: some View {
        ZStack(alignment: .trailing) {
            // Red delete action revealed behind the card
            Button {
                showConfirmation = true
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Delete")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(width: max(0, -offset))
                .frame(maxHeight: .infinity)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
            }
            .opacity(-offset > 12 ? 1 : 0)

            content()
                .offset(x: offset)
                // Use a *simultaneous* gesture with a larger activation distance so a
                // vertical drag scrolls the enclosing ScrollView normally; only a clearly
                // horizontal drag claims the swipe and reveals the Delete action.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18, coordinateSpace: .local)
                        .onChanged { value in
                            if !dragStarted {
                                // Ignore vertical drags entirely — let the ScrollView have them.
                                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                                dragStarted = true
                                startOffset = offset
                            }
                            guard dragStarted else { return }
                            let newOffset = startOffset + value.translation.width
                            withAnimation(.interactiveSpring()) {
                                offset = max(min(newOffset, 0), -actionWidth)
                            }
                        }
                        .onEnded { _ in
                            defer { dragStarted = false }
                            guard dragStarted else { return }
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                offset = -offset > revealThreshold ? -actionWidth : 0
                            }
                        }
                )
                .onTapGesture {
                    guard offset != 0 else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        offset = 0
                    }
                }
        }
        .confirmationDialog(confirmTitle, isPresented: $showConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { offset = 0 }
                onDelete()
            }
            Button("Cancel", role: .cancel) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { offset = 0 }
            }
        } message: {
            Text(confirmMessage)
        }
    }
}

// MARK: - Bible Note Row

// Shared by BibleNoteRow/JournalEntryRow — formatter creation is too
// expensive to repeat on every row render.
private let journalRowDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    return formatter
}()

struct BibleNoteRow: View {
    let note: VerseNote
    var folderName: String? = nil
    @ObservedObject private var org = NoteOrganizationStore.shared
    @Environment(\.colorScheme) var colorScheme

    var formattedDate: String {
        if let date = AppDateFormatters.iso8601.date(from: note.updatedAt) {
            return journalRowDateFormatter.string(from: date)
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

                if org.isBibleNotePinned(note.id) {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(Color.reforgedGold)
                }
            }

            // Note content
            Text(note.content)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineLimit(4)

            // Badges
            HStack(spacing: 6) {
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

                if let folderName {
                    NoteFolderBadge(name: folderName)
                }
            }
        }
        .padding(ReforgedTheme.spacingM)
        .reforgedCard()
    }
}

// MARK: - Folder Badge

struct NoteFolderBadge: View {
    let name: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "folder.fill")
                .font(.system(size: 9))
            Text(name)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.adaptiveChipBackground(colorScheme))
        .clipShape(Capsule())
    }
}

// MARK: - Journal Entry Row

struct JournalEntryRow: View {
    let entry: JournalEntry
    var folderName: String? = nil
    var onEdit: (() -> Void)?
    @Environment(\.colorScheme) var colorScheme

    var formattedDate: String {
        if let date = AppDateFormatters.iso8601.date(from: entry.updatedAt) {
            return journalRowDateFormatter.string(from: date)
        }
        if let date = AppDateFormatters.iso8601.date(from: entry.date) {
            return journalRowDateFormatter.string(from: date)
        }
        return entry.date
    }

    var template: ReflectionTemplate? {
        ReflectionTemplate.named(entry.reflectionMethod)
    }

    var entryIcon: String {
        if let template { return template.icon }
        if entry.prompt != nil { return "lightbulb.fill" }
        return entry.resolvedCategory.icon
    }

    var iconColor: Color {
        if let template { return template.accent.color(colorScheme) }
        if entry.prompt != nil { return .reforgedGold }
        return entry.resolvedCategory.accent.color(colorScheme)
    }

    var iconTint: Color {
        if let template { return template.accent.tint }
        if entry.prompt != nil { return .reforgedGold }
        return entry.resolvedCategory.accent.tint
    }

    private var preview: String {
        entry.previewBody
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(iconTint.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: entryIcon)
                        .font(.caption)
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Spacer()

                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(Color.reforgedGold)
                }

                if onEdit != nil {
                    Button(action: { onEdit?() }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }
            }

            // Content preview
            if !preview.isEmpty {
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(3)
            }

            // Linked verses
            let verses = entry.allLinkedVerses
            if !verses.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.reforgedGold)
                    Text(verses.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Color.reforgedGold)
                        .lineLimit(1)
                }
            }

            // Metadata chips: category, method, folder, tags
            FlexibleChips {
                if entry.resolvedCategory != .general {
                    NoteCategoryChip(category: entry.resolvedCategory)
                }
                if let template {
                    HStack(spacing: 6) {
                        Image(systemName: template.icon)
                            .font(.system(size: 10))
                        Text("\(template.name) Method")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(template.accent.color(colorScheme))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(template.accent.tint.opacity(0.1))
                    .clipShape(Capsule())
                }
                if let folderName {
                    NoteFolderBadge(name: folderName)
                }
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
        .padding(ReforgedTheme.spacingM)
        .reforgedCard()
    }
}

/// A simple wrapping HStack for metadata chips.
struct FlexibleChips<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(spacing: 6) { content() }
    }
}

// MARK: - New Journal Entry Sheet

struct NewJournalEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Binding var entries: [JournalEntry]
    var usePrompt: Bool = false
    var templateMode: Bool = false
    var verseReference: String? = nil
    var verseText: String? = nil
    var entryToEdit: JournalEntry? = nil
    var onSave: (() -> Void)?
    @State private var contentAttributedText = NSAttributedString()
    @State private var titleText: String = ""
    @State private var selectedCategory: NoteCategory = .general
    @State private var selectedFolderId: String? = nil
    @State private var linkedVerses: [String] = []
    @State private var selectedPrompt: String?
    @ObservedObject private var org = NoteOrganizationStore.shared
    @State private var displayedPrompts: [String] = randomJournalPrompts()
    @State private var isLoadingPrompts = false
    @State private var promptsFailed = false
    @State private var selectedTemplate: ReflectionTemplate?
    @State private var lastScaffoldPlain: String = ""
    @State private var pendingTemplate: ReflectionTemplate?
    @State private var showReplaceConfirm = false
    @State private var showVersePicker = false
    @State private var pickerBook = BibleData.defaultBook
    @State private var pickerChapter: Int = 1
    @State private var pickerVerseStart: Int = 0
    @State private var pickerVerseEnd: Int = 0

    private var isEditing: Bool { entryToEdit != nil }
    private var contentIsEmpty: Bool {
        contentAttributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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

                    // Prompt Suggestions
                    if usePrompt {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 6) {
                                Text("Choose a Prompt")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))

                                if isLoadingPrompts {
                                    ProgressView()
                                        .scaleEffect(0.75)
                                }

                                if verseReference != nil && SettingsManager.shared.aiEnabled {
                                    Spacer()
                                    if promptsFailed && !isLoadingPrompts {
                                        Button {
                                            Task { await loadVersePrompts() }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.clockwise")
                                                Text("Retry")
                                            }
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(Color.reforgedGold)
                                        }
                                    } else {
                                        HStack(spacing: 4) {
                                            Image(systemName: "sparkles")
                                                .font(.caption2)
                                            Text("AI")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundStyle(Color.reforgedGold)
                                    }
                                }
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    if isLoadingPrompts {
                                        ForEach(0..<3, id: \.self) { _ in
                                            Text("Generating prompt for this verse...")
                                                .font(.caption)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(Color.adaptiveChipBackground(colorScheme))
                                                .clipShape(Capsule())
                                                .redacted(reason: .placeholder)
                                        }
                                    } else {
                                        ForEach(displayedPrompts, id: \.self) { prompt in
                                            PromptChip(
                                                prompt: prompt,
                                                isSelected: selectedPrompt == prompt
                                            ) {
                                                selectedPrompt = prompt
                                                if contentAttributedText.string.isEmpty {
                                                    contentAttributedText = NSAttributedString.from(prompt + "\n\n")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .task { await loadVersePrompts() }
                    }

                    // Reflection method picker + guide
                    if templateMode {
                        reflectionMethodSection
                    }

                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        TextField("Optional — uses first line if blank", text: $titleText)
                            .font(.body)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                            .overlay(
                                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                                    .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                            )
                    }

                    // Category
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Category")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(NoteCategory.selectable) { category in
                                    CategorySelectChip(
                                        category: category,
                                        isSelected: selectedCategory == category
                                    ) {
                                        selectedCategory = category
                                        HapticManager.shared.selectionChanged()
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

                        RichTextEditor(
                            attributedText: $contentAttributedText,
                            placeholder: "Write your reflection…",
                            minHeight: 220
                        )
                    }

                    // Folder
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Folder")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Menu {
                            Button {
                                selectedFolderId = nil
                            } label: {
                                Label("None (All Notes)", systemImage: selectedFolderId == nil ? "checkmark" : "tray.full")
                            }
                            ForEach(org.folders) { folder in
                                Button {
                                    selectedFolderId = folder.id
                                } label: {
                                    Label(folder.name, systemImage: selectedFolderId == folder.id ? "checkmark" : folder.icon)
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: org.folder(id: selectedFolderId)?.icon ?? "tray.full")
                                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                Text(org.folder(id: selectedFolderId)?.name ?? "None (All Notes)")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
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
                    }

                    // Linked Verses
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Linked Verses")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))

                            Text("(optional)")
                                .font(.subheadline)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                            Spacer()

                            Button {
                                showVersePicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.caption.bold())
                                    Text("Add Verse")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.reforgedNavy.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }

                        if linkedVerses.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "book.closed")
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                Text("No verses linked yet")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                            .overlay(
                                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                                    .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                            )
                        } else {
                            VStack(spacing: 8) {
                                ForEach(linkedVerses, id: \.self) { ref in
                                    HStack(spacing: 10) {
                                        Image(systemName: "book.fill")
                                            .font(.caption)
                                            .foregroundStyle(Color.reforgedGold)
                                        Text(ref)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                        Spacer()
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                linkedVerses.removeAll { $0 == ref }
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.body)
                                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.adaptiveCardBackground(colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                                            .stroke(Color.reforgedGold.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
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
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Save") {
                        saveEntry()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .disabled(contentIsEmpty)
                }
            }
            .sheet(isPresented: $showVersePicker) {
                VersePickerSheet(
                    selectedBook: $pickerBook,
                    selectedChapter: $pickerChapter,
                    selectedVerseStart: $pickerVerseStart,
                    selectedVerseEnd: $pickerVerseEnd,
                    translation: SettingsManager.shared.defaultTranslation
                ) { _, reference in
                    if !linkedVerses.contains(reference) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            linkedVerses.append(reference)
                        }
                    }
                }
            }
            .confirmationDialog(
                "Replace your reflection?",
                isPresented: $showReplaceConfirm,
                titleVisibility: .visible
            ) {
                Button("Replace with \(pendingTemplate?.name ?? "template")", role: .destructive) {
                    if let template = pendingTemplate { applyTemplate(template, force: true) }
                    pendingTemplate = nil
                }
                Button("Keep my text", role: .cancel) { pendingTemplate = nil }
            } message: {
                Text("Applying this method will replace what you've written so far.")
            }
            .onAppear {
                if let existing = entryToEdit {
                    // Load existing entry for editing
                    if let rich = existing.formattedContent {
                        contentAttributedText = rich.attributedString
                    } else {
                        contentAttributedText = existing.content.isEmpty
                            ? NSAttributedString()
                            : NSAttributedString.from(existing.content)
                    }
                    linkedVerses = existing.allLinkedVerses
                    selectedPrompt = existing.prompt
                    selectedTemplate = ReflectionTemplate.named(existing.reflectionMethod)
                    titleText = existing.title ?? ""
                    selectedCategory = existing.resolvedCategory
                    selectedFolderId = existing.folderId
                } else if let ref = verseReference, !linkedVerses.contains(ref) {
                    linkedVerses.append(ref)
                }
            }
        }
    }

    // MARK: Reflection method (Guided) UI

    private var reflectionMethodSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose a Method")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ReflectionTemplate.all) { template in
                        ReflectionMethodChip(
                            template: template,
                            isSelected: selectedTemplate?.id == template.id
                        ) {
                            applyTemplate(template)
                        }
                    }
                }
            }

            if let template = selectedTemplate {
                ReflectionMethodGuide(template: template)
                    .transition(.opacity)
            } else {
                Text("Pick a method to scaffold your reflection with guided steps.")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
    }

    /// Applies a template's scaffold to the editor. Confirms first when the user
    /// has already written something that isn't just the previous scaffold.
    private func loadVersePrompts() async {
        guard usePrompt,
              let ref = verseReference,
              let text = verseText,
              SettingsManager.shared.aiEnabled else { return }
        isLoadingPrompts = true
        promptsFailed = false
        do {
            displayedPrompts = try await GeminiService.shared.generateJournalPrompts(
                reference: ref, verseText: text)
        } catch {
            // Keep the generic fallback prompts on screen, but surface a Retry affordance.
            promptsFailed = true
        }
        isLoadingPrompts = false
    }

    private func applyTemplate(_ template: ReflectionTemplate, force: Bool = false) {
        let current = contentAttributedText.string
        let currentTrimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        let canReplaceFreely = force
            || currentTrimmed.isEmpty
            || current == lastScaffoldPlain

        guard canReplaceFreely else {
            pendingTemplate = template
            showReplaceConfirm = true
            return
        }

        let seed = template.seedsScripture ? (linkedVerses.first ?? verseReference) : nil
        let scaffold = template.scaffold(scriptureSeed: seed)
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTemplate = template
        }
        contentAttributedText = scaffold
        lastScaffoldPlain = scaffold.string
        HapticManager.shared.selectionChanged()
    }

    private var navigationTitleText: String {
        if isEditing { return "Edit Entry" }
        if templateMode { return "Guided Reflection" }
        return usePrompt ? "Prompted Entry" : "Free Write"
    }

    func saveEntry() {
        HapticManager.shared.journalSaved()

        let plainText      = contentAttributedText.string
        let richContent    = RichTextNoteContent(attributedString: contentAttributedText)
        let now            = AppDateFormatters.iso8601.string(from: Date())
        let trimmedTitle   = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryValue  = selectedCategory == .general ? nil : selectedCategory.rawValue

        if let existing = entryToEdit {
            // Update in-place
            let updated = JournalEntry(
                id: existing.id,
                date: existing.date,
                content: plainText,
                tags: existing.tags,
                formattedContent: richContent,
                linkedVerse: existing.linkedVerse,
                linkedVerses: linkedVerses,
                linkedLesson: existing.linkedLesson,
                linkedInsight: existing.linkedInsight,
                prompt: selectedPrompt,
                reflectionMethod: selectedTemplate?.acronym ?? existing.reflectionMethod,
                title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                folderId: selectedFolderId,
                category: categoryValue,
                isPinned: existing.isPinned,
                updatedAt: now
            )
            if let idx = entries.firstIndex(where: { $0.id == existing.id }) {
                entries[idx] = updated
            }
            JournalStorageManager.shared.updateEntry(updated)
        } else {
            let entry = JournalEntry(
                id: UUID().uuidString,
                date: now,
                content: plainText,
                tags: [],
                formattedContent: richContent,
                linkedVerses: linkedVerses,
                prompt: selectedPrompt,
                reflectionMethod: selectedTemplate?.acronym,
                title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                folderId: selectedFolderId,
                category: categoryValue,
                isPinned: false,
                updatedAt: now
            )
            entries.insert(entry, at: 0)
            JournalStorageManager.shared.addEntry(entry)
            appState.addXP(20, source: "reflection")
        }
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

// MARK: - Reflection Method Chip

struct ReflectionMethodChip: View {
    let template: ReflectionTemplate
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: template.icon)
                        .font(.callout)
                        .foregroundStyle(isSelected ? .white : template.accent.color(colorScheme))

                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme))

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }

                Text(template.tagline)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: 200, alignment: .leading)
            .background(isSelected ? template.accent.tint : Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                    .stroke(isSelected ? Color.clear : Color.adaptiveBorder(colorScheme), lineWidth: 1)
            )
            .shadow(color: isSelected ? template.accent.tint.opacity(0.25) : Color.clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reflection Method Guide

/// A reference card listing each step of the selected method with its guidance,
/// shown alongside the editor so saved entries stay clean.
struct ReflectionMethodGuide: View {
    let template: ReflectionTemplate
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(template.summary)
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(template.sections) { section in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(template.accent.tint.opacity(0.14))
                            .frame(width: 30, height: 30)
                        Text(section.letter)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(template.accent.color(colorScheme))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text(section.guidance)
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(ReforgedTheme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(template.accent.tint.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                .stroke(template.accent.tint.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Export Notes Sheet

struct ExportNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    let journalEntries: [JournalEntry]
    let bibleNotes: [VerseNote]

    @State private var includeJournal = true
    @State private var includeBibleNotes = true
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var exportError = false

    private var activeEntries: [JournalEntry] { includeJournal ? journalEntries : [] }
    private var activeNotes: [VerseNote]      { includeBibleNotes ? bibleNotes : [] }
    private var hasContent: Bool              { !activeEntries.isEmpty || !activeNotes.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Content toggles
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Content to Export")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Toggle(isOn: $includeJournal) {
                            Label(
                                "Journal Reflections (\(journalEntries.count))",
                                systemImage: "pencil.line"
                            )
                            .font(.subheadline)
                        }
                        .tint(Color.reforgedNavy)

                        Toggle(isOn: $includeBibleNotes) {
                            Label(
                                "Bible Notes (\(bibleNotes.count))",
                                systemImage: "book.fill"
                            )
                            .font(.subheadline)
                        }
                        .tint(Color.reforgedNavy)
                    }
                    .padding(ReforgedTheme.spacingM)
                    .reforgedCard()

                    // Format options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose Format")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        ExportFormatRow(
                            icon: "doc.richtext.fill",
                            iconColor: .red,
                            title: "PDF Document",
                            subtitle: "Best for reading and printing",
                            isLoading: isExporting,
                            isDisabled: !hasContent
                        ) {
                            performExport { ExportService.shared.exportAsPDF(journalEntries: activeEntries, bibleNotes: activeNotes) }
                        }

                        ExportFormatRow(
                            icon: "doc.text.fill",
                            iconColor: Color(red: 0.18, green: 0.35, blue: 0.75),
                            title: "Word Document (.docx)",
                            subtitle: "Opens in Word, Pages, Google Docs",
                            isLoading: isExporting,
                            isDisabled: !hasContent
                        ) {
                            performExport { ExportService.shared.exportAsDocx(journalEntries: activeEntries, bibleNotes: activeNotes) }
                        }

                        ExportFormatRow(
                            icon: "doc.plaintext.fill",
                            iconColor: .gray,
                            title: "Plain Text (.txt)",
                            subtitle: "Works with any app or text editor",
                            isLoading: isExporting,
                            isDisabled: !hasContent
                        ) {
                            performExport { ExportService.shared.exportAsText(journalEntries: activeEntries, bibleNotes: activeNotes) }
                        }

                        ExportFormatRow(
                            icon: "archivebox.fill",
                            iconColor: .orange,
                            title: "ZIP Archive",
                            subtitle: "Bundle of all notes as individual files",
                            isLoading: isExporting,
                            isDisabled: !hasContent
                        ) {
                            performExport { ExportService.shared.exportAsZip(journalEntries: activeEntries, bibleNotes: activeNotes) }
                        }
                    }

                    // Privacy note
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(Color.green)
                        Text("Your notes are only shared with apps you choose")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                }
                .padding()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Export Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Export Failed", isPresented: $exportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Could not generate the export file. Please try again.")
            }
        }
    }

    private func performExport(_ generate: @escaping () -> URL?) {
        guard !isExporting else { return }
        isExporting = true
        Task { @MainActor in
            if let url = generate() {
                exportURL = url
                showShareSheet = true
            } else {
                exportError = true
            }
            isExporting = false
        }
    }
}

struct ExportFormatRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var isLoading: Bool
    var isDisabled: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Spacer()

                if isLoading {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .padding(ReforgedTheme.spacingM)
            .reforgedCard()
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }
}

#if false
#Preview {
    JournalView()
        .environmentObject(AppState.shared)
}
#endif
