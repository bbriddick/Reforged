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

    // Throttle for the "you hit a block" notification (avoid spamming on repeated renders).
    private let notifThrottleKey = "lastBlockNotificationAt"
    private let notifThrottle: TimeInterval = 300 // 5 minutes

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
        "\"\(item.verseText)\"\n— \(item.verseReference)"
    }

    private func makeConfiguration(_ item: ShieldEncouragement) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: navyBackground,
            icon: UIImage(named: "AppIcon"),
            title: ShieldConfiguration.Label(
                text: item.suggestion,
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
            primaryButtonBackgroundColor: navyButton
        )
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

    // MARK: - App Shield

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let item = randomEncouragement()
        scheduleRefocusNotificationIfNeeded(item)
        return makeConfiguration(item)
    }

    // MARK: - Web Domain Shield

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        let item = randomEncouragement()
        scheduleRefocusNotificationIfNeeded(item)
        return makeConfiguration(item)
    }
}
