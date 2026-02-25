import Foundation
import AuthenticationServices
import Combine

// MARK: - Apple Sign In Service

@MainActor
class AppleSignInService: NSObject, ObservableObject {
    static let shared = AppleSignInService()

    @Published var isSignedIn: Bool = false
    @Published var userIdentifier: String?
    @Published var userName: String?
    @Published var userEmail: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var signInContinuation: CheckedContinuation<ASAuthorization, Error>?

    // Keychain keys
    private let keychainUserID = "reforged.apple.userIdentifier"
    private let keychainUserName = "reforged.apple.userName"
    private let keychainUserEmail = "reforged.apple.userEmail"
    private let keychainRefreshToken = "reforged.apple.refreshToken"

    // Client secret JWT (ES256-signed, valid ~6 months from Feb 25, 2026).
    // Generated from: Team ID 53998XCUML, Key ID X2VC4L54B5, Client ID com.reforged.app
    // Expires: ~Aug 2026 — regenerate before expiry.
    private let clientSecret = "eyJhbGciOiJFUzI1NiIsImtpZCI6IlgyVkM0TDU0QjUiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiI1Mzk5OFhDVU1MIiwiaWF0IjoxNzcyMDM4Njc1LCJleHAiOjE3ODc4MTU2NzUsImF1ZCI6Imh0dHBzOi8vYXBwbGVpZC5hcHBsZS5jb20iLCJzdWIiOiJjb20ucmVmb3JnZWQuYXBwIn0.3xHh1BNaJQlnN4MhYtdcyHr60u6K8n8uPeRmvVOq5OVzcbnzSDxDuIcK0Gbe5x014VhUHQ_8uxMGo3__w1JvpQ"
    private let clientID = "com.reforged.app"

    override init() {
        super.init()
        loadFromKeychain()

        // Listen for credential revocation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(credentialRevoked),
            name: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil
        )

        // Check credential state on launch
        if let userIdentifier = userIdentifier {
            Task {
                await checkCredentialState(userIdentifier: userIdentifier)
            }
        }
    }

    // MARK: - Credential State

    func checkCredentialState(userIdentifier: String) async {
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: userIdentifier)
            switch state {
            case .authorized:
                isSignedIn = true
            case .revoked, .notFound:
                clearKeychain()
                isSignedIn = false
                self.userIdentifier = nil
                userName = nil
                userEmail = nil
            case .transferred:
                // Handle account transfer if needed
                break
            @unknown default:
                break
            }
        } catch {
            print("Error checking credential state: \(error)")
        }
    }

    // MARK: - Sign In

    func signIn() async throws -> (userIdentifier: String, fullName: PersonNameComponents?, email: String?) {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let authorization = try await performSignInRequest()

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AppleSignInError.invalidCredential
        }

        let userId = credential.user
        let fullName = credential.fullName
        let email = credential.email

        // Store in Keychain
        saveToKeychain(userIdentifier: userId)
        if let givenName = fullName?.givenName {
            saveToKeychain(key: keychainUserName, value: givenName)
            userName = givenName
        }
        if let email = email {
            saveToKeychain(key: keychainUserEmail, value: email)
            userEmail = email
        }

        userIdentifier = userId
        isSignedIn = true

        return (userId, fullName, email)
    }

    private func performSignInRequest() async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Sign Out

    func signOut() {
        clearKeychain()
        isSignedIn = false
        userIdentifier = nil
        userName = nil
        userEmail = nil
    }

    // MARK: - Credential Revocation

    @objc private func credentialRevoked() {
        Task { @MainActor in
            signOut()
        }
    }

    // MARK: - Token Exchange & Revocation

    /// Exchange an authorization code for a refresh token via Apple's /auth/token endpoint.
    /// The authorizationCode is one-time use and valid for only 5 minutes.
    func exchangeAuthCodeForTokens(authCode: String) async {
        guard clientSecret != "YOUR_CLIENT_SECRET_JWT_HERE" else {
            print("⚠️ Client secret not configured — skipping token exchange")
            return
        }

        let url = URL(string: "https://appleid.apple.com/auth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": authCode,
            "grant_type": "authorization_code"
        ]
        request.httpBody = params
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return }

            if httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let refreshToken = json["refresh_token"] as? String {
                saveToKeychain(key: keychainRefreshToken, value: refreshToken)
                print("✅ Apple refresh token obtained and stored")
            } else {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("⚠️ Token exchange failed (\(httpResponse.statusCode)): \(body)")
            }
        } catch {
            print("⚠️ Token exchange error: \(error)")
        }
    }

    /// Revoke the stored refresh token via Apple's /auth/revoke endpoint.
    /// Should be called during account deletion before clearing local data.
    func revokeToken() async {
        guard clientSecret != "YOUR_CLIENT_SECRET_JWT_HERE" else {
            print("⚠️ Client secret not configured — skipping token revocation")
            return
        }

        guard let refreshToken = loadFromKeychain(key: keychainRefreshToken) else {
            print("⚠️ No refresh token stored — skipping token revocation")
            return
        }

        let url = URL(string: "https://appleid.apple.com/auth/revoke")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "token": refreshToken,
            "token_type_hint": "refresh_token"
        ]
        request.httpBody = params
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("✅ Apple token revoked successfully")
            } else {
                print("⚠️ Token revocation returned unexpected response")
            }
        } catch {
            print("⚠️ Token revocation error: \(error)")
        }
    }

    // MARK: - Keychain Helpers

    private func loadFromKeychain() {
        if let userId = loadFromKeychain(key: keychainUserID) {
            userIdentifier = userId
            isSignedIn = true
        }
        userName = loadFromKeychain(key: keychainUserName)
        userEmail = loadFromKeychain(key: keychainUserEmail)
    }

    private func saveToKeychain(userIdentifier: String) {
        saveToKeychain(key: keychainUserID, value: userIdentifier)
    }

    private func saveToKeychain(key: String, value: String) {
        let data = Data(value.utf8)

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.reforged.app"
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.reforged.app",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.reforged.app",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func clearKeychain() {
        for key in [keychainUserID, keychainUserName, keychainUserEmail, keychainRefreshToken] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: "com.reforged.app"
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            signInContinuation?.resume(returning: authorization)
            signInContinuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            signInContinuation?.resume(throwing: error)
            signInContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    @MainActor
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the key window
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Errors

enum AppleSignInError: LocalizedError {
    case invalidCredential
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid Apple ID credential"
        case .cancelled:
            return "Sign in was cancelled"
        case .unknown(let message):
            return message
        }
    }
}
