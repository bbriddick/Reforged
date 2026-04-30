import Foundation
import UserNotifications
import UIKit

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var deviceToken: String?
    @Published var isAuthorized: Bool = false
    
    private override init() {
        super.init()
    }
    
    /// Request permission to send notifications
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                
                if granted {
                    self.registerForRemoteNotifications()
                }
                
                if let error = error {
                    print("Notification authorization error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Register for remote push notifications
    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    /// Handle successful device token registration
    func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        print("Device Token: \(token)")
        
        // TODO: Send this token to your server for push notifications
        // Example: sendTokenToServer(token)
    }
    
    /// Handle registration failure
    func handleRegistrationError(_ error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - Daily Smart Reminders

    /// All notification identifiers managed by this manager.
    /// Must be kept in sync with the identifiers used in scheduleDailyReminder().
    private var allManagedIdentifiers: [String] {
        var ids: [String] = ["daily-reading-reminder", "daily-review-reminder"]
        for weekday in 1...7 {
            ids.append("reading-reminder-\(weekday)")
            ids.append("review-reminder-\(weekday)")
        }
        return ids
    }

    /// Schedule reading & memory-review reminders on the days the user has selected.
    /// Each enabled weekday gets its own weekly-repeating UNCalendarNotificationTrigger.
    @MainActor func scheduleDailyReminder() {
        let center = UNUserNotificationCenter.current()
        // Remove all previously scheduled reminders (both legacy daily and weekday-specific).
        center.removePendingNotificationRequests(withIdentifiers: allManagedIdentifiers)

        let settings = SettingsManager.shared
        guard settings.notificationsEnabled else { return }

        let baseComponents = Calendar.current.dateComponents([.hour, .minute], from: settings.dailyReminderTime)

        // Resolve enabled days — empty set means every day.
        let readingDays = settings.readingReminderDays.isEmpty ? Set(1...7) : settings.readingReminderDays
        let memoryDays  = settings.memoryReminderDays.isEmpty  ? Set(1...7) : settings.memoryReminderDays

        if settings.readingPlanReminders {
            let content = UNMutableNotificationContent()
            content.title = "Time to Read"
            content.body = "Open up to read a chapter and grow in God's Word today."
            content.sound = .default
            content.userInfo = ["action": "open-bible"]

            for weekday in readingDays.sorted() {
                var components = baseComponents
                components.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "reading-reminder-\(weekday)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }

        if settings.memoryReviewReminders {
            // Schedule memory reminders 5 minutes after the reading time.
            var reviewBase = baseComponents
            reviewBase.minute = (baseComponents.minute ?? 0) + 5
            if let min = reviewBase.minute, min >= 60 {
                reviewBase.minute = min - 60
                reviewBase.hour = (reviewBase.hour ?? 0) + 1
            }

            let content = UNMutableNotificationContent()
            content.title = "Verse Review Time"
            content.body = "Strengthen your memory with a quick verse review."
            content.sound = .default
            content.userInfo = ["action": "open-memory"]

            for weekday in memoryDays.sorted() {
                var components = reviewBase
                components.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "review-reminder-\(weekday)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }

    // MARK: - Personalized Daily Reading Notifications (Gemini)

    private let personalizedLastDateKey = "notification_personalized_last_date"

    /// Generates personalized reading reminder content via Gemini, then re-schedules
    /// the reading reminders with that content. Runs at most once per day.
    @MainActor func schedulePersonalizedReadingReminders() {
        let settings = SettingsManager.shared
        guard settings.notificationsEnabled, settings.readingPlanReminders else { return }
        guard settings.aiEnabled else {
            // AI off — fall back to static reminders already scheduled
            return
        }

        // Throttle: only generate once per calendar day
        let lastDate = UserDefaults.standard.object(forKey: personalizedLastDateKey) as? Date
        if let last = lastDate, Calendar.current.isDateInToday(last) { return }

        Task {
            // Gather reading plan context
            let planContext = await Self.activePlanContext()

            do {
                let (title, body) = try await GeminiService.shared.generateDailyReadingNotification(
                    planName: planContext.planName,
                    todaysReading: planContext.todaysReading
                )

                let center = UNUserNotificationCenter.current()
                // Remove static reading reminders so we can replace them with personalised ones
                let readingIDs = (1...7).map { "reading-reminder-\($0)" }
                center.removePendingNotificationRequests(withIdentifiers: readingIDs)

                let baseComponents = Calendar.current.dateComponents([.hour, .minute], from: settings.dailyReminderTime)
                let readingDays = settings.readingReminderDays.isEmpty ? Set(1...7) : settings.readingReminderDays

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                content.userInfo = ["action": "open-bible"]

                for weekday in readingDays.sorted() {
                    var components = baseComponents
                    components.weekday = weekday
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let request = UNNotificationRequest(
                        identifier: "reading-reminder-\(weekday)",
                        content: content,
                        trigger: trigger
                    )
                    try? await center.add(request)
                }

                UserDefaults.standard.set(Date(), forKey: personalizedLastDateKey)
            } catch {
                // Gemini unavailable — static reminders from scheduleDailyReminder() remain
                print("[NotificationManager] Gemini notification generation failed: \(error)")
            }
        }
    }

    /// Returns the name and today's reading reference for the user's most-progressed active plan.
    private static func activePlanContext() async -> (planName: String?, todaysReading: String?) {
        await MainActor.run {
            let service = ReadingPlanService.shared
            // Find the plan the user has made the most progress in
            let active = BibleReadingPlans.all.filter { service.hasStarted($0.id) }
            guard let plan = active.max(by: { service.currentDay(for: $0.id) < service.currentDay(for: $1.id) }) else {
                return (nil, nil)
            }
            let dayIndex = service.currentDay(for: plan.id) - 1
            guard dayIndex >= 0, dayIndex < plan.entries.count else {
                return (plan.name, nil)
            }
            let entry = plan.entries[dayIndex]
            return (plan.name, entry.isReflectionDay ? "a reflection day" : entry.scriptureReference)
        }
    }

    /// Update notification content based on what the user has already done today
    @MainActor func rescheduleWithSmartContent() {
        let settings = SettingsManager.shared
        guard settings.notificationsEnabled else { return }

        let hasRead = ReadingStreakManager.shared.hasReadToday
        let hasDueVerses = !AppState.shared.getVersesForReview().isEmpty

        let center = UNUserNotificationCenter.current()

        // Remove existing to reschedule with updated content
        center.removePendingNotificationRequests(withIdentifiers: allManagedIdentifiers)

        let reminderDate = settings.dailyReminderTime
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)

        // If user already did both, skip
        if hasRead && !hasDueVerses {
            return
        }

        let content = UNMutableNotificationContent()
        content.sound = .default

        if !hasRead && hasDueVerses {
            content.title = "Daily Reminder"
            content.body = "Time to read and review your verses!"
            content.userInfo = ["action": "open-bible"]
        } else if hasRead && hasDueVerses {
            content.title = "Verse Review"
            content.body = "Great reading today! Don't forget your verse review."
            content.userInfo = ["action": "open-memory"]
        } else if !hasRead {
            content.title = "Time to Read"
            content.body = "Open up to read a chapter today."
            content.userInfo = ["action": "open-bible"]
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-reading-reminder", content: content, trigger: trigger)
        center.add(request)
    }

    /// Schedule a local notification (for testing)
    @MainActor func schedulePodcastNotification(episodeCount: Int, title: String) {
        let settings = SettingsManager.shared
        guard settings.podcastNewEpisodeNotifications, settings.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = episodeCount == 1 ? "New Walk Talks Episode" : "\(episodeCount) New Walk Talks Episodes"
        content.body = episodeCount == 1 ? title : "Open the Discipleship tab to listen."
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: settings.podcastNotificationTime)
        let now = Date()
        let trigger: UNNotificationTrigger
        if let fire = Calendar.current.nextDate(after: now, matching: components, matchingPolicy: .nextTime), fire > now {
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        }

        let request = UNNotificationRequest(
            identifier: "podcast-new-episode-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Podcast notification error: \(error.localizedDescription)")
            }
        }
    }

    func scheduleLocalNotification(title: String, body: String, delay: TimeInterval = 5) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    /// Clear all pending notifications
    func clearPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    /// Clear all delivered notifications
    func clearDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    /// Reset badge count
    func resetBadgeCount() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
}
