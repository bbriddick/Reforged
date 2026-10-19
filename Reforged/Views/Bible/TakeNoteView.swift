import SwiftUI

// MARK: - Selection Action Bar

enum SelectionAction {
    case highlight(HighlightColor)
    case removeHighlight
    case addNote
    case addToMemory
    case bookmark
    case removeBookmark
    case copy
    case share
    case verseStudy
}

/// Where the action row's content sits inside its scroll view, to know which edges to fade.
private struct ActionBarScrollKey: PreferenceKey {
    static var defaultValue: ClosedRange<CGFloat> = 0...0
    static func reduce(value: inout ClosedRange<CGFloat>, nextValue: () -> ClosedRange<CGFloat>) {
        value = nextValue()
    }
}

/// Floating bar over the reader when verses are selected. The material is functional here (it sits
/// over scrolling Scripture), and every control keeps a 44 pt hit area.
struct SelectionActionBar: View {
    @ObservedObject var readingState: BibleReadingState
    let onDismiss: () -> Void
    let onAction: (SelectionAction) -> Void
    @State private var showColorPicker = false
    @State private var contentRange: ClosedRange<CGFloat> = 0...0
    @State private var viewportWidth: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme

    /// Content is scrolled off the leading / trailing edge, so that edge fades to hint at more.
    private var fadesLeading: Bool { contentRange.lowerBound < -1 }
    private var fadesTrailing: Bool { viewportWidth > 0 && contentRange.upperBound > viewportWidth + 1 }

