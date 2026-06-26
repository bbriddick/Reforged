import SwiftUI

// MARK: - Collection Builder

/// Sheet for creating a new verse collection, either by importing a Bible chapter (auto-split
/// by verse, with checkboxes to trim) or by assembling verses manually.
struct CollectionBuilderView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private enum BuilderMode: String, CaseIterable {
        case chapter = "From Chapter"
        case manual = "Manual"
    }

    @State private var mode: BuilderMode = .chapter
    @State private var name: String = ""

    // From Chapter
    @State private var selectedBookID: String = (BibleData.books.first ?? BibleData.fallbackBook).id
    @State private var selectedChapter: Int = 1
    @State private var fetchedVerses: [ParsedVerse] = []
    @State private var selectedReferences: Set<String> = []
    @State private var isLoading = false
    @State private var loadError: String?

    // Manual
    @State private var manualVerses: [CollectionVerse] = []
    @State private var manualReference: String = ""
    @State private var manualText: String = ""

    private var translation: BibleTranslation { SettingsManager.shared.defaultTranslation }

    private var selectedBook: BibleBook {
        BibleData.books.first { $0.id == selectedBookID } ?? BibleData.fallbackBook
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.adaptiveBackground(colorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: ReforgedTheme.spacingL) {
                        Picker("Source", selection: $mode) {
                            ForEach(BuilderMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        nameField

                        switch mode {
                        case .chapter: chapterSection
                        case .manual:  manualSection
                        }
                    }
                    .padding(ReforgedTheme.spacingL)
                }
            }
            .navigationTitle("New Collection")
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
        }
    }

    // MARK: - Shared name field

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            TextField("Collection name", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - From Chapter

    private var chapterSection: some View {
        VStack(alignment: .leading, spacing: ReforgedTheme.spacingM) {
            HStack(spacing: 12) {
                Picker("Book", selection: $selectedBookID) {
                    ForEach(BibleData.books) { book in
                        Text(book.name).tag(book.id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedBookID) { _ in
                    selectedChapter = 1
                }

                Picker("Chapter", selection: $selectedChapter) {
                    ForEach(1...selectedBook.chapters, id: \.self) { ch in
                        Text("\(ch)").tag(ch)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Button(action: loadChapter) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Load").fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }

            if let loadError {
                Text(loadError)
                    .font(.subheadline)
                    .foregroundStyle(Color.reforgedCoral)
            }

            if !fetchedVerses.isEmpty {
                HStack {
                    Text("\(selectedReferences.count) of \(fetchedVerses.count) selected")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Spacer()
                    Button(selectedReferences.count == fetchedVerses.count ? "Deselect All" : "Select All") {
                        if selectedReferences.count == fetchedVerses.count {
                            selectedReferences.removeAll()
                        } else {
                            selectedReferences = Set(fetchedVerses.map { $0.reference })
                        }
                    }
                    .font(.subheadline)
                }

                VStack(spacing: 8) {
                    ForEach(fetchedVerses) { verse in
                        verseToggleRow(verse)
                    }
                }
            }
        }
    }

    private func verseToggleRow(_ verse: ParsedVerse) -> some View {
        let isOn = selectedReferences.contains(verse.reference)
        return Button {
            HapticManager.shared.selectionChanged()
            if isOn { selectedReferences.remove(verse.reference) }
            else { selectedReferences.insert(verse.reference) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? Color.adaptivePrimaryIcon(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verse.reference)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Text(verse.text)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func loadChapter() {
        isLoading = true
        loadError = nil
        let book = selectedBook
        let chapter = selectedChapter
        let t = translation
        Task {
            do {
                let entry = try await ChapterScrollCoordinator.performChapterFetch(
                    book: book.name, chapter: chapter, translation: t)
                await MainActor.run {
                    fetchedVerses = entry.verses
                    selectedReferences = Set(entry.verses.map { $0.reference })
                    if name.trimmingCharacters(in: .whitespaces).isEmpty {
                        name = "\(book.name) \(chapter)"
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadError = "Couldn't load \(book.name) \(chapter). Check your connection and try again."
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Manual

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: ReforgedTheme.spacingM) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Reference (e.g. John 3:16)", text: $manualReference)
                    .textFieldStyle(.roundedBorder)
                TextField("Verse text", text: $manualText, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
                Button(action: addManualVerse) {
                    Label("Add Verse", systemImage: "plus.circle.fill")
                }
                .disabled(manualReference.trimmingCharacters(in: .whitespaces).isEmpty
                          || manualText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !appState.memoryVerses.isEmpty {
                Text("Or add from your memory verses")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                VStack(spacing: 8) {
                    ForEach(appState.memoryVerses) { mv in
                        let isAdded = manualVerses.contains { $0.reference == mv.reference }
                        Button {
                            HapticManager.shared.selectionChanged()
                            if isAdded {
                                manualVerses.removeAll { $0.reference == mv.reference }
                            } else {
                                addManualVerse(reference: mv.reference, text: mv.text)
                            }
                        } label: {
                            HStack {
                                Text(mv.reference)
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Spacer()
                                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundStyle(Color.adaptivePrimaryIcon(colorScheme))
                            }
                            .padding(12)
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isAdded ? .isSelected : [])
                    }
                }
            }

            if !manualVerses.isEmpty {
                Text("In this collection (\(manualVerses.count))")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                VStack(spacing: 8) {
                    ForEach(manualVerses) { cv in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cv.reference)
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                Text(cv.text)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                            }
                            Spacer(minLength: 0)
                            Button {
                                HapticManager.shared.lightImpact()
                                manualVerses.removeAll { $0.id == cv.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(Color.reforgedCoral)
                            }
                            .accessibilityLabel("Remove \(cv.reference)")
                        }
                        .padding(12)
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                    }
                }
            }
        }
    }

    private func addManualVerse() {
        HapticManager.shared.lightImpact()
        addManualVerse(reference: manualReference, text: manualText)
        manualReference = ""
        manualText = ""
    }

    private func addManualVerse(reference: String, text: String) {
        let ref = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let txt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ref.isEmpty, !txt.isEmpty else { return }
        guard !manualVerses.contains(where: { $0.reference == ref }) else { return }
        manualVerses.append(CollectionVerse(reference: ref, text: txt))
    }

    // MARK: - Save

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch mode {
        case .chapter: return !selectedReferences.isEmpty
        case .manual:  return !manualVerses.isEmpty
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let collectionId = UUID().uuidString
        let verses: [CollectionVerse]

        switch mode {
        case .chapter:
            verses = fetchedVerses
                .filter { selectedReferences.contains($0.reference) }
                .map { CollectionVerse(id: "\(collectionId):\($0.reference)",
                                       reference: $0.reference, text: $0.text) }
        case .manual:
            verses = manualVerses.map {
                CollectionVerse(id: "\(collectionId):\($0.reference)",
                                reference: $0.reference, text: $0.text)
            }
        }

        guard !verses.isEmpty else { return }

        let collection = VerseCollection(
            id: collectionId,
            name: trimmedName,
            verses: verses,
            translation: translation.compactCode
        )
        appState.addCollection(collection)
        dismiss()
    }
}
