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

    /// Schedule daily reading & review reminders at the user's chosen time
    @MainActor func scheduleDailyReminder() {
        let center = UNUserNotificationCenter.current()
        // Remove old reminders
        center.removePendingNotificationRequests(withIdentifiers: [
            "daily-reading-reminder",
            "daily-review-reminder"
        ])

        let settings = SettingsManager.shared
        guard settings.notificationsEnabled else { return }

        let reminderDate = settings.dailyReminderTime
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)

        if settings.readingPlanReminders {
            let content = UNMutableNotificationContent()
            content.title = "Time to Read"
            content.body = "Open up to read a chapter and grow in God's Word today."
            content.sound = .default
            content.userInfo = ["action": "open-bible"]

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "daily-reading-reminder", content: content, trigger: trigger)
            center.add(request)
        }

        if settings.memoryReviewReminders {
            // Schedule review reminder 5 minutes after reading
            var reviewComponents = components
            reviewComponents.minute = (components.minute ?? 0) + 5
            if let min = reviewComponents.minute, min >= 60 {
                reviewComponents.minute = min - 60
                reviewComponents.hour = (reviewComponents.hour ?? 0) + 1
            }

            let content = UNMutableNotificationContent()
            content.title = "Verse Review Time"
            content.body = "Strengthen your memory with a quick verse review."
            content.sound = .default
            content.userInfo = ["action": "open-memory"]

            let trigger = UNCalendarNotificationTrigger(dateMatching: reviewComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "daily-review-reminder", content: content, trigger: trigger)
            center.add(request)
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
        center.removePendingNotificationRequests(withIdentifiers: [
            "daily-reading-reminder",
            "daily-review-reminder"
        ])

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
