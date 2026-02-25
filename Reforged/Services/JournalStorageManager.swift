import Foundation
import CryptoKit
import Security

/// Secure local storage manager for journal entries
/// Journal entries are stored ONLY locally on the device and are NEVER uploaded to any server
/// Entries are encrypted using device-specific keys stored in the Keychain
class JournalStorageManager {
    static let shared = JournalStorageManager()

    private let userDefaults = UserDefaults.standard
    private let journalEntriesKey = "encrypted_journal_entries"
    private let encryptionKeyTag = "com.reforged.journal.encryptionKey"

    private init() {
        // Ensure encryption key exists
        _ = getOrCreateEncryptionKey()
    }

    // MARK: - Public Interface

    /// Load all journal entries from secure local storage
    func loadEntries() -> [JournalEntry] {
        guard let encryptedData = userDefaults.data(forKey: journalEntriesKey) else {
            return []
        }

        guard let key = getOrCreateEncryptionKey() else {
            print("Failed to get encryption key")
            return []
        }

        guard let decryptedData = decrypt(data: encryptedData, using: key) else {
            print("Failed to decrypt journal entries")
            return []
        }

        do {
            let entries = try JSONDecoder().decode([JournalEntry].self, from: decryptedData)
            return entries
        } catch {
            print("Failed to decode journal entries: \(error)")
            return []
        }
    }

    /// Save all journal entries to secure local storage
    func saveEntries(_ entries: [JournalEntry]) {
        guard let key = getOrCreateEncryptionKey() else {
            print("Failed to get encryption key")
            return
        }

        do {
            let data = try JSONEncoder().encode(entries)
            guard let encryptedData = encrypt(data: data, using: key) else {
                print("Failed to encrypt journal entries")
                return
            }
            userDefaults.set(encryptedData, forKey: journalEntriesKey)
        } catch {
            print("Failed to encode journal entries: \(error)")
        }
    }

    /// Add a new journal entry
    func addEntry(_ entry: JournalEntry) {
        var entries = loadEntries()
        entries.insert(entry, at: 0)
        saveEntries(entries)
    }

    /// Update an existing journal entry
    func updateEntry(_ entry: JournalEntry) {
        var entries = loadEntries()
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            saveEntries(entries)
        }
    }

    /// Delete a journal entry
    func deleteEntry(id: String) {
        var entries = loadEntries()
        entries.removeAll { $0.id == id }
        saveEntries(entries)
    }

    /// Delete all journal entries (for account deletion or data clear)
    func deleteAllEntries() {
        userDefaults.removeObject(forKey: journalEntriesKey)
    }

    // MARK: - Encryption Key Management (Keychain)

    private func getOrCreateEncryptionKey() -> SymmetricKey? {
        // Try to retrieve existing key from Keychain
        if let existingKey = retrieveKeyFromKeychain() {
            return existingKey
        }

        // Create new key and store in Keychain
        let newKey = SymmetricKey(size: .bits256)
        if storeKeyInKeychain(newKey) {
            return newKey
        }

        return nil
    }

    private func retrieveKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: encryptionKeyTag,
            kSecAttrAccount as String: "journalEncryptionKey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let keyData = result as? Data else {
            return nil
        }

        return SymmetricKey(data: keyData)
    }

    private func storeKeyInKeychain(_ key: SymmetricKey) -> Bool {
        let keyData = key.withUnsafeBytes { Data($0) }

        // Delete existing key if present
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: encryptionKeyTag,
            kSecAttrAccount as String: "journalEncryptionKey"
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: encryptionKeyTag,
            kSecAttrAccount as String: "journalEncryptionKey",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Encryption/Decryption using AES-GCM

    private func encrypt(data: Data, using key: SymmetricKey) -> Data? {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            print("Encryption error: \(error)")
            return nil
        }
    }

    private func decrypt(data: Data, using key: SymmetricKey) -> Data? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            print("Decryption error: \(error)")
            return nil
        }
    }
}
