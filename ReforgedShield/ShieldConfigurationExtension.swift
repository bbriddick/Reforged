import UIKit
import ManagedSettings
import ManagedSettingsUI
import UserNotifications

// MARK: - Shared Encouragement Model
//
// Mirror of ShieldEncouragement in the main app (Reforged/Services/ShieldContentProvider.swift).
// The shield extension is a separate target and cannot import the app's types,
// so it decodes the same JSON shape with this local copy. Keep keys in sync.

private struct ShieldEncouragement: Codable {
    let suggestion: String
    let verseText: String
    let verseReference: String
}

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - Colors

    private let navyBackground = UIColor(red: 0.06, green: 0.10, blue: 0.18, alpha: 1)
    private let navyButton     = UIColor(red: 0.15, green: 0.25, blue: 0.55, alpha: 1)
    private let lightGray      = UIColor(white: 0.75, alpha: 1)

    private let appGroup = "group.com.reforged.app"
    private let payloadKey = "shieldEncouragements"

    // Set by UnlockGateService while the Scripture unlock gate is armed and unmet.
    // The extension can't tell which ManagedSettingsStore caused a given shield, so
    // this only says "a gate is pending", not "this shield is the gate's" — see
    // `titleText(for:)`.
    private let gatePendingKey = "unlockGatePending"

    // Throttle for the "you hit a block" notification (avoid spamming on repeated renders).
    private let notifThrottleKey = "lastBlockNotificationAt"
    private let notifThrottle: TimeInterval = 300 // 5 minutes

    // Shield-hit stats, shared with the main app's insights/streak features and
    // the ReforgedShieldAction extension. Keep key names in sync across targets.
    private let hitsByDayKey = "shieldHitsByDay"          // JSON [String: Int], "yyyy-MM-dd" keys
    private let lastHitAtKey = "shieldLastHitAt"          // Date, dedupes rapid re-renders
    private let cycleRequestedAtKey = "shieldCycleRequestedAt" // Date, set by the action extension
    private let hitDedupeWindow: TimeInterval = 10
    private let cycleGraceWindow: TimeInterval = 5
    private let hitRetentionDays = 60

    // Bundled fallback used when the shared store is empty/unavailable.
    private let fallback = ShieldEncouragement(
        suggestion: "Focused on What Matters",
        verseText: "I have stored up your word in my heart, that I might not sin against you.",
        verseReference: "Psalm 119:11"
    )

    // MARK: - Content

    /// Reads the cached encouragements from the shared App Group and returns a
    /// random one, falling back to the bundled default.
    private func randomEncouragement() -> ShieldEncouragement {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: payloadKey),
              let items = try? JSONDecoder().decode([ShieldEncouragement].self, from: data),
              let pick = items.randomElement() else {
            return fallback
        }
        return pick
    }

    private func subtitleText(for item: ShieldEncouragement) -> String {
        var text = "\"\(item.verseText)\"\n— \(item.verseReference)"
        if isGatePending {
            text += "\n\nRead a chapter or practice a memory verse in Reforged to unlock for today."
        }
        return text
    }

    /// True while the unlock gate is armed and today's requirement is unmet.
    private var isGatePending: Bool {
        UserDefaults(suiteName: appGroup)?.bool(forKey: gatePendingKey) ?? false
    }

    /// The gate's title names the way out. Every other block keeps the suggestion.
    private func titleText(for item: ShieldEncouragement) -> String {
        isGatePending ? "The Word Comes First" : item.suggestion
    }

    private func makeConfiguration(_ item: ShieldEncouragement) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: navyBackground,
            icon: UIImage(named: "AppIcon"),
            title: ShieldConfiguration.Label(
                text: titleText(for: item),
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitleText(for: item),
                color: lightGray
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Go Back",
                color: .white
            ),
            primaryButtonBackgroundColor: navyButton,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Another Verse",
                color: lightGray
            )
        )
    }

    // MARK: - Hit Logging

    /// Records one "temptation turned away" per shield encounter into the shared
    /// App Group, keyed by day. Two guards keep the count honest: rapid re-renders
    /// within 10 s are one encounter, and the re-render triggered by the action
    /// extension's "Another Verse" (.defer) must not double-count.
    private func recordShieldHit() {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        let now = Date()
        if let cycleAt = defaults.object(forKey: cycleRequestedAtKey) as? Date,
           now.timeIntervalSince(cycleAt) < cycleGraceWindow {
            return
        }
        if let last = defaults.object(forKey: lastHitAtKey) as? Date,
           now.timeIntervalSince(last) < hitDedupeWindow {
            return
        }
        defaults.set(now, forKey: lastHitAtKey)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let dayKey = formatter.string(from: now)

        var hits: [String: Int] = [:]
        if let data = defaults.data(forKey: hitsByDayKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            hits = decoded
        }
        hits[dayKey, default: 0] += 1

        // Prune beyond the retention window so the payload stays tiny.
        if let cutoffDate = Calendar.current.date(byAdding: .day, value: -hitRetentionDays, to: now) {
            let cutoff = formatter.string(from: cutoffDate)
            hits = hits.filter { $0.key >= cutoff }
        }
        if let encoded = try? JSONEncoder().encode(hits) {
            defaults.set(encoded, forKey: hitsByDayKey)
        }
    }

    // MARK: - Block Notification

    /// Fires a local notification when a block is shown so the user can open
    /// Reforged to a refocusing passage. Throttled via the shared App Group so
    /// repeated renders / rapid retries don't spam. The notification carries the
    /// same verse shown on the shield; tapping it deep-links to the passage.
    private func scheduleRefocusNotificationIfNeeded(_ item: ShieldEncouragement) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        if let last = defaults.object(forKey: notifThrottleKey) as? Date,
           Date().timeIntervalSince(last) < notifThrottle {
            return
        }
        defaults.set(Date(), forKey: notifThrottleKey)

        let content = UNMutableNotificationContent()
        content.title = "Pause and refocus"
        content.body = "\"\(item.verseText)\"\n— \(item.verseReference)"
        content.sound = .default
        content.userInfo = [
            "action": "refocus",
            "verseText": item.verseText,
            "verseReference": item.verseReference,
            "suggestion": item.suggestion
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "reforged.refocus.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Shield Overloads

    /// Shared render path for every shield surface.
    private func brandedConfiguration() -> ShieldConfiguration {
        let item = randomEncouragement()
        recordShieldHit()
        scheduleRefocusNotificationIfNeeded(item)
        return makeConfiguration(item)
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        brandedConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        brandedConfiguration()
    }

    // Category-token blocks route through these overloads; without them the
    // system shows its default gray shield instead of the branded verse overlay.
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        brandedConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        brandedConfiguration()
    }
}
