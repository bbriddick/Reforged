import Foundation
import Security

// MARK: - Supabase Auth Result

struct SupabaseAuthResult {
    let success: Bool
    let userId: String?
    let errorMessage: String?
    let emailConfirmationRequired: Bool

    static func success(userId: String) -> SupabaseAuthResult {
        SupabaseAuthResult(success: true, userId: userId, errorMessage: nil, emailConfirmationRequired: false)
    }
    static func confirmationRequired() -> SupabaseAuthResult {
        SupabaseAuthResult(success: false, userId: nil, errorMessage: nil, emailConfirmationRequired: true)
    }
    static func failure(_ message: String) -> SupabaseAuthResult {
        SupabaseAuthResult(success: false, userId: nil, errorMessage: message, emailConfirmationRequired: false)
    }
}

// MARK: - Supabase Profile Row

private struct SupabaseProfileRow: Decodable {
    let userId: String
    let firstName: String
    let displayName: String
    let avatar: String
    let goals: [String]
    let xp: Int
    let level: Int
    let streak: Int
    let longestStreak: Int
    let lastActiveDate: String
    let completedLessons: [String]

    enum CodingKeys: String, CodingKey {
        case userId          = "user_id"
        case firstName       = "first_name"
        case displayName     = "display_name"
        case avatar
        case goals
        case xp
        case level
        case streak
        case longestStreak   = "longest_streak"
        case lastActiveDate  = "last_active_date"
        case completedLessons = "completed_lessons"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId          = try c.decode(String.self, forKey: .userId)
        firstName       = (try? c.decode(String.self, forKey: .firstName))  ?? ""
        displayName     = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        avatar          = (try? c.decode(String.self, forKey: .avatar))      ?? ""
        goals           = (try? c.decode([String].self, forKey: .goals))     ?? []
        xp              = (try? c.decode(Int.self,    forKey: .xp))          ?? 0
        level           = (try? c.decode(Int.self,    forKey: .level))       ?? 1
        streak          = (try? c.decode(Int.self,    forKey: .streak))      ?? 0
        longestStreak   = (try? c.decode(Int.self,    forKey: .longestStreak)) ?? 0
        lastActiveDate  = (try? c.decode(String.self, forKey: .lastActiveDate)) ?? ""
        completedLessons = (try? c.decode([String].self, forKey: .completedLessons)) ?? []
    }
}

// MARK: - SupabaseAuthService

@MainActor
final class SupabaseAuthService: ObservableObject {
    static let shared = SupabaseAuthService()

    @Published var isSignedIn: Bool = false
    @Published var userId: String?
    @Published var userEmail: String?

    // MARK: - Keychain Keys
    private let kAccessToken   = "reforged.supabase.accessToken"
    private let kRefreshToken  = "reforged.supabase.refreshToken"
    private let kUserId        = "reforged.supabase.userId"
    private let kUserEmail     = "reforged.supabase.userEmail"
    private let kExpiresAt     = "reforged.supabase.expiresAt"

    private init() {
        loadSessionFromKeychain()
    }

    // MARK: - Session Restore

    private func loadSessionFromKeychain() {
        guard let uid = loadFromKeychain(key: kUserId) else { return }
        userId    = uid
        userEmail = loadFromKeychain(key: kUserEmail)
        isSignedIn = true
    }

    // MARK: - URL / Key Helpers

    private var baseURL: String {
        SettingsManager.shared.supabaseProjectURL?.absoluteString ?? ""
    }
    private var anonKey: String { SettingsManager.shared.supabaseAnonKey }

