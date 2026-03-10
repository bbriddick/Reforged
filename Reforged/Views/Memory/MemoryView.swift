import SwiftUI

struct MemoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.isSidebarNavigation) var isSidebarNavigation
    @State private var showAddVerse = false
    @State private var verseToDelete: MemoryVerse?
    @State private var showDeleteConfirmation = false
    @State private var showHowItWorks = false

    var versesForReview: [MemoryVerse] {
        appState.getVersesForReview()
    }

    var totalVerses: Int {
        appState.memoryVerses.count
    }

    var averageMastery: Int {
        guard !appState.memoryVerses.isEmpty else { return 0 }
        let total = appState.memoryVerses.reduce(0) { $0 + Int(($1.accuracy ?? 0)) }
        return total / appState.memoryVerses.count
    }

    // Adaptive grid columns for stats
    var statsColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        } else {
            return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        }
    }

    // Adaptive grid columns for verse cards
    var verseColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        } else {
            return [GridItem(.flexible())]
        }
    }

    var body: some View {
        Group {
            if isSidebarNavigation {
                memoryContent
            } else {
                NavigationStack {
                    memoryContent
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .sheet(isPresented: $showAddVerse) {
            AddVerseSheet()
        }
        .sheet(isPresented: $showHowItWorks) {
            SpacedRepetitionInfoSheet()
        }
        .alert("Delete Verse", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                verseToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let verse = verseToDelete {
                    withAnimation {
                        appState.removeMemoryVerse(verse.id)
                    }
                    verseToDelete = nil
                }
            }
        } message: {
            if let verse = verseToDelete {
                Text("Are you sure you want to delete \(verse.reference)? This cannot be undone.")
            }
        }
    }

    var memoryContent: some View {
        ScrollView {
            VStack(spacing: ReforgedTheme.spacingL) {
                // Header section
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scripture Memory")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Text("Memorize God's Word through spaced repetition")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    Spacer()
                    Button(action: { showHowItWorks = true }) {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .accessibilityLabel("How it works")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Stats Row - Responsive grid
                LazyVGrid(columns: statsColumns, spacing: 12) {
                    MemoryStatCard(
                        value: "\(totalVerses)",
                        label: "Verses",
                        icon: "text.book.closed.fill",
                        color: .reforgedNavy
                    )

                    MemoryStatCard(
                        value: "\(averageMastery)%",
                        label: "Mastery",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .reforgedGold
                    )

                    MemoryStatCard(
                        value: "\(versesForReview.count)",
                        label: "Reviews",
                        icon: "arrow.triangle.2.circlepath",
                        color: .reforgedCoral
                    )

                    // Extra stat on iPad
                    if horizontalSizeClass == .regular {
                        MemoryStatCard(
                            value: "\(appState.user.streak)",
                            label: "Streak",
                            icon: "flame.fill",
                            color: Color(red: 1.0, green: 0.5, blue: 0.0)
                        )
                    }
                }

                // Review Card (prominent CTA)
                if !versesForReview.isEmpty {
                    ReviewCard(count: versesForReview.count)
                }

                // Verses List
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("My Verses")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Spacer()

                        Button(action: { showAddVerse = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.caption.bold())
                                Text("Add")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.reforgedNavy)
                            .clipShape(Capsule())
                        }
                    }

                    if appState.memoryVerses.isEmpty {
                        EmptyVersesView(onAdd: { showAddVerse = true })
                    } else {
                        // Responsive grid for verse cards
                        LazyVGrid(columns: verseColumns, spacing: 16) {
                            ForEach(appState.memoryVerses) { verse in
                                VerseCard(
                                    verse: verse,
                                    onDelete: {
                                        verseToDelete = verse
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                    }
                }

                // Suggested Verses Section
                SuggestedVersesSection()
            }
            .responsivePadding(.horizontal)
            .padding(.vertical)
            .frame(maxWidth: horizontalSizeClass == .regular ? 1200 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
    }
}

// MARK: - Memory Stat Card

struct MemoryStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text(label)
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .gamifiedStatCard(accent: color)
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let count: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationLink(destination: MemoryReviewView()) {
            HStack(spacing: 16) {
                // Animated brain icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.reforgedCoral, Color.reforgedCoral.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.reforgedCoral.opacity(0.4), radius: 8, y: 4)

                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Verses Due")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text("\(count) verse\(count == 1 ? "" : "s") ready for review")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Spacer()

                // Start button
                ZStack {
                    Circle()
                        .fill(Color.reforgedCoral)
                        .frame(width: 44, height: 44)

                    Image(systemName: "play.fill")
                        .font(.callout)
                        .foregroundStyle(.white)
                }
            }
            .padding(ReforgedTheme.spacingM)
            .gamifiedStatCard(accent: .reforgedCoral)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Verse Card

enum VerseCardSheet: Identifiable {
    case practiceOptions
    case reflectionEditor
    var id: Int { hashValue }
}

struct VerseCard: View {
    let verse: MemoryVerse
    let onDelete: () -> Void
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showActions = false
    @State private var activeSheet: VerseCardSheet? = nil

    var daysUntilReview: Int {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: verse.nextReviewDate).day ?? 0
        return max(0, days)
    }

    var statusText: String {
        if daysUntilReview == 0 {
            return "Due now"
        } else if daysUntilReview == 1 {
            return "Due tomorrow"
        } else {
            return "Due in \(daysUntilReview) days"
        }
    }

    var statusColor: Color {
        if daysUntilReview == 0 {
            return .reforgedCoral
        } else {
            return Color(red: 0.2, green: 0.7, blue: 0.4)
        }
    }

    var masteryPercent: Int {
        Int(verse.accuracy ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(verse.reference)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        // Translation badge
                        if let translation = verse.translation {
                            Text(translation)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.reforgedNavy)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    // Category tag
                    Text(verse.category)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(colorScheme == .dark ? Color(white: 0.26) : Color.reforgedNavy.opacity(0.1))
                        .clipShape(Capsule())
                }

                Spacer()

                // Actions menu
                Menu {
                    Button(action: { activeSheet = .practiceOptions }) {
                        Label("Practice", systemImage: "brain.head.profile")
                    }

                    Button(action: { activeSheet = .reflectionEditor }) {
                        Label(verse.reflectionNote == nil ? "Add Reflection" : "Edit Reflection",
                              systemImage: "heart.text.square")
                    }

                    Divider()

                    if verse.level < 5 {
                        Button(action: { appState.markVerseAsMastered(verse.id) }) {
                            Label("Mark as Mastered", systemImage: "checkmark.seal.fill")
                        }
                    }

                    Button(role: .destructive, action: onDelete) {
                        Label("Delete Verse", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(width: 32, height: 32)
                        .background(Color.adaptiveBorder(colorScheme).opacity(0.5))
                        .clipShape(Circle())
                }
            }

            // Verse text
            Text(verse.text)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .lineLimit(3)

            // Footer row
            HStack {
                // Mastery indicator
                HStack(spacing: 6) {
                    // Mini progress bar
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.adaptiveBorder(colorScheme))
                            .frame(width: 40, height: 6)

                        Capsule()
                            .fill(masteryPercent >= 80 ? Color.green : (masteryPercent >= 50 ? Color.orange : Color.reforgedCoral))
                            .frame(width: CGFloat(masteryPercent) * 0.4, height: 6)
                    }

                    // Level name instead of raw percentage
                    Text(verse.levelName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(verse.level == 5 ? Color.green : Color.adaptiveTextSecondary(colorScheme))

                    // Mastered star badge
                    if verse.level == 5 {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Color.green)
                    }
                }

                // Status badge
                Text(verse.level == 5 ? "Mastered" : statusText)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(verse.level == 5 ? Color.green : statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((verse.level == 5 ? Color.green : statusColor).opacity(0.12))
                    .clipShape(Capsule())

                Spacer()

                Button(action: { activeSheet = .practiceOptions }) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                        Text("Practice")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.reforgedNavy.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(ReforgedTheme.spacingM)
        .reforgedCard()
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .practiceOptions:
                PracticeOptionsSheet(verse: verse)
            case .reflectionEditor:
                ReflectionNoteSheet(verse: verse)
            }
        }
    }
}

// MARK: - Suggested Verses Section

struct SuggestedVersesSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var selectedCategory: String = SuggestedVersesData.categories[0]

    private var existingReferences: Set<String> {
        Set(appState.memoryVerses.map { $0.reference })
    }

    private var filteredVerses: [SuggestedVerse] {
        SuggestedVersesData.verses(for: selectedCategory)
            .filter { !existingReferences.contains($0.reference) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.reforgedGold)
                Text("Suggested Verses")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }

            // Category chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SuggestedVersesData.categories, id: \.self) { category in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = category
                            }
                        } label: {
                            Text(category)
                                .font(.subheadline)
                                .fontWeight(selectedCategory == category ? .semibold : .regular)
                                .foregroundStyle(selectedCategory == category ? .white : Color.adaptiveText(colorScheme))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCategory == category
                                        ? Color.reforgedNavy
                                        : Color.adaptiveCardBackground(colorScheme)
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            selectedCategory == category
                                                ? Color.clear
                                                : Color.adaptiveBorder(colorScheme),
                                            lineWidth: 1
                                        )
                                )
                        }
                    }
                }
            }

            // Verse cards
            if filteredVerses.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.reforgedGold)
                    Text("You've added all suggested \(selectedCategory.lowercased()) verses!")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredVerses) { verse in
                        SuggestedVerseCard(verse: verse, translation: settingsManager.defaultTranslation)
                    }
                }
            }
        }
    }
}

