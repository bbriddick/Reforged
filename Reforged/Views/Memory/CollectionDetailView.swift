import SwiftUI

// Lets a MemoryMode be used directly as a `.sheet(item:)` payload.
extension MemoryMode: Identifiable {
    var id: String { rawValue }
}

// MARK: - Collection Card (used in the Memory tab grid)

struct CollectionCard: View {
    let collection: VerseCollection
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "rectangle.stack.fill")
                    .foregroundStyle(Color.adaptivePrimaryIcon(colorScheme))
                Spacer()
                if let code = collection.translation {
                    Text(code.uppercased())
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.adaptiveChipBackground(colorScheme))
                        .clipShape(Capsule())
                }
            }
            Text(collection.name)
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text("\(collection.verses.count) verse\(collection.verses.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ReforgedTheme.spacingM)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }
}

// MARK: - Collection Detail

struct CollectionDetailView: View {
    let collectionId: String
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var shuffle = false
    @State private var sessionMode: MemoryMode?
    @State private var showMatching = false
    @State private var showComplete = false
    @State private var showDeleteConfirm = false

    private var collection: VerseCollection? {
        appState.verseCollections.first { $0.id == collectionId }
    }

    /// Verses mapped into transient MemoryVerses for the pool games.
    private func memoryVerses(_ collection: VerseCollection) -> [MemoryVerse] {
        collection.verses.map { $0.asMemoryVerse(translation: collection.translation) }
    }

    private func sessionVerses(_ collection: VerseCollection) -> [CollectionVerse] {
        shuffle ? collection.verses.shuffled() : collection.verses
    }

    var body: some View {
        Group {
            if let collection {
                content(collection)
            } else {
                // Collection was deleted while open.
                Color.adaptiveBackground(colorScheme).ignoresSafeArea()
                    .onAppear { dismiss() }
            }
        }
    }

    private func content(_ collection: VerseCollection) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReforgedTheme.spacingL) {
                // Order toggle
                Picker("Order", selection: $shuffle) {
                    Text("In Order").tag(false)
                    Text("Shuffle").tag(true)
                }
                .pickerStyle(.segmented)

                // Practice — single-verse modes
                VStack(alignment: .leading, spacing: 12) {
                    Text("Practice")
                        .font(.headline).fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(MemoryMode.allCases, id: \.self) { mode in
                            Button {
                                HapticManager.shared.buttonTap()
                                sessionMode = mode
                            } label: {
                                modeTile(mode)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Games scoped to this collection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Games")
                        .font(.headline).fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    HStack(spacing: 12) {
                        PracticeGameCard(
                            title: "Matching Game",
                            subtitle: "Match references to verses",
                            icon: "square.grid.2x2.fill",
                            xpRange: "150–200 XP",
                            color: Color.adaptivePrimaryIcon(colorScheme)
                        ) { showMatching = true }
                            .opacity(collection.verses.count >= 4 ? 1 : 0.4)
                            .disabled(collection.verses.count < 4)

                        PracticeGameCard(
                            title: "Complete the Verse",
                            subtitle: "Fill in the missing words",
                            icon: "pencil.and.outline",
                            xpRange: "75–315 XP",
                            color: Color.reforgedGold
                        ) { showComplete = true }
                    }
                    if collection.verses.count < 4 {
                        Text("Matching needs at least 4 verses.")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }

                // Verses
                VStack(alignment: .leading, spacing: 12) {
                    Text("Verses (\(collection.verses.count))")
                        .font(.headline).fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    ForEach(collection.verses) { verse in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(verse.reference)
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            Text(verse.text)
                                .font(.subheadline)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                    }
                }
            }
            .padding(ReforgedTheme.spacingL)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete Collection", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Collection", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                appState.removeCollection(collection.id)
                dismiss()
            }
        } message: {
            Text("Delete \"\(collection.name)\"? This cannot be undone.")
        }
        .fullScreenCover(item: $sessionMode) { mode in
            CollectionPracticeSessionView(
                verses: sessionVerses(collection),
                mode: mode,
                collectionName: collection.name,
                translation: collection.translation
            )
            .environmentObject(appState)
        }
        .sheet(isPresented: $showMatching) {
            MatchingGameView(collectionVerses: memoryVerses(collection))
                .environmentObject(appState)
        }
        .sheet(isPresented: $showComplete) {
            CompleteTheVerseView(collectionVerses: memoryVerses(collection))
                .environmentObject(appState)
        }
    }

    private func modeTile(_ mode: MemoryMode) -> some View {
        HStack(spacing: 10) {
            Image(systemName: mode.icon)
                .font(.title3)
                .foregroundStyle(Color.adaptivePrimaryIcon(colorScheme))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.displayName)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(mode.description)
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }
}

