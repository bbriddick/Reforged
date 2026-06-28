import Foundation
import UserNotifications

// MARK: - Model

struct WeeklyCheckin: Codable, Identifiable {
    let id: String
    let title: String
    let message: String
    let frequency: String
    let dayOfWeek: String
    let time: String
    let category: String

    enum CodingKeys: String, CodingKey {
        case id, title, message, frequency, time, category
        case dayOfWeek = "day_of_week"
    }
}

// MARK: - Service

enum WeeklyCheckinService {
    private static let supabaseURL = "https://ztklhghgnpmmjtznphfs.supabase.co"
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp0a2xoZ2hnbnBtbWp0em5waGZzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjczODgyMTcsImV4cCI6MjA4Mjk2NDIxN30._zL6VW5SJzJnXKG8cPIsPS75697dfvUMk0pSjrN7UZo"

    static func fetchAll() async throws -> [WeeklyCheckin] {
        var comps = URLComponents(string: "\(supabaseURL)/rest/v1/weekly_checkins")!
        comps.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "day_of_week.asc,time.asc")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode([WeeklyCheckin].self, from: data)
    }

    static func fetch(day: String) async throws -> [WeeklyCheckin] {
        var comps = URLComponents(string: "\(supabaseURL)/rest/v1/weekly_checkins")!
        comps.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "day_of_week", value: "eq.\(day)"),
            URLQueryItem(name: "order", value: "time.asc")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode([WeeklyCheckin].self, from: data)
    }

    // MARK: - Local Cache

    private static let cacheKey = "weeklyCheckins.cache"

    /// Returns the most recently cached check-in list, or an empty array if none.
    static func cachedCheckins() -> [WeeklyCheckin] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let checkins = try? JSONDecoder().decode([WeeklyCheckin].self, from: data) else {
            return []
        }
        return checkins
    }

    private static func cache(_ checkins: [WeeklyCheckin]) {
        if let data = try? JSONEncoder().encode(checkins) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    // MARK: - Scheduling

    /// Fetch fresh check-ins from Supabase, cache them, then schedule exactly one
    /// weekly notification at the user's chosen day and time.
    static func fetchAndSchedule() async {
        do {
            let checkins = try await fetchAll()
            cache(checkins)
            await NotificationManager.shared.scheduleWeeklyCheckins(checkins)
        } catch {
            // Network unavailable — reschedule from whatever is cached.
            let cached = cachedCheckins()
            if !cached.isEmpty {
                await NotificationManager.shared.scheduleWeeklyCheckins(cached)
            }
            debugLog("[WeeklyCheckinService] Failed to fetch check-ins: \(error)")
        }
    }

    /// Re-schedule the weekly check-in from the local cache without hitting the network.
    /// Called when the user changes the day/time/enabled settings.
    static func rescheduleFromCache() async {
        let checkins = cachedCheckins()
        guard !checkins.isEmpty else { return }
        await NotificationManager.shared.scheduleWeeklyCheckins(checkins)
    }
}