struct SuggestedVerseCard: View {
    let verse: SuggestedVerse
    let translation: BibleTranslation
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var isAdded = false
    @State private var isFetching = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(verse.reference)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedGold)
                    Text(translation.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.reforgedNavy.opacity(0.7))
                        .clipShape(Capsule())
                }

                Text(verse.text)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineLimit(2)
            }

            Spacer()

            Button {
                addVerse()
            } label: {
                if isFetching {
                    ProgressView()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isAdded ? Color.green : Color.reforgedNavy)
                }
            }
            .disabled(isAdded || isFetching)
        }
        .padding(12)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 0.5)
        )
    }

    func addVerse() {
        if translation == .esv {
            // ESV text is already stored in suggested verse data
            let memoryVerse = MemoryVerse(
                id: UUID().uuidString,
                reference: verse.reference,
                text: verse.text,
                esvText: verse.text,
                category: verse.category,
                translation: translation.rawValue,
                lastFetched: ISO8601DateFormatter().string(from: Date()),
                nextReviewDate: Date(),
                reviewCount: 0,
                easeFactor: 2.5,
                interval: 1,
                isLearning: true,
                accuracy: nil,
                modeStats: nil
            )
            withAnimation { appState.addMemoryVerse(memoryVerse); isAdded = true }
            HapticManager.shared.lightImpact()
        } else {
            // Fetch verse text in the user's preferred translation
            isFetching = true
            Task {
                do {
                    var fetchedText = ""
                    var fetchedRef = verse.reference
                    switch translation {
                    case .esv:
                        break // handled above
                    case .kjv:
                        let result = try await KJVService.shared.fetchVerseForMemory(reference: verse.reference)
                        fetchedText = result.text
                        fetchedRef = result.canonical.isEmpty ? verse.reference : result.canonical
                    case .csb, .nkjv, .nasb:
                        let result = try await ApiBibleService.shared.fetchVerseForMemory(reference: verse.reference, translation: translation)
                        fetchedText = result.text
                        fetchedRef = result.canonical.isEmpty ? verse.reference : result.canonical
                    }
                    let memoryVerse = MemoryVerse(
                        id: UUID().uuidString,
                        reference: fetchedRef,
                        text: fetchedText,
                        esvText: nil,
                        category: verse.category,
                        translation: translation.rawValue,
                        lastFetched: ISO8601DateFormatter().string(from: Date()),
                        nextReviewDate: Date(),
                        reviewCount: 0,
                        easeFactor: 2.5,
                        interval: 1,
                        isLearning: true,
                        accuracy: nil,
                        modeStats: nil
                    )
                    await MainActor.run {
                        withAnimation { appState.addMemoryVerse(memoryVerse); isAdded = true }
                        isFetching = false
                        HapticManager.shared.lightImpact()
                    }
                } catch {
                    await MainActor.run { isFetching = false }
                }
            }
        }
    }
}