    private var edgeFade: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: fadesLeading ? .clear : .black, location: 0),
                .init(color: .black, location: fadesLeading ? 0.1 : 0),
                .init(color: .black, location: fadesTrailing ? 0.9 : 1),
                .init(color: fadesTrailing ? .clear : .black, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var verseCountLabel: String {
        let n = readingState.selectedVerses.count
        return n == 1 ? "1 verse selected" : "\(n) verses selected"
    }

    /// True when every selected verse is already bookmarked, which drives the toggle's filled state.
    private var allBookmarked: Bool {
        !readingState.selectedVerses.isEmpty
            && readingState.selectedVerses.allSatisfy { readingState.isBookmarked($0) }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Verse count + dismiss
            HStack(spacing: 4) {
                Text(verseCountLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .padding(.leading, 12)

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Clear selection")
            }
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            VStack(spacing: 0) {
                // Color picker (expands above the pill)
                if showColorPicker {
                    HStack(spacing: 4) {
                        ForEach(HighlightColor.allCases) { color in
                            Button {
                                onAction(.highlight(color))
                                withAnimation { showColorPicker = false }
                            } label: {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Highlight \(color.rawValue)")
                        }

                        // Clear highlight
                        Button {
                            onAction(.removeHighlight)
                            withAnimation { showColorPicker = false }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Remove highlight")
                    }
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .padding(.bottom, 8)
                    .transition(.scale.combined(with: .opacity))
                }

                // Action buttons, horizontally scrollable so the row never overflows on
                // narrow phones (it holds up to 7 actions when a single verse is selected).
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ActionBarButton(icon: "highlighter", label: "Highlight", isActive: showColorPicker) {
                            withAnimation(.spring(response: 0.3)) {
                                showColorPicker.toggle()
                            }
                        }

                        ActionBarButton(icon: "note.text", label: "Note") {
                            onAction(.addNote)
                        }

                        ActionBarButton(icon: allBookmarked ? "bookmark.fill" : "bookmark",
                                        label: "Bookmark",
                                        isActive: allBookmarked) {
                            onAction(allBookmarked ? .removeBookmark : .bookmark)
                        }

                        ActionBarButton(icon: "brain.head.profile", label: "Memory") {
                            onAction(.addToMemory)
                        }

                        if readingState.selectedVerses.count == 1 {
                            ActionBarButton(icon: "text.magnifyingglass", label: "Study") {
                                onAction(.verseStudy)
                            }
                        }

                        ActionBarButton(icon: "doc.on.doc", label: "Copy") {
                            onAction(.copy)
                        }

                        ActionBarButton(icon: "square.and.arrow.up", label: "Share") {
                            onAction(.share)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        GeometryReader { geo in
                            let frame = geo.frame(in: .named("selectionActionBar"))
                            Color.clear.preference(key: ActionBarScrollKey.self,
                                                   value: frame.minX...max(frame.minX, frame.maxX))
                        }
                    )
                }
                .coordinateSpace(name: "selectionActionBar")
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { viewportWidth = geo.size.width }
                            .onChange(of: geo.size.width) { viewportWidth = $0 }
                    }
                )
                .onPreferenceChange(ActionBarScrollKey.self) { contentRange = $0 }
                // Fade only the content, and only on edges where more is waiting.
                .mask(edgeFade)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: Color.black.opacity(0.12), radius: 16, y: -4)
            }
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
                // Symbols differ in height (note.text is short, bookmark and brain are tall);
                // a fixed slot keeps every label on one line.
                Image(systemName: icon)
                    .font(.title3)
                    .frame(height: 26)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(iconColor)
            .frame(minWidth: 60, minHeight: 52, alignment: .center)
            .background(
                isActive ? Color.reforgedGold.opacity(0.15) : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Take Note View

/// Write a note on the selected verse or range. Order follows the task: the verse you are
/// writing about, the note itself, help getting started, verses to link, then the verse's
/// highlight and the note's actions.
struct TakeNoteView: View {
    let verses: [ParsedVerse]
    @ObservedObject var readingState: BibleReadingState
    let onDismiss: () -> Void
    var prefilledPrompt: String? = nil

    @State private var noteAttributedText = NSAttributedString()
    @State private var crossReferences: [String] = []
    @State private var showCrossRefPicker = false
    @State private var crossRefBook = BibleData.defaultBook
    @State private var crossRefChapter: Int = 1
    @State private var crossRefVerseStart: Int = 0
    @State private var crossRefVerseEnd: Int = 0
    @State private var showNoteShareSheet = false
    @State private var confirmDelete = false
    @State private var confirmDiscard = false
    /// What the editor held when the sheet opened, to tell a real edit from a plain look.
    @State private var initialText = ""
    @State private var initialReferences: [String] = []
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var settings = SettingsManager.shared
    @State private var studyPrompts: [String] = []
    @State private var isLoadingPrompts = false
    /// True when `studyPrompts` are the general offline set rather than personalised ones.
    @State private var usingFallbackPrompts = false

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

    private var hasUnsavedChanges: Bool {
        noteText != initialText || crossReferences != initialReferences
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    versePreview

                    noteSection

                    if settings.aiEnabled {
                        promptsSection
                    }

                    linkedVersesSection

                    highlightSection

                    actionsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Take Note")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasUnsavedChanges)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            confirmDiscard = true
                        } else {
                            onDismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { saveAndDismiss() }
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Discard your changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { onDismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .confirmationDialog("Delete this note?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete note", role: .destructive) {
                    HapticManager.shared.lightImpact()
                    readingState.removeNote(reference: noteReference)
                    noteAttributedText = NSAttributedString()
                    crossReferences = []
                    initialText = ""
                    initialReferences = []
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The note on \(noteReference) will be removed. The verse and its highlight stay.")
            }
            .onAppear {
                let existing = existingNote?.content ?? ""
                if existing.isEmpty, let prefilledPrompt {
                    noteAttributedText = NSAttributedString.from(prefilledPrompt)
                } else {
                    noteAttributedText = existing.isEmpty ? NSAttributedString() : NSAttributedString.from(existing)
                }
                crossReferences = existingNote?.crossReferences ?? []
                // Remember what was there on arrival, so only the user's edits count as changes.
                initialText = existing
                initialReferences = crossReferences
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

    /// Saves a non-empty note (new or updated) and closes.
    private func saveAndDismiss() {
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

    // MARK: - Shared building blocks

    private func sectionHeader(_ title: String, action: (title: String, icon: String, run: () -> Void)? = nil) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            Spacer()

            if let action {
                Button(action: action.run) {
                    Label(action.title, systemImage: action.icon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        .padding(.horizontal, 4)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 4)
        .frame(minHeight: 28)
    }

    private func surface<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 16)
    }

    // MARK: - Verse

    /// Scripture is serif and carries its reference. A range shows each verse number so the note
    /// can say which verse it means.
    private var versePreview: some View {
        surface {
            VStack(alignment: .leading, spacing: 10) {
                Text(noteReference)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.reforgedGold)

                Text(verseText)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }

    private var verseText: AttributedString {
        var out = AttributedString()
        for (index, verse) in verses.enumerated() {
            if verses.count > 1 {
                var number = AttributedString("\(verse.number) ")
                number.font = .caption.weight(.semibold)
                number.foregroundColor = Color.reforgedGold
                number.baselineOffset = 4
                out.append(number)
            }
            var text = AttributedString(verse.text + (index < verses.count - 1 ? " " : ""))
            text.font = settings.scriptureFont
            text.foregroundColor = Color.adaptiveText(colorScheme)
            out.append(text)
        }
        return out
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Your note")

            RichTextEditor(
                attributedText: $noteAttributedText,
                placeholder: "Write what this verse says to you",
                minHeight: 160
            )
        }
    }

    // MARK: - Prompts (AI)

    private var promptsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Prompts to get you started")

            surface {
                if isLoadingPrompts {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
                } else if studyPrompts.isEmpty {
                    Text("No prompts available.")
                        .font(.footnote)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(16)
                } else {
                    ForEach(Array(studyPrompts.enumerated()), id: \.offset) { index, prompt in
                        if index > 0 { rowDivider }
                        Button {
                            appendToNote(prompt)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Text(prompt)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Image(systemName: "plus.circle")
                                    .font(.body)
                                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(minHeight: 52, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Adds this prompt to your note")
                    }

                    if usingFallbackPrompts {
                        rowDivider
                        Button {
                            Task { await loadStudyPrompts() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                Text("General prompts. Tap to load ones for this verse.")
                            }
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .task {
                guard studyPrompts.isEmpty else { return }
                await loadStudyPrompts()
            }
        }
    }

    private func appendToNote(_ prompt: String) {
        let current = noteAttributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = current.isEmpty ? "" : "\n\n"
        let mutable = NSMutableAttributedString(attributedString: noteAttributedText)
        mutable.append(NSAttributedString.from(prefix + prompt))
        noteAttributedText = mutable
    }

    // MARK: - Linked verses

    private var linkedVersesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                "Linked verses",
                action: (title: "Add", icon: "plus", run: { showCrossRefPicker = true })
            )

            surface {
                if crossReferences.isEmpty {
                    Text("Link related verses to this note.")
                        .font(.footnote)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(16)
                } else {
                    ForEach(Array(crossReferences.enumerated()), id: \.element) { index, ref in
                        if index > 0 { rowDivider }
                        HStack(spacing: 8) {
                            Text(ref)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.reforgedGold)
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    crossReferences.removeAll { $0 == ref }
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(ref)")
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 4)
                        .frame(minHeight: 48)
                    }
                }
            }
        }
    }

    // MARK: - Highlight

    private var highlightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                "Highlight",
                action: existingHighlight == nil ? nil : (title: "Remove", icon: "xmark.circle", run: {
                    HapticManager.shared.lightImpact()
                    for v in verses {
                        readingState.removeHighlight(reference: v.reference)
                    }
                })
            )

            surface {
                HStack(spacing: 0) {
                    ForEach(HighlightColor.allCases) { color in
                        let selected = existingHighlight?.color == color.rawValue
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
                            ZStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 32, height: 32)
                                Circle()
                                    .stroke(selected ? Color.adaptiveNavyText(colorScheme) : Color.clear, lineWidth: 2.5)
                                    .frame(width: 40, height: 40)
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(color.rawValue.capitalized)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        surface {
            Button {
                HapticManager.shared.lightImpact()
                showNoteShareSheet = true
            } label: {
                actionRow(icon: "square.and.arrow.up", title: "Share verse and note", destructive: false)
            }
            .buttonStyle(.plain)

            // Delete is only offered when a saved note exists.
            if existingNote != nil {
                rowDivider
                Button {
                    confirmDelete = true
                } label: {
                    actionRow(icon: "trash", title: "Delete note", destructive: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionRow(icon: String, title: String, destructive: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .frame(width: 24)
            Text(title)
                .font(.subheadline.weight(.medium))
            Spacer()
        }
        .foregroundStyle(destructive ? Color.reforgedCoral : Color.adaptiveText(colorScheme))
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    // MARK: - Loading

    private func loadStudyPrompts() async {
        isLoadingPrompts = true
        let verseText = verses.map { $0.text }.joined(separator: " ")
        do {
            studyPrompts = try await GeminiService.shared.generateJournalPrompts(
                reference: noteReference,
                verseText: verseText
            )
            usingFallbackPrompts = false
        } catch {
            // Offline or the service is down: general prompts still give the note a start.
            debugLog("[TakeNote] prompts failed: \(error)")
            studyPrompts = GeminiService.fallbackJournalPrompts
            usingFallbackPrompts = true
        }
        isLoadingPrompts = false
    }
}
