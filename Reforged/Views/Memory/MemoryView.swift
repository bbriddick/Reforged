import SwiftUI

private enum MemoryToolbarVerseAction {
    case practice
    case speak
    case loop
}

struct MemoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.isSidebarNavigation) var isSidebarNavigation
    @AppStorage("hasSeenMemoryWalkthrough") private var hasSeenWalkthrough = false
    @State private var stickyUnit: StickyUnit?
    @State private var showAddVerse = false
    /// Shows the Southland camp-verse track in place of the main journey.
    @State private var showSouthlandTrack = false
    /// A camp day or the whole week just finished (or a manual share): shows the poster sheet.
    @State private var southlandMilestone: SouthlandMilestone?
    @State private var verseToDelete: MemoryVerse?
    @State private var showDeleteConfirmation = false
    @State private var showHowItWorks = false
    @State private var showLevelSheet = false
    @State private var showCrownShop = false
    /// The streak engine itself — the same source the Home card reads — so the
    /// chip and the card can never disagree (user.streak is only a sync mirror).
    @ObservedObject private var streakManager = ReadingStreakManager.shared
    @State private var showStreakSheet = false
    @State private var streakSheetHighlightsFreeze = false
    @State private var showWalkthrough = false
    @State private var showMatchingGame = false
    @State private var showCompleteTheVerse = false
    @State private var showCollectionBuilder = false
    @State private var activeLessonVerse: MemoryVerse? = nil
    @State private var showSayItBackUtility = false
    @State private var sayItBackUtilityVerse: MemoryVerse? = nil
    /// Which verses the review session covers, set just before `showReviewSession` is raised.
    @State private var reviewUnitRefs: Set<String>? = nil
    /// The review is presented from an item that carries its own verse scope, so the session
    /// can never pick up a stale scope (and fall back to the global due queue) from state that
    /// changed in the same update as the presentation.
    @State private var reviewRequest: ReviewRequest?
    private var showReviewSession: Bool {
        get { reviewRequest != nil }
        nonmutating set { reviewRequest = newValue ? ReviewRequest(refs: reviewUnitRefs) : nil }
    }
    @State private var showPracticeOptions = false
    @State private var practiceVerse: MemoryVerse? = nil
    @State private var showToolbarVersePicker = false
    @State private var toolbarVerseAction: MemoryToolbarVerseAction = .practice
    @ObservedObject private var dailyPlanManager = DailyMemoryPlanManager.shared

    var versesForReview: [MemoryVerse] {
        appState.getVersesForReview()
    }

    var totalVerses: Int {
        appState.memoryVerses.count
    }

    var masteredCount: Int {
        appState.memoryVerses.filter { $0.level >= 5 }.count
    }

    // Cached so the O(n) reduce doesn't run on every body evaluation.
    // Updated only when memoryVerses actually changes (see .onChange below).
    @State private var averageMastery: Int = 0

    private func computeAverageMastery(_ verses: [MemoryVerse]) -> Int {
        guard !verses.isEmpty else { return 0 }
        let total = verses.reduce(0) { $0 + Int(($1.accuracy ?? 0)) }
        return total / verses.count
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
        .sheet(item: $appState.pendingChallenge) { invite in
            VerseChallengeSheet(invite: invite) { verse in
                // Let the sheet finish dismissing before the lesson cover rises.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { activeLessonVerse = verse }
            }
            .environmentObject(appState)
        }
        .sheet(item: $southlandMilestone) { milestone in
            SouthlandRewardSheet(milestone: milestone)
                .environmentObject(appState)
        }
        .onChange(of: activeLessonVerse?.id) { id in
            if id == nil { checkSouthlandMilestone() }
        }
        .onChange(of: showReviewSession) { showing in
            if !showing { checkSouthlandMilestone() }
        }
        .sheet(isPresented: $showHowItWorks) {
            SpacedRepetitionInfoSheet()
        }
        .sheet(isPresented: $showCrownShop) {
            CrownShopView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showLevelSheet) {
            LevelProgressSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showStreakSheet, onDismiss: { streakSheetHighlightsFreeze = false }) {
            StreakProgressSheet(highlightFreeze: streakSheetHighlightsFreeze)
                .environmentObject(appState)
        }
        // "Streak unprotected" notification (or the freeze-saved card's "Get another")
        // lands here: open the streak sheet with the freeze section pulsing.
        .onAppear(perform: consumeFreezePrompt)
        .onAppear { FeatureUsage.record(.memoryTab) }
        .onReceive(NotificationCenter.default.publisher(for: .openMemoryVerse)) { note in
            guard let reference = note.userInfo?[AppNotificationUserInfoKey.reference] as? String,
                  let verse = appState.memoryVerses.first(where: { $0.reference == reference }) else { return }
            activeLessonVerse = verse
        }
        .onChange(of: appState.pendingFreezePrompt) { _ in consumeFreezePrompt() }
        .sheet(isPresented: $showWalkthrough) {
            MemoryWalkthroughSheet(onAddVerse: {
                showAddVerse = true
            })
        }
        .sheet(isPresented: $showMatchingGame) {
            // Fewer than 4 custom verses makes a trivial board (the last pair is
            // forced), so fall back to the full pool padded with suggestions.
            MatchingGameView(collectionVerses: customMemoryVerses.count >= 4 ? customMemoryVerses : nil)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showCompleteTheVerse) {
            CompleteTheVerseView(collectionVerses: customMemoryVerses.isEmpty ? nil : customMemoryVerses)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showCollectionBuilder) {
            CollectionBuilderView()
                .environmentObject(appState)
        }
        .fullScreenCover(item: $activeLessonVerse) { verse in
            DailyLessonRunnerView(verse: verse) {
                // Refreshes on finish
            }
            .environmentObject(appState)
        }
        .fullScreenCover(item: $reviewRequest) { request in
            NavigationStack {
                MemoryReviewView(restrictReferences: request.refs)
                    .environmentObject(appState)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { reviewRequest = nil }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPracticeOptions) {
            if let verse = practiceVerse ?? appState.memoryVerses.first {
                PracticeOptionsSheet(verse: verse)
                    .environmentObject(appState)
            }
        }
        .sheet(isPresented: $showSayItBackUtility) {
            if let verse = sayItBackUtilityVerse ?? appState.memoryVerses.first {
                NavigationStack {
                    SayItBackView(verse: verse) { quality in
                        appState.updateVerseReview(verseId: verse.id, quality: quality)
                        appState.addXP(quality >= 3 ? 25 : 10, source: "say-it-back")
                        showSayItBackUtility = false
                    }
                    .navigationTitle(verse.reference)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showSayItBackUtility = false }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showToolbarVersePicker) {
            MemoryToolVersePicker(
                customVerses: customMemoryVerses,
                journeyVerses: journeyMemoryVerses
            ) { verse in
                showToolbarVersePicker = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    launchToolbarAction(toolbarVerseAction, with: verse)
                }
            }
            .environmentObject(appState)
        }
        .onAppear {
            averageMastery = computeAverageMastery(appState.memoryVerses)
            if !hasSeenWalkthrough {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showWalkthrough = true
                    hasSeenWalkthrough = true
                }
            }
        }
        .onChange(of: appState.memoryVerses) { verses in
            averageMastery = computeAverageMastery(verses)
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
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: ReforgedTheme.spacingL) {
                // Compact status band: title + glanceable stat pills + help. Frees
                // the vertical room the old large title + subtitle ate, so the
                // journey path rises and leads.
                HStack(spacing: 8) {
                    Text("Memory")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Spacer(minLength: 6)

                    Button { showStreakSheet = true } label: {
                        HeaderStatChip(icon: "flame.fill", value: "\(streakManager.currentStreak)",
                                       tint: Color(red: 1.0, green: 0.5, blue: 0.0))
                    }
                    .buttonStyle(ChipPressStyle())
                    .accessibilityLabel("\(streakManager.currentStreak) day streak")
                    .accessibilityHint("Shows your streak and streak freezes")

                    // currentLevel, not user.level: the stored field is only a sync
                    // mirror and used to sit at 1 forever.
                    Button { showLevelSheet = true } label: {
                        HeaderStatChip(icon: "star.fill", value: "Lv \(appState.user.currentLevel)",
                                       tint: .reforgedGold)
                    }
                    .buttonStyle(ChipPressStyle())
                    .accessibilityLabel("Level \(appState.user.currentLevel), \(LevelProgression.title(for: appState.user.currentLevel))")
                    .accessibilityHint("Shows your level progression")
                    // Crowns: the spendable reward for effort — opens the shop.
                    Button { showCrownShop = true } label: {
                        HeaderStatChip(icon: "crown.fill", value: "\(appState.crownBalance)",
                                       tint: Color(red: 0.20, green: 0.65, blue: 0.40))
                    }
                    .buttonStyle(ChipPressStyle())
                    .accessibilityLabel("\(appState.crownBalance) crowns")
                    .accessibilityHint("Opens the crown shop")

                    Button(action: { showHowItWorks = true }) {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .accessibilityLabel("How it works")
                }

                // The themed curriculum journey is the home for everyone — a new
                // member sees the whole path (all nodes "available") and taps in.
                populatedContent
            }
            .responsivePadding(.horizontal)
            .padding(.vertical)
            .frame(maxWidth: horizontalSizeClass == .regular ? 1200 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .coordinateSpace(name: MemoryJourneyAnchor.scrollSpace)
        .overlay(alignment: .top) {
            if let unit = stickyUnit {
                StickyUnitBar(unit: unit)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.15), value: stickyUnit)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                MemoryAudioBar()
                memoryFloatingToolbar
            }
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        // Open on the member's next step instead of the top of a long path, and glide
        // there again after a lesson moves the frontier.
        .onAppear { scrollToCurrentNode(proxy, animated: false, delay: 0.45) }
        .onChange(of: appState.memoryVerses.count) { _ in
            // A verse the member just added is revealed by the journey itself.
            guard appState.journeyRevealRef == nil else { return }
            scrollToCurrentNode(proxy, animated: true, delay: 0.6)
        }
        }
    }

    private func scrollToCurrentNode(_ proxy: ScrollViewProxy, animated: Bool, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if animated {
                withAnimation(.easeInOut(duration: 0.6)) {
                    proxy.scrollTo(MemoryJourneyAnchor.current, anchor: .center)
                }
            } else {
                proxy.scrollTo(MemoryJourneyAnchor.current, anchor: .center)
            }
        }
    }

    // MARK: - Empty State Layout (no verses yet)
    // Prioritises onboarding: compact add CTA → suggested verses → locked games

    @ViewBuilder
    private var emptyStateContent: some View {


        // Single-row "Add your first verse" card
        Button(action: { showAddVerse = true }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.reforgedNavy)
                        .frame(width: 52, height: 52)
                        .shadow(color: Color.reforgedNavy.opacity(0.28), radius: 8, y: 4)
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Add your first verse")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Pick one you know, or choose from suggestions below")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(16)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 10, y: 4)
        }
        .buttonStyle(.plain)

        // Suggested verses — featured prominently for new users
        SuggestedVersesSection()

        // Practice games — shown greyed out so users know they exist
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Practice")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Spacer()
                Label("Unlocks after adding a verse", systemImage: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            HStack(spacing: 12) {
                PracticeGameCard(
                    title: "Matching Game",
                    subtitle: "Match references to verses",
                    icon: "square.grid.2x2.fill",
                    xpRange: "150–200 XP",
                    color: Color.adaptivePrimaryIcon(colorScheme)
                ) {}
                .disabled(true)
                .opacity(0.38)

                PracticeGameCard(
                    title: "Complete the Verse",
                    subtitle: "Fill in the missing words",
                    icon: "pencil.and.outline",
                    xpRange: "75–315 XP",
                    color: Color.reforgedGold
                ) {}
                .disabled(true)
                .opacity(0.38)
            }
        }
    }

    // MARK: - Populated State Layout (has verses)

    @ViewBuilder
    private var populatedContent: some View {

        // 1. THE JOURNEY — unified Duolingo-style path (HUD + review-first banner + winding nodes)
        let southlandLearned = appState.memoryVerses
            .filter { SouthlandCurriculum.references.contains($0.reference) }.count

        if showSouthlandTrack {
            SouthlandTrackHeader(
                learned: southlandLearned,
                xp: appState.southlandPointsEarned,
                onBack: { switchSouthlandTrack(to: false) },
                onShare: { southlandMilestone = SouthlandMilestone(kind: .progress) }
            )

            MemoryJourneyView(
                launchLesson: { verse in
                    activeLessonVerse = verse
                },
                reviewAll: {
                    reviewUnitRefs = Set(appState.memoryVerses
                        .filter { $0.isDueForReview && SouthlandCurriculum.references.contains($0.reference) }
                        .map { $0.reference })
                    showReviewSession = true
                },
                reviewUnit: { unit in
                    // Track reviews stay on the camp verses, never the main path.
                    reviewUnitRefs = Set(unit.verses.map { $0.reference })
                        .intersection(SouthlandCurriculum.references)
                    showReviewSession = true
                },
                onPractice: { verse in
                    practiceVerse = verse
                    showPracticeOptions = true
                },
                onAddCustom: { showAddVerse = true },
                stickyUnit: $stickyUnit,
                units: SouthlandCurriculum.units,
                openAccess: true,
                trackRefs: SouthlandCurriculum.references,
                onReviewVerse: { verse in
                    reviewUnitRefs = [verse.reference]
                    showReviewSession = true
                }
            )
            .environmentObject(appState)
        } else {
            SouthlandPromoCard(learned: southlandLearned) { switchSouthlandTrack(to: true) }

            MemoryJourneyView(
                launchLesson: { verse in
                    activeLessonVerse = verse
                },
                reviewAll: {
                    reviewUnitRefs = nil
                    showReviewSession = true
                },
                reviewUnit: { unit in
                    reviewUnitRefs = Set(unit.verses.map { $0.reference })
                    showReviewSession = true
                },
                onPractice: { verse in
                    practiceVerse = verse
                    showPracticeOptions = true
                },
                onAddCustom: { showAddVerse = true },
                stickyUnit: $stickyUnit
            )
            .environmentObject(appState)
        }

        // Collections live below the journey; global practice tools now float in a
        // bottom toolbar (see memoryFloatingToolbar).
        if !showSouthlandTrack {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Collections", actionTitle: "New") {
                showCollectionBuilder = true
            }

            if appState.verseCollections.isEmpty {
                Button(action: { showCollectionBuilder = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.title3)
                            .foregroundStyle(Color.adaptivePrimaryIcon(colorScheme))
                        Text("Import a chapter or build your own set, then practice it in order or shuffled.")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding(ReforgedTheme.spacingM)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                            .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                LazyVGrid(columns: verseColumns, spacing: 12) {
                    ForEach(appState.verseCollections) { collection in
                        NavigationLink {
                            CollectionDetailView(collectionId: collection.id)
                                .environmentObject(appState)
                        } label: {
                            CollectionCard(collection: collection)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        }
    }

    /// Swaps between the main journey and the Southland camp-verse track.
    /// After a lesson or review closes, shows a poster for any camp day newly finished.
    private func checkSouthlandMilestone() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard southlandMilestone == nil, activeLessonVerse == nil, !showReviewSession,
                  let next = SouthlandMilestones.pending(appState) else { return }
            southlandMilestone = next
        }
    }

    private func switchSouthlandTrack(to on: Bool) {
        stickyUnit = nil
        withAnimation(.easeInOut(duration: 0.3)) { showSouthlandTrack = on }
    }

    // MARK: - Floating Memory Tools Toolbar
    // A translucent, floating bar of global practice tools pinned directly
    // above the tab bar while the journey scrolls behind it.
    private var memoryFloatingToolbar: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    floatingTool(icon: "brain.head.profile", title: "Practice",
                                 color: Color.adaptivePrimaryIcon(colorScheme)) {
                        chooseVerse(for: .practice)
                    }
                    floatingTool(icon: "mic.fill", title: "Speak", color: .reforgedGold) {
                        chooseVerse(for: .speak)
                    }
                    floatingTool(icon: "square.grid.2x2.fill", title: "Match",
                                 color: Color.adaptivePrimaryIcon(colorScheme)) {
                        showMatchingGame = true
                    }
                    floatingTool(icon: "pencil.and.outline", title: "Fill",
                                 color: Color(red: 0.2, green: 0.7, blue: 0.4)) {
                        showCompleteTheVerse = true
                    }
                    floatingTool(icon: "headphones", title: "Loop", color: .reforgedCoral) {
                        chooseVerse(for: .loop)
                    }
                    floatingTool(icon: "rectangle.stack.fill", title: "Sets", color: .blue) {
                        showCollectionBuilder = true
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.adaptiveBorder(colorScheme).opacity(0.6), lineWidth: 0.5)
            )

            Button {
                HapticManager.shared.buttonTap()
                showAddVerse = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.reforgedCoral, in: Circle())
                    .shadow(color: Color.reforgedCoral.opacity(0.28), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add custom verse")
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.16), radius: 16, y: 6)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private func consumeFreezePrompt() {
        guard appState.pendingFreezePrompt else { return }
        appState.pendingFreezePrompt = false
        showLevelSheet = false
        streakSheetHighlightsFreeze = true
        // Let the tab switch settle before presenting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showStreakSheet = true }
    }

    private var customMemoryVerses: [MemoryVerse] {
        let curriculumReferences = Set(MemoryCurriculum.allVerses.map(\.reference))
        return appState.memoryVerses.filter { !curriculumReferences.contains($0.reference) }
    }

    private var journeyMemoryVerses: [MemoryVerse] {
        let customIDs = Set(customMemoryVerses.map(\.id))
        return appState.memoryVerses.filter { !customIDs.contains($0.id) }
    }

    private func chooseVerse(for action: MemoryToolbarVerseAction) {
        guard !appState.memoryVerses.isEmpty else {
            showAddVerse = true
            return
        }
        toolbarVerseAction = action
        showToolbarVersePicker = true
    }

    private func launchToolbarAction(_ action: MemoryToolbarVerseAction, with verse: MemoryVerse) {
        switch action {
        case .practice:
            practiceVerse = verse
            showPracticeOptions = true
        case .speak:
            sayItBackUtilityVerse = verse
            showSayItBackUtility = true
        case .loop:
            MemoryAudioPlayer.shared.play(verse: verse)
        }
    }

    @ViewBuilder
    private func floatingTool(icon: String, title: String, color: Color,
                              action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.buttonTap()
            action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .frame(width: 58)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Docked Memory Tools Toolbar
    @ViewBuilder
    private var memoryToolsToolbarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Memory Tools")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    toolPillButton(
                        icon: "mic.fill",
                        title: "Say It Back",
                        color: Color.reforgedGold
                    ) {
                        sayItBackUtilityVerse = appState.memoryVerses.first
                        showSayItBackUtility = true
                    }

                    toolPillButton(
                        icon: "square.grid.2x2.fill",
                        title: "Matching",
                        color: Color.adaptivePrimaryIcon(colorScheme)
                    ) {
                        showMatchingGame = true
                    }

                    toolPillButton(
                        icon: "pencil.and.outline",
                        title: "Fill In Blanks",
                        color: Color(red: 0.2, green: 0.7, blue: 0.4)
                    ) {
                        showCompleteTheVerse = true
                    }

                    toolPillButton(
                        icon: "headphones",
                        title: "Loop Audio",
                        color: Color.reforgedCoral
                    ) {
                        if let verse = appState.memoryVerses.first {
                            MemoryAudioPlayer.shared.play(verse: verse)
                        }
                    }

                    toolPillButton(
                        icon: "rectangle.stack.fill",
                        title: "Collections",
                        color: Color.blue
                    ) {
                        showCollectionBuilder = true
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func toolPillButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            action()
        }) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    /// Shared section header: bold title on the left, a pill "+ action" button
    /// on the right. Keeps My Verses / Collections visually consistent.
    @ViewBuilder
    private func sectionHeader(title: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Spacer()
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.caption.bold())
                    Text(actionTitle).font(.subheadline).fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.reforgedNavy)
                .clipShape(Capsule())
            }
        }
    }
}