// MARK: - Empty Verses View

struct EmptyVersesView: View {
    let onAdd: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.reforgedNavy.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
            }

            VStack(spacing: 8) {
                Text("No verses yet")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("Add your first verse to start your memorization journey")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
            }

            Button(action: onAdd) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.callout.bold())
                    Text("Add Your First Verse")
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

// MARK: - Add Verse Sheet

struct AddVerseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var reference = ""
    @State private var text = ""
    @State private var category = "General"
    @State private var selectedTranslation: BibleTranslation = .esv
    @State private var isFetching = false
    @State private var fetchError: String?
    @State private var canonicalReference = ""
    @State private var showVersePicker = false

    // Verse picker state
    @State private var selectedBook: BibleBook = BibleData.books.first { $0.name == "John" } ?? BibleData.books[0]
    @State private var selectedChapter: Int = 3
    @State private var selectedVerseStart: Int = 0
    @State private var selectedVerseEnd: Int = 0

    let categories = ["Salvation", "Trust", "Strength", "Hope", "Guidance", "Love", "Faith", "Peace", "General"]

    var body: some View {
        NavigationStack {
            Form {
                // Translation selection
                Section {
                    HStack {
                        Text("Translation")
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Spacer()
                        Menu {
                            ForEach(BibleTranslation.allCases) { translation in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedTranslation = translation
                                        // Clear text when changing translation so user re-fetches
                                        if !reference.isEmpty && !text.isEmpty {
                                            text = ""
                                            fetchError = "Translation changed. Tap download to fetch in \(translation.rawValue)."
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text("\(translation.rawValue) – \(translation.fullName)")
                                        if selectedTranslation == translation {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(selectedTranslation.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.reforgedNavy)
                            .clipShape(Capsule())
                        }
                    }
                } header: {
                    Text("Bible Version")
                }

                // Verse picker section
                Section {
                    Button {
                        showVersePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "text.book.closed.fill")
                                .foregroundStyle(Color.reforgedGold)
                            Text("Browse Bible")
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Spacer()
                            Text(selectedTranslation.rawValue)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.reforgedNavy)
                                .clipShape(Capsule())
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                    }
                } header: {
                    Text("Pick from Bible")
                } footer: {
                    Text("Tap to browse and select verses from the \(selectedTranslation.fullName)")
                }

                Section("Or Enter Reference") {
                    HStack {
                        TextField("e.g., John 3:16", text: $reference)
                            .textInputAutocapitalization(.words)
                            .onChange(of: reference) { _ in
                                fetchError = nil
                            }

                        if isFetching {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if !reference.isEmpty {
                            Button(action: fetchVerseText) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let error = fetchError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                    }
                }

                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                } header: {
                    HStack {
                        Text("Verse Text")
                        Spacer()
                        if !canonicalReference.isEmpty {
                            Text(canonicalReference)
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                    }
                } footer: {
                    Text("Use 'Browse Bible' above or enter a reference and tap the download button to auto-fill from \(selectedTranslation.rawValue).")
                        .font(.caption)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }
            }
            .navigationTitle("Add Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addVerse()
                        dismiss()
                    }
                    .disabled(reference.isEmpty || text.isEmpty)
                }
            }
            .sheet(isPresented: $showVersePicker) {
                VersePickerSheet(
                    selectedBook: $selectedBook,
                    selectedChapter: $selectedChapter,
                    selectedVerseStart: $selectedVerseStart,
                    selectedVerseEnd: $selectedVerseEnd,
                    translation: selectedTranslation,
                    onSelect: { fetchedText, fetchedReference in
                        text = fetchedText
                        reference = fetchedReference
                        canonicalReference = fetchedReference
                    }
                )
            }
            .onAppear {
                selectedTranslation = settingsManager.defaultTranslation
            }
        }
    }

    func fetchVerseText() {
        guard !reference.isEmpty else { return }

        isFetching = true
        fetchError = nil

        Task {
            do {
                var fetchedText: String = ""
                var fetchedCanonical: String = ""

                switch selectedTranslation {
                case .esv:
                    let result = try await ESVService.shared.fetchVerseForMemory(reference: reference)
                    fetchedText = result.text
                    fetchedCanonical = result.canonical
                case .kjv:
                    let result = try await KJVService.shared.fetchVerseForMemory(reference: reference)
                    fetchedText = result.text
                    fetchedCanonical = result.canonical
                case .csb, .nkjv, .nasb:
                    let result = try await ApiBibleService.shared.fetchVerseForMemory(reference: reference, translation: selectedTranslation)
                    fetchedText = result.text
                    fetchedCanonical = result.canonical
                }

                await MainActor.run {
                    text = fetchedText
                    canonicalReference = fetchedCanonical
                    if !fetchedCanonical.isEmpty {
                        reference = fetchedCanonical
                    }
                    isFetching = false
                }
            } catch {
                await MainActor.run {
                    fetchError = error.localizedDescription
                    isFetching = false
                }
            }
        }
    }

    func addVerse() {
        let verse = MemoryVerse(
            id: UUID().uuidString,
            reference: canonicalReference.isEmpty ? reference : canonicalReference,
            text: text,
            esvText: selectedTranslation == .esv ? text : nil,
            category: category,
            translation: selectedTranslation.rawValue,
            lastFetched: ISO8601DateFormatter().string(from: Date()),
            nextReviewDate: Date(),
            reviewCount: 0,
            easeFactor: 2.5,
            interval: 1,
            isLearning: true,
            accuracy: nil,
            modeStats: nil
        )
        appState.addMemoryVerse(verse)
    }
}

