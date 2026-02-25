import Foundation
import Combine

/// Syncs Bible reading position across devices via iCloud key-value store (NSUbiquitousKeyValueStore).
/// Works automatically with Apple ID — no login required.
/// Highlights and notes are synced via CloudKit (CloudKitSyncService) instead.
class iCloudSyncService: ObservableObject {
    static let shared = iCloudSyncService()

    private let store = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()
    private var isSyncing = false

    // iCloud KVS keys (reading position only)
    private let lastBookKey = "icloud_bible_last_book"
    private let lastChapterKey = "icloud_bible_last_chapter"

    private init() {
        // Listen for external iCloud changes (from other devices)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )

        // Trigger initial sync from iCloud
        store.synchronize()

        // Listen for local Bible data changes to push reading position to iCloud
        NotificationCenter.default.publisher(for: .bibleDataDidChange)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pushToiCloud()
            }
            .store(in: &cancellables)
    }

    // MARK: - Push Reading Position to iCloud

    func pushToiCloud() {
        guard !isSyncing else { return }

        let settings = BibleReadingSettings.shared

        // Reading position only
        store.set(settings.lastBook, forKey: lastBookKey)
        store.set(settings.lastChapter, forKey: lastChapterKey)

        store.synchronize()
    }

    // MARK: - Receive iCloud Changes

    @objc private func iCloudDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        // Only process server changes or initial sync
        guard changeReason == NSUbiquitousKeyValueStoreServerChange ||
              changeReason == NSUbiquitousKeyValueStoreInitialSyncChange else {
            return
        }

        guard let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.mergeFromiCloud(changedKeys: changedKeys)
        }
    }

    private func mergeFromiCloud(changedKeys: [String]) {
        isSyncing = true
        defer { isSyncing = false }

        if changedKeys.contains(lastBookKey) || changedKeys.contains(lastChapterKey) {
            let settings = BibleReadingSettings.shared
            if let book = store.string(forKey: lastBookKey) {
                settings.lastBook = book
            }
            let chapter = Int(store.longLong(forKey: lastChapterKey))
            if chapter > 0 {
                settings.lastChapter = chapter
            }
        }
    }
}
