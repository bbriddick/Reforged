import Foundation
import Security

// MARK: - Age Gate (Requirements §1)
//
// COPPA/GDPR-K age-neutral gate for the Groups tab. The user enters a date of
// birth once; anyone computed as under 13 is routed to a restricted screen and
// the decision is written to BOTH UserDefaults and the keychain. The keychain
// copy survives an app delete/reinstall, so a minor can't clear the block by
// reinstalling — the "prevent bypass" requirement. `.restricted` is sticky:
// once set it is never downgraded on this device.

enum AgeGateStatus: String {
    case unknown     // no DOB entered yet
    case allowed     // 13+
    case restricted  // under 13 — blocked
}

@MainActor
final class AgeGateManager: ObservableObject {
    static let shared = AgeGateManager()

    /// Minimum age to access Groups. Isolated as a constant for the eventual
    /// parental-consent flow that will unlock under-13 accounts.
    static let minimumAge = 13

    @Published private(set) var status: AgeGateStatus

    private let kStatus = "reforged.ageGate.status"
    private let kBirthDate = "reforged.ageGate.birthDate"       // ISO-8601, day precision
    private let keychainRestrictedKey = "reforged.ageGate.restricted"
    private let keychainService = "com.reforged.app"

    private init() {
        // Keychain wins: a restricted flag there is authoritative and cannot be
        // cleared by wiping UserDefaults.
        if Self.readKeychainFlag(key: keychainRestrictedKey, service: keychainService) {
            status = .restricted
        } else if let raw = UserDefaults.standard.string(forKey: kStatus),
                  let s = AgeGateStatus(rawValue: raw) {
            status = s
        } else {
            status = .unknown
        }
    }

    // MARK: - Public API

    var isRestricted: Bool { status == .restricted }
    var needsAgeCheck: Bool { status == .unknown }

    /// Stored date of birth, if one was entered. Used to pre-fill the picker and
    /// to sync `birth_date` to the profile once (13+ only).
    var storedBirthDate: Date? {
        guard let iso = UserDefaults.standard.string(forKey: kBirthDate) else { return nil }
        return Self.dayFormatter.date(from: iso)
    }

    static func age(from birthDate: Date, on reference: Date = Date()) -> Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: reference).year ?? 0
    }

    /// Records the entered date of birth and returns the resulting status.
    /// A `.restricted` outcome is persisted to the keychain so it can't be
    /// bypassed by reinstalling; `.allowed` also syncs `birth_date` upstream.
    @discardableResult
    func submit(birthDate: Date) -> AgeGateStatus {
        // Never downgrade an existing restriction.
        if status == .restricted { return .restricted }

        UserDefaults.standard.set(Self.dayFormatter.string(from: birthDate), forKey: kBirthDate)

        let newStatus: AgeGateStatus = Self.age(from: birthDate) >= Self.minimumAge ? .allowed : .restricted
        status = newStatus
        UserDefaults.standard.set(newStatus.rawValue, forKey: kStatus)

        if newStatus == .restricted {
            Self.writeKeychainFlag(true, key: keychainRestrictedKey, service: keychainService)
        } else {
            Task { await syncBirthDateToProfile(birthDate) }
        }
        return newStatus
    }

    #if DEBUG
    /// Test-only reset. Deliberately excluded from release builds so it can't be
    /// used as a bypass path.
    func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: kStatus)
        UserDefaults.standard.removeObject(forKey: kBirthDate)
        Self.deleteKeychainFlag(key: keychainRestrictedKey, service: keychainService)
        status = .unknown
    }
    #endif

    // MARK: - Profile Sync

    private func syncBirthDateToProfile(_ birthDate: Date) async {
        guard let token = await SupabaseAuthService.shared.validAccessToken(),
              let uid = SupabaseAuthService.shared.userId,
              let base = SettingsManager.shared.supabaseProjectURL else { return }
        let anon = SettingsManager.shared.supabaseAnonKey
        guard let url = URL(string: "\(base.absoluteString)/rest/v1/profiles?user_id=eq.\(uid)") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue(anon, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(
            withJSONObject: ["birth_date": Self.dayFormatter.string(from: birthDate)])
        _ = try? await URLSession.shared.data(for: req)
    }

    // MARK: - Formatters

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Keychain Flag Helpers

    private static func writeKeychainFlag(_ value: Bool, key: String, service: String) {
        let data = Data([value ? 1 : 0])
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func readKeychainFlag(key: String, service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let first = data.first else { return false }
        return first == 1
    }

    private static func deleteKeychainFlag(key: String, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}
