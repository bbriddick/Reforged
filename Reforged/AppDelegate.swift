import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Pre-load bundled KJV Bible on a background thread so it is ready
        // before the user opens BibleView for the first time.
        Task.detached(priority: .userInitiated) {
            KJVService.shared.loadBundledJSON()
        }

        // Warm the WordsOfChristData singleton on a background thread so that
        // red-letter markup is ready before the user opens BibleView. Without
        // this, the 655 KB JSON decode would run synchronously on whichever
        // thread first accesses the singleton, potentially blocking the main thread.
        Task.detached(priority: .utility) {
            _ = WordsOfChristData.shared
        }

        // Silently warm the disk cache around the user's last-read position for
        // their default translation. Runs at .background priority with 100 ms pacing
        // between requests so it never competes with UI or the KJV bundle load.
        // Skips KJV, TR, and WLC which are already fully bundled.
        Task.detached(priority: .background) {
            await AppDelegate.warmBibleCache()
        }

        return true
    }

    // MARK: - Launch Cache Warm-up

    /// Pre-fetches the remaining chapters of the user's current book and the next
    /// two books for every non-bundled translation in their active translation
    /// order, storing results in the persistent disk caches.
    ///
    /// Multiple translations for the same chapter are fetched in parallel.
    /// Chapters are paced 100 ms apart to respect API rate limits.
    private static func warmBibleCache() async {
        // Collect all non-bundled translations the user has enabled.
        // KJV is fully bundled; TR and WLC are original-language and bundled.
        let rawOrder = UserDefaults.standard.array(forKey: "settings.translationOrder") as? [String] ?? []
        let networkTranslations: [BibleTranslation] = rawOrder
            .compactMap { BibleTranslation(rawValue: $0) }
            .filter { !$0.isOriginalLanguage && $0 != .kjv }

        guard !networkTranslations.isEmpty else { return }

        let lastBook     = UserDefaults.standard.string(forKey: "bible_last_book") ?? "John"
        let savedChapter = UserDefaults.standard.integer(forKey: "bible_last_chapter")
        let startChapter = savedChapter > 0 ? savedChapter : 1

        guard let startBookIdx = BibleData.books.firstIndex(where: { $0.name == lastBook }) else { return }

        // Build the chapter list: remaining chapters of current book + next 2 books
        var toFetch: [(book: String, chapter: Int)] = []
        let curBook = BibleData.books[startBookIdx]
        if startChapter <= curBook.chapters {
            for ch in startChapter...curBook.chapters { toFetch.append((curBook.name, ch)) }
        }
        for offset in 1...2 {
            let idx = startBookIdx + offset
            guard idx < BibleData.books.count else { break }
            let nb = BibleData.books[idx]
            for ch in 1...nb.chapters { toFetch.append((nb.name, ch)) }
        }

        for (book, chapter) in toFetch {
            guard !Task.isCancelled else { return }
            // Fetch all active translations for this chapter simultaneously
            await withTaskGroup(of: Void.self) { group in
                for translation in networkTranslations {
                    group.addTask {
                        do {
                            switch translation {
                            case .esv:
                                _ = try await ESVService.shared.fetchChapterParsed(book: book, chapter: chapter)
                            case .csb, .nkjv, .nasb, .rvr1960:
                                _ = try await ApiBibleService.shared.fetchChapterParsed(
                                    book: book, chapter: chapter, translation: translation)
                            default:
                                break
                            }
                        } catch {}
                    }
                }
            }
            // 100 ms between chapter batches — stays well within rate limits
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    
    // MARK: - Remote Notification Registration
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationManager.shared.handleDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationManager.shared.handleRegistrationError(error)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }
    
    /// Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle the notification data
        handleNotificationPayload(userInfo)
        
        completionHandler()
    }
    
    /// Process notification payload
    private func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        // Handle deep linking or navigation based on notification payload
        if let urlString = userInfo["url"] as? String,
           let url = URL(string: urlString) {
            // Post notification to navigate to URL in WebView
            NotificationCenter.default.post(
                name: .navigateToURL,
                object: nil,
                userInfo: [AppNotificationUserInfoKey.url: url]
            )
        }
        
        // Handle deep link actions from daily reminders
        if let action = userInfo["action"] as? String {
            switch action {
            case "open-bible":
                NotificationCenter.default.post(
                    name: .switchTab,
                    object: nil,
                    userInfo: [AppNotificationUserInfoKey.tab: 2]
                )
            case "open-memory":
                NotificationCenter.default.post(
                    name: .switchTab,
                    object: nil,
                    userInfo: [AppNotificationUserInfoKey.tab: 3]
                )
            default:
                break
            }
        }
    }
}
