import SwiftUI

// MARK: - Selection Action Bar

enum SelectionAction {
    case highlight(HighlightColor)
    case removeHighlight
    case addNote
    case addToMemory
    case copy
    case share
}

struct SelectionActionBar: View {
    @ObservedObject var readingState: BibleReadingState
    let onAction: (SelectionAction) -> Void
    @State private var showColorPicker = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Color picker
            if showColorPicker {
                HStack(spacing: 12) {
                    ForEach(HighlightColor.allCases) { color in
                        Button {
                            onAction(.highlight(color))
                            withAnimation { showColorPicker = false }
                        } label: {
                            Circle()
                                .fill(color.color)
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(color: color.color.opacity(0.4), radius: 4, y: 2)
                        }
                    }

                    // Clear highlight
                    Button {
                        onAction(.removeHighlight)
                        withAnimation { showColorPicker = false }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.adaptiveCardBackground(colorScheme))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.bottom, 8)
                .transition(.scale.combined(with: .opacity))
            }

            // Action buttons
            HStack(spacing: 16) {
                ActionBarButton(icon: "highlighter", label: "Highlight") {
                    withAnimation(.spring(response: 0.3)) {
                        showColorPicker.toggle()
                    }
                }

                ActionBarButton(icon: "note.text", label: "Note") {
                    onAction(.addNote)
                }

                ActionBarButton(icon: "brain.head.profile", label: "Memory") {
                    onAction(.addToMemory)
                }

                ActionBarButton(icon: "doc.on.doc", label: "Copy") {
                    onAction(.copy)
                }

                ActionBarButton(icon: "square.and.arrow.up", label: "Share") {
                    onAction(.share)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.15), radius: 20, y: -5)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct ActionBarButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var iconColor: Color {
        if isActive {
            return Color.reforgedGold
        }
        return Color.adaptivePrimaryIcon(colorScheme)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(iconColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                isActive ? Color.reforgedGold.opacity(0.15) : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Take Note View (Improved Verse Action Sheet)

struct TakeNoteView: View {
    let verses: [ParsedVerse]
    @ObservedObject var readingState: BibleReadingState
    let onDismiss: () -> Void

    @State private var noteAttributedText = NSAttributedString()
    @State private var crossReferences: [String] = []
    @State private var showCrossRefPicker = false
    @State private var crossRefBook = BibleData.defaultBook
    @State private var crossRefChapter: Int = 1
    @State private var crossRefVerseStart: Int = 0
    @State private var crossRefVerseEnd: Int = 0
    @State private var showNoteShareSheet = false
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var settings = SettingsManager.shared
    @State private var studyPrompts: [String] = []
    @State private var isLoadingPrompts = false

    private var noteText: String { noteAttributedText.string }

    // Convenience: first verse for single-verse operations
    private var primaryVerse: ParsedVerse? { verses.first }

    // Reference covering the full range: "John 3:16" or "John 3:16-18"
    private var noteReference: String {
        guard let first = verses.first else { return "" }
        guard let last = verses.last, verses.count > 1 else { return first.reference }
        // Build "Book Chapter:start-end"
        return "\(readingState.currentBook) \(readingState.currentChapter):\(first.number)-\(last.number)"
    }

    var existingNote: VerseNote? {
        readingState.getNote(for: noteReference)
    }

    var existingHighlight: VerseHighlight? {
        guard let primaryVerse else { return nil }
        return readingState.getHighlight(for: primaryVerse.reference)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Verse preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text(noteReference)
                            .font(.headline)
                            .foregroundStyle(Color.reforgedGold)

                        ForEach(verses) { v in
                            Text(v.text)
                                .font(.subheadline)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.adaptiveBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))

                    // Highlight section (applies to primary verse)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Highlight")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                        HStack(spacing: 12) {
                            ForEach(HighlightColor.allCases) { color in
                                Button {
                                    HapticManager.shared.verseHighlighted()
                                    for v in verses {
                                        readingState.highlight(
                                            reference: v.reference,
                                            book: readingState.currentBook,
                                            chapter: readingState.currentChapter,
                                            verse: v.number,
                                            color: color
                                        )
                                    }
                                } label: {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    existingHighlight?.color == color.rawValue ? Color.reforgedNavy : Color.clear,
                                                    lineWidth: 3
                                                )
                                        )
                                }
                            }

                            Spacer()

                            if existingHighlight != nil {
                                Button {
                                    HapticManager.shared.lightImpact()
                                    for v in verses {
                                        readingState.removeHighlight(reference: v.reference)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                }
                            }
                        }
                    }