private struct MemoryToolVersePicker: View {
    let customVerses: [MemoryVerse]
    let journeyVerses: [MemoryVerse]
    let onSelect: (MemoryVerse) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            List {
                if !customVerses.isEmpty {
                    Section("My Verses") {
                        ForEach(customVerses) { verseRow($0) }
                    }
                }

                if !journeyVerses.isEmpty {
                    Section("Journey Verses") {
                        ForEach(journeyVerses) { verseRow($0) }
                    }
                }
            }
            .navigationTitle("Choose a Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func verseRow(_ verse: MemoryVerse) -> some View {
        Button {
            HapticManager.shared.buttonTap()
            onSelect(verse)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(verse.reference)
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(verse.text)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(2)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
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
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .overlay(alignment: .bottom) {
            // 3D Bottom Bevel Lip
            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge)
                .fill(color.opacity(0.3))
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge))
        }
        .shadow(color: color.opacity(0.18), radius: 8, y: 4)
    }
}

// MARK: - Practice Game Card

struct PracticeGameCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let xpRange: String
    let color: Color
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(color)
                    }
                    Spacer()
                    Text(xpRange)
                        .font(Font.custom("Roboto", size: 11).bold())
                        .foregroundStyle(Color.reforgedGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.reforgedGold.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(title)
                    .font(Font.custom("Roboto", size: 14).bold())
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .font(Font.custom("Roboto", size: 12))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge)
                    .stroke(Color.reforgedCoral.opacity(0.35), lineWidth: 1.5)
            )
            .overlay(alignment: .bottom) {
                // 3D Deck Bevel Lip
                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge)
                    .fill(Color.reforgedCoral.opacity(0.4))
                    .frame(height: 4)
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge))
            }
            .shadow(color: Color.reforgedCoral.opacity(0.25), radius: 10, y: 5)
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
    @ObservedObject private var audioPlayer = MemoryAudioPlayer.shared
    @State private var showActions = false
    @State private var activeSheet: VerseCardSheet? = nil

    private var isThisVersePlaying: Bool {
        audioPlayer.currentVerse?.id == verse.id
    }

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
                        .background(Color.adaptiveChipBackground(colorScheme))
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

                Button {
                    if isThisVersePlaying {
                        if audioPlayer.isPlaying { audioPlayer.pause() } else { audioPlayer.resume() }
                    } else {
                        audioPlayer.play(verse: verse)
                    }
                } label: {
                    Image(systemName: isThisVersePlaying && audioPlayer.isPlaying ? "pause.circle.fill" : "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundStyle(isThisVersePlaying ? Color.reforgedNavy : Color.adaptiveNavyText(colorScheme))
                }
                .padding(.trailing, 4)

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
                    .background(Color.adaptiveChipBackground(colorScheme))
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
                    .environmentObject(appState)
            case .reflectionEditor:
                ReflectionNoteSheet(verse: verse)
                    .environmentObject(appState)
            }
        }
    }
}

