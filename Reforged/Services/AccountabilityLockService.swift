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

    /// What's persisted: a random salt plus SHA-256(salt + pin).
    private struct Record: Codable {
        let salt: Data
        let hash: Data
    }

    // MARK: - Public API

    /// Sets (or replaces) the accountability PIN. Returns false if the PIN is too
    /// short or the Keychain write fails.
    @discardableResult
    func setPIN(_ pin: String) -> Bool {
        guard pin.count >= Self.pinLength else { return false }
        guard let salt = Self.randomSalt() else { return false }
        let record = Record(salt: salt, hash: Self.hash(pin: pin, salt: salt))
        guard let data = try? JSONEncoder().encode(record), store(data) else { return false }
        isLockEnabled = true
        return true
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
