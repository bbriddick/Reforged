import Foundation
import CryptoKit

// MARK: - Accountability Lock Service
//
// Stores an accountability PIN for the Focus & Purity Shield. The point of the
// PIN is self-control with a trusted partner: the user enables blocking, then a
// friend sets a PIN that only they know. After that, the user cannot LOWER their
// own protection (turn a block off, deselect apps, or remove the lock) without
// the partner entering the PIN.
//
// Only a salted SHA-256 hash of the PIN is persisted — never the PIN itself — and
// it lives in the Keychain (not UserDefaults), so it survives app reinstalls and
// can't be cleared by wiping app data. Increasing protection never requires the PIN.

@MainActor
final class AccountabilityLockService: ObservableObject {

    static let shared = AccountabilityLockService()

    /// True when a PIN has been set and the shield is locked down.
    @Published private(set) var isLockEnabled: Bool = false

    /// Minimum PIN length the keypad enforces.
    static let pinLength = 4

    private let keychainService = "com.reforged.accountabilityLock"
    private let keychainAccount = "shieldPIN"

    private init() {
        isLockEnabled = (loadRecord() != nil)
    }

    /// What's persisted: a random salt, SHA-256(salt + pin), and the accountability
    /// partner's contact (email or phone). `partnerContact` is optional so older
    /// records (saved before this field existed) still decode.
    private struct Record: Codable {
        let salt: Data
        let hash: Data
        var partnerContact: String?
    }

    // MARK: - Public API

    /// Sets (or replaces) the accountability PIN and partner contact. Returns false
    /// if the PIN is too short or the Keychain write fails.
    @discardableResult
    func setPIN(_ pin: String, partnerContact: String?) -> Bool {
        guard pin.count >= Self.pinLength else { return false }
        guard let salt = Self.randomSalt() else { return false }
        let trimmed = partnerContact?.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = Record(
            salt: salt,
            hash: Self.hash(pin: pin, salt: salt),
            partnerContact: (trimmed?.isEmpty == false) ? trimmed : nil
        )
        guard let data = try? JSONEncoder().encode(record), store(data) else { return false }
        isLockEnabled = true
        return true
    }

    /// The stored partner contact (email or phone), if any.
    var partnerContact: String? { loadRecord()?.partnerContact }

    /// A privacy-masked version of the partner contact for display.
    var partnerContactMasked: String? {
        guard let contact = partnerContact else { return nil }
        return Self.mask(contact)
    }

    /// Checks a candidate PIN against the stored hash.
    func verifyPIN(_ pin: String) -> Bool {
        guard let record = loadRecord() else { return false }
        let candidate = Self.hash(pin: pin, salt: record.salt)
        // SHA256.Digest comparison is fixed-length; fine for a local PIN.
        return candidate == record.hash
    }

    /// Removes the lock only when the correct PIN is supplied.
    @discardableResult
    func removeLock(pin: String) -> Bool {
        guard verifyPIN(pin) else { return false }
        deleteRecord()
        isLockEnabled = false
        return true
    }

    // MARK: - Partner Notification

    /// Notifies the accountability partner that the user attempted to lower their
    /// protection. The actual email/SMS is sent by a Supabase Edge Function
    /// (`accountability-notify`); the app only posts the event. No-op if no partner
    /// contact is stored or the backend isn't configured.
    func notifyPartnerOfDisableAttempt(
        reason: String = "tried to lower their Focus & Purity Shield protection"
    ) async {
        guard let contact = partnerContact, !contact.isEmpty else { return }
        guard let url = SettingsManager.shared.accountabilityNotifyFunctionURL else { return }
        let anonKey = SettingsManager.shared.supabaseAnonKey
        guard !anonKey.isEmpty else { return }

        // Prefer the signed-in user's JWT (ties the alert to their account); fall
        // back to the anon key for unauthenticated sessions.
        let bearer = (await SupabaseAuthService.shared.validAccessToken()) ?? anonKey

        let body: [String: Any] = [
            "contact": contact,
            "channel": contact.contains("@") ? "email" : "sms",
            "reason": reason,
            "appName": "Reforged",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.setValue("ios", forHTTPHeaderField: "x-client-platform")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[Accountability] partner notify HTTP \(http.statusCode)")
            }
        } catch {
            print("[Accountability] partner notify failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Masking

    /// Masks an email (`j***@domain.com`) or phone (`•••• 1234`) for display.
    static func mask(_ contact: String) -> String {
        if contact.contains("@") {
            let parts = contact.split(separator: "@", maxSplits: 1)
            guard parts.count == 2, let first = parts.first, let domain = parts.last else { return contact }
            let lead = first.prefix(1)
            return "\(lead)***@\(domain)"
        }
        let digits = contact.filter { $0.isNumber }
        guard digits.count >= 4 else { return "••••" }
        return "•••• \(digits.suffix(4))"
    }

    // MARK: - Hashing

    private static func randomSalt() -> Data? {
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!)
        }
        return status == errSecSuccess ? salt : nil
    }

    private static func hash(pin: String, salt: Data) -> Data {
        var data = salt
        data.append(Data(pin.utf8))
        return Data(SHA256.hash(data: data))
    }

    // MARK: - Keychain

    @discardableResult
    private func store(_ data: Data) -> Bool {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    private func loadRecord() -> Record? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let record = try? JSONDecoder().decode(Record.self, from: data) else {
            return nil
        }
        return record
    }

    private func deleteRecord() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
