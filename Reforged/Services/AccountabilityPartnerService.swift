import SwiftUI
import FamilyControls
import UserNotifications

// MARK: - Accountability Partner Service
//
// The honest accountability surface iOS allows a third-party app: a tamper log
// the user can't erase without the partner's PIN, plus user-sent reports.
//
//   • Every protection-lowering change is recorded as a TamperEvent — even
//     PIN-authorized ones (the partner entered the PIN; the log shows what for).
//   • Revoking Screen Time authorization in Settings is detected on foreground
//     by diffing against the last known status.
//   • Reports/alerts are PRE-COMPOSED messages the user sends themself (iOS
//     apps cannot silently send SMS/email). CloudKit partner push is a possible
//     phase 2; app deletion is undetectable client-side.
//
// Partner contact + log live in the App Group so future extensions can read them.

struct TamperEvent: Codable, Identifiable {
    enum Kind: String, Codable {
        case protectionLowered
        case lockRemoved
        case authorizationRevoked
        case scheduleDisabled
        case limitDisabled
        case gateDisabled
        case sessionEndedEarly

        var title: String {
            switch self {
            case .protectionLowered:    return "Protection lowered"
            case .lockRemoved:          return "Accountability lock removed"
            case .authorizationRevoked: return "Screen Time access revoked"
            case .scheduleDisabled:     return "Schedule disabled"
            case .limitDisabled:        return "Daily limit disabled"
            case .gateDisabled:         return "Scripture unlock gate disabled"
            case .sessionEndedEarly:    return "Strict session ended early"
            }
        }
    }

    var id = UUID()
    let date: Date
    let kind: Kind
    let detail: String
}

enum AccountabilityPartnerKeys {
    static let suite            = "group.com.reforged.app"
    static let partnerName      = "accountabilityPartnerName"
    static let partnerPhone     = "accountabilityPartnerPhone"
    static let tamperEventsData = "tamperEventsData"
    static let lastAuthStatus   = "lastKnownAuthStatusApproved"
    static let maxEvents        = 200

    // Weekly report reminder. Opt-in: `reminderEnabled` defaults false, per the
    // app-wide rule that reminder toggles are never on without explicit consent.
    static let reminderEnabled  = "partnerReportReminderEnabled"
    static let reminderDay      = "partnerReportReminderDay"     // 1 = Sunday … 7 = Saturday
    static let reminderHour     = "partnerReportReminderHour"
    static let reminderMinute   = "partnerReportReminderMinute"
    static let reminderPrompted = "partnerReportReminderPrompted"
    static let defaultDay       = 1   // Sunday
    static let defaultHour      = 19  // 7:00 PM
}

@MainActor
final class AccountabilityPartnerService: ObservableObject {

    static let shared = AccountabilityPartnerService()

    @Published var partnerName: String = "" {
        didSet {
            defaults?.set(partnerName, forKey: AccountabilityPartnerKeys.partnerName)
            // The reminder body names the partner, and clearing the name drops the
            // reminder entirely — so it has to be rebuilt when the name changes.
            rescheduleReminder()
        }
    }
    @Published var partnerPhone: String = "" {
        didSet { defaults?.set(partnerPhone, forKey: AccountabilityPartnerKeys.partnerPhone) }
    }
    @Published private(set) var tamperLog: [TamperEvent] = []

    /// Weekly nudge to actually send the report. Off unless the user opts in.
    @Published var reminderEnabled: Bool = false {
        didSet {
            defaults?.set(reminderEnabled, forKey: AccountabilityPartnerKeys.reminderEnabled)
            rescheduleReminder()
        }
    }
    /// 1 = Sunday … 7 = Saturday.
    @Published var reminderDay: Int = AccountabilityPartnerKeys.defaultDay {
        didSet {
            defaults?.set(reminderDay, forKey: AccountabilityPartnerKeys.reminderDay)
            rescheduleReminder()
        }
    }
    @Published var reminderTime: Date = Date() {
        didSet {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            defaults?.set(comps.hour ?? AccountabilityPartnerKeys.defaultHour, forKey: AccountabilityPartnerKeys.reminderHour)
            defaults?.set(comps.minute ?? 0, forKey: AccountabilityPartnerKeys.reminderMinute)
            rescheduleReminder()
        }
    }
    /// Whether the one-time "want a weekly reminder?" ask has been shown.
    @Published var hasPromptedForReminder: Bool = false {
        didSet { defaults?.set(hasPromptedForReminder, forKey: AccountabilityPartnerKeys.reminderPrompted) }
    }

