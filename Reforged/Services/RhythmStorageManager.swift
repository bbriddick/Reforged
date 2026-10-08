import Foundation

/// Stores the member's self-built daily rhythm: the checklist items and each
/// day's completion.
///
/// UserDefaults-backed (Codable JSON), mirroring the app's other lightweight
/// stores. Completion is keyed by `ReadingStreakManager.currentDayKey` so the
/// checklist turns over with the user's local day (never UTC). Any change to the
/// items re-syncs the item reminders through `NotificationManager` so scheduled
/// notifications always match what the user sees.
@MainActor
final class RhythmStorageManager: ObservableObject {
    static let shared = RhythmStorageManager()

    private let userDefaults = UserDefaults.standard
    private let itemsKey = "reforged_rhythm_items"
    private let completionKey = "reforged_rhythm_completion"

    /// All checklist items, sorted for display.
    @Published private(set) var items: [RhythmItem] = []
    /// Completed item ids per local day key.
    @Published private(set) var completionByDay: [String: Set<String>] = [:]

    private init() {
        load()
    }

    // MARK: - Day helpers

    var todayKey: String { ReadingStreakManager.shared.currentDayKey }
    private var todayWeekday: Int { Calendar.current.component(.weekday, from: Date()) }

    // MARK: - Queries

    /// Items that should appear on today's checklist (active on today's weekday),
    /// in display order.
    var itemsDueToday: [RhythmItem] {
        let weekday = todayWeekday
        return items.filter { $0.isActive(on: weekday) }
    }

    func isCompletedToday(_ itemId: String) -> Bool {
        completionByDay[todayKey]?.contains(itemId) ?? false
    }

    var todayCompletedCount: Int {
        let done = completionByDay[todayKey] ?? []
        return itemsDueToday.filter { done.contains($0.id) }.count
    }

    var todayDueCount: Int { itemsDueToday.count }

    var todayProgress: Double {
        todayDueCount == 0 ? 0 : Double(todayCompletedCount) / Double(todayDueCount)
    }

    // MARK: - Mutations

    func upsert(_ item: RhythmItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        } else {
            var new = item
            new.sortOrder = (items.map(\.sortOrder).max() ?? -1) + 1
            items.append(new)
        }
        sortItems()
        persistItems()
        syncReminders()
    }

    func delete(_ item: RhythmItem) {
        items.removeAll { $0.id == item.id }
        // Drop it from any day's completion set so counts stay honest.
        for key in completionByDay.keys {
            completionByDay[key]?.remove(item.id)
        }
        persistItems()
        persistCompletion()
        syncReminders()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        for (idx, _) in items.enumerated() { items[idx].sortOrder = idx }
        persistItems()
    }

    /// Toggle today's completion for an item.
    func toggleToday(_ itemId: String) {
        var todaySet = completionByDay[todayKey] ?? []
        if todaySet.contains(itemId) {
            todaySet.remove(itemId)
        } else {
            todaySet.insert(itemId)
        }
        completionByDay[todayKey] = todaySet
        persistCompletion()
    }

    func deleteAll() {
        items = []
        completionByDay = [:]
        userDefaults.removeObject(forKey: itemsKey)
        userDefaults.removeObject(forKey: completionKey)
        syncReminders()
    }

    // MARK: - Reminders

    /// Push the current item set to the notification scheduler. Called after every
    /// change; the scheduler owns removing stale "rhythm-" requests.
    func syncReminders() {
        NotificationManager.shared.scheduleRhythmReminders(items)
    }

    // MARK: - Persistence

    private func sortItems() {
        items.sort { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    private func load() {
        if let data = userDefaults.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([RhythmItem].self, from: data) {
            items = decoded
            sortItems()
        }
        if let data = userDefaults.data(forKey: completionKey),
           let decoded = try? JSONDecoder().decode([String: Set<String>].self, from: data) {
            completionByDay = decoded
        }
    }

    private func persistItems() {
        if let data = try? JSONEncoder().encode(items) {
            userDefaults.set(data, forKey: itemsKey)
        }
    }

    private func persistCompletion() {
        if let data = try? JSONEncoder().encode(completionByDay) {
            userDefaults.set(data, forKey: completionKey)
        }
    }
}
