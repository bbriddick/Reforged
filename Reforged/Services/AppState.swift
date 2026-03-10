import Foundation
import Combine

// MARK: - App State Manager

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var user: UserProfile = .empty
    @Published var memoryVerses: [MemoryVerse] = []
    @Published var tracks: [Track] = []
    @Published var dailyInsight: DailyInsight?
    @Published var isLoading = true
    @Published var hasSyncedFromCloud = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?

    // MARK: - Gamification Events
    @Published var showXPGain = false
    @Published var lastXPGain: Int = 0
    @Published var lastXPSource: String = ""
    @Published var showLevelUp = false
    @Published var newLevel: Int = 0
    @Published var showBadgeEarned = false
    @Published var earnedBadge: Badge? = nil
    @Published var showStreakMilestone = false

    private let cloudKit = CloudKitSyncService.shared
    private let appleSignIn = AppleSignInService.shared
    private var cancellables = Set<AnyCancellable>()
    private var saveTask: Task<Void, Never>?
    private var syncDebounceTask: Task<Void, Never>?

    private init() {
        // One-time migration: clean up old Supabase session data
        if !UserDefaults.standard.bool(forKey: "migration_v2_cloudkit_complete") {
            UserDefaults.standard.removeObject(forKey: "supabase_session")
            UserDefaults.standard.set(true, forKey: "migration_v2_cloudkit_complete")
        }

        loadFromLocalStorage()
        setupAutoSync()
        // Initialize iCloud KVS sync for reading position
        _ = iCloudSyncService.shared
    }

    // MARK: - Local Storage

    private func loadFromLocalStorage() {
        if let data = UserDefaults.standard.data(forKey: "reforged_user"),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.user = user
            migrateBadgesAndPerks()
        }

        if let data = UserDefaults.standard.data(forKey: "reforged_verses"),
           let verses = try? JSONDecoder().decode([MemoryVerse].self, from: data) {
            self.memoryVerses = verses
        }

        // Always load fresh track content from LearningTracks, then restore completion progress
        self.tracks = LearningTracks.allTracks
        // Restore lesson completion state from user's saved progress
        for lessonId in user.completedLessons {
            for i in tracks.indices {
                if let j = tracks[i].lessons.firstIndex(where: { $0.id == lessonId }) {
                    if !tracks[i].lessons[j].isCompleted {
                        tracks[i].lessons[j].isCompleted = true
                        tracks[i].completedLessons += 1
                    }
                }
            }
        }

        // Replenish streak freezes at start of each month
        checkMonthlyFreezeReplenish()

        // Load daily insight - always check if it's from today
        loadTodaysDailyInsight()

        if let date = UserDefaults.standard.object(forKey: "reforged_last_sync") as? Date {
            self.lastSyncDate = date
        }

        isLoading = false
    }

    private func saveToLocalStorage() {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "reforged_user")
        }
        if let data = try? JSONEncoder().encode(memoryVerses) {
            UserDefaults.standard.set(data, forKey: "reforged_verses")
        }
        if let data = try? JSONEncoder().encode(tracks) {
            UserDefaults.standard.set(data, forKey: "reforged_tracks")
        }
        if let insight = dailyInsight, let data = try? JSONEncoder().encode(insight) {
            UserDefaults.standard.set(data, forKey: "reforged_daily_insight")
        }
        if let date = lastSyncDate {
            UserDefaults.standard.set(date, forKey: "reforged_last_sync")
        }
    }

    // MARK: - Cloud Sync

    private func setupAutoSync() {
        // Debounced auto-save to cloud
        $user.combineLatest($memoryVerses, $tracks)
            .dropFirst()
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.saveToLocalStorage()
                self?.debouncedSyncToCloud()
            }
            .store(in: &cancellables)

        // Listen for Bible reading state changes (highlights/notes)
        NotificationCenter.default.publisher(for: .bibleDataDidChange)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.debouncedSyncToCloud()
            }
            .store(in: &cancellables)
    }

    private func debouncedSyncToCloud() {
        syncDebounceTask?.cancel()
        syncDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second debounce
            guard !Task.isCancelled else { return }
            await syncToCloud()
        }
    }

    // MARK: - Full Cloud Sync

    func performFullSync() async {
        guard appleSignIn.isSignedIn else { return }

        isSyncing = true
        defer { isSyncing = false }

        // Ensure CloudKit is available
        await cloudKit.checkAccountStatus()
        guard cloudKit.isCloudAvailable else {
            print("CloudKit not available, skipping sync")
            hasSyncedFromCloud = true
            return
        }

        do {
            // Check if CloudKit has any data (first sync detection).
            // Use explicit do/catch so a transient network error doesn't look like
            // "no cloud data" and incorrectly trigger a migration push.
            let cloudProfile: UserProfile?
            do {
                cloudProfile = try await cloudKit.fetchProfile()
            } catch {
                print("☁️ Could not fetch cloud profile (\(error)) — skipping sync to avoid overwriting data")
                hasSyncedFromCloud = true
                return
            }

            if cloudProfile == nil && user.onboardingCompleted {
                // No cloud data but we have local data — push everything up (first-time migration)
                print("☁️ First CloudKit sync: pushing local data to cloud")
                let highlights = Array(BibleReadingState.shared.highlights.values)
                let notes = Array(BibleReadingState.shared.notes.values)
                try await cloudKit.pushAllData(
                    profile: user,
                    memoryVerses: memoryVerses,
                    highlights: highlights,
                    notes: notes,
                    tracks: tracks
                )
            } else {
                // Normal sync: load from cloud
                await loadProfileFromCloud()
                await loadMemoryVersesFromCloud()
                await loadHighlightsFromCloud()
                await loadNotesFromCloud()
                await loadTrackProgressFromCloud()
            }

            lastSyncDate = Date()
            hasSyncedFromCloud = true
            saveToLocalStorage()

            print("✅ Full sync completed")
        } catch {
            print("❌ Full sync error: \(error)")
            hasSyncedFromCloud = true // Still mark as synced so app continues
        }
    }

    func syncToCloud() async {
        guard appleSignIn.isSignedIn, user.onboardingCompleted, hasSyncedFromCloud else { return }
        guard cloudKit.isCloudAvailable else { return }

        do {
            // Sync profile
            try await cloudKit.saveProfile(user)

            // Sync memory verses
            try await cloudKit.saveMemoryVerses(memoryVerses)

            // Sync track progress
            try await cloudKit.saveTrackProgress(tracks)

            // Sync highlights and notes
            let highlights = Array(BibleReadingState.shared.highlights.values)
            try await cloudKit.saveHighlights(highlights)

            let notes = Array(BibleReadingState.shared.notes.values)
            try await cloudKit.saveNotes(notes)

            lastSyncDate = Date()
            print("✅ Sync to cloud completed")
        } catch {
            print("❌ Error syncing to cloud: \(error)")
        }
    }

    // MARK: - Profile Sync

    private func loadProfileFromCloud() async {
        do {
            if let cloudProfile = try await cloudKit.fetchProfile() {
                // Update user from cloud data (prefer cloud values)
                if !cloudProfile.firstName.isEmpty { user.firstName = cloudProfile.firstName }
                if !cloudProfile.lastName.isEmpty { user.lastName = cloudProfile.lastName }
                if !cloudProfile.displayName.isEmpty { user.displayName = cloudProfile.displayName }
                if !cloudProfile.avatar.isEmpty { user.avatar = cloudProfile.avatar }
                if !cloudProfile.goals.isEmpty { user.goals = cloudProfile.goals }
                if cloudProfile.xp > 0 { user.xp = max(user.xp, cloudProfile.xp) }
                if cloudProfile.streak > 0 { user.streak = max(user.streak, cloudProfile.streak) }
                user.longestStreak = max(user.longestStreak, cloudProfile.longestStreak)
                if !cloudProfile.lastActiveDate.isEmpty { user.lastActiveDate = cloudProfile.lastActiveDate }
                if !cloudProfile.completedLessons.isEmpty {
                    // Merge completed lessons (union)
                    let merged = Set(user.completedLessons).union(Set(cloudProfile.completedLessons))
                    user.completedLessons = Array(merged)
                }
                user.streakFreezes = max(user.streakFreezes, cloudProfile.streakFreezes)
                if !cloudProfile.freezeUsedDates.isEmpty { user.freezeUsedDates = cloudProfile.freezeUsedDates }
                if !cloudProfile.activeDates.isEmpty {
                    let merged = Set(user.activeDates).union(Set(cloudProfile.activeDates))
                    user.activeDates = Array(merged)
                }
                if !cloudProfile.chaptersRead.isEmpty {
                    let merged = Set(user.chaptersRead).union(Set(cloudProfile.chaptersRead))
                    user.chaptersRead = Array(merged)
                }
                if !cloudProfile.badges.isEmpty { user.badges = cloudProfile.badges }
                user.weeklyActivity = cloudProfile.weeklyActivity

                user.onboardingCompleted = true
                user.loggedIn = true
            }
        } catch {
            print("Error loading profile from cloud: \(error)")
        }
    }

    // MARK: - Memory Verses Sync

    private func loadMemoryVersesFromCloud() async {
        do {
            let cloudVerses = try await cloudKit.fetchMemoryVerses()

            // Merge: prefer cloud data but keep local-only verses
            let cloudIds = Set(cloudVerses.map { $0.id })
            let localOnlyVerses = memoryVerses.filter { !cloudIds.contains($0.id) }

            memoryVerses = cloudVerses + localOnlyVerses
        } catch {
            print("Error loading memory verses from cloud: \(error)")
        }
    }

    // MARK: - Highlights Sync

    private func loadHighlightsFromCloud() async {
        do {
            let cloudHighlights = try await cloudKit.fetchHighlights()
            let readingState = BibleReadingState.shared

            // Merge: newest createdAt wins per reference
            var merged = readingState.highlights
            for highlight in cloudHighlights {
                if let existing = merged[highlight.reference] {
                    if highlight.createdAt > existing.createdAt {
                        merged[highlight.reference] = highlight
                    }
                } else {
                    merged[highlight.reference] = highlight
                }
            }

            readingState.isSyncingFromCloud = true
            readingState.highlights = merged
            readingState.isSyncingFromCloud = false
            // Persist merged highlights to UserDefaults so they survive a cold restart
            // before the next sync cycle (avoids losing cloud data between launches).
            readingState.persistToStorage()
        } catch {
            print("Error loading highlights from cloud: \(error)")
        }
    }

    // MARK: - Notes Sync

    private func loadNotesFromCloud() async {
        do {
            let cloudNotes = try await cloudKit.fetchNotes()
            let readingState = BibleReadingState.shared

            // Merge: newest updatedAt wins per reference
            var merged = readingState.notes
            for note in cloudNotes {
                if let existing = merged[note.reference] {
                    if note.updatedAt > existing.updatedAt {
                        merged[note.reference] = note
                    }
                } else {
                    merged[note.reference] = note
                }
            }

            readingState.isSyncingFromCloud = true
            readingState.notes = merged
            readingState.isSyncingFromCloud = false
            // Persist merged notes to UserDefaults so they survive a cold restart
            // before the next sync cycle.
            readingState.persistToStorage()
        } catch {
            print("Error loading notes from cloud: \(error)")
        }
    }

    // MARK: - Track Progress Sync

    private func loadTrackProgressFromCloud() async {
        do {
            let cloudProgress = try await cloudKit.fetchTrackProgress()

            for progress in cloudProgress {
                if let trackIndex = tracks.firstIndex(where: { $0.id == progress.trackId }) {
                    tracks[trackIndex].completedLessons = max(tracks[trackIndex].completedLessons, progress.completedLessons)
                }
            }
        } catch {
            print("Error loading track progress from cloud: \(error)")
        }
    }

    // MARK: - Daily Insight

    /// Load today's daily insight - checks if cached insight is from today, otherwise loads fresh
    private func loadTodaysDailyInsight() {
        let todayString = getTodayDateString()

        // Check if we have a cached insight from today
        if let data = UserDefaults.standard.data(forKey: "reforged_daily_insight"),
           let insight = try? JSONDecoder().decode(DailyInsight.self, from: data) {
            // Check if the cached insight is from today
            if insight.date.hasPrefix(todayString) {
                self.dailyInsight = insight
                return
            }
        }

        // Load fresh insight for today from bundled data
        if let bundledInsight = BundledDataService.shared.getTodaysInsight() {
            self.dailyInsight = BundledDataService.shared.convertToDailyInsight(bundledInsight)
            saveToLocalStorage()
        }
    }

    /// Refresh daily insight (called when app becomes active or on new day)
    func refreshDailyInsightIfNeeded() {
        let todayString = getTodayDateString()

        // Check if current insight is from today
        if let currentInsight = dailyInsight, currentInsight.date.hasPrefix(todayString) {
            return // Already have today's insight
        }

        // Load new insight
        loadTodaysDailyInsight()
    }

    private func getTodayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Legacy methods for backwards compatibility

    func loadFromCloud() async {
        await performFullSync()
    }

    func saveToCloud() async {
        await syncToCloud()
    }

    // MARK: - XP & Progress

    func addXP(_ amount: Int, source: String = "other") {
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        let oldLevel = user.currentLevel

        // Calculate multiplier
        var multiplier: Double = 1.0

        // Streak multiplier: 1.5x at 7+ days, 2x at 30+ days
        if user.streak >= 30 {
            multiplier = 2.0
        } else if user.streak >= 7 {
            multiplier = 1.5
        }

        // XP boost perk (1.25x if active)
        if user.perks.first(where: { $0.id == "xp-boost-small" && $0.isUnlocked && $0.isActive }) != nil {
            multiplier *= 1.25
        }

        // Daily first-action bonus
        var dailyBonus = 0
        if !user.activeDates.contains(today) {
            dailyBonus = 10
        }

        let finalAmount = Int(Double(amount) * multiplier) + dailyBonus
        user.xp += finalAmount
        user.weeklyActivity.xpEarned.append(XPActivity(date: today, amount: finalAmount, source: source))
        recordActivity()

        // Trigger XP gain notification
        lastXPGain = finalAmount
        lastXPSource = source
        showXPGain = true

        // Check for level up
        let newLevelValue = user.currentLevel
        if newLevelValue > oldLevel {
            newLevel = newLevelValue
            // Slight delay to let XP animation show first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showLevelUp = true
            }
        }

        // Check badges and perks after XP change
        checkAndAwardBadges()
        checkAndUnlockPerks()
    }

    func completeLesson(_ lessonId: String) {
        guard !user.completedLessons.contains(lessonId) else { return }

        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        user.completedLessons.append(lessonId)
        user.weeklyActivity.lessonsCompleted.append(LessonActivity(lessonId: lessonId, date: today))

        // Update track progress
        for i in tracks.indices {
            if let lessonIndex = tracks[i].lessons.firstIndex(where: { $0.id == lessonId }) {
                tracks[i].lessons[lessonIndex].isCompleted = true
                tracks[i].completedLessons += 1
            }
        }

        // Award streak freeze every 5 lessons
        if user.completedLessons.count % 5 == 0 {
            earnStreakFreeze()
        }

        checkAndAwardBadges()
    }

    func recordActivity() {
        let today = SettingsManager.shared.currentLogicalDateString()
        let lastActive = user.lastActiveDate.prefix(10)

        guard lastActive != today else {
            if !user.activeDates.contains(today) {
                user.activeDates.append(today)
            }
            return
        }

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayStr = String(ISO8601DateFormatter().string(from: yesterday).prefix(10))

        if lastActive == yesterdayStr {
            user.streak += 1
        } else {
            // Check for auto-freeze
            if user.streakFreezes > 0 {
                user.streakFreezes -= 1
                user.freezeUsedDates.append(yesterdayStr)
                user.streak += 1
            } else {
                user.streak = 1
            }
        }

        user.longestStreak = max(user.longestStreak, user.streak)
        user.lastActiveDate = ISO8601DateFormatter().string(from: Date())

        if !user.activeDates.contains(today) {
            user.activeDates.append(today)
        }

        checkAndAwardBadges()
    }

    // MARK: - Streak Freezes

    /// Maximum streak freezes a user can hold
    private let maxStreakFreezes = 8
    /// Monthly free freezes
    private let monthlyFreezeAllowance = 4
    /// XP cost per purchased freeze
    let freezePurchaseCost = 100

    func useStreakFreeze() -> Bool {
        guard user.streakFreezes > 0 else { return false }
        user.streakFreezes -= 1
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        user.freezeUsedDates.append(today)
        return true
    }

    func earnStreakFreeze() {
        user.streakFreezes = min(user.streakFreezes + 1, maxStreakFreezes)
    }

    func purchaseStreakFreeze() -> Bool {
        guard user.xp >= freezePurchaseCost, user.streakFreezes < maxStreakFreezes else { return false }
        user.xp -= freezePurchaseCost
        user.streakFreezes += 1
        saveToLocalStorage()
        return true
    }

    /// Replenish freezes to 4 at the start of each month
    func checkMonthlyFreezeReplenish() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonth = formatter.string(from: Date())

        guard user.lastFreezeReplenishMonth != currentMonth else { return }

        // Top up to at least 4, but don't reduce if they have more
        user.streakFreezes = max(user.streakFreezes, monthlyFreezeAllowance)
        user.lastFreezeReplenishMonth = currentMonth
        saveToLocalStorage()
    }

    // MARK: - Memory Verses

    func getVersesForReview() -> [MemoryVerse] {
        let now = Date()
        return memoryVerses.filter { $0.nextReviewDate <= now }
    }

    func updateVerseReview(verseId: String, quality: Int) {
        guard let index = memoryVerses.firstIndex(where: { $0.id == verseId }) else { return }

        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        user.weeklyActivity.versesReviewed.append(VerseActivity(verseId: verseId, date: today))

        memoryVerses[index].updateReview(quality: quality)
    }

    func addMemoryVerse(_ verse: MemoryVerse) {
        guard !memoryVerses.contains(where: { $0.reference == verse.reference }) else { return }
        memoryVerses.append(verse)
        checkAndAwardBadges()
    }

    func removeMemoryVerse(_ verseId: String) {
        memoryVerses.removeAll { $0.id == verseId }
    }

    func markVerseAsMastered(_ verseId: String) {
        guard let index = memoryVerses.firstIndex(where: { $0.id == verseId }) else { return }
        memoryVerses[index].markAsMastered()
    }

    // MARK: - Bible Reading

    func markChapterRead(book: String, chapter: Int) -> Bool {
        let chapterKey = "\(book) \(chapter)"
        guard !user.chaptersRead.contains(chapterKey) else { return false }

        let today = SettingsManager.shared.currentLogicalDateString()
        user.chaptersRead.append(chapterKey)
        user.weeklyActivity.chaptersRead.append(ChapterActivity(chapter: chapterKey, date: today))
        addXP(15, source: "chapter")
        // Save immediately so progress survives force-quit (don't rely on debounce alone)
        saveToLocalStorage()
        return true
    }

    // MARK: - Badge & Perk System

    /// Merge new badges/perks into existing user data (preserves earned state)
    private func migrateBadgesAndPerks() {
        let allBadges = SampleData.badges
        let existingBadgeIds = Set(user.badges.map { $0.id })
        for badge in allBadges where !existingBadgeIds.contains(badge.id) {
            user.badges.append(badge)
        }

        let allPerks = SampleData.perks
        let existingPerkIds = Set(user.perks.map { $0.id })
        for perk in allPerks where !existingPerkIds.contains(perk.id) {
            user.perks.append(perk)
        }
    }

    /// Check all badge conditions and award any newly earned badges
    func checkAndAwardBadges() {
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        let chaptersCount = user.chaptersRead.count
        let verseCount = memoryVerses.count
        let streak = user.streak
        let xp = user.xp
        let lessonsCount = user.completedLessons.count
        let journalCount = user.weeklyActivity.reflectionsWritten.count

        // Check if any track is fully completed
        let hasCompletedTrack = tracks.contains { track in
            !track.lessons.isEmpty && track.lessons.allSatisfy { $0.isCompleted }
        }

        // Check if all 6 memory practice modes have been used
        let hasAllModes = memoryVerses.contains { verse in
            guard let stats = verse.modeStats else { return false }
            return stats.fillInBlank.attempts > 0 &&
                   stats.firstLetter.attempts > 0 &&
                   stats.typing.attempts > 0 &&
                   stats.flashcard.attempts > 0 &&
                   (stats.tapToReveal?.attempts ?? 0) > 0 &&
                   (stats.dragAndDrop?.attempts ?? 0) > 0
        }

        let conditions: [String: Bool] = [
            // Reading badges
            "first-chapter": chaptersCount >= 1,
            "chapters-10": chaptersCount >= 10,
            "chapters-50": chaptersCount >= 50,
            "chapters-100": chaptersCount >= 100,
            "chapters-500": chaptersCount >= 500,
            // Memory badges
            "first-verse": verseCount >= 1,
            "verses-5": verseCount >= 5,
            "verses-10": verseCount >= 10,
            "verses-25": verseCount >= 25,
            "perfect-review": false, // Tracked separately in review flow
            // Streak badges
            "streak-7": streak >= 7,
            "streak-14": streak >= 14,
            "streak-30": streak >= 30,
            "streak-100": streak >= 100,
            "streak-365": streak >= 365,
            // XP badges
            "xp-500": xp >= 500,
            "xp-5000": xp >= 5000,
            "xp-25000": xp >= 25000,
            // Lesson badges
            "first-lesson": lessonsCount >= 1,
            "lessons-10": lessonsCount >= 10,
            "track-complete": hasCompletedTrack,
            // Journal badges
            "first-journal": journalCount >= 1,
            "journals-10": journalCount >= 10,
            // Special
            "all-modes": hasAllModes,
        ]

        for (badgeId, met) in conditions {
            guard met else { continue }
            guard let index = user.badges.firstIndex(where: { $0.id == badgeId && !$0.isEarned }) else { continue }

            user.badges[index].isEarned = true
            user.badges[index].earnedDate = today

            // Trigger celebration (only show one at a time)
            if earnedBadge == nil {
                earnedBadge = user.badges[index]
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.showBadgeEarned = true
                }
            }
        }
    }

    /// Award the "perfect-review" badge (called from review flow when 5 easy in a row)
    func awardPerfectReviewBadge() {
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        guard let index = user.badges.firstIndex(where: { $0.id == "perfect-review" && !$0.isEarned }) else { return }
        user.badges[index].isEarned = true
        user.badges[index].earnedDate = today
        earnedBadge = user.badges[index]
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showBadgeEarned = true
        }
    }

    /// Check perk unlock conditions and unlock any newly eligible perks
    func checkAndUnlockPerks() {
        let level = user.currentLevel
        let streak = user.streak
        let xp = user.xp
        let earnedBadgeIds = Set(user.badges.filter { $0.isEarned }.map { $0.id })

        for i in user.perks.indices where !user.perks[i].isUnlocked {
            let met: Bool
            switch user.perks[i].unlockCondition {
            case .level(let required): met = level >= required
            case .streak(let required): met = streak >= required
            case .badge(let badgeId): met = earnedBadgeIds.contains(badgeId)
            case .xp(let required): met = xp >= required
            }
            if met {
                user.perks[i].isUnlocked = true
            }
        }
    }

    // MARK: - Account Deletion

    /// Delete all user data from CloudKit, clear local storage, and sign out.
    /// Local data is always cleared even if cloud deletion fails.
    /// Throws if cloud deletion failed (local reset still completed).
    func deleteAccount() async throws {
        // Cancel any pending sync to prevent race conditions
        syncDebounceTask?.cancel()

        // 1. Attempt to delete cloud data (non-fatal — local reset always happens)
        var cloudDeleteError: Error? = nil
        do {
            try await cloudKit.deleteAllData()
        } catch {
            cloudDeleteError = error
            print("⚠️ Failed to delete cloud data: \(error)")
        }

        // 2. Revoke Apple Sign In token (non-fatal if it fails)
        await appleSignIn.revokeToken()

        // 3. Always sign out (clears Keychain including refresh token)
        appleSignIn.signOut()

        // 4. Always clear all local data
        resetToFreshState()

        // 5. Clear additional UserDefaults keys
        UserDefaults.standard.removeObject(forKey: "reforged_daily_insight")
        UserDefaults.standard.removeObject(forKey: "reforged_last_sync")
        UserDefaults.standard.removeObject(forKey: "migration_v2_cloudkit_complete")

        // 6. If cloud delete failed, throw so UI can inform the user
        if let error = cloudDeleteError {
            throw error
        }
    }

    // MARK: - Reset

    func resetToFreshState() {
        user = .empty
        tracks = LearningTracks.allTracks
        memoryVerses = SampleData.memoryVerses
        BibleReadingState.shared.isSyncingFromCloud = true
        BibleReadingState.shared.highlights = [:]
        BibleReadingState.shared.notes = [:]
        BibleReadingState.shared.isSyncingFromCloud = false
        hasSyncedFromCloud = false
        saveToLocalStorage()
    }
}