// MARK: - Collection Practice Session
//
// Iterates one practice mode across every verse in the collection, advancing on each
// completion instead of dismissing. Unlike MemoryPracticeView, it does NOT write to the
// spaced-repetition schedule (the verses aren't in AppState.memoryVerses).

struct CollectionPracticeSessionView: View {
    let verses: [CollectionVerse]
    let mode: MemoryMode
    let collectionName: String
    let translation: String?

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var currentIndex = 0
    @State private var isComplete = false
    @State private var totalXP = 0
    @State private var showConfetti = false

    private var currentVerse: MemoryVerse {
        verses[min(currentIndex, verses.count - 1)].asMemoryVerse(translation: translation)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.adaptiveBackground(colorScheme).ignoresSafeArea()

                if verses.isEmpty {
                    Text("No verses to practice.")
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                } else if isComplete {
                    completionView
                } else {
                    modeView
                        .id(currentIndex) // force a fresh subview per verse
                }
            }
            .navigationTitle(mode.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isComplete {
                        Text("\(min(currentIndex + 1, verses.count)) / \(verses.count)")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var modeView: some View {
        switch mode {
        case .flashcard:
            FlashcardPracticeView(verse: currentVerse, onComplete: handleComplete)
        case .tapToReveal:
            TapToRevealView(verse: currentVerse, onComplete: handleComplete)
        case .dragAndDrop:
            DragAndDropView(verse: currentVerse, onComplete: handleComplete)
        case .fillInBlank:
            FillInBlankView(verse: currentVerse, onComplete: handleComplete)
        case .firstLetter:
            FirstLetterView(verse: currentVerse, onComplete: handleComplete)
        case .typing:
            TypingPracticeView(verse: currentVerse, onComplete: handleComplete)
        }
    }

    private var completionView: some View {
        VStack(spacing: ReforgedTheme.spacingL) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.reforgedGold)
            Text("Collection Complete!")
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text("\(verses.count) verse\(verses.count == 1 ? "" : "s") from \(collectionName)")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            Text("+\(totalXP) XP")
                .font(.title3).fontWeight(.bold)
                .foregroundStyle(Color.reforgedGold)

            HStack(spacing: 12) {
                Button {
                    HapticManager.shared.buttonTap()
                    showConfetti = false
                    currentIndex = 0
                    totalXP = 0
                    isComplete = false
                } label: {
                    Text("Practice Again").fontWeight(.semibold)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(Color.adaptiveChipBackground(colorScheme))
                        .clipShape(Capsule())
                }
                Button { dismiss() } label: {
                    Text("Done").fontWeight(.semibold).foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(Color.reforgedNavy)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(ReforgedTheme.spacingXL)
        .confetti(isActive: $showConfetti, intensity: .high)
        .onAppear {
            HapticManager.shared.achievementUnlocked()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showConfetti = true
            }
        }
    }

    private func handleComplete(quality: Int) {
        let xp = quality >= 3 ? 20 : 5
        totalXP += xp
        appState.addXP(xp, source: "collection_practice")

        if currentIndex + 1 < verses.count {
            currentIndex += 1
        } else {
            withAnimation { isComplete = true }
        }
    }
}
