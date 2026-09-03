import Foundation
import ManagedSettings

// MARK: - Shield Action Extension
//
// Handles taps on the shield overlay's buttons. This runs in its own process,
// sandboxed like the configuration extension: no network, no way to open the
// main app. It communicates through the shared App Group.
//
//   Primary "Go Back"        → close the shield (return to Home Screen).
//   Secondary "Another Verse" → stamp a cycle request in the App Group and
//                               defer, which re-invokes the configuration
//                               extension and renders a fresh random verse.
//
// Keep App Group key names in sync with ShieldConfigurationExtension.swift.

class ShieldActionExtension: ShieldActionDelegate {

    private let appGroup = "group.com.reforged.app"
    private let cycleNonceKey = "shieldCycleNonce"
    private let cycleRequestedAtKey = "shieldCycleRequestedAt"

    private func handleShared(action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            if let defaults = UserDefaults(suiteName: appGroup) {
                defaults.set(UUID().uuidString, forKey: cycleNonceKey)
                defaults.set(Date(), forKey: cycleRequestedAtKey)
            }
            completionHandler(.defer)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleShared(action: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleShared(action: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleShared(action: action, completionHandler: completionHandler)
    }
}
