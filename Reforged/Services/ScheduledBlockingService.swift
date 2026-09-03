import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

// MARK: - Scheduled Blocking Service
//
// Time-window blocking ("Bedtime", "Morning devotion"): the user defines up to
// 5 windows, each with its own app selection and active weekdays. Each window
// gets its own DeviceActivity ("schedule_<uuid>", daily repeating — iOS handles
// overnight wrap) and its own ManagedSettingsStore ("reforged-schedule-<uuid>")
// so overlapping windows end independently.
//
// The monitor extension applies/clears the store at interval start/end, with
// the weekday check done there (one activity per schedule, not per weekday —
// Apple caps concurrent activities around 20). `reconcileNow()` is the backstop
// for reboots, missed callbacks, and mid-window edits: called on app foreground,
// it recomputes "inside window now?" and applies/clears stores directly.
//
// NOTE: keep the App Group keys below in sync with the monitor extension.

struct BlockSchedule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String = "Bedtime"
    var startHour: Int = 21
    var startMinute: Int = 0
    var endHour: Int = 6
    var endMinute: Int = 0
    /// Calendar weekdays (1 = Sunday … 7 = Saturday) on which the window STARTS.
    var weekdays: Set<Int> = Set(1...7)
    var selectionData: Data = Data()
    var isEnabled: Bool = true

    var selection: FamilyActivitySelection {
        (try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData)) ?? FamilyActivitySelection()
    }

    var hasSelection: Bool {
        let sel = selection
        return !sel.applicationTokens.isEmpty || !sel.categoryTokens.isEmpty || !sel.webDomainTokens.isEmpty
    }

    var startMinutesSinceMidnight: Int { startHour * 60 + startMinute }
    var endMinutesSinceMidnight: Int { endHour * 60 + endMinute }
    /// Overnight windows (e.g. 21:00 → 06:00) end on the following day.
    var isOvernight: Bool { endMinutesSinceMidnight <= startMinutesSinceMidnight }

    /// Whether the window is live at `date`, considering enabled state, the
    /// weekday the window started on, and overnight wrap.
    func isActive(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard isEnabled, hasSelection else { return false }
        let nowMinutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let weekday = calendar.component(.weekday, from: date)
        if !isOvernight {
            return weekdays.contains(weekday)
                && nowMinutes >= startMinutesSinceMidnight
                && nowMinutes < endMinutesSinceMidnight
        }
        // Overnight: the evening half belongs to today's weekday, the morning
        // half to yesterday's (the day the window started).
        if nowMinutes >= startMinutesSinceMidnight {
            return weekdays.contains(weekday)
        }
        if nowMinutes < endMinutesSinceMidnight {
            let yesterday = weekday == 1 ? 7 : weekday - 1
            return weekdays.contains(yesterday)
        }
        return false
    }
}

enum ScheduledBlockingKeys {
    static let suite         = "group.com.reforged.app"
    static let schedulesData = "blockSchedulesData"
    static let activeIds     = "scheduleActiveIds"
    /// Per-schedule armed-config signature: "scheduleMonitorConfig_<uuid>".
    static func monitorConfig(_ id: UUID) -> String { "scheduleMonitorConfig_\(id.uuidString)" }
    static func storeName(_ id: UUID) -> String { "reforged-schedule-\(id.uuidString)" }
    static func activityName(_ id: UUID) -> String { "schedule_\(id.uuidString)" }

    static let maxSchedules = 5
    static let minWindowMinutes = 15
}

@MainActor
final class ScheduledBlockingService: ObservableObject {

    static let shared = ScheduledBlockingService()

    @Published private(set) var schedules: [BlockSchedule] = []
    /// Ids of schedules whose window is live right now (drives "Active" badges).
    @Published private(set) var activeIds: Set<UUID> = []

    private let defaults = UserDefaults(suiteName: ScheduledBlockingKeys.suite)
    private let center = DeviceActivityCenter()

    private init() {
        loadSchedules()
    }

    var canAddSchedule: Bool { schedules.count < ScheduledBlockingKeys.maxSchedules }

    // MARK: - CRUD