    private let defaults = UserDefaults(suiteName: AccountabilityPartnerKeys.suite)
    /// Guards the `didSet` reschedulers while `init` is populating from storage.
    private var isLoading = true

    private init() {
        partnerName = defaults?.string(forKey: AccountabilityPartnerKeys.partnerName) ?? ""
        partnerPhone = defaults?.string(forKey: AccountabilityPartnerKeys.partnerPhone) ?? ""
        reminderEnabled = defaults?.bool(forKey: AccountabilityPartnerKeys.reminderEnabled) ?? false
        reminderDay = defaults?.object(forKey: AccountabilityPartnerKeys.reminderDay) as? Int
            ?? AccountabilityPartnerKeys.defaultDay
        hasPromptedForReminder = defaults?.bool(forKey: AccountabilityPartnerKeys.reminderPrompted) ?? false

        var comps = DateComponents()
        comps.hour = defaults?.object(forKey: AccountabilityPartnerKeys.reminderHour) as? Int
            ?? AccountabilityPartnerKeys.defaultHour
        comps.minute = defaults?.object(forKey: AccountabilityPartnerKeys.reminderMinute) as? Int ?? 0
        reminderTime = Calendar.current.date(from: comps) ?? Date()

        loadLog()
        isLoading = false
    }

    var hasPartner: Bool { !partnerName.trimmingCharacters(in: .whitespaces).isEmpty }

    /// The weekly reminder is built by `NotificationManager.scheduleDailyReminder()`,
    /// the single source of truth for reminder scheduling — never schedule it here.
    private func rescheduleReminder() {
        guard !isLoading else { return }
        NotificationManager.shared.scheduleDailyReminder()
    }

    // MARK: - Tamper Log

    func record(_ kind: TamperEvent.Kind, detail: String) {
        var log = tamperLog
        log.append(TamperEvent(date: Date(), kind: kind, detail: detail))
        if log.count > AccountabilityPartnerKeys.maxEvents {
            log.removeFirst(log.count - AccountabilityPartnerKeys.maxEvents)
        }
        tamperLog = log
        persistLog()
    }

    /// The log is part of the accountability surface — clearing it requires the
    /// partner's PIN, same as lowering protection.
    @discardableResult
    func clearLog(pin: String) -> Bool {
        guard AccountabilityLockService.shared.verifyPIN(pin) else { return false }
        clearLogVerified()
        return true
    }

    /// Clears the log when the partner PIN was already verified by the caller
    /// (e.g. PINEntryView's verify flow).
    func clearLogVerified() {
        tamperLog = []
        persistLog()
    }

    /// Events dated within calendar day `day` (used by the streak computation).
    func events(on day: Date, calendar: Calendar = .current) -> [TamperEvent] {
        tamperLog.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    // MARK: - SOS Uses

    /// Day-keyed count of "Tempted" SOS uses — a POSITIVE stat (reaching for
    /// help), charted alongside shield hits in the insights view. Same shape
    /// and 60-day retention as `shieldHitsByDay`.
    func recordSOSUse() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let dayKey = formatter.string(from: Date())

        var uses: [String: Int] = [:]
        if let data = defaults?.data(forKey: "sosUsesByDay"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            uses = decoded
        }
        uses[dayKey, default: 0] += 1
        if let cutoffDate = Calendar.current.date(byAdding: .day, value: -60, to: Date()) {
            let cutoff = formatter.string(from: cutoffDate)
            uses = uses.filter { $0.key >= cutoff }
        }
        if let encoded = try? JSONEncoder().encode(uses) {
            defaults?.set(encoded, forKey: "sosUsesByDay")
        }
    }