// MARK: - Practice Options Sheet

struct PracticeOptionsSheet: View {
    let verse: MemoryVerse
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showReflectionEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Verse reference header
                    VStack(spacing: 4) {
                        Text(verse.reference)
                            .font(.headline)
                            .foregroundStyle(Color.adaptiveNavyText(colorScheme))

                        Text("Choose a practice mode")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding(.top)

                    // Reflection note prompt
                    if verse.reflectionNote == nil {
                        Button {
                            showReflectionEditor = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(Color.reforgedGold)
                                    .font(.subheadline)
                                Text("Add a personal note to deepen your memory")
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(Color.reforgedGold)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.reforgedGold.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.reforgedGold.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    // Practice mode cards
                    ForEach(MemoryMode.allCases, id: \.self) { mode in
                        NavigationLink(destination: MemoryPracticeView(verse: verse, mode: mode)) {
                            PracticeModeCard(mode: mode)
                        }
                        .buttonStyle(.plain)
                    }

                    // Deep Drill card
                    NavigationLink(destination: DeepDrillView(verse: verse)) {
                        DeepDrillCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Practice Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showReflectionEditor) {
                ReflectionNoteSheet(verse: verse)
            }
        }
    }
}

struct PracticeModeCard: View {
    let mode: MemoryMode
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.reforgedNavy.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: mode.icon)
                    .font(.title3)
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.displayName)
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text(mode.description)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding()
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }
}

