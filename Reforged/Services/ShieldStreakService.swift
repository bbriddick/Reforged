import SwiftUI
import UserNotifications

// MARK: - Shield Streak Service
//
// "Protected days": a calendar day counts when (a) some shield protection was
// on for the whole day (`protectionEnabledSince` ≤ start of day) and (b) no
// tamper event was recorded that day. The streak is consecutive protected days
// ending YESTERDAY — today shows as "in progress" until it completes.
//
// `protectionEnabledSince` is stamped when any protection turns on and cleared
// when all protection is off (maintained by FocusBlockingService callers via
// `noteProtectionChanged`). Milestones fire once per streak run.

enum ShieldStreakKeys {
    static let suite              = "group.com.reforged.app"
    static let enabledSince       = "shieldProtectionEnabledSince"
    static let bestStreak         = "shieldBestStreak"
    static let milestonesNotified = "shieldMilestonesNotified"
    static let milestones         = [7, 30, 90]
}

@MainActor
final class ShieldStreakService: ObservableObject {

    static let shared = ShieldStreakService()

    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var bestStreak: Int = 0
    /// Whether today is on track to extend the streak.
    @Published private(set) var todayInProgress: Bool = false

    private let defaults = UserDefaults(suiteName: ShieldStreakKeys.suite)
    private let calendar = Calendar.current

    private init() {
        bestStreak = defaults?.integer(forKey: ShieldStreakKeys.bestStreak) ?? 0
        recompute()
    }

    /// Recomputes whether ANY protection is active (always-on blocks, daily
    /// limit, or an enabled schedule) and updates the anchor. Call after any
    /// protection toggle and on app foreground.
    func refreshProtectionState() {
        let anyActive = FocusBlockingService.shared.isAnyBlockingActive
            || SocialLimitService.shared.isEnabled
            || UnlockGateService.shared.isEnabled
            || ScheduledBlockingService.shared.schedules.contains { $0.isEnabled && $0.hasSelection }
        noteProtectionChanged(anyActive: anyActive)
    }

    /// Call whenever protection turns on/off so the "since" anchor stays honest.
    /// Turning protection on when it was off starts the clock; turning the last
    /// protection off clears it (and the streak dies at the next recompute).
    func noteProtectionChanged(anyActive: Bool) {
        let since = defaults?.object(forKey: ShieldStreakKeys.enabledSince) as? Date
        if anyActive && since == nil {
            defaults?.set(Date(), forKey: ShieldStreakKeys.enabledSince)
        } else if !anyActive && since != nil {
            defaults?.removeObject(forKey: ShieldStreakKeys.enabledSince)
            // A fresh enable starts a fresh streak run — allow milestones again.
            defaults?.removeObject(forKey: ShieldStreakKeys.milestonesNotified)
        }
        recompute()
    }

    /// Recomputes the streak from the anchor + tamper log. Cheap; call on
    /// foreground and after any tamper event.
    func recompute() {
        guard let since = defaults?.object(forKey: ShieldStreakKeys.enabledSince) as? Date else {
            currentStreak = 0
            todayInProgress = false
            return
        }

        let startOfToday = calendar.startOfDay(for: Date())
        var streak = 0
        var day = calendar.date(byAdding: .day, value: -1, to: startOfToday)!

        // Walk backwards from yesterday while each day was fully protected and
        // tamper-free. The tamper log holds ≤200 events, so this stays cheap.
        while calendar.startOfDay(for: since) <= day,
              AccountabilityPartnerService.shared.events(on: day).isEmpty {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        currentStreak = streak
        todayInProgress = AccountabilityPartnerService.shared.events(on: startOfToday).isEmpty

        if streak > bestStreak {
            bestStreak = streak
            defaults?.set(streak, forKey: ShieldStreakKeys.bestStreak)
        }

        notifyMilestonesIfNeeded()
    }

    // MARK: - Milestones

    private func notifyMilestonesIfNeeded() {
        var notified = Set(defaults?.array(forKey: ShieldStreakKeys.milestonesNotified) as? [Int] ?? [])
        for milestone in ShieldStreakKeys.milestones where currentStreak >= milestone && !notified.contains(milestone) {
            notified.insert(milestone)
            scheduleMilestoneNotification(days: milestone)
        }
        defaults?.set(Array(notified), forKey: ShieldStreakKeys.milestonesNotified)
    }

    private func scheduleMilestoneNotification(days: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(days) protected days 🎉"
        content.body = "Your shield has stood for \(days) straight days. \"He who began a good work in you will bring it to completion.\" — Philippians 1:6"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "reforged.shieldstreak.\(days)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