// MARK: - Suggested Verses Section

struct SuggestedVersesSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var selectedCategory: String = SuggestedVersesData.defaultCategory

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
    @State private var liveText: String? = nil
    @State private var isLoadingPreview = false

    /// Text to display in the card — live-fetched translation or ESV fallback while loading
    private var displayText: String { liveText ?? verse.text }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(verse.reference)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedGold)
                    HStack(spacing: 4) {
                        if isLoadingPreview {
                            ProgressView()
                                .scaleEffect(0.55)
                                .frame(width: 10, height: 10)
                        }
                        Text(translation.rawValue)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.reforgedNavy.opacity(0.7))
                    .clipShape(Capsule())
                }

                Text(displayText)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineLimit(2)
            }
            .task(id: translation) {
                await fetchPreviewText()
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
                        .foregroundStyle(isAdded ? Color.green : Color.adaptivePrimaryIcon(colorScheme))
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
        // If the preview text has already been fetched, use it directly — no second network call
        if let ready = liveText {
            let memoryVerse = MemoryVerse(
                id: UUID().uuidString,
                reference: verse.reference,
                text: ready,
                esvText: translation == .esv ? ready : nil,
                category: verse.category,
                translation: translation.rawValue,
                lastFetched: AppDateFormatters.iso8601.string(from: Date()),
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
            return
        }

        if translation == .esv {
            // ESV text is already stored in suggested verse data — no fetch needed
            let memoryVerse = MemoryVerse(
                id: UUID().uuidString,
                reference: verse.reference,
                text: verse.text,
                esvText: verse.text,
                category: verse.category,
                translation: translation.rawValue,
                lastFetched: AppDateFormatters.iso8601.string(from: Date()),
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
            // Preview fetch didn't finish yet — fetch on demand
            isFetching = true
            Task {
                do {
                    var fetchedText = ""
                    var fetchedRef = verse.reference
                    switch translation {
                    case .esv:
                        break
                    case .kjv:
                        let result = try await KJVService.shared.fetchVerseForMemory(reference: verse.reference)
                        fetchedText = result.text
                        fetchedRef = result.canonical.isEmpty ? verse.reference : result.canonical
                    case .net:
                        let result = try await NETService.shared.fetchVerseForMemory(reference: verse.reference)
                        fetchedText = result.text
                        fetchedRef = result.canonical.isEmpty ? verse.reference : result.canonical
                    case .csb, .nkjv, .nasb, .rvr1960, .nlt:
                        let result = try await ApiBibleService.shared.fetchVerseForMemory(reference: verse.reference, translation: translation)
                        fetchedText = result.text
                        fetchedRef = result.canonical.isEmpty ? verse.reference : result.canonical
                    case .tr, .sblgnt, .wlc:
                        break  // not applicable for memory verses
                    }
                    let memoryVerse = MemoryVerse(
                        id: UUID().uuidString,
                        reference: fetchedRef,
                        text: fetchedText,
                        esvText: nil,
                        category: verse.category,
                        translation: translation.rawValue,
                        lastFetched: AppDateFormatters.iso8601.string(from: Date()),
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

    /// Fetches and caches preview text for the current translation.
    /// Called via `.task(id: translation)` so it re-runs on every translation switch.
    private func fetchPreviewText() async {
        // ESV text is bundled in SuggestedVersesData — no network call needed
        if translation == .esv {
            liveText = verse.text
            return
        }

        isLoadingPreview = true
        liveText = nil

        do {
            var fetched = ""
            switch translation {
            case .esv:
                fetched = verse.text
            case .kjv:
                let result = try await KJVService.shared.fetchVerseForMemory(reference: verse.reference)
                fetched = result.text
            case .net:
                let result = try await NETService.shared.fetchVerseForMemory(reference: verse.reference)
                fetched = result.text
            case .csb, .nkjv, .nasb, .rvr1960, .nlt:
                let result = try await ApiBibleService.shared.fetchVerseForMemory(reference: verse.reference, translation: translation)
                fetched = result.text
            case .tr, .sblgnt, .wlc:
                break  // not applicable for memory verses
            }
            liveText = fetched
        } catch {
            liveText = nil // fall back to ESV preview text shown via displayText
        }

        isLoadingPreview = false
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
                    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.reforgedNavy.opacity(0.10))
                    .frame(width: 80, height: 80)

                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.adaptivePrimaryIcon(colorScheme))
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
    @State private var selectedTranslation: BibleTranslation = .kjv
    @State private var isFetching = false
    @State private var fetchError: String?
    @State private var canonicalReference = ""
    @State private var showVersePicker = false
    @State private var isEditingText = false
    @State private var fetchTask: Task<Void, Never>?
    @FocusState private var referenceFocused: Bool
    @FocusState private var textFocused: Bool

    // Verse picker state
    @State private var selectedBook: BibleBook = BibleData.defaultBook
    @State private var selectedChapter: Int = 3
    @State private var selectedVerseStart: Int = 0
    @State private var selectedVerseEnd: Int = 0

    /// "General" first, then the learning-path themes so custom verses file
    /// alongside the curriculum, then legacy categories not covered by a theme.
    private var categories: [String] {
        var seen = Set<String>()
        return (["General"] + MemoryCurriculum.units.map(\.theme) + ["Guidance"])
            .filter { seen.insert($0).inserted }
    }

    /// The next un-added learning-path verse from each of the first few units,
    /// so suggestions span themes instead of six from the same unit.
    private var suggestions: [(verse: CurriculumVerse, theme: String)] {
        let owned = Set(appState.memoryVerses.map(\.reference))
        return MemoryCurriculum.units
            .compactMap { unit in
                unit.verses.first { !owned.contains($0.reference) }.map { (verse: $0, theme: unit.theme) }
            }
            .prefix(6)
            .map { $0 }
    }

    private var canAdd: Bool {
        !reference.trimmingCharacters(in: .whitespaces).isEmpty
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isFetching
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ReforgedTheme.spacingL) {
                    findSection
                    previewSection
                    if text.isEmpty && !isFetching && !isEditingText && fetchError == nil && !suggestions.isEmpty {
                        suggestionsSection
                    }
                    categorySection
                }
                .padding(.horizontal, 20)
                .padding(.top, ReforgedTheme.spacingS)
                .padding(.bottom, ReforgedTheme.spacingL)
                .readableContentWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { addBar }
            .navigationTitle("Add Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
                        fetchTask?.cancel()
                        isFetching = false
                        fetchError = nil
                        isEditingText = false
                        canonicalReference = fetchedReference
                        reference = fetchedReference
                        text = fetchedText
                    }
                )
            }
            .onAppear {
                selectedTranslation = settingsManager.defaultTranslation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { referenceFocused = true }
            }
            .onDisappear { fetchTask?.cancel() }
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
            Picker("Translation", selection: $selectedTranslation) {
                ForEach(BibleTranslation.allCases.filter(\.supportsMemoryFetch)) { translation in
                    Text("\(translation.rawValue) – \(translation.fullName)").tag(translation)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedTranslation.rawValue)
                    .font(.subheadline.weight(.bold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.adaptiveChipBackground(colorScheme))
            .clipShape(Capsule())
        }
        .accessibilityLabel("Translation, \(selectedTranslation.fullName)")
        .onChange(of: selectedTranslation) { _ in
            // Re-fetch the same reference in the new translation instead of
            // making the user do it by hand.
            guard !reference.isEmpty, !isEditingText else { return }
            scheduleFetch(debounce: false)
        }
    }

    // MARK: Preview

    @ViewBuilder
    private var previewSection: some View {
        if isEditingText {
            VStack(alignment: .leading, spacing: ReforgedTheme.spacingS) {
                HStack {
                    Text("Verse text")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Spacer()
                    Button("Done") { textFocused = false; isEditingText = false }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.reforgedCoral)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 4)
                TextEditor(text: $text)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(6)
                    .scrollContentBackground(.hidden)
                    .focused($textFocused)
                    .frame(minHeight: 140)
                    .padding(12)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous)
                            .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                    )
            }
        } else if isFetching {
            verseCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.adaptiveTextSecondary(colorScheme).opacity(0.15))
                            .frame(height: 12)
                            .frame(maxWidth: i == 2 ? 160 : .infinity)
                    }
                    Text("Finding \(reference) in \(selectedTranslation.rawValue)…")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(.top, 4)
                }
                .accessibilityElement(children: .combine)
            }
        } else if let error = fetchError {
            verseCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Button("Type the text instead") { beginManualEntry() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.reforgedCoral)
                }
            }
        } else if !text.isEmpty {
            verseCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(text)
                        .font(.system(.body, design: .serif))
                        .lineSpacing(6)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("\(displayReference) · \(selectedTranslation.rawValue)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.reforgedGold)
                        Spacer()
                        Button("Edit") { beginManualEntry() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
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

    private var displayReference: String {
        canonicalReference.isEmpty ? reference : canonicalReference
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
                    Button { pickSuggestion(item.verse, theme: item.theme) } label: {
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
                    if index < suggestions.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))
        }
    }

    // MARK: Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: ReforgedTheme.spacingS + 4) {
            Text("Category")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .padding(.horizontal, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ReforgedTheme.spacingS) {
                    ForEach(categories, id: \.self) { cat in
                        let isSelected = cat == category
                        Button { category = cat } label: {
                            Text(cat)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.adaptiveCardBackground(colorScheme) : Color.adaptiveText(colorScheme))
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(isSelected ? Color.adaptiveNavyText(colorScheme) : Color.adaptiveChipBackground(colorScheme))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(NoBlobButtonStyle())
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }

    // MARK: Add

    private var addBar: some View {
        Button {
            addVerse()
            dismiss()
        } label: {
            Text(canAdd ? "Add \(displayReference)" : "Add Verse")
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(Color.reforgedCoral))
                .opacity(canAdd ? 1 : 0.4)
        }
        .buttonStyle(NoBlobButtonStyle())
        .disabled(!canAdd)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .readableContentWidth()
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
    }

    // MARK: Fetching

    private func referenceEdited(_ newValue: String) {
        // Programmatic updates (fetch result, picker, suggestion) set the
        // canonical reference first; only react to the user's own typing.
        if !newValue.isEmpty && newValue == canonicalReference { return }
        canonicalReference = ""
        fetchError = nil
        if !isEditingText { text = "" }
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

    private func pickSuggestion(_ verse: CurriculumVerse, theme: String) {
        referenceFocused = false
        category = categories.contains(theme) ? theme : "General"
        isEditingText = false
        fetchError = nil
        canonicalReference = verse.reference
        reference = verse.reference
        if selectedTranslation == .kjv {
            // Curriculum text is bundled KJV — no network needed.
            withAnimation(.easeOut(duration: 0.25)) { text = verse.text }
        } else {
            text = ""
            scheduleFetch(debounce: false)
        }
    }

    private func beginManualEntry() {
        fetchTask?.cancel()
        isFetching = false
        fetchError = nil
        isEditingText = true
        referenceFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { textFocused = true }
    }

    private func scheduleFetch(debounce: Bool) {
        let query = reference.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        fetchTask?.cancel()
        fetchError = nil
        isFetching = true
        let translation = selectedTranslation
        fetchTask = Task {
            if debounce {
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
            guard !Task.isCancelled else { return }
            do {
                let result = try await fetchVerse(reference: query, translation: translation)
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
                    if result.text.isEmpty {
                        fetchError = "Couldn't find \(query) in \(translation.rawValue)."
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isFetching = false
                    fetchError = "Couldn't find \(query) in \(translation.rawValue). Check the spelling, or try another translation."
                }
            }
        }
    }

    private func fetchVerse(reference: String, translation: BibleTranslation) async throws -> (text: String, canonical: String) {
        switch translation {
        case .esv:
            return try await ESVService.shared.fetchVerseForMemory(reference: reference)
        case .kjv:
            return try await KJVService.shared.fetchVerseForMemory(reference: reference)
        case .net:
            return try await NETService.shared.fetchVerseForMemory(reference: reference)
        case .csb, .nkjv, .nasb, .rvr1960, .nlt:
            return try await ApiBibleService.shared.fetchVerseForMemory(reference: reference, translation: translation)
        case .tr, .sblgnt, .wlc:
            return ("", "")  // original-language texts aren't offered for memory
        }
    }

    func addVerse() {
        let verse = MemoryVerse(
            id: UUID().uuidString,
            reference: displayReference,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            esvText: selectedTranslation == .esv ? text : nil,
            category: category,
            translation: selectedTranslation.rawValue,
            lastFetched: AppDateFormatters.iso8601.string(from: Date()),
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

private extension BibleTranslation {
    /// Original-language texts have no memory fetch path.
    var supportsMemoryFetch: Bool {
        switch self {
        case .tr, .sblgnt, .wlc: return false
        default: return true
        }
    }
}

// MARK: - Practice Options Sheet

struct PracticeOptionsSheet: View {
    let verse: MemoryVerse
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showReflectionEditor = false

    private let modeColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .tracking(0.6)
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

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

                    // Practice modes — compact 2-column grid so all six fit
                    // without long scrolling.
                    sectionLabel("Practice modes")
                    LazyVGrid(columns: modeColumns, spacing: 12) {
                        ForEach(MemoryMode.allCases, id: \.self) { mode in
                            NavigationLink(destination: MemoryPracticeView(verse: verse, mode: mode)) {
                                PracticeModeTile(mode: mode)
                            }
                            .buttonStyle(PracticeLipButtonStyle(
                                face: Color.adaptiveCardBackground(colorScheme),
                                lip: Color.adaptiveBorder(colorScheme),
                                stroke: Color.adaptiveBorder(colorScheme),
                                cornerRadius: 16,
                                depth: 4
                            ))
                        }
                    }

                    // Featured / secondary actions stay full-width so they read
                    // as distinct from the mode grid above.
                    sectionLabel("Go deeper")
                    NavigationLink(destination: SayItBackView(verse: verse) { quality in
                        appState.updateVerseReview(verseId: verse.id, quality: quality)
                        appState.addXP(quality >= 3 ? 30 : 10, source: "say-it-back")
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.reforgedGold.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "waveform.badge.mic")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.reforgedGold)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Say It Back")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Text("Speak aloud to verify recitation with real-time speech AI")
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        .padding(14)
                        .background(Color.adaptiveCardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.reforgedGold.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: DeepDrillView(verse: verse)) {
                        DeepDrillCard()
                    }
                    .buttonStyle(.plain)

                    Button {
                        MemoryAudioPlayer.shared.play(verse: verse)
                        dismiss()
                    } label: {
                        ListenOnLoopCard()
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: VerseChallenge.message(reference: verse.reference,
                                                           from: appState.user.firstName)) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.reforgedCoral, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Challenge a friend")
                                    .font(.headline.bold())
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Text("Send this verse and memorize it together")
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption.bold())
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        .padding(14)
                        .practiceCard(radius: 14)
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

// MARK: - Practice Mode Tile (compact grid cell)

struct PracticeModeTile: View {
    let mode: MemoryMode
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Rounded-square icon chip, the same shape the Memory path uses for unit icons.
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.reforgedCoral)
                    .frame(width: 44, height: 44)

                Image(systemName: mode.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(mode.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(mode.description)
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(14)
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

// MARK: - Listen on Loop Card

struct ListenOnLoopCard: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.reforgedNavy.opacity(colorScheme == .dark ? 0.4 : 1.0))
                    .frame(width: 50, height: 50)

                Image(systemName: "repeat")
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Listen on Loop")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("Hear this passage on repeat")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            Spacer()

            Image(systemName: "play.fill")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding()
        .background(Color.reforgedNavy.opacity(colorScheme == .dark ? 0.15 : 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.reforgedNavy.opacity(0.25), lineWidth: 1)
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
        guard parts.count >= 2, let lastPart = parts.last, let chapter = Int(lastPart) else { return }
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
                case .net:
                    let result = try await NETService.shared.fetchChapterParsed(book: selectedBook.name, chapter: selectedChapter)
                    fetchedVerses = result.verses
                case .csb, .nkjv, .nasb, .rvr1960, .nlt:
                    let result = try await ApiBibleService.shared.fetchChapterParsed(book: selectedBook.name, chapter: selectedChapter, translation: translation)
                    fetchedVerses = result.verses
                case .tr, .sblgnt, .wlc:
                    break  // not applicable for memory verse picker
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
                .background(isSelected ? Color.reforgedNavy : Color.adaptiveChipBackground(colorScheme))
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
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.adaptiveChipBackground(colorScheme))
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

// MARK: - Memory Walkthrough Sheet

struct MemoryWalkthroughSheet: View {
    var onAddVerse: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var page = 0

    private let pageCount = 6
    private var isLast: Bool { page == pageCount - 1 }

    var body: some View {
        VStack(spacing: 0) {
            OnbDots(index: page, count: pageCount).padding(.top, 24)

            TabView(selection: $page) {
                ForEach(0..<pageCount, id: \.self) { i in
                    MemoryTourPage(index: i).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 4) {
                ReturningPrimaryButton(title: isLast ? "Start my path" : "Next") {
                    if isLast {
                        dismiss()
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                    }
                }
                Button {
                    dismiss()
                    if isLast {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onAddVerse?() }
                    }
                } label: {
                    Text(isLast ? "Add a verse of my own" : "Skip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(NoBlobButtonStyle())
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Tour pages

private struct MemoryTourPage: View {
    let index: Int
    @Environment(\.colorScheme) private var colorScheme

    private var title: String {
        ["Scripture, by heart.", "Follow your path.", "A short review each time.",
         "Review when ready.", "Practice anytime.", "One verse at a time."][index]
    }

    private var lead: String {
        [
            "Learn one verse at a time. Each one gets a short lesson, then comes back right before you would forget it.",
            "Verses are grouped by theme, from Faith to Eternity. Tap START to learn the next one. Later verses unlock as you go.",
            "Each verse is practiced in five quick steps, and you earn XP when you finish.",
            "When verses are due, a coral banner appears on your path. Swipe through a quick deck, then try harder exercises as a verse gets stronger.",
            "The toolbar at the bottom of the Memory tab has extra practice for any verse you have learned.",
            "Start small, come back tomorrow, and let reviews do the heavy lifting. Each review pushes the next one further out."
        ][index]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(lead)
                        .font(.body)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 32)

                visual
                    .padding(.top, 32)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder private var visual: some View {
        switch index {
        case 0: TourVerseVisual()
        case 1: TourPathVisual()
        case 2: TourLessonVisual()
        case 3: TourReviewVisual()
        case 4: TourToolsVisual()
        default: TourSpacingVisual()
        }
    }
}

private let tourGreen = Color(red: 0.20, green: 0.65, blue: 0.40)
private let tourGreenBevel = Color(red: 0.13, green: 0.48, blue: 0.28)
private let tourGoldBevel = Color(red: 0.75, green: 0.58, blue: 0.10)

private extension View {
    /// The soft white card used across the new onboarding.
    func tourCard(_ scheme: ColorScheme, radius: CGFloat = 20) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.adaptiveCardBackground(scheme))
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.06), radius: 14, y: 6)
            )
    }
}

// MARK: Page 1: a verse with blanks

private struct TourVerseVisual: View {
    @Environment(\.colorScheme) private var colorScheme

    private func blank(_ word: String) -> Text {
        Text(word).foregroundColor(.clear).underline(true, color: Color.reforgedCoral)
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("JOHN 3:16")
                    .font(.caption.weight(.bold)).tracking(1.2)
                    .foregroundStyle(Color.reforgedGold)
                (Text("For God so loved the ") + blank("world") + Text(", that he gave his only ") +
                 blank("begotten") + Text(" Son, that whosoever ") + blank("believeth") +
                 Text(" in him should not perish, but have ") + blank("everlasting") + Text(" life."))
                    .font(.custom("LibreBaskerville-Regular", size: 17))
                    .lineSpacing(6)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tourCard(colorScheme)

            HStack(spacing: 8) {
                stage("book.fill", "Learn", .reforgedGold)
                chevron
                stage("arrow.triangle.2.circlepath", "Review", .reforgedCoral)
                chevron
                stage("crown.fill", "Remember", tourGreen)
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.5))
    }

    private func stage(_ icon: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Circle().fill(color).frame(width: 48, height: 48)
                .overlay(Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(.white))
            Text(label).font(.footnote.weight(.semibold)).foregroundStyle(Color.adaptiveText(colorScheme))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: Page 2: the path

/// A live crop of the real path: the same banner, nodes and connectors the Memory tab uses,
/// fed from the first curriculum unit, so the tour can never drift from what users see.
private struct TourPathVisual: View {
    private let unit = MemoryCurriculum.units[0]

    var body: some View {
        VStack(spacing: 6) {
            UnitHeaderBanner(unit: unit, isStarted: true, isCollapsed: false, onToggle: {})
            CurriculumVerseNode(verse: unit.verses[0], unit: unit, status: .available, locked: false,
                                level: 0, isCurrent: true, xOffset: 0, prevOffset: nil, bounce: true,
                                onTap: {}, onPractice: {}, onRemove: nil)
            CurriculumVerseNode(verse: unit.verses[1], unit: unit, status: .available, locked: true,
                                level: 0, isCurrent: false, xOffset: 57, prevOffset: 0, bounce: false,
                                onTap: {}, onPractice: {}, onRemove: nil)
            CheckpointNode(unit: unit, kind: .quickRecall, unlocked: false, xOffset: 0, prevOffset: 57, onTap: {})
        }
        .frame(maxWidth: .infinity)
        .frame(height: 400, alignment: .top)
        .clipped()
        .mask(LinearGradient(stops: [.init(color: .black, location: 0.72), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A preview of your memory path")
    }
}

// MARK: Page 3: lesson steps

private struct TourLessonVisual: View {
    @Environment(\.colorScheme) private var colorScheme

    private let steps: [(String, String, String, Color)] = [
        ("headphones", "Listen", "Hear the verse read aloud", .reforgedCoral),
        ("hand.tap.fill", "Tap it together", "Build it phrase by phrase", Color(red: 0.40, green: 0.24, blue: 0.52)),
        ("hand.draw.fill", "Drag the words", "Put each word in its place", Color(red: 0.06, green: 0.45, blue: 0.58)),
        ("text.badge.plus", "Fill the blanks", "Recall the missing words", tourGreen),
        ("mic.fill", "Say it back", "Recite it into the mic", .reforgedGold),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                    HStack(spacing: 14) {
                        VStack(spacing: 0) {
                            Circle().fill(s.3).frame(width: 40, height: 40)
                                .overlay(Image(systemName: s.0).font(.system(size: 17, weight: .bold)).foregroundStyle(.white))
                            if i < steps.count - 1 {
                                Rectangle().fill(Color.adaptiveBorder(colorScheme)).frame(width: 2, height: 18)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.1).font(.subheadline.bold()).foregroundStyle(Color.adaptiveText(colorScheme))
                            Text(s.2).font(.footnote).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        .padding(.bottom, i < steps.count - 1 ? 18 : 0)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(20)
            .tourCard(colorScheme)

            HStack(spacing: 8) {
                Image(systemName: "star.fill").foregroundStyle(Color.reforgedGold)
                Text("XP when you finish")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Capsule().fill(Color.reforgedGold.opacity(0.15)))
            .padding(.top, 16)
        }
    }
}

// MARK: Page 4: the swipe deck

private struct TourReviewVisual: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragX: CGFloat = 0
    @State private var cardOpacity: Double = 1
    @State private var stampOpacity: Double = 0
    @State private var known = true

    private let ladder: [(String, String)] = [
        ("rectangle.on.rectangle.angled", "Cards"), ("hand.tap.fill", "Tap"), ("hand.draw.fill", "Drag"),
        ("a.circle", "Letters"), ("keyboard", "Type"),
    ]

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 14) {
                ZStack {
                    card.scaleEffect(0.90).offset(y: 22).opacity(0.5)
                    card.scaleEffect(0.95).offset(y: 11).opacity(0.8)
                    card
                        .overlay(stamp)
                        .rotationEffect(.degrees(Double(dragX) / 16))
                        .offset(x: dragX)
                        .opacity(cardOpacity)
                }
                .frame(height: 190)

                HStack {
                    Label("Still learning", systemImage: "arrow.left").foregroundStyle(.red)
                    Spacer()
                    HStack(spacing: 4) { Text("Known"); Image(systemName: "arrow.right") }.foregroundStyle(.green)
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 6)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("STRONGER VERSES GRADUATE")
                    .font(.caption.weight(.bold)).tracking(1.2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                HStack(spacing: 0) {
                    ForEach(Array(ladder.enumerated()), id: \.offset) { i, s in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(Color.adaptiveChipBackground(colorScheme))
                                .frame(width: 42, height: 42)
                                .overlay(Image(systemName: s.0).font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(i == ladder.count - 1 ? Color.reforgedCoral
                                                                           : Color.adaptivePrimaryIcon(colorScheme)))
                            Text(s.1).font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await loop() }
    }

    private var card: some View {
        VStack(spacing: 10) {
            Text("ROMANS 8:28")
                .font(.caption.weight(.bold)).tracking(1.2)
                .foregroundStyle(Color.reforgedGold)
            Text("Tap to flip, then swipe")
                .font(.custom("LibreBaskerville-Regular", size: 17))
                .foregroundStyle(Color.adaptiveText(colorScheme))
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .tourCard(colorScheme, radius: 22)
    }

    private var stamp: some View {
        Text(known ? "KNOWN" : "STILL LEARNING")
            .font(.system(size: known ? 28 : 18, weight: .heavy))
            .foregroundStyle(known ? Color.green : Color.red)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(known ? Color.green : Color.red, lineWidth: 3))
            .rotationEffect(.degrees(known ? -14 : 14))
            .opacity(stampOpacity)
    }

    @MainActor private func loop() async {
        if reduceMotion { dragX = 40; stampOpacity = 1; return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            let dir: CGFloat = known ? 1 : -1
            withAnimation(.easeOut(duration: 0.45)) { dragX = 70 * dir; stampOpacity = 1 }
            try? await Task.sleep(nanoseconds: 750_000_000)
            withAnimation(.easeIn(duration: 0.3)) { dragX = 380 * dir; cardOpacity = 0; stampOpacity = 0 }
            try? await Task.sleep(nanoseconds: 450_000_000)
            known.toggle()
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { dragX = 0 }
            withAnimation(.easeOut(duration: 0.3)) { cardOpacity = 1 }
        }
    }
}

// MARK: Page 5: practice tools

private struct TourToolsVisual: View {
    @Environment(\.colorScheme) private var colorScheme

    private var tools: [(String, String, String, Color)] {
        [
            ("brain.head.profile", "Practice", "Flip and recite", Color.adaptivePrimaryIcon(colorScheme)),
            ("mic.fill", "Speak", "Say it aloud", .reforgedGold),
            ("headphones", "Loop", "Listen on repeat", .reforgedCoral),
            ("square.grid.2x2.fill", "Match", "Pair refs to text", Color.adaptivePrimaryIcon(colorScheme)),
            ("pencil.and.outline", "Fill", "Missing words", tourGreen),
            ("rectangle.stack.fill", "Sets", "Your collections", .blue),
        ]
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            ForEach(Array(tools.enumerated()), id: \.offset) { _, t in
                HStack(spacing: 12) {
                    Circle().fill(t.3.opacity(0.14)).frame(width: 42, height: 42)
                        .overlay(Image(systemName: t.0).font(.system(size: 17, weight: .semibold)).foregroundStyle(t.3))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(t.1).font(.subheadline.bold()).foregroundStyle(Color.adaptiveText(colorScheme))
                        Text(t.2).font(.caption).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .tourCard(colorScheme, radius: 16)
            }
        }
    }
}

// MARK: Page 6: spaced reviews

private struct TourSpacingVisual: View {
    @Environment(\.colorScheme) private var colorScheme

    // Gaps grow as the verse sticks.
    private let stops: [CGFloat] = [0, 0.09, 0.26, 0.55, 1]

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                GeometryReader { geo in
                    let w = geo.size.width - 40
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.adaptiveBorder(colorScheme)).frame(height: 4).padding(.horizontal, 20)
                        ForEach(Array(stops.enumerated()), id: \.offset) { i, f in
                            let last = i == stops.count - 1
                            Circle()
                                .fill(i == 0 ? Color.reforgedGold : (last ? tourGreen : Color.reforgedCoral))
                                .frame(width: last ? 40 : 30, height: last ? 40 : 30)
                                .overlay(Image(systemName: i == 0 ? "book.fill" : (last ? "crown.fill" : "arrow.triangle.2.circlepath"))
                                    .font(.system(size: last ? 16 : 12, weight: .bold)).foregroundStyle(.white))
                                .position(x: 20 + w * f, y: geo.size.height / 2)
                        }
                    }
                }
                .frame(height: 44)
                HStack {
                    Text("Learned").font(.footnote.weight(.semibold))
                    Spacer()
                    Text("Remembered").font(.footnote.weight(.semibold))
                }
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(20)
            .tourCard(colorScheme)

            HStack(spacing: 12) {
                Circle().fill(Color.adaptivePrimaryIcon(colorScheme).opacity(0.12)).frame(width: 40, height: 40)
                    .overlay(Image(systemName: "plus").font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.adaptivePrimaryIcon(colorScheme)))
                Text("Want a verse that is not on your path? Add your own any time.")
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
        }
    }
}

#if false
#Preview {
    MemoryView()
        .environmentObject(AppState.shared)
}
#endif

/// Tactile press for the header stat chips: a quick squeeze, no system highlight.
private struct ChipPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}


/// A review session request: nil `refs` means the global due queue.
private struct ReviewRequest: Identifiable {
    let id = UUID()
    let refs: Set<String>?
}
