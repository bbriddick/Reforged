import UIKit
import ManagedSettings
import ManagedSettingsUI

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

    // MARK: - App Shield

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(randomEncouragement())
    }

    // MARK: - Web Domain Shield

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(randomEncouragement())
    }
}