                    // Note section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Note")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                        RichTextEditor(
                            attributedText: $noteAttributedText,
                            placeholder: "Add your note…",
                            minHeight: 120
                        )

                        // Cross-references section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Cross-References", systemImage: "arrow.triangle.branch")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                Spacer()
                                Button {
                                    showCrossRefPicker = true
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "plus")
                                        Text("Add")
                                    }
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.reforgedNavy)
                                }
                            }

                            if crossReferences.isEmpty {
                                Text("Link related verses to this note")
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.7))
                                    .padding(.vertical, 2)
                            } else {
                                ForEach(crossReferences, id: \.self) { ref in
                                    HStack(spacing: 8) {
                                        Image(systemName: "book.closed")
                                            .font(.caption)
                                            .foregroundStyle(Color.reforgedNavy)
                                        Text(ref)
                                            .font(.subheadline)
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                        Spacer()
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                crossReferences.removeAll { $0 == ref }
                                            }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.caption2)
                                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.adaptiveCardBackground(colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                                    )
                                }
                            }
                        }

                        // Study prompts (AI)
                        if settings.aiEnabled {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.caption.bold())
                                        .foregroundStyle(Color.reforgedGold)
                                    Text("Study Prompts")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                    Spacer()
                                    Text("Tap to add")
                                        .font(.caption2)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
                                }

                                if isLoadingPrompts {
                                    HStack(spacing: 8) {
                                        ForEach(0..<3, id: \.self) { _ in
                                            Text("                    ")
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.adaptiveBackground(colorScheme))
                                                .clipShape(Capsule())
                                                .redacted(reason: .placeholder)
                                        }
                                    }
                                } else if !studyPrompts.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(studyPrompts, id: \.self) { prompt in
                                            Button {
                                                let current = noteAttributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
                                                let prefix = current.isEmpty ? "" : "\n\n"
                                                let mutable = NSMutableAttributedString(attributedString: noteAttributedText)
                                                mutable.append(NSAttributedString.from(prefix + prompt))
                                                noteAttributedText = mutable
                                            } label: {
                                                Text(prompt)
                                                    .font(.caption)
                                                    .multilineTextAlignment(.leading)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(Color.reforgedGold.opacity(0.08))
                                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(Color.reforgedGold.opacity(0.25), lineWidth: 1)
                                                    )
                                            }
                                        }
                                    }
                                }
                            }
                            .task {
                                guard studyPrompts.isEmpty else { return }
                                isLoadingPrompts = true
                                let verseText = verses.map { $0.text }.joined(separator: " ")
                                studyPrompts = (try? await GeminiService.shared.generateJournalPrompts(
                                    reference: noteReference,
                                    verseText: verseText
                                )) ?? []
                                isLoadingPrompts = false
                            }
                        }

                        // Delete + Share action row
                        HStack(spacing: 12) {
                            // Delete — only visible when a saved note exists
                            if existingNote != nil {
                                Button {
                                    HapticManager.shared.lightImpact()
                                    readingState.removeNote(reference: noteReference)
                                    noteAttributedText = NSAttributedString()
                                    crossReferences = []
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.reforgedCoral)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(Color.reforgedCoral.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                                                .stroke(Color.reforgedCoral.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }

                            // Share — always visible; shares verse + current note text
                            Button {
                                HapticManager.shared.lightImpact()
                                showNoteShareSheet = true
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color.reforgedNavy)
                                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.adaptiveCardBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Take Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // Auto-save on dismiss if there's content
                        if !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HapticManager.shared.noteSaved()
                            if existingNote != nil {
                                readingState.updateNote(
                                    reference: noteReference,
                                    content: noteText,
                                    crossReferences: crossReferences
                                )
                            } else {
                                readingState.addNote(
                                    reference: noteReference,
                                    book: readingState.currentBook,
                                    chapter: readingState.currentChapter,
                                    verse: primaryVerse?.number ?? 1,
                                    content: noteText,
                                    crossReferences: crossReferences
                                )
                            }
                        }
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                let existing = existingNote?.content ?? ""
                noteAttributedText = existing.isEmpty ? NSAttributedString() : NSAttributedString.from(existing)
                crossReferences = existingNote?.crossReferences ?? []
            }
            .sheet(isPresented: $showCrossRefPicker) {
                VersePickerSheet(
                    selectedBook: $crossRefBook,
                    selectedChapter: $crossRefChapter,
                    selectedVerseStart: $crossRefVerseStart,
                    selectedVerseEnd: $crossRefVerseEnd,
                    translation: SettingsManager.shared.defaultTranslation
                ) { _, reference in
                    if !crossReferences.contains(reference) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            crossReferences.append(reference)
                        }
                    }
                }
            }
            .sheet(isPresented: $showNoteShareSheet) {
                let shareSelection = VerseShareSelection(
                    verses: verses,
                    book: readingState.currentBook,
                    chapter: readingState.currentChapter,
                    translation: SettingsManager.shared.defaultTranslation.rawValue
                )
                VerseShareSheet(
                    selection: shareSelection,
                    noteText: noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : noteText
                )
            }
        }
    }
}
