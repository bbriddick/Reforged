import SwiftUI

// MARK: - Memorize Together (cards inside the Friends tab)

struct TogetherCards: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = SharedVersesStore.shared
    @ObservedObject private var friends = FriendsStore.shared

    @State private var showPropose = false
    @State private var quizToTake: VerseQuiz?
    @State private var verseForQuiz: SharedVerse?
    @State private var verseToEnd: SharedVerse?

    private var requests: [SharedVerse] { store.verses.filter(\.needsMyResponse) }
    private var active: [SharedVerse] { store.verses.filter(\.isActive) }
    private var waiting: [SharedVerse] { store.verses.filter { $0.isPending && $0.createdByMe } }
    private var toTake: [VerseQuiz] { store.quizzes.filter(\.isToTake) }
    private var results: [VerseQuiz] { store.quizzes.filter { $0.role == "sender" && $0.status == "completed" && !store.isLogged($0) } }
    private var myResults: [VerseQuiz] { store.quizzes.filter { $0.role == "recipient" && $0.status == "completed" && !store.isLogged($0) } }

    var body: some View {
        VStack(spacing: FriendsLayout.sectionSpacing) {
            if !requests.isEmpty || !toTake.isEmpty { needsYouBlock }
            togetherBlock
            if !results.isEmpty { resultsBlock }
            if !myResults.isEmpty { myResultsBlock }
        }
        .onDisappear { store.archiveSeenResults() }
        .sheet(isPresented: $showPropose) { ProposeVerseSheet() }
        .sheet(item: $quizToTake) { quiz in TakeQuizView(quiz: quiz) }
        .sheet(item: $verseForQuiz) { verse in SendQuizSheet(verse: verse) }
        .alert("Stop memorizing together?", isPresented: Binding(get: { verseToEnd != nil }, set: { if !$0 { verseToEnd = nil } })) {
            Button("Stop sharing", role: .destructive) { if let v = verseToEnd { Task { await store.end(v) } } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(verseToEnd?.friendName ?? "Your friend") will no longer see your progress on \(verseToEnd?.reference ?? "this verse"). The verse stays in your Memory deck.")
        }
    }

    // MARK: Needs you

    private var needsYouBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            FriendsSectionHeader(title: "Needs you", subtitle: "\(requests.count + toTake.count) waiting")
            VStack(spacing: 0) {
                ForEach(Array(requests.enumerated()), id: \.element.id) { index, sv in
                    if index > 0 { Divider() }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(sv.friendName) wants to memorize \(sv.reference) with you")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text(sv.translation)
                            .font(.footnote)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        HStack(spacing: 10) {
                            Button("Accept") { Task { await store.accept(sv) } }
                                .buttonStyle(PillButtonStyle())
                            Button("Not now") { Task { await store.decline(sv) } }
                                .buttonStyle(PillButtonStyle(filled: false))
                        }
                    }
                    .padding(.vertical, 10)
                }
                if !requests.isEmpty && !toTake.isEmpty { Divider() }
                ForEach(Array(toTake.enumerated()), id: \.element.id) { index, quiz in
                    if index > 0 { Divider() }
                    Button { quizToTake = quiz } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "questionmark.bubble.fill")
                                .font(.title3)
                                .foregroundStyle(Color.reforgedGold)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(quiz.friendName) quizzed you")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Text("\(quiz.reference) · \(quiz.quizDifficulty.label)")
                                    .font(.footnote)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .friendsCard()
        }
    }

    // MARK: Shared verses

    private var togetherBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            FriendsSectionHeader(title: "Memorize Together") {
                if !active.isEmpty || !waiting.isEmpty {
                    Button { showPropose = true } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.reforgedGold)
                            .frame(width: 44, height: 44)
                            .background(Color.reforgedGold.opacity(0.14), in: Circle())
                    }
                    .accessibilityLabel("Memorize a verse together")
                }
            }

            if active.isEmpty && waiting.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.reforgedGold)
                    Text("Learn a verse side by side")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Pick a verse with a friend. You'll see each other's progress, quiz each other, and build a streak together.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Button { showPropose = true } label: {
                        Label("Choose a verse", systemImage: "plus")
                    }
                    .buttonStyle(PillButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .friendsCard(padding: 24)
            } else {
                ForEach(active) { sv in verseCard(sv) }
                ForEach(waiting) { sv in
                    HStack(spacing: 12) {
                        Image(systemName: "hourglass").foregroundStyle(.secondary).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sv.reference).font(.body.weight(.semibold))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Text("Waiting for \(sv.friendName)")
                                .font(.footnote)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        Spacer()
                        Button("Cancel") { Task { await store.end(sv) } }
                            .buttonStyle(PillButtonStyle(filled: false))
                    }
                    .friendsCard()
                }
            }
        }
    }

    private func verseCard(_ sv: SharedVerse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sv.reference)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("with \(sv.friendName) · \(sv.translation)")
                        .font(.footnote)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer(minLength: 8)
                if sv.pairStreak > 0 {
                    Label("\(sv.pairStreak)", systemImage: "flame.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10).frame(minHeight: 32)
                        .background(Color.orange.opacity(0.14), in: Capsule())
                }
                Menu {
                    Button { verseForQuiz = sv } label: { Label("Quiz \(sv.friendName)", systemImage: "questionmark.bubble") }
                    Button { Task { await store.remind(sv) } } label: { Label("Remind \(sv.friendName)", systemImage: "bell") }
                    Button(role: .destructive) { verseToEnd = sv } label: { Label("Stop sharing", systemImage: "xmark.circle") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .padding(.trailing, -10).padding(.top, -10)
            }

            HStack(alignment: .top, spacing: 16) {
                progressColumn(name: "You", level: sv.myLevel, reviewedToday: sv.iReviewedToday)
                progressColumn(name: sv.friendName, level: sv.friendLevel, reviewedToday: sv.friendReviewedToday)
            }

            statusLine(sv)
        }
        .friendsCard()
    }

    private func progressColumn(name: String, level: Int?, reviewedToday: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(1)
                Image(systemName: reviewedToday ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                    .foregroundStyle(reviewedToday ? Color.green : Color.secondary.opacity(0.6))
            }
            Text(level.map { MemoryVerse.levelName(for: $0) } ?? "Just started")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme))
            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { i in
                    Capsule()
                        .fill(i <= (level ?? 0) ? Color.reforgedGold : Color.reforgedGold.opacity(0.15))
                        .frame(height: 5)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func statusLine(_ sv: SharedVerse) -> some View {
        if sv.masteredTogether {
            Label("You both mastered this verse", systemImage: "checkmark.seal.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.reforgedGold)
        } else if sv.iReviewedToday && sv.friendReviewedToday {
            Label("You both reviewed today", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.green)
        } else if !sv.iReviewedToday {
            Text("Review it in Memory to keep your streak going")
                .font(.footnote)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        } else {
            Text("Waiting on \(sv.friendName) today")
                .font(.footnote)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
    }

    // MARK: Quizzes I took (shows the reaction my friend sent)

    private var myResultsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            FriendsSectionHeader(title: "Your quiz scores")
            VStack(spacing: 0) {
                ForEach(Array(myResults.enumerated()), id: \.element.id) { index, quiz in
                    if index > 0 { Divider() }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(quiz.score ?? 0)% on \(quiz.reference)")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Text("Quiz from \(quiz.friendName)")
                                .font(.footnote)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        Spacer(minLength: 8)
                        if let r = quiz.reaction, let reaction = QuizReaction(rawValue: r) {
                            Text(reaction.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.reforgedGold)
                                .padding(.horizontal, 12).frame(minHeight: 34)
                                .background(Color.reforgedGold.opacity(0.14), in: Capsule())
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
            .friendsCard()
        }
    }

    // MARK: Quiz results

    private var resultsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            FriendsSectionHeader(title: "Quiz results")
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, quiz in
                    if index > 0 { Divider() }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("\(quiz.friendName) scored \(quiz.score ?? 0)%")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Spacer()
                            Text(quiz.reference)
                                .font(.footnote)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(QuizReaction.allCases) { reaction in
                                    let selected = quiz.reaction == reaction.rawValue
                                    Button(reaction.label) { Task { await store.react(quiz, reaction) } }
                                        .buttonStyle(PillButtonStyle(filled: selected))
                                }
                                if quiz.xpClaimable {
                                    Button { Task { await store.claimXP(quiz) } } label: {
                                        Label("Claim XP", systemImage: "sparkles")
                                    }
                                    .buttonStyle(PillButtonStyle())
                                }
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
            .friendsCard()
        }
    }
}

// MARK: - Propose a verse (mirrors the Memory tab's Add Verse sheet)

struct ProposeVerseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var friends = FriendsStore.shared
    @ObservedObject private var store = SharedVersesStore.shared
    @State private var friendId: String = ""
    @State private var reference = ""
    @State private var canonicalReference = ""
    @State private var text = ""
    @State private var translation: BibleTranslation = SettingsManager.shared.defaultTranslation
    @State private var isFetching = false
    @State private var fetchError: String?
    @State private var fetchTask: Task<Void, Never>?
    @State private var sending = false
    @State private var showVersePicker = false
    @FocusState private var referenceFocused: Bool

    // Verse picker state (same as AddVerseSheet)
    @State private var selectedBook: BibleBook = BibleData.defaultBook
    @State private var selectedChapter: Int = 3
    @State private var selectedVerseStart: Int = 0
    @State private var selectedVerseEnd: Int = 0

    private var friend: FriendActivity? { friends.friends.first { $0.friendId == friendId } }
    private var displayReference: String { canonicalReference.isEmpty ? reference : canonicalReference }
    private var canSend: Bool {
        friend != nil && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isFetching && !sending
    }

    /// Next learning-path verse from each unit that isn't already shared with someone.
    private var suggestions: [(verse: CurriculumVerse, theme: String)] {
        let shared = Set(store.verses.map(\.reference))
        return MemoryCurriculum.units
            .compactMap { unit in
                unit.verses.first { !shared.contains($0.reference) }.map { (verse: $0, theme: unit.theme) }
            }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ReforgedTheme.spacingL) {
                    friendSection
                    findSection
                    previewSection
                    if text.isEmpty && !isFetching && fetchError == nil && !suggestions.isEmpty {
                        suggestionsSection
                    }
                    Text("\(friend?.displayName ?? "Your friend") sees the reference only. You each read the text from your own Bible. If they accept, it's added to both Memory decks.")
                        .font(.footnote)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, ReforgedTheme.spacingS)
                .padding(.bottom, ReforgedTheme.spacingL)
                .readableContentWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { sendBar }
            .navigationTitle("Memorize Together")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .sheet(isPresented: $showVersePicker) {
                VersePickerSheet(
                    selectedBook: $selectedBook,
                    selectedChapter: $selectedChapter,
                    selectedVerseStart: $selectedVerseStart,
                    selectedVerseEnd: $selectedVerseEnd,
                    translation: translation,
                    onSelect: { fetchedText, fetchedReference in
                        fetchTask?.cancel()
                        isFetching = false
                        fetchError = nil
                        canonicalReference = fetchedReference
                        reference = fetchedReference
                        text = fetchedText
                    }
                )
            }
            .onAppear {
                store.errorMessage = nil
                if friendId.isEmpty { friendId = friends.friends.first?.friendId ?? "" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { referenceFocused = true }
            }
            .onDisappear { fetchTask?.cancel() }
        }
    }

    // MARK: Friend

    @ViewBuilder
    private var friendSection: some View {
        if friends.friends.count > 1 {
            VStack(alignment: .leading, spacing: ReforgedTheme.spacingS + 4) {
                Text("With")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .padding(.horizontal, 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ReforgedTheme.spacingS) {
                        ForEach(friends.friends) { f in
                            let selected = f.friendId == friendId
                            Button { friendId = f.friendId } label: {
                                Text(f.displayName)
                                    .font(.subheadline.weight(selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? Color.adaptiveCardBackground(colorScheme) : Color.adaptiveText(colorScheme))
                                    .padding(.horizontal, 14)
                                    .frame(height: 36)
                                    .background(selected ? Color.adaptiveNavyText(colorScheme) : Color.adaptiveChipBackground(colorScheme))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(NoBlobButtonStyle())
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
        }
    }

    // MARK: Find

    private var findSection: some View {
        VStack(spacing: ReforgedTheme.spacingS + 4) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                TextField("Reference, e.g. John 3:16", text: $reference)
                    .font(.body)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($referenceFocused)
                    .onSubmit { scheduleFetch(debounce: false) }
                    .onChange(of: reference) { newValue in referenceEdited(newValue) }
                if !reference.isEmpty {
                    Button {
                        reference = ""
                        referenceFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear reference")
                }
                translationMenu
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(minHeight: 56)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous)
                    .stroke(referenceFocused ? Color.reforgedCoral.opacity(0.55) : Color.adaptiveBorder(colorScheme), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 8, y: 4)

            Button {
                referenceFocused = false
                showVersePicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "text.book.closed")
                        .foregroundStyle(Color.reforgedGold)
                    Text("Browse by book and chapter")
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(NoBlobButtonStyle())
        }
    }

    private var translationMenu: some View {
        Menu {
            Picker("Translation", selection: $translation) {
                ForEach(VerseTextFetcher.supported) { t in
                    Text("\(t.rawValue) – \(t.fullName)").tag(t)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(translation.rawValue).font(.subheadline.weight(.bold))
                Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.bold))
            }
            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.adaptiveChipBackground(colorScheme))
            .clipShape(Capsule())
        }
        .accessibilityLabel("Translation, \(translation.fullName)")
        .onChange(of: translation) { _ in
            guard !reference.isEmpty else { return }
            scheduleFetch(debounce: false)
        }
    }

    // MARK: Preview

    @ViewBuilder
    private var previewSection: some View {
        if isFetching {
            verseCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.adaptiveTextSecondary(colorScheme).opacity(0.15))
                            .frame(height: 12)
                            .frame(maxWidth: i == 2 ? 160 : .infinity)
                    }
                    Text("Finding \(reference) in \(translation.rawValue)…")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(.top, 4)
                }
                .accessibilityElement(children: .combine)
            }
        } else if let error = fetchError ?? store.errorMessage {
            verseCard {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
        } else if !text.isEmpty {
            verseCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(text)
                        .font(.system(.body, design: .serif))
                        .lineSpacing(6)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(displayReference) · \(translation.rawValue)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.reforgedGold)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else if !reference.isEmpty && !looksLikeVerseReference(reference) {
            Text("Add a verse number, like \(reference.trimmingCharacters(in: .whitespaces)) 1:1, or press search.")
                .font(.footnote)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .padding(.horizontal, 4)
        }
    }

    private func verseCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge + 4, style: .continuous))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 8, y: 4)
    }

    // MARK: Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: ReforgedTheme.spacingS + 4) {
            Text("From your learning path")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.element.verse.id) { index, item in
                    Button { pickSuggestion(item.verse) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.verse.reference)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Text(item.theme)
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .font(.title3)
                                .foregroundStyle(Color.reforgedGold)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NoBlobButtonStyle())
                    .accessibilityHint("Fills in this verse")
                    if index < suggestions.count - 1 { Divider().padding(.leading, 16) }
                }
            }
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))
        }
    }

    // MARK: Send

    private var sendBar: some View {
        Button { send() } label: {
            Text(canSend ? "Send \(displayReference) to \(friend?.displayName ?? "friend")" : "Send Verse")
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(Color.reforgedCoral))
                .opacity(canSend ? 1 : 0.4)
        }
        .buttonStyle(NoBlobButtonStyle())
        .disabled(!canSend)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .readableContentWidth()
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
    }

    private func send() {
        guard let friend else { return }
        sending = true
        let prefetched = (text: text, canonical: displayReference)
        Task {
            let ok = await store.propose(to: friend, reference: displayReference,
                                         translation: translation, prefetched: prefetched)
            sending = false
            if ok { dismiss() }
        }
    }

    // MARK: Fetching (same flow as AddVerseSheet)

    private func referenceEdited(_ newValue: String) {
        // Programmatic updates set the canonical reference first; only react to typing.
        if !newValue.isEmpty && newValue == canonicalReference { return }
        canonicalReference = ""
        fetchError = nil
        text = ""
        if looksLikeVerseReference(newValue) {
            scheduleFetch(debounce: true)
        } else {
            fetchTask?.cancel()
            isFetching = false
        }
    }

    private func looksLikeVerseReference(_ value: String) -> Bool {
        value.range(of: #"[A-Za-z].*\d+\s*[:.]\s*\d+"#, options: .regularExpression) != nil
    }

    private func pickSuggestion(_ verse: CurriculumVerse) {
        referenceFocused = false
        fetchError = nil
        canonicalReference = verse.reference
        reference = verse.reference
        if translation == .kjv {
            withAnimation(.easeOut(duration: 0.25)) { text = verse.text }   // bundled KJV, no network
        } else {
            text = ""
            scheduleFetch(debounce: false)
        }
    }

    private func scheduleFetch(debounce: Bool) {
        let query = reference.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        fetchTask?.cancel()
        fetchError = nil
        isFetching = true
        let tr = translation
        fetchTask = Task {
            if debounce { try? await Task.sleep(nanoseconds: 700_000_000) }
            guard !Task.isCancelled else { return }
            do {
                let result = try await VerseTextFetcher.fetch(reference: query, translation: tr)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if !result.canonical.isEmpty {
                        canonicalReference = result.canonical
                        reference = result.canonical
                    }
                    withAnimation(.easeOut(duration: 0.25)) {
                        text = result.text
                        isFetching = false
                    }
                    if result.text.isEmpty { fetchError = "Couldn't find \(query) in \(tr.rawValue)." }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isFetching = false
                    fetchError = "Couldn't find \(query) in \(tr.rawValue). Check the spelling, or try another translation."
                }
            }
        }
    }
}