    func save(_ schedule: BlockSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
        } else {
            guard canAddSchedule else { return }
            schedules.append(schedule)
        }
        persistSchedules()
        arm(schedule)
        reconcileNow()
    }

    func delete(id: UUID) {
        guard let schedule = schedules.first(where: { $0.id == id }) else { return }
        disarm(schedule)
        schedules.removeAll { $0.id == id }
        persistSchedules()
        reconcileNow()
    }

    func setEnabled(_ enabled: Bool, id: UUID) {
        guard var schedule = schedules.first(where: { $0.id == id }) else { return }
        schedule.isEnabled = enabled
        if let index = schedules.firstIndex(where: { $0.id == id }) {
            schedules[index] = schedule
        }
        persistSchedules()
        if enabled {
            arm(schedule)
        } else {
            disarm(schedule)
        }
        reconcileNow()
    }

    // MARK: - Reconciliation

    /// Recomputes each schedule's live state and applies/clears its store
    /// directly. The DeviceActivity callbacks remain the primary mechanism;
    /// this is the foreground backstop for reboots, missed callbacks, and edits
    /// made mid-window. Also re-arms any enabled schedule whose monitoring got
    /// dropped (e.g. after the user revoked and re-granted authorization).
    func reconcileNow() {
        let now = Date()
        var live: Set<UUID> = []
        let running = Set(center.activities.map(\.rawValue))

        for schedule in schedules {
            let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(ScheduledBlockingKeys.storeName(schedule.id)))
            if schedule.isActive(at: now) {
                live.insert(schedule.id)
                applyShield(schedule.selection, to: store)
            } else {
                clearShield(store)
            }
            if schedule.isEnabled, schedule.hasSelection,
               !running.contains(ScheduledBlockingKeys.activityName(schedule.id)) {
                arm(schedule)
            }
        }

        activeIds = live
        defaults?.set(live.map(\.uuidString), forKey: ScheduledBlockingKeys.activeIds)
    }

    // MARK: - DeviceActivity

    private func signature(for schedule: BlockSchedule) -> String {
        "\(schedule.startHour):\(schedule.startMinute)|\(schedule.endHour):\(schedule.endMinute)|"
        + "\(schedule.weekdays.sorted().map(String.init).joined(separator: ","))|"
        + schedule.selectionData.base64EncodedString()
    }

    private func arm(_ schedule: BlockSchedule) {
        guard schedule.isEnabled, schedule.hasSelection else {
            disarm(schedule)
            return
        }

        let activity = DeviceActivityName(ScheduledBlockingKeys.activityName(schedule.id))
        let configKey = ScheduledBlockingKeys.monitorConfig(schedule.id)
        let sig = signature(for: schedule)

        // Restart churn makes DeviceActivity fire spurious callbacks — skip the
        // re-arm entirely when the armed config is unchanged (same guard as the
        // social daily limit).
        if center.activities.contains(activity), defaults?.string(forKey: configKey) == sig {
            return
        }

        let deviceSchedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: schedule.startHour, minute: schedule.startMinute),
            intervalEnd: DateComponents(hour: schedule.endHour, minute: schedule.endMinute),
            repeats: true
        )

        do {
            center.stopMonitoring([activity])
            try center.startMonitoring(activity, during: deviceSchedule)
            defaults?.set(sig, forKey: configKey)
        } catch {
            debugLog("[ScheduledBlocking] startMonitoring failed for \(schedule.label): \(error.localizedDescription)")
        }
    }

    private func disarm(_ schedule: BlockSchedule) {
        center.stopMonitoring([DeviceActivityName(ScheduledBlockingKeys.activityName(schedule.id))])
        defaults?.removeObject(forKey: ScheduledBlockingKeys.monitorConfig(schedule.id))
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(ScheduledBlockingKeys.storeName(schedule.id)))
        clearShield(store)
    }

    // MARK: - Shield Helpers

    private func applyShield(_ selection: FamilyActivitySelection, to store: ManagedSettingsStore) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    private func clearShield(_ store: ManagedSettingsStore) {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    // MARK: - Persistence

    private func persistSchedules() {
        if let data = try? JSONEncoder().encode(schedules) {
            defaults?.set(data, forKey: ScheduledBlockingKeys.schedulesData)
        }
        ShieldStreakService.shared.refreshProtectionState()
    }

    private func loadSchedules() {
        if let data = defaults?.data(forKey: ScheduledBlockingKeys.schedulesData),
           let decoded = try? JSONDecoder().decode([BlockSchedule].self, from: data) {
            schedules = decoded
        }
        let storedActive = defaults?.stringArray(forKey: ScheduledBlockingKeys.activeIds) ?? []
        activeIds = Set(storedActive.compactMap(UUID.init))
    }
}
