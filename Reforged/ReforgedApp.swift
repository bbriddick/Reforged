import SwiftUI

@main
struct ReforgedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "reforged" else { return }

        if url.host?.lowercased() == "bible",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let reference = components.queryItems?.first(where: { $0.name == "reference" })?.value,
           !reference.isEmpty {
            NotificationCenter.default.post(
                name: .switchTab,
                object: nil,
                userInfo: [AppNotificationUserInfoKey.tab: 2]
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: .navigateToBibleVerse,
                    object: nil,
                    userInfo: [AppNotificationUserInfoKey.reference: reference]
                )
            }
        }
    }
}
