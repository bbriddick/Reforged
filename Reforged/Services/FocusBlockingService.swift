import SwiftUI
import FamilyControls
import ManagedSettings

// MARK: - Focus Blocking Service
//
// Screen Time content blocking via Apple's FamilyControls + ManagedSettings.
// Requires the com.apple.developer.family-controls entitlement (approved) on
// both the main app and the ReforgedShield extension. Authorization and shield
// enforcement only function on a physical device — not the iOS Simulator.

@MainActor
final class FocusBlockingService: ObservableObject {

    static let shared = FocusBlockingService()

    // MARK: - Published State

    @Published var isAuthorized: Bool = false
    @Published var blockNSFW: Bool = false
    @Published var blockSocialMedia: Bool = false
    /// Apps/categories the user picked under "Block Specific Apps".
    @Published var selection: FamilyActivitySelection = FamilyActivitySelection()
    /// Apps/categories the user picked for social-media blocking (typically the
    /// Social Networking category). Apple gives no programmatic category token,
    /// so this must come from the FamilyActivityPicker.
    @Published var socialSelection: FamilyActivitySelection = FamilyActivitySelection()

    // MARK: - Private

    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("reforged-shield"))

    private enum Keys {
        static let blockNSFW          = "focusBlockNSFW"
        static let blockSocialMedia   = "focusBlockSocialMedia"
        static let selectionData      = "focusSelectionData"
        static let socialSelectionData = "focusSocialSelectionData"
    }

    // MARK: - Domain Lists

    static let nsfwDomains: Set<WebDomain> = Set([
        "pornhub.com", "xvideos.com", "xnxx.com", "redtube.com", "youporn.com",
        "xhamster.com", "brazzers.com", "onlyfans.com", "chaturbate.com", "livejasmin.com",
        "stripchat.com", "myfreecams.com", "bongacams.com", "cam4.com", "camsoda.com",
        "slutload.com", "drtuber.com", "tube8.com", "rule34.xxx", "gelbooru.com",
        "nhentai.net", "xart.com", "nubiles.net", "bangbros.com", "realitykings.com"
    ].map { WebDomain(domain: $0) })

    static let socialMediaDomains: Set<WebDomain> = Set([
        "facebook.com", "instagram.com", "tiktok.com", "twitter.com", "x.com",
        "snapchat.com", "reddit.com", "tumblr.com", "discord.com", "pinterest.com",
        "bereal.com", "threads.net", "youtube.com", "twitch.tv", "linkedin.com"
    ].map { WebDomain(domain: $0) })

    // MARK: - Init

    private init() {
        loadPersistedState()
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    private func checkAuthorizationStatus() {
        isAuthorized = (AuthorizationCenter.shared.authorizationStatus == .approved)
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = (AuthorizationCenter.shared.authorizationStatus == .approved)
        } catch {
            isAuthorized = false
            print("[FocusBlockingService] Authorization failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Blocking

    func applyBlockingIfEnabled() {
        guard isAuthorized else { return }
        applyBlocking()
        // Keep the shield's encouraging content fresh whenever blocking is active.
        ShieldContentProvider.shared.refreshIfNeeded()
    }

    private func applyBlocking() {
        // --- Web content filter (Safari) ---
        // Adult content uses Apple's built-in automatic adult-web filter (far more
        // comprehensive than a hardcoded list); social websites are layered on top.
        let socialDomains = blockSocialMedia ? FocusBlockingService.socialMediaDomains : []
        if blockNSFW {
            store.webContent.blockedByFilter = .auto(socialDomains)
        } else if !socialDomains.isEmpty {
            store.webContent.blockedByFilter = .specific(socialDomains)
        } else {
            store.webContent.blockedByFilter = nil
        }

        // --- App / category / web-domain shields ---
        // Union the manual "specific apps" selection with the social selection so
        // toggling social blocking shields the social apps & category the user chose.
        var appTokens      = selection.applicationTokens
        var categoryTokens = selection.categoryTokens
        var webTokens      = selection.webDomainTokens
        if blockSocialMedia {
            appTokens.formUnion(socialSelection.applicationTokens)
            categoryTokens.formUnion(socialSelection.categoryTokens)
            webTokens.formUnion(socialSelection.webDomainTokens)
        }

        store.shield.applications = appTokens.isEmpty ? nil : appTokens
        store.shield.applicationCategories = categoryTokens.isEmpty ? nil : .specific(categoryTokens)
        store.shield.webDomains = webTokens.isEmpty ? nil : webTokens
    }

    // MARK: - Setters

    func setBlockNSFW(_ enabled: Bool) async {
        if enabled && !isAuthorized {
            await requestAuthorization()
            guard isAuthorized else { return }
        }
        blockNSFW = enabled
        persistState()
        applyBlocking()
    }

    func setBlockSocialMedia(_ enabled: Bool) async {
        if enabled && !isAuthorized {
            await requestAuthorization()
            guard isAuthorized else { return }
        }
        blockSocialMedia = enabled
        persistState()
        applyBlocking()
    }

    func updateSelection(_ newSelection: FamilyActivitySelection) {
        selection = newSelection
        persistState()
        if isAuthorized { applyBlocking() }
    }

    /// Stores the social-media selection (from the picker) without changing the
    /// on/off flag. Call before `setBlockSocialMedia(true)`.
    func updateSocialSelection(_ newSelection: FamilyActivitySelection) {
        socialSelection = newSelection
        persistState()
        if isAuthorized && blockSocialMedia { applyBlocking() }
    }

    /// Whether the user has picked anything for social-media blocking yet.
    var hasSocialSelection: Bool {
        !socialSelection.applicationTokens.isEmpty
        || !socialSelection.categoryTokens.isEmpty
        || !socialSelection.webDomainTokens.isEmpty
    }

    // MARK: - Convenience

    var isAnyBlockingActive: Bool {
        blockNSFW || blockSocialMedia
        || !selection.applicationTokens.isEmpty
        || !selection.webDomainTokens.isEmpty
    }

    var selectedAppCount: Int { selection.applicationTokens.count }

    var statusDescription: String {
        guard isAnyBlockingActive else { return "No content blocked" }
        var parts: [String] = []
        if blockNSFW         { parts.append("Adult content") }
        if blockSocialMedia  { parts.append("Social media") }
        let count = selectedAppCount
        if count > 0         { parts.append("\(count) app\(count == 1 ? "" : "s")") }
        return parts.joined(separator: " · ") + " blocked"
    }

    // MARK: - Persistence

    func persistState() {
        let defaults = UserDefaults.standard
        defaults.set(blockNSFW,        forKey: Keys.blockNSFW)
        defaults.set(blockSocialMedia, forKey: Keys.blockSocialMedia)
        if let encoded = try? JSONEncoder().encode(selection) {
            defaults.set(encoded, forKey: Keys.selectionData)
        }
        if let encodedSocial = try? JSONEncoder().encode(socialSelection) {
            defaults.set(encodedSocial, forKey: Keys.socialSelectionData)
        }
    }

    private func loadPersistedState() {
        let defaults = UserDefaults.standard
        blockNSFW        = defaults.bool(forKey: Keys.blockNSFW)
        blockSocialMedia = defaults.bool(forKey: Keys.blockSocialMedia)
        if let data = defaults.data(forKey: Keys.selectionData),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = decoded
        }
        if let data = defaults.data(forKey: Keys.socialSelectionData),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            socialSelection = decoded
        }
    }
}