    // MARK: - Authorization Revocation

    /// Call on app foreground: if Screen Time access flipped from approved to
    /// not-approved, all shields silently died — record it and tell the user.
    ///
    /// `AuthorizationCenter` reports `.notDetermined` for a moment right at
    /// process launch (same race `FocusBlockingService.refreshAuthorizationStatus`
    /// works around), and this runs on `scenePhase == .active`, which fires inside
    /// that window. Reading it once there turns every cold launch into a false
    /// "protection was turned off" alarm, so poll until the status settles and
    /// only persist a reading we actually trust.
    func checkAuthorizationRevocation() {
        Task { await checkAuthorizationRevocationSettled() }
    }

    private func checkAuthorizationRevocationSettled() async {
        let wasApproved = defaults?.bool(forKey: AccountabilityPartnerKeys.lastAuthStatus) ?? false

        var status = AuthorizationCenter.shared.authorizationStatus
        // Only a downgrade from approved needs settling, and revocation surfaces
        // as `.notDetermined` (not `.denied`), so that reading can't be trusted
        // until it's had time to resolve. An unchanged status needs no wait.
        if wasApproved && status != .approved {
            for _ in 0..<12 {
                try? await Task.sleep(nanoseconds: 250_000_000)
                status = AuthorizationCenter.shared.authorizationStatus
                if status == .approved { break }
            }
        }

        let approved = (status == .approved)
        defaults?.set(approved, forKey: AccountabilityPartnerKeys.lastAuthStatus)

        if wasApproved && !approved {
            record(.authorizationRevoked, detail: "Screen Time access for Reforged was turned off in Settings — all blocking stopped.")
            scheduleRevocationNotification()
        }
    }

    private func scheduleRevocationNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Shield protection was turned off"
        content.body = "Reforged's Screen Time access was revoked in Settings, so nothing is being blocked. Open Reforged to re-enable your shield."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "reforged.authrevoked.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Reports

    /// Pre-composed weekly report the user sends to their partner. Honest about
    /// what iOS lets us see: protection status, streak, hits, and any tampering.
    func weeklyReportText() -> String {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        var lines: [String] = ["My Reforged shield report for this week:"]

        let status = FocusBlockingService.shared.statusDescription
        lines.append("• Protection: \(status)")

        let streak = ShieldStreakService.shared.currentStreak
        if streak > 0 {
            lines.append("• Protected-days streak: \(streak) day\(streak == 1 ? "" : "s")")
        }

        let hits = shieldHitCount(since: weekAgo)
        lines.append("• Temptations turned away by the shield: \(hits)")

        let weekEvents = tamperLog.filter { $0.date >= weekAgo }
        if weekEvents.isEmpty {
            lines.append("• No protection changes this week.")
        } else {
            lines.append("• Protection changes this week:")
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE h:mm a"
            for event in weekEvents.suffix(10) {
                lines.append("   – \(formatter.string(from: event.date)): \(event.kind.title)")
            }
        }

        lines.append("Sent from Reforged — thanks for keeping me accountable.")
        return lines.joined(separator: "\n")
    }

    /// Sum of day-keyed shield hits (written by the shield extension) since `date`.
    private func shieldHitCount(since date: Date) -> Int {
        guard let data = defaults?.data(forKey: "shieldHitsByDay"),
              let hits = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return 0
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoff = formatter.string(from: date)
        return hits.filter { $0.key >= cutoff }.values.reduce(0, +)
    }

    // MARK: - Persistence

    private func persistLog() {
        if let data = try? JSONEncoder().encode(tamperLog) {
            defaults?.set(data, forKey: AccountabilityPartnerKeys.tamperEventsData)
        }
    }

    private func loadLog() {
        guard let data = defaults?.data(forKey: AccountabilityPartnerKeys.tamperEventsData),
              let decoded = try? JSONDecoder().decode([TamperEvent].self, from: data) else {
            return
        }
        tamperLog = decoded
    }
}
