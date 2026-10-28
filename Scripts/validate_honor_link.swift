import Foundation

@main
struct HonorLinkValidation {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }
    static func roundTrip<T: Codable & Equatable>(_ value: T) throws {
        let data = try HonorLinkJSON.encode(value)
        let decoded = try HonorLinkJSON.decode(T.self, from: data)
        check(decoded == value, "Round trip failed for \(T.self)")
    }
    static func main() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let verse = LinkMemoryVerse(reference: "Romans 8:1", text: "There is therefore now no condemnation…",
            translation: "ESV", level: 3, nextReview: "2027-01-16")
        try roundTrip(verse)
        try roundTrip([verse])
        try roundTrip([LinkMemoryVerse]())
        try roundTrip(LinkReading(day: "2027-01-15", reference: "Romans 8:1-17", title: "Hope"))
        try roundTrip(LinkReading(day: "2027-01-15", reference: "Romans 8", title: nil))
        try roundTrip(Optional<LinkReading>.none)
        let protection = LinkProtection(active: true, since: now, updatedAt: now)
        try roundTrip(protection)
        try roundTrip(LinkProtection(active: false, since: nil, updatedAt: now))
        let partner = LinkPartner(name: "Sam", phone: "+15555550123", updatedAt: now, writer: "honor")
        try roundTrip(partner)
        try roundTrip(LinkPartner(name: "", phone: "", updatedAt: now, writer: "reforged"))
        try roundTrip(Optional<LinkPartner>.none)
        try roundTrip(now)
        try roundTrip(1)
        try roundTrip(["2027-01-15"])
        try roundTrip(["2027-01-15": 4])
        try roundTrip(["2027-01-15": ["reading", "memory", "lesson"]])
        let json = String(data: try HonorLinkJSON.encode(protection), encoding: .utf8)!
        check(json.contains("2027-01-15T08:00:00Z"), "Dates must be ISO 8601 strings")
        let honorFixture = Data(#"{"active":true,"since":"2027-01-15T08:00:00Z","updatedAt":"2027-01-15T08:00:00Z"}"#.utf8)
        let fixture = try HonorLinkJSON.decode(LinkProtection.self, from: honorFixture)
        check(fixture == protection, "Honor fixture must decode")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let today = calendar.startOfDay(for: now)
        let oldest = calendar.date(byAdding: .day, value: -89, to: today)!
        let expired = calendar.date(byAdding: .day, value: -90, to: today)!
        let future = calendar.date(byAdding: .day, value: 1, to: today)!
        let todayKey = HonorLinkJSON.dayKey(now, calendar: calendar)
        let oldestKey = HonorLinkJSON.dayKey(oldest, calendar: calendar)
        let activity = HonorLinkJSON.recentActivity([
            todayKey: ["memory", "reading", "memory", "private"], oldestKey: ["lesson"],
            HonorLinkJSON.dayKey(expired, calendar: calendar): ["reading"],
            HonorLinkJSON.dayKey(future, calendar: calendar): ["reading"], "invalid": ["reading"]
        ], now: now, calendar: calendar)
        check(activity.count == 2, "Keep exactly the valid 90-day window")
        check(activity[todayKey] == ["memory", "reading"], "Only public activity raw values, no duplicates")
        check(activity[oldestKey] == ["lesson"], "Include day 89")
        let midnightUTC = ISO8601DateFormatter().date(from: "2026-03-09T00:30:00Z")!
        check(HonorLinkJSON.dayKey(midnightUTC, calendar: calendar) == "2026-03-08", "Use local calendar day across DST")
        check(HonorLinkJSON.newerPartner(partner, than: nil) == partner, "Adopt initial shared partner")
        check(HonorLinkJSON.newerPartner(partner, than: partner) == nil, "Do not echo equal timestamps")
        var newer = partner
        newer.updatedAt = now.addingTimeInterval(1)
        check(HonorLinkJSON.newerPartner(partner, than: newer) == nil, "Older partner cannot replace local edits")
        check(HonorLinkJSON.newerPartner(newer, than: partner) == newer, "Newer writer wins")
        print("Honor link validation passed (all v1 types, fixtures, dates, trimming, partner ordering)")
    }
}
