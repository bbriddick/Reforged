import Foundation

// MARK: - ReadingPlanService

@MainActor
final class ReadingPlanService: ObservableObject {
    static let shared = ReadingPlanService()

    // planId → set of completed day numbers
    @Published private(set) var completedDaysMap: [String: Set<Int>] = [:]
    @Published private(set) var startDates: [String: Date] = [:]

    /// Fast lookup set mirroring ReadingStreakManager's chapter-read history.
    /// Keys are "BookName Chapter" strings (e.g. "Genesis 1", "John 3").
    private var readChapters: Set<String> = []

    private let kCompletedDays          = "reforged.readingPlans.completedDays"
    private let kStartDates             = "reforged.readingPlans.startDates"
    private let kStreakChaptersByDate   = "reforged_chapters_read_by_date"   // ReadingStreakManager key

    private init() { load() }

    // MARK: - Query

    func completedDays(for planId: String) -> Set<Int> {
        completedDaysMap[planId] ?? []
    }

    func isDayComplete(_ day: Int, planId: String) -> Bool {
        completedDaysMap[planId]?.contains(day) ?? false
    }

    /// The next unread day (1-based). Returns totalDays when the plan is finished.
    func currentDay(for planId: String) -> Int {
        let completed = completedDaysMap[planId] ?? []
        guard !completed.isEmpty else { return 1 }
        let total = BibleReadingPlans.all.first(where: { $0.id == planId })?.totalDays ?? Int.max
        return min((completed.max() ?? 0) + 1, total)
    }

    /// 0.0 … 1.0 completion ratio.
    func progress(for planId: String) -> Double {
        guard let plan = BibleReadingPlans.all.first(where: { $0.id == planId }),
              plan.totalDays > 0 else { return 0 }
        return Double(completedDaysMap[planId]?.count ?? 0) / Double(plan.totalDays)
    }

    func hasStarted(_ planId: String) -> Bool {
        !(completedDaysMap[planId]?.isEmpty ?? true)
    }

    func isComplete(_ planId: String) -> Bool {
        guard let plan = BibleReadingPlans.all.first(where: { $0.id == planId }) else { return false }
        return (completedDaysMap[planId]?.count ?? 0) >= plan.totalDays
    }

    // MARK: - Active plan
    //
    // Home's "Due Today" row and the hero suggestion both need to agree on what
    // the plan is asking for right now, so the answer lives here rather than
    // being derived separately in each view.

    /// First plan that has been started but not yet finished.
    var activePlan: BibleReadingPlan? {
        BibleReadingPlans.all.first { hasStarted($0.id) && !isComplete($0.id) }
    }

    /// The entry the active plan is currently on. Note this is the next UNREAD day
    /// (see `currentDay`), not a day derived from the calendar — the plan is a
    /// self-paced queue, so there is always a next entry until the plan is finished.
    /// Don't read "is the user done today?" off this; ask ReadingStreakManager.
    var activeEntry: BiblePlanEntry? {
        guard let plan = activePlan else { return nil }
        return plan.entries.first { $0.day == currentDay(for: plan.id) }
    }

    // MARK: - Mutations

    func markDayComplete(_ day: Int, planId: String) {
        if completedDaysMap[planId] == nil {
            completedDaysMap[planId] = []
            startDates[planId] = Date()
        }
        let isNewlyComplete = completedDaysMap[planId]?.insert(day).inserted ?? false
        save()

        // Finishing a plan day is Bible reading, whether it happened via the Bible
        // view or by ticking the checkmark in the plan. Routing it through the
        // streak manager is also what writes the App Group and reloads the widget —
        // this service's own `save()` only touches UserDefaults.standard, so the
        // checkmark path used to leave both the streak and the widget untouched.
        // recordActivity is idempotent within a day, so the Bible-view path (which
        // already recorded) stays a no-op here.
        if isNewlyComplete {
            ReadingStreakManager.shared.recordActivity(.reading)
        }
    }

    func toggleDay(_ day: Int, planId: String) {
        if isDayComplete(day, planId: planId) {
            completedDaysMap[planId]?.remove(day)
            if completedDaysMap[planId]?.isEmpty == true {
                completedDaysMap.removeValue(forKey: planId)
                startDates.removeValue(forKey: planId)
            }
        } else {
            markDayComplete(day, planId: planId)
        }
        save()
    }

    func resetPlan(_ planId: String) {
        completedDaysMap.removeValue(forKey: planId)
        startDates.removeValue(forKey: planId)
        save()
    }

    // MARK: - Auto-completion (called by BibleView.markChapterAsRead)

    /// Called every time the user marks a chapter as read in the Bible view.
    /// Checks whether any active plan day now has all its chapters read, and if so
    /// auto-marks it complete — continuing the plan streak automatically.
    func notifyChapterRead(bookName: String, chapter: Int) {
        let key = "\(bookName) \(chapter)"
        readChapters.insert(key)

        for plan in BibleReadingPlans.all {
            guard !isComplete(plan.id) else { continue }
            let completed = completedDaysMap[plan.id] ?? []

            for entry in plan.entries {
                guard !completed.contains(entry.day), !entry.isReflectionDay else { continue }
                let required = entry.requiredChapters
                guard !required.isEmpty else { continue }   // verse-range entries: manual only

                if required.allSatisfy({ readChapters.contains("\($0.book) \($0.chapter)") }) {
                    markDayComplete(entry.day, planId: plan.id)
                }
            }
        }
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: kCompletedDays),
           let decoded = try? JSONDecoder().decode([String: [Int]].self, from: data) {
            completedDaysMap = decoded.mapValues { Set($0) }
        }
        if let data = UserDefaults.standard.data(forKey: kStartDates),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            startDates = decoded
        }
        // Hydrate readChapters from ReadingStreakManager's persisted history so that
        // chapters read before this session are still counted towards auto-completion.
        if let data = UserDefaults.standard.data(forKey: kStreakChaptersByDate),
           let dict = try? JSONDecoder().decode([String: [String]].self, from: data) {
            readChapters = Set(dict.values.flatMap { $0 })
        }
    }

    private func save() {
        let flat = completedDaysMap.mapValues { Array($0) }
        if let data = try? JSONEncoder().encode(flat) {
            UserDefaults.standard.set(data, forKey: kCompletedDays)
        }
        if let data = try? JSONEncoder().encode(startDates) {
            UserDefaults.standard.set(data, forKey: kStartDates)
        }
    }
}
