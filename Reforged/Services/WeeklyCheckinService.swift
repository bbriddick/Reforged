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

    /// Fetch and schedule all check-ins as weekly repeating notifications.
    static func fetchAndSchedule() async {
        do {
            let checkins = try await fetchAll()
            await NotificationManager.shared.scheduleWeeklyCheckins(checkins)
        } catch {
            print("[WeeklyCheckinService] Failed to fetch check-ins: \(error)")
        }
    }
}
