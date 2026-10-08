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
            debugLog("Failed to get encryption key")
            return []
        }

        guard let decryptedData = decrypt(data: encryptedData, using: key) else {
            debugLog("Failed to decrypt journal entries")
            return []
        }

        do {
            let entries = try JSONDecoder().decode([JournalEntry].self, from: decryptedData)
            return entries
        } catch {
            debugLog("Failed to decode journal entries: \(error)")
            return []
        }
    }

    /// Save all journal entries to secure local storage
    func saveEntries(_ entries: [JournalEntry]) {
        guard let key = getOrCreateEncryptionKey() else {
            debugLog("Failed to get encryption key")
            return
        }

        do {
            let data = try JSONEncoder().encode(entries)
            guard let encryptedData = encrypt(data: data, using: key) else {
                debugLog("Failed to encrypt journal entries")
                return
            }
            userDefaults.set(encryptedData, forKey: journalEntriesKey)
        } catch {
            debugLog("Failed to encode journal entries: \(error)")
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
            debugLog("Encryption error: \(error)")
            return nil
        }
    }

    private func decrypt(data: Data, using key: SymmetricKey) -> Data? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            debugLog("Decryption error: \(error)")
            return nil
        }
    }
}

// MARK: - Note Organization Store

/// Device-only, encrypted store for the Notes library organization layer:
/// user-created folders plus folder/pin membership for Bible verse notes
/// (whose primary records live in `BibleReadingState`). Journal reflections
/// carry their own `folderId`/`isPinned` on `JournalEntry`, so this store only
/// needs to track folders and the Bible-note side mappings.
///
/// Kept separate from `JournalStorageManager` so the two encrypted blobs can be
/// versioned independently, but it follows the exact same AES-GCM + Keychain
/// approach so nothing ever leaves the device.
@MainActor
final class NoteOrganizationStore: ObservableObject {
    static let shared = NoteOrganizationStore()

    /// All user-created folders, kept sorted by `sortIndex` then name.
    @Published private(set) var folders: [NoteFolder] = []
    /// Bible-note id -> folder id.
    @Published private(set) var bibleNoteFolders: [String: String] = [:]
    /// Pinned Bible-note ids.
    @Published private(set) var pinnedBibleNotes: Set<String> = []

    private let userDefaults = UserDefaults.standard
    private let storageKey = "encrypted_note_organization"
    private let encryptionKeyTag = "com.reforged.notes.org.encryptionKey"

    private struct Payload: Codable {
        var folders: [NoteFolder]
        var bibleNoteFolders: [String: String]
        var pinnedBibleNotes: [String]
    }

    private init() {
        load()
    }

    // MARK: Folders

    func addFolder(name: String, icon: String, accent: NoteAccent) -> NoteFolder {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = NoteFolder(
            name: trimmed.isEmpty ? "Untitled Folder" : trimmed,
            icon: icon,
            accent: accent,
            sortIndex: (folders.map(\.sortIndex).max() ?? -1) + 1
        )
        folders.append(folder)
        sortFolders()
        persist()
        return folder
    }

    func updateFolder(_ folder: NoteFolder) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[idx] = folder
        sortFolders()
        persist()
    }

    /// Removes a folder. Journal entries are detached by the caller; here we
    /// only clear Bible-note memberships that pointed at it.
    func deleteFolder(id: String) {
        folders.removeAll { $0.id == id }
        for (noteId, folderId) in bibleNoteFolders where folderId == id {
            bibleNoteFolders.removeValue(forKey: noteId)
        }
        persist()
    }

    func folder(id: String?) -> NoteFolder? {
        guard let id else { return nil }
        return folders.first { $0.id == id }
    }

    // MARK: Bible-note membership

    func folderId(forBibleNote id: String) -> String? {
        bibleNoteFolders[id]
    }

    func setFolder(_ folderId: String?, forBibleNote id: String) {
        if let folderId {
            bibleNoteFolders[id] = folderId
        } else {
            bibleNoteFolders.removeValue(forKey: id)
        }
        persist()
    }

    func isBibleNotePinned(_ id: String) -> Bool {
        pinnedBibleNotes.contains(id)
    }

    func toggleBibleNotePinned(_ id: String) {
        if pinnedBibleNotes.contains(id) {
            pinnedBibleNotes.remove(id)
        } else {
            pinnedBibleNotes.insert(id)
        }
        persist()
    }

    // MARK: Persistence

    private func sortFolders() {
        folders.sort { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func load() {
        guard let encrypted = userDefaults.data(forKey: storageKey),
              let key = getOrCreateEncryptionKey(),
              let decrypted = decrypt(data: encrypted, using: key),
              let payload = try? JSONDecoder().decode(Payload.self, from: decrypted) else {
            return
        }
        folders = payload.folders
        bibleNoteFolders = payload.bibleNoteFolders
        pinnedBibleNotes = Set(payload.pinnedBibleNotes)
        sortFolders()
    }

    private func persist() {
        let payload = Payload(
            folders: folders,
            bibleNoteFolders: bibleNoteFolders,
            pinnedBibleNotes: Array(pinnedBibleNotes)
        )
        guard let key = getOrCreateEncryptionKey(),
              let data = try? JSONEncoder().encode(payload),
              let encrypted = encrypt(data: data, using: key) else {
            return
        }
        userDefaults.set(encrypted, forKey: storageKey)
    }

    // MARK: Encryption (mirrors JournalStorageManager, distinct Keychain tag)

    private func getOrCreateEncryptionKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: encryptionKeyTag,
            kSecAttrAccount as String: "notesOrgEncryptionKey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let keyData = result as? Data {
            return SymmetricKey(data: keyData)
        }
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: encryptionKeyTag,
            kSecAttrAccount as String: "notesOrgEncryptionKey",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(addQuery as CFDictionary)
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess ? newKey : nil
    }

    private func encrypt(data: Data, using key: SymmetricKey) -> Data? {
        try? AES.GCM.seal(data, using: key).combined
    }

    private func decrypt(data: Data, using key: SymmetricKey) -> Data? {
        guard let box = try? AES.GCM.SealedBox(combined: data) else { return nil }
        return try? AES.GCM.open(box, using: key)
    }
}
