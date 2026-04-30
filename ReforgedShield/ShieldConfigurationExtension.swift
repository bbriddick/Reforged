import UIKit
import ManagedSettings
import ManagedSettingsUI

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - Colors

    private let navyBackground = UIColor(red: 0.06, green: 0.10, blue: 0.18, alpha: 1)
    private let navyButton     = UIColor(red: 0.15, green: 0.25, blue: 0.55, alpha: 1)
    private let lightGray      = UIColor(white: 0.75, alpha: 1)

    private let psalm = "\"I have stored up your word in my heart, that I might not sin against you.\"\n— Psalm 119:11"

    // MARK: - App Shield

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: navyBackground,
            icon: UIImage(named: "AppIcon"),
            title: ShieldConfiguration.Label(
                text: "Focused on What Matters",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: psalm,
                color: lightGray
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Go Back",
                color: .white
            ),
            primaryButtonBackgroundColor: navyButton
        )
    }

    // MARK: - Web Domain Shield

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: navyBackground,
            icon: UIImage(named: "AppIcon"),
            title: ShieldConfiguration.Label(
                text: "This Site is Blocked",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: psalm,
                color: lightGray
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Go Back",
                color: .white
            ),
            primaryButtonBackgroundColor: navyButton
        )
    }
}
