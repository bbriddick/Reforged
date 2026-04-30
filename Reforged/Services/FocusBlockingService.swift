import SwiftUI

// MARK: - Focus Blocking Service (Stub — blocking pending entitlement approval)
//
// The full Screen Time blocking implementation is commented out below.
// To re-enable:
//   1. Add com.apple.developer.family-controls to Reforged/Reforged.entitlements
//   2. Restore FocusBlockingView.swift to the full blocking UI
//   3. Add ReforgedShield extension back to the Embed Foundation Extensions build phase
//   4. Uncomment everything below and remove this stub
//
// Apply for the Family Controls distribution entitlement at:
//   https://developer.apple.com/contact/request/family-controls-distribution

@MainActor
final class FocusBlockingService: ObservableObject {

    static let shared = FocusBlockingService()

    // Stub published state — kept so DiscipleshipView card compiles unchanged
    @Published var isAuthorized: Bool = false
    @Published var blockNSFW: Bool = false
    @Published var blockSocialMedia: Bool = false

    var isAnyBlockingActive: Bool { false }
    var selectedAppCount: Int { 0 }
    var statusDescription: String { "Coming soon" }

    private init() {}

    func applyBlockingIfEnabled() {
        // No-op until family-controls entitlement is approved
    }
}

// =============================================================================
// MARK: - FULL IMPLEMENTATION (uncomment when family-controls entitlement approved)
// =============================================================================
//
// import FamilyControls
// import ManagedSettings
//
// @MainActor
// final class FocusBlockingService: ObservableObject {
//
//     static let shared = FocusBlockingService()
//
//     // MARK: - Published State
//
//     @Published var isAuthorized: Bool = false
//     @Published var blockNSFW: Bool = false
//     @Published var blockSocialMedia: Bool = false
//     @Published var selection: FamilyActivitySelection = FamilyActivitySelection()
//
//     // MARK: - Private
//
//     private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("reforged-shield"))
//
//     private enum Keys {
//         static let blockNSFW        = "focusBlockNSFW"
//         static let blockSocialMedia = "focusBlockSocialMedia"
//         static let selectionData    = "focusSelectionData"
//     }
//
//     // MARK: - Domain Lists
//
//     static let nsfwDomains: Set<WebDomain> = Set([
//         "pornhub.com", "xvideos.com", "xnxx.com", "redtube.com", "youporn.com",
//         "xhamster.com", "brazzers.com", "onlyfans.com", "chaturbate.com", "livejasmin.com",
//         "stripchat.com", "myfreecams.com", "bongacams.com", "cam4.com", "camsoda.com",
//         "slutload.com", "drtuber.com", "tube8.com", "rule34.xxx", "gelbooru.com",
//         "nhentai.net", "xart.com", "nubiles.net", "bangbros.com", "realitykings.com"
//     ].map { WebDomain(domain: $0) })
//
//     static let socialMediaDomains: Set<WebDomain> = Set([
//         "facebook.com", "instagram.com", "tiktok.com", "twitter.com", "x.com",
//         "snapchat.com", "reddit.com", "tumblr.com", "discord.com", "pinterest.com",
//         "bereal.com", "threads.net", "youtube.com", "twitch.tv", "linkedin.com"
//     ].map { WebDomain(domain: $0) })
//
//     // MARK: - Init
//
//     private init() {
//         loadPersistedState()
//         checkAuthorizationStatus()
//     }
//
//     // MARK: - Authorization
//
//     private func checkAuthorizationStatus() {
//         isAuthorized = (AuthorizationCenter.shared.authorizationStatus == .approved)
//     }
//
//     func requestAuthorization() async {
//         do {
//             try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
//             isAuthorized = (AuthorizationCenter.shared.authorizationStatus == .approved)
//         } catch {
//             isAuthorized = false
//             print("[FocusBlockingService] Authorization failed: \(error.localizedDescription)")
//         }
//     }
//
//     // MARK: - Blocking
//
//     func applyBlockingIfEnabled() {
//         guard isAuthorized else { return }
//         applyBlocking()
//     }
//
//     private func applyBlocking() {
//         var blockedDomains = Set<WebDomain>()
//         if blockNSFW         { blockedDomains.formUnion(FocusBlockingService.nsfwDomains) }
//         if blockSocialMedia  { blockedDomains.formUnion(FocusBlockingService.socialMediaDomains) }
//
//         store.webContent.blockedByFilter = blockedDomains.isEmpty ? nil : .specific(blockedDomains)
//
//         let appTokens = selection.applicationTokens
//         store.shield.applications = appTokens.isEmpty ? nil : appTokens
//
//         let webTokens = selection.webDomainTokens
//         store.shield.webDomains = webTokens.isEmpty ? nil : webTokens
//     }
//
//     // MARK: - Setters
//
//     func setBlockNSFW(_ enabled: Bool) async {
//         if enabled && !isAuthorized {
//             await requestAuthorization()
//             guard isAuthorized else { return }
//         }
//         blockNSFW = enabled
//         persistState()
//         applyBlocking()
//     }
//
//     func setBlockSocialMedia(_ enabled: Bool) async {
//         if enabled && !isAuthorized {
//             await requestAuthorization()
//             guard isAuthorized else { return }
//         }
//         blockSocialMedia = enabled
//         persistState()
//         applyBlocking()
//     }
//
//     func updateSelection(_ newSelection: FamilyActivitySelection) {
//         selection = newSelection
//         persistState()
//         if isAuthorized { applyBlocking() }
//     }
//
//     // MARK: - Convenience
//
//     var isAnyBlockingActive: Bool {
//         blockNSFW || blockSocialMedia
//         || !selection.applicationTokens.isEmpty
//         || !selection.webDomainTokens.isEmpty
//     }
//
//     var selectedAppCount: Int { selection.applicationTokens.count }
//
//     var statusDescription: String {
//         guard isAnyBlockingActive else { return "No content blocked" }
//         var parts: [String] = []
//         if blockNSFW         { parts.append("Adult content") }
//         if blockSocialMedia  { parts.append("Social media") }
//         let count = selectedAppCount
//         if count > 0         { parts.append("\(count) app\(count == 1 ? "" : "s")") }
//         return parts.joined(separator: " · ") + " blocked"
//     }
//
//     // MARK: - Persistence
//
//     func persistState() {
//         let defaults = UserDefaults.standard
//         defaults.set(blockNSFW,        forKey: Keys.blockNSFW)
//         defaults.set(blockSocialMedia, forKey: Keys.blockSocialMedia)
//         if let encoded = try? JSONEncoder().encode(selection) {
//             defaults.set(encoded, forKey: Keys.selectionData)
//         }
//     }
//
//     private func loadPersistedState() {
//         let defaults = UserDefaults.standard
//         blockNSFW        = defaults.bool(forKey: Keys.blockNSFW)
//         blockSocialMedia = defaults.bool(forKey: Keys.blockSocialMedia)
//         if let data = defaults.data(forKey: Keys.selectionData),
//            let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
//             selection = decoded
//         }
//     }
// }