    private func makeRequest(path: String, method: String, body: [String: Any]? = nil,
                             accessToken: String? = nil, extraHeaders: [String: String] = [:]) throws -> URLRequest {
        guard !baseURL.isEmpty, let url = URL(string: "\(baseURL)\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        for (k, v) in extraHeaders { req.setValue(v, forHTTPHeaderField: k) }
        if let body = body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return req
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, displayName: String) async -> SupabaseAuthResult {
        do {
            let body: [String: Any] = [
                "email": email,
                "password": password,
                "options": ["data": ["display_name": displayName]]
            ]
            let req = try makeRequest(path: "/auth/v1/signup", method: "POST", body: body)
            let (data, response) = try await URLSession.shared.data(for: req)

            guard let http = response as? HTTPURLResponse else {
                return .failure("No response from server.")
            }

            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

            guard http.statusCode == 200 else {
                let msg = json["error_description"] as? String
                    ?? json["msg"] as? String
                    ?? json["message"] as? String
                    ?? "Sign-up failed (status \(http.statusCode))."
                return .failure(msg)
            }

            // Supabase returns access_token if email confirmation is disabled
            if let accessToken  = json["access_token"] as? String,
               let refreshToken = json["refresh_token"] as? String,
               let userObj      = json["user"] as? [String: Any],
               let uid          = userObj["id"] as? String {
                let expiresIn = json["expires_in"] as? Double ?? 3600
                saveSession(accessToken: accessToken, refreshToken: refreshToken,
                            userId: uid, email: email, expiresIn: expiresIn)
                return .success(userId: uid)
            }

            // Email confirmation required (confirmation_sent_at present, no access_token)
            return .confirmationRequired()

        } catch {
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async -> SupabaseAuthResult {
        do {
            let body: [String: Any] = ["email": email, "password": password]
            let req = try makeRequest(path: "/auth/v1/token?grant_type=password",
                                      method: "POST", body: body)
            let (data, response) = try await URLSession.shared.data(for: req)

            guard let http = response as? HTTPURLResponse else {
                return .failure("No response from server.")
            }

            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

            guard http.statusCode == 200 else {
                let raw = json["error_description"] as? String
                    ?? json["msg"] as? String
                    ?? json["message"] as? String
                    ?? ""
                let msg = raw.lowercased().contains("invalid login") || raw.lowercased().contains("credentials")
                    ? "Incorrect email or password."
                    : (raw.isEmpty ? "Sign-in failed (status \(http.statusCode))." : raw)
                return .failure(msg)
            }

            guard let accessToken  = json["access_token"] as? String,
                  let refreshToken = json["refresh_token"] as? String,
                  let userObj      = json["user"] as? [String: Any],
                  let uid          = userObj["id"] as? String else {
                return .failure("Unexpected response from server.")
            }

            let expiresIn = json["expires_in"] as? Double ?? 3600
            saveSession(accessToken: accessToken, refreshToken: refreshToken,
                        userId: uid, email: email, expiresIn: expiresIn)
            return .success(userId: uid)

        } catch {
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        if let token = loadFromKeychain(key: kAccessToken) {
            do {
                let req = try makeRequest(path: "/auth/v1/logout", method: "POST",
                                          accessToken: token)
                _ = try? await URLSession.shared.data(for: req)
            } catch { /* best-effort */ }
        }
        clearKeychain()
        isSignedIn = false
        userId    = nil
        userEmail = nil
    }

    // MARK: - Token Refresh

    /// Returns `true` if a valid token is available (refreshing if necessary).
    func refreshTokenIfNeeded() async -> Bool {
        // Check expiry with 60 s buffer
        if let expiresAtStr = loadFromKeychain(key: kExpiresAt),
           let expiresAt    = Double(expiresAtStr),
           Date().timeIntervalSince1970 < expiresAt - 60 {
            return true
        }

        guard let refreshToken = loadFromKeychain(key: kRefreshToken) else {
            clearKeychain(); isSignedIn = false; userId = nil; userEmail = nil
            return false
        }

        do {
            let body: [String: Any] = ["refresh_token": refreshToken]
            let req = try makeRequest(path: "/auth/v1/token?grant_type=refresh_token",
                                      method: "POST", body: body)
            let (data, response) = try await URLSession.shared.data(for: req)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json         = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newAccess    = json["access_token"] as? String,
                  let newRefresh   = json["refresh_token"] as? String,
                  let userObj      = json["user"] as? [String: Any],
                  let uid          = userObj["id"] as? String else {
                clearKeychain(); isSignedIn = false; userId = nil; userEmail = nil
                return false
            }

            let email      = userObj["email"] as? String ?? userEmail ?? ""
            let expiresIn  = json["expires_in"] as? Double ?? 3600
            saveSession(accessToken: newAccess, refreshToken: newRefresh,
                        userId: uid, email: email, expiresIn: expiresIn)
            return true

        } catch {
            clearKeychain(); isSignedIn = false; userId = nil; userEmail = nil
            return false
        }
    }

    // MARK: - Token Access

    /// Returns a valid access token for the current session, refreshing it if close to expiry.
    /// Returns `nil` when the user is not signed in or the session cannot be refreshed.
    func validAccessToken() async -> String? {
        guard isSignedIn else { return nil }
        let refreshed = await refreshTokenIfNeeded()
        guard refreshed else { return nil }
        return loadFromKeychain(key: kAccessToken)
    }

    // MARK: - Profile Upsert

    func upsertProfile(_ user: UserProfile) async {
        guard await refreshTokenIfNeeded(),
              let token = loadFromKeychain(key: kAccessToken) else { return }

        let body: [String: Any] = [
            "user_id":          user.id,
            "first_name":       user.firstName,
            "display_name":     user.displayName,
            "avatar":           user.avatar,
            "goals":            user.goals,
            "xp":               user.xp,
            "level":            user.level,
            "streak":           user.streak,
            "longest_streak":   user.longestStreak,
            "last_active_date": user.lastActiveDate,
            "completed_lessons": user.completedLessons
        ]

        do {
            let req = try makeRequest(
                path: "/rest/v1/profiles?on_conflict=user_id",
                method: "POST",
                body: body,
                accessToken: token,
                extraHeaders: ["Prefer": "resolution=merge-duplicates"]
            )
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode < 300 {
                print("✅ Supabase profile upserted")
            } else if let http = response as? HTTPURLResponse {
                print("⚠️ Supabase upsert status: \(http.statusCode)")
            }
        } catch {
            print("❌ Supabase upsert error: \(error)")
        }
    }

    // MARK: - Profile Fetch

    /// Returns a partial `UserProfile` hydrated from the remote Supabase profiles row.
    func fetchProfile() async -> UserProfile? {
        guard await refreshTokenIfNeeded(),
              let token = loadFromKeychain(key: kAccessToken),
              let uid   = userId else { return nil }

        do {
            let req = try makeRequest(
                path: "/rest/v1/profiles?user_id=eq.\(uid)&select=*",
                method: "GET",
                accessToken: token
            )
            let (data, response) = try await URLSession.shared.data(for: req)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            let rows = try JSONDecoder().decode([SupabaseProfileRow].self, from: data)
            guard let row = rows.first else { return nil }

            // Build a partial UserProfile from the remote row; caller merges fields they want
            return UserProfile(
                id: row.userId,
                firstName: row.firstName,
                lastName: "",
                displayName: row.displayName,
                email: userEmail,
                avatar: row.avatar,
                goals: row.goals,
                xp: row.xp,
                level: row.level,
                streak: row.streak,
                longestStreak: row.longestStreak,
                lastActiveDate: row.lastActiveDate,
                badges: [],
                completedLessons: row.completedLessons,
                memoryVerses: [],
                onboardingCompleted: true,
                loggedIn: true,
                streakFreezes: 0,
                freezeUsedDates: [],
                activeDates: [],
                chaptersRead: [],
                weeklyActivity: WeeklyActivity()
            )
        } catch {
            print("❌ Supabase fetchProfile error: \(error)")
            return nil
        }
    }

    // MARK: - Session Helpers

    private func saveSession(accessToken: String, refreshToken: String,
                             userId uid: String, email: String, expiresIn: Double) {
        let expiresAt = Date().timeIntervalSince1970 + expiresIn
        saveToKeychain(key: kAccessToken,  value: accessToken)
        saveToKeychain(key: kRefreshToken, value: refreshToken)
        saveToKeychain(key: kUserId,       value: uid)
        saveToKeychain(key: kUserEmail,    value: email)
        saveToKeychain(key: kExpiresAt,    value: String(expiresAt))
        userId    = uid
        userEmail = email
        isSignedIn = true
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(key: String, value: String) {
        let data = Data(value.utf8)
        let deleteQuery: [String: Any] = [
            kSecClass    as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.reforged.app"
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.reforged.app",
            kSecValueData   as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.reforged.app",
            kSecReturnData  as String: true,
            kSecMatchLimit  as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func clearKeychain() {
        for key in [kAccessToken, kRefreshToken, kUserId, kUserEmail, kExpiresAt] {
            let query: [String: Any] = [
                kSecClass       as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: "com.reforged.app"
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}
