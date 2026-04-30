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

    // MARK: - Mutations

    func markDayComplete(_ day: Int, planId: String) {
        if completedDaysMap[planId] == nil {
            completedDaysMap[planId] = []
            startDates[planId] = Date()
        }
        completedDaysMap[planId]?.insert(day)
        save()
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