// MARK: - Deep Drill Card

struct DeepDrillCard: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.reforgedCoral, Color.reforgedGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Deep Drill")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text("+30 XP")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.reforgedGold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.reforgedGold.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text("Flashcard · Fill Blank · Typing")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.reforgedCoral.opacity(0.06), Color.reforgedGold.opacity(0.06)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [Color.reforgedCoral.opacity(0.35), Color.reforgedGold.opacity(0.35)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Verse Picker Sheet

struct VersePickerSheet: View {
    @Binding var selectedBook: BibleBook
    @Binding var selectedChapter: Int
    @Binding var selectedVerseStart: Int
    @Binding var selectedVerseEnd: Int
    let translation: BibleTranslation
    let onSelect: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var step: PickerStep = .book
    @State private var verses: [ParsedVerse] = []
    @State private var isLoading = false
    @State private var referenceSearch = ""

    enum PickerStep {
        case book, chapter, verse
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Reference search bar (always visible)
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    TextField("Go to reference (e.g. John 3:16)", text: $referenceSearch)
                        .font(.subheadline)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .submitLabel(.go)
                        .onSubmit { parseAndNavigateToReference() }
                    if !referenceSearch.isEmpty {
                        Button { referenceSearch = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.adaptiveBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 0.5)
                )
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Progress indicator
                HStack(spacing: 8) {
                    StepIndicator(step: 1, current: step, label: "Book")
                    StepIndicator(step: 2, current: step, label: "Chapter")
                    StepIndicator(step: 3, current: step, label: "Verse")
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                Divider()

                switch step {
                case .book:
                    BookPickerView(
                        selectedBook: $selectedBook,
                        onSelect: {
                            withAnimation { step = .chapter }
                        }
                    )
                case .chapter:
                    ChapterPickerView(
                        book: selectedBook,
                        selectedChapter: $selectedChapter,
                        onSelect: {
                            loadVerses()
                            withAnimation { step = .verse }
                        },
                        onBack: {
                            withAnimation { step = .book }
                        }
                    )
                case .verse:
                    VerseSelectView(
                        verses: verses,
                        selectedStart: $selectedVerseStart,
                        selectedEnd: $selectedVerseEnd,
                        isLoading: isLoading,
                        onConfirm: confirmSelection,
                        onBack: {
                            withAnimation { step = .chapter }
                        }
                    )
                }
            }
            .navigationTitle("Select Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    func parseAndNavigateToReference() {
        let input = referenceSearch.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return }