// MARK: - Send a quiz

struct SendQuizSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SharedVersesStore.shared
    let verse: SharedVerse
    @State private var busy = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.availableDifficulties(for: verse)) { difficulty in
                        Button {
                            busy = true
                            Task {
                                let ok = await store.sendQuiz(verse, difficulty: difficulty)
                                busy = false
                                if ok { dismiss() }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(difficulty.label).font(.headline)
                                    Text("\(difficulty.blanks) missing words").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "paperplane.fill").foregroundStyle(Color.reforgedGold)
                            }
                        }
                        .disabled(busy)
                    }
                } header: {
                    Text("Quiz \(verse.friendName) on \(verse.reference)")
                } footer: {
                    Text("They fill in the missing words from their own Bible. You'll both earn XP when they finish (up to 3 quizzes a day).")
                }
                if let msg = store.errorMessage {
                    Section { Label(msg, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.subheadline) }
                }
            }
            .navigationTitle("Send a quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { store.errorMessage = nil }
        }
    }
}

// MARK: - Take a quiz

private struct BankItem: Identifiable, Equatable {
    let id = UUID()
    let word: String
}

struct TakeQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = SharedVersesStore.shared
    let quiz: VerseQuiz

    @State private var tokens: [QuizToken] = []
    @State private var answers: [String] = []
    @State private var bank: [BankItem] = []
    @State private var placed: [Int: BankItem] = [:]
    @State private var loading = true
    @State private var submitting = false
    @State private var result: (correct: Int, total: Int, score: Int)?

    private var allFilled: Bool { !answers.isEmpty && placed.count == answers.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("\(quiz.reference) · \(quiz.translation)")
                        .font(.headline).foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("From \(quiz.friendName) · \(quiz.quizDifficulty.label)")
                        .font(.subheadline).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    if loading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if tokens.isEmpty {
                        Text("We couldn't load this verse. Check your connection and try again.")
                            .foregroundStyle(.secondary)
                    } else {
                        FlowLayout(spacing: 6, lineSpacing: 10) {
                            ForEach(tokens) { token in tokenView(token) }
                        }
                        .font(.title3)

                        if let result {
                            resultView(result)
                        } else {
                            Divider()
                            Text("Tap a word, then tap its blank. Tap a filled blank to take it back.")
                                .font(.footnote).foregroundStyle(.secondary)
                            FlowLayout(spacing: 8, lineSpacing: 8) {
                                ForEach(bank) { item in
                                    Button { place(item) } label: {
                                        Text(item.word)
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(Color.reforgedGold.opacity(0.18), in: Capsule())
                                            .foregroundStyle(Color.adaptiveText(colorScheme))
                                    }
                                }
                            }
                            Button { submit() } label: {
                                Text(submitting ? "Checking…" : "Check answers")
                                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(allFilled ? Color.reforgedGold : Color.gray.opacity(0.4),
                                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .foregroundStyle(.white)
                            }
                            .disabled(!allFilled || submitting)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(result == nil ? "Later" : "Done") { dismiss() } } }
            .task { await load() }
        }
    }

    private func load() async {
        guard tokens.isEmpty, let text = await store.text(for: quiz), !text.isEmpty else { loading = false; return }
        let built = QuizBuilder.make(text: text, count: quiz.quizDifficulty.blanks)
        tokens = built.tokens
        answers = built.answers
        bank = built.answers.map { BankItem(word: $0) }.shuffled()
        loading = false
    }

    @ViewBuilder
    private func tokenView(_ token: QuizToken) -> some View {
        if let b = token.blankIndex {
            HStack(spacing: 0) {
                Text(token.leading)
                Button {
                    guard result == nil, let item = placed[b] else { return }
                    placed[b] = nil
                    bank.append(item)
                } label: {
                    Text(placed[b]?.word ?? "       ")
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .frame(minWidth: 56)
                        .background(blankBackground(b), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.reforgedGold.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: placed[b] == nil ? [3] : [])))
                }
                .buttonStyle(.plain)
                Text(token.trailing)
            }
            .foregroundStyle(Color.adaptiveText(colorScheme))
        } else {
            Text(token.leading + token.core + token.trailing)
                .foregroundStyle(Color.adaptiveText(colorScheme))
        }
    }

    private func blankBackground(_ index: Int) -> Color {
        guard result != nil, let item = placed[index] else {
            return placed[index] != nil ? Color.reforgedGold.opacity(0.18) : .clear
        }
        return item.word.lowercased() == answers[index].lowercased() ? Color.green.opacity(0.25) : Color.red.opacity(0.25)
    }

    private func place(_ item: BankItem) {
        guard result == nil, let slot = answers.indices.first(where: { placed[$0] == nil }) else { return }
        placed[slot] = item
        bank.removeAll { $0 == item }
    }

    private func submit() {
        let correct = answers.indices.filter { placed[$0]?.word.lowercased() == answers[$0].lowercased() }.count
        submitting = true
        Task {
            if let score = await store.complete(quiz, total: answers.count, correct: correct) {
                result = (correct, answers.count, score)
            }
            submitting = false
        }
    }

    private func resultView(_ r: (correct: Int, total: Int, score: Int)) -> some View {
        VStack(spacing: 8) {
            Text("\(r.correct) of \(r.total) correct")
                .font(.title2.bold())
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text(r.score == 100 ? "Perfect! 🙌" : "Nice work. Keep reviewing it in Memory.")
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            if let xp = store.infoMessage, xp.hasPrefix("+") {
                Label(xp, systemImage: "sparkles").foregroundStyle(Color.reforgedGold).font(.headline)
            }
            Text("\(quiz.friendName) will see your score.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}


// MARK: - Quiz history for one friend

struct QuizHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = SharedVersesStore.shared
    let friendName: String

    var body: some View {
        NavigationStack {
            let entries = store.log(for: friendName)
            List {
                if entries.isEmpty {
                    Text("No finished quizzes with \(friendName) yet.")
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                ForEach(entries) { e in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(e.score)% on \(e.reference)").font(.body.weight(.semibold))
                            Text(e.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let r = e.reaction, let reaction = QuizReaction(rawValue: r) {
                            Text(reaction.label).font(.footnote).foregroundStyle(Color.reforgedGold)
                        }
                    }
                }
            }
            .navigationTitle("\(friendName)'s quizzes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
