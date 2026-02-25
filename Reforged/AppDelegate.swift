import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        return true
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
                name: NSNotification.Name("NavigateToURL"),
                object: nil,
                userInfo: ["url": url]
            )
        }
        
        // Handle deep link actions from daily reminders
        if let action = userInfo["action"] as? String {
            switch action {
            case "open-bible":
                NotificationCenter.default.post(
                    name: NSNotification.Name("SwitchTab"),
                    object: nil,
                    userInfo: ["tab": 2]
                )
            case "open-memory":
                NotificationCenter.default.post(
                    name: NSNotification.Name("SwitchTab"),
                    object: nil,
                    userInfo: ["tab": 3]
                )
            default:
                break
            }
        }
    }
}
