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

    private func openChallenge(_ invite: VerseChallengeInvite) {
        AppState.shared.pendingChallenge = invite
        NotificationCenter.default.post(
            name: .switchTab,
            object: nil,
            userInfo: [AppNotificationUserInfoKey.tab: 3]
        )
    }

    private func handleDeepLink(_ url: URL) {
        // Universal link: https://reforgedapp.org/friend/ABCD2345
        if url.scheme?.lowercased() == "https",
           url.host?.lowercased().hasSuffix("reforgedapp.org") == true {
            let parts = url.pathComponents.filter { $0 != "/" }
            if parts.count >= 2, parts[0].lowercased() == "friend", !parts[1].isEmpty {
                FriendsStore.shared.handleDeepLink(code: parts[1])
            } else if let invite = VerseChallenge.invite(from: url) {
                openChallenge(invite)
            }
            return
        }

        guard url.scheme?.lowercased() == "reforged" else { return }

        if url.host?.lowercased() == "panic" {
            NotificationCenter.default.post(name: .showTemptedSOS, object: nil)
            return
        }

        // reforged://memorize?ref=John%203:16&from=Sam  → offer to memorize that verse.
        if let invite = VerseChallenge.invite(from: url) {
            openChallenge(invite)
            return
        }

        // reforged://friend?code=ABCD2345  → open Friends and redeem the code.
        if url.host?.lowercased() == "friend",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
           !code.isEmpty {
            FriendsStore.shared.handleDeepLink(code: code)
            return
        }

        // reforged://join?code=ABC123  → open Groups tab and auto-join the code.
        if url.host?.lowercased() == "join",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
           !code.isEmpty {
            AppState.shared.pendingGroupInviteCode = code.uppercased()
            NotificationCenter.default.post(
                name: .switchTab,
                object: nil,
                userInfo: [AppNotificationUserInfoKey.tab: 6]
            )
            return
        }

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