        // Find last colon separating chapter:verse
        guard let colonIdx = input.lastIndex(of: ":") else { return }
        let verseStr = String(input[input.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
        let bookChapterStr = String(input[..<colonIdx]).trimmingCharacters(in: .whitespaces)

        // Parse verse range (e.g., "16" or "16-20")
        let verseParts = verseStr.components(separatedBy: "-")
        guard let startVerse = Int(verseParts[0].trimmingCharacters(in: .whitespaces)) else { return }
        let endVerse = verseParts.count > 1 ? (Int(verseParts[1].trimmingCharacters(in: .whitespaces)) ?? startVerse) : startVerse

        // Parse book name and chapter (last word = chapter number)
        let parts = bookChapterStr.components(separatedBy: " ")
        guard parts.count >= 2, let chapter = Int(parts.last!) else { return }
        let bookName = parts.dropLast().joined(separator: " ")

        // Find matching book (partial match)
        guard let book = BibleData.books.first(where: {
            $0.name.localizedCaseInsensitiveContains(bookName) ||
            bookName.localizedCaseInsensitiveContains($0.name)
        }) else { return }

        guard chapter >= 1 && chapter <= book.chapters else { return }

        selectedBook = book
        selectedChapter = chapter
        selectedVerseStart = max(1, startVerse)
        selectedVerseEnd = max(startVerse, endVerse)
        referenceSearch = ""
        loadVerses()
        withAnimation { step = .verse }
    }

    func loadVerses() {
        isLoading = true
        Task {
            do {
                var fetchedVerses: [ParsedVerse] = []

                switch translation {
                case .esv:
                    let result = try await ESVService.shared.fetchChapterParsed(book: selectedBook.name, chapter: selectedChapter)
                    fetchedVerses = result.verses
                case .kjv:
                    let result = try await KJVService.shared.fetchChapterParsed(book: selectedBook.name, chapter: selectedChapter)
                    fetchedVerses = result.verses
                case .csb, .nkjv, .nasb:
                    let result = try await ApiBibleService.shared.fetchChapterParsed(book: selectedBook.name, chapter: selectedChapter, translation: translation)
                    fetchedVerses = result.verses
                }

                await MainActor.run {
                    verses = fetchedVerses
                    selectedVerseStart = 0
                    selectedVerseEnd = 0
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    func confirmSelection() {
        guard selectedVerseStart > 0 else { return }
        let selectedVerses = verses.filter { $0.number >= selectedVerseStart && $0.number <= selectedVerseEnd }
        let text = selectedVerses.map { $0.text }.joined(separator: " ")
        let reference: String
        if selectedVerseStart == selectedVerseEnd {
            reference = "\(selectedBook.name) \(selectedChapter):\(selectedVerseStart)"
        } else {
            reference = "\(selectedBook.name) \(selectedChapter):\(selectedVerseStart)-\(selectedVerseEnd)"
        }
        onSelect(text, reference)
        dismiss()
    }
}

struct StepIndicator: View {
    let step: Int
    let current: VersePickerSheet.PickerStep
    let label: String
    @Environment(\.colorScheme) var colorScheme

    var isActive: Bool {
        switch current {
        case .book: return step == 1
        case .chapter: return step <= 2
        case .verse: return step <= 3
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.reforgedNavy : Color.gray.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay(
                    Text("\(step)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                )

            Text(label)
                .font(.caption2)
                .foregroundStyle(isActive ? Color.adaptiveNavyText(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity)
    }
}

struct BookPickerView: View {
    @Binding var selectedBook: BibleBook
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""
    @State private var selectedTestament: BibleBook.Testament? = nil

    var filteredBooks: [BibleBook] {
        var books = BibleData.books
        if let testament = selectedTestament {
            books = books.filter { $0.testament == testament }
        }
        if !searchText.isEmpty {
            books = books.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return books
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                TextField("Search books...", text: $searchText)
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.adaptiveBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding()

            // Testament filter
            HStack(spacing: 10) {
                FilterChipMemory(title: "All", isSelected: selectedTestament == nil) {
                    selectedTestament = nil
                }
                FilterChipMemory(title: "Old Testament", isSelected: selectedTestament == .old) {
                    selectedTestament = .old
                }
                FilterChipMemory(title: "New Testament", isSelected: selectedTestament == .new) {
                    selectedTestament = .new
                }
            }
            .padding(.horizontal)

            // Book list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredBooks) { book in
                        Button {
                            selectedBook = book
                            onSelect()
                        } label: {
                            HStack {
                                Text(book.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Spacer()
                                Text("\(book.chapters) ch")
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(book.id == selectedBook.id ? Color.reforgedGold.opacity(0.1) : Color.clear)
                        }
                    }
                }
            }
        }
    }
}

struct FilterChipMemory: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : Color.adaptiveNavyText(colorScheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.reforgedNavy : (colorScheme == .dark ? Color(white: 0.25) : Color.reforgedNavy.opacity(0.1)))
                .clipShape(Capsule())
        }
    }
}

struct ChapterPickerView: View {
    let book: BibleBook
    @Binding var selectedChapter: Int
    let onSelect: () -> Void
    let onBack: () -> Void
    @Environment(\.colorScheme) var colorScheme

    let columns = [GridItem(.adaptive(minimum: 55), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Books")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.reforgedGold)
                }

                Spacer()

                Text(book.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Spacer()
                Spacer().frame(width: 60)
            }
            .padding()

            // Chapter grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(1...book.chapters, id: \.self) { chapter in
                        Button {
                            selectedChapter = chapter
                            onSelect()
                        } label: {
                            Text("\(chapter)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(chapter == selectedChapter ? .white : Color.adaptiveText(colorScheme))
                                .frame(width: 55, height: 55)
                                .background(chapter == selectedChapter ? Color.reforgedNavy : Color.adaptiveBackground(colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct VerseSelectView: View {
    let verses: [ParsedVerse]
    @Binding var selectedStart: Int
    @Binding var selectedEnd: Int
    let isLoading: Bool
    let onConfirm: () -> Void
    let onBack: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var nothingSelected: Bool { selectedStart == 0 }

    var selectionLabel: String {
        guard !verses.isEmpty else { return "" }
        if nothingSelected { return "Tap a verse to select it" }
        if selectedStart == selectedEnd { return "Verse \(selectedStart) selected · tap another to extend" }
        let count = selectedEnd - selectedStart + 1
        return "Verses \(selectedStart)–\(selectedEnd) selected (\(count) verses)"
    }

    var confirmTitle: String {
        if selectedStart == selectedEnd {
            return "Use Verse \(selectedStart)"
        } else {
            return "Use Verses \(selectedStart)–\(selectedEnd)"
        }
    }

    func handleTap(_ verse: ParsedVerse) {
        let n = verse.number
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            if nothingSelected {
                // First tap — select single verse
                selectedStart = n
                selectedEnd = n
            } else if selectedStart == selectedEnd {
                if n == selectedStart {
                    // Tap same verse → deselect
                    selectedStart = 0
                    selectedEnd = 0
                } else if n > selectedStart {
                    // Tap later verse → extend range
                    selectedEnd = n
                } else {
                    // Tap earlier verse → new single selection
                    selectedStart = n
                    selectedEnd = n
                }
            } else {
                // Range active — reset to new single verse
                selectedStart = n
                selectedEnd = n
            }
        }
        HapticManager.shared.lightImpact()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Chapters")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.reforgedGold)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("Select Verse(s)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    if !verses.isEmpty && !isLoading {
                        Text(nothingSelected ? "Tap a verse to begin" : "Tap another verse to extend the range")
                            .font(.caption2)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }

                Spacer()
                Spacer().frame(width: 70)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            if isLoading {
                Spacer()
                ProgressView("Loading verses...")
                Spacer()
            } else if verses.isEmpty {
                Spacer()
                Text("No verses found")
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(verses) { verse in
                            PickerVerseCard(
                                verse: verse,
                                isInRange: verse.number >= selectedStart && verse.number <= selectedEnd,
                                isStart: verse.number == selectedStart,
                                isEnd: verse.number == selectedEnd,
                                isSingleSelection: selectedStart == selectedEnd,
                                onTap: { handleTap(verse) }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }

                // Bottom confirm area
                VStack(spacing: 8) {
                    Divider()
                    VStack(spacing: 6) {
                        Text(selectionLabel)
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        Button(action: onConfirm) {
                            Text(nothingSelected ? "Select a verse above" : confirmTitle)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(nothingSelected ? Color.gray : Color.reforgedNavy)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(nothingSelected)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .background(Color.adaptiveCardBackground(colorScheme))
            }
        }
    }
}

struct PickerVerseCard: View {
    let verse: ParsedVerse
    let isInRange: Bool
    let isStart: Bool
    let isEnd: Bool
    let isSingleSelection: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var cardBackground: Color {
        if isStart && isSingleSelection {
            return Color.reforgedNavy
        } else if isInRange {
            return Color.reforgedNavy.opacity(colorScheme == .dark ? 0.18 : 0.06)
        } else {
            return Color.adaptiveCardBackground(colorScheme)
        }
    }

    var numberBackground: Color {
        if isStart && isSingleSelection { return Color.white.opacity(0.2) }
        if isStart { return Color.reforgedNavy }
        if isEnd { return Color.reforgedGold }
        return Color.adaptiveBackground(colorScheme)
    }

    var numberForeground: Color {
        if isStart || isEnd { return .white }
        if isInRange && isSingleSelection { return .white }
        return Color.adaptiveTextSecondary(colorScheme)
    }

    var textColor: Color {
        isStart && isSingleSelection ? .white : Color.adaptiveText(colorScheme)
    }

    var borderColor: Color {
        if isStart { return Color.reforgedNavy }
        if isEnd { return Color.reforgedGold }
        if isInRange { return Color.reforgedNavy.opacity(0.25) }
        return Color.adaptiveBorder(colorScheme)
    }

    var borderWidth: CGFloat {
        (isStart || isEnd) ? 1.5 : 0.5
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Verse number badge
                ZStack {
                    Circle()
                        .fill(numberBackground)
                        .frame(width: 30, height: 30)
                    Text("\(verse.number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(numberForeground)
                }

                // Verse text
                Text(verse.text)
                    .font(.subheadline)
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Start / End badge
                if isStart && !isSingleSelection {
                    Text("START")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.reforgedNavy)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.reforgedNavy.opacity(0.1))
                        .clipShape(Capsule())
                } else if isEnd && !isSingleSelection {
                    Text("END")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.reforgedGold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.reforgedGold.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Spaced Repetition Info Sheet

struct SpacedRepetitionInfoSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private struct InfoRow: View {
        let icon: String
        let iconColor: Color
        let title: String
        let description: String
        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    Text("The more you know a verse, the less often you'll be asked to review it. When a year passes without needing a reminder, that verse is Mastered.")
                        .font(.body)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    // Progress levels
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Progress Levels")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(icon: "1.circle.fill", iconColor: .reforgedCoral,
                                    title: "Learning",
                                    description: "Reviewed less than a week ago — you're just getting started.")
                            InfoRow(icon: "2.circle.fill", iconColor: .orange,
                                    title: "Familiar",
                                    description: "Due every week or so — building a habit with this verse.")
                            InfoRow(icon: "3.circle.fill", iconColor: Color(red: 0.2, green: 0.7, blue: 0.4),
                                    title: "Known",
                                    description: "Due every month — you know it well but still need reinforcement.")
                            InfoRow(icon: "4.circle.fill", iconColor: Color.blue,
                                    title: "Well-Known",
                                    description: "Due every 90+ days — nearly committed to long-term memory.")
                            InfoRow(icon: "checkmark.seal.fill", iconColor: Color.green,
                                    title: "Mastered",
                                    description: "Due once a year or less — it's yours for life.")
                        }
                    }

                    // Rating guide
                    VStack(alignment: .leading, spacing: 6) {
                        Text("After Each Practice")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(icon: "arrow.counterclockwise.circle.fill", iconColor: .reforgedCoral,
                                    title: "Again — I didn't know it",
                                    description: "Resets the verse back to day 1. You'll see it again tomorrow.")
                            InfoRow(icon: "minus.circle.fill", iconColor: .orange,
                                    title: "Hard — I struggled",
                                    description: "Keeps the review interval short so you practice again soon.")
                            InfoRow(icon: "checkmark.circle.fill", iconColor: Color(red: 0.2, green: 0.7, blue: 0.4),
                                    title: "Good — I knew it",
                                    description: "Extends the interval — you'll see it less frequently.")
                            InfoRow(icon: "star.circle.fill", iconColor: Color.blue,
                                    title: "Easy — I knew it cold",
                                    description: "Extends the interval even further. You're mastering this verse.")
                        }
                    }

                    Text("You can also manually mark any verse as Mastered using the ··· menu on its card.")
                        .font(.footnote)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(.top, 4)
                }
                .padding()
            }
            .background(Color.adaptiveCardBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("How It Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.reforgedGold)
                }
            }
        }
    }
}

#Preview {
    MemoryView()
        .environmentObject(AppState.shared)
}
