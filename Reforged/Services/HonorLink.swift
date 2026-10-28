import Foundation

// v1 wire contract. Only version and partner have two writers; Honor keys are read-only here.
enum HonorLinkKeys {
    static let suite = "group.com.reforged.app"
    static let changed = "com.reforged.link.changed"
    static let version = "link.v1.version"
    static let memoryVerses = "link.v1.reforged.memoryVerses"
    static let todayReading = "link.v1.reforged.todayReading"
    static let activityKinds = "link.v1.reforged.activityKinds"
    static let installedAt = "link.v1.honor.installedAt"
    static let protection = "link.v1.honor.protection"
    static let faithfulDays = "link.v1.honor.faithfulDays"
    static let fleeCountByDay = "link.v1.honor.fleeCountByDay"
    static let partner = "link.v1.partner"
    // Local coordination metadata, deliberately outside the wire contract.
    static let ownsBlocking = "honorOwnsBlocking"
    static let prompted = "honorBlockingPrompted_v1"
    static let localPartner = "honorLinkLocalPartner_v1"
}

struct LinkMemoryVerse: Codable, Equatable {
    var reference: String
    var text: String
    var translation: String
    var level: Int
    var nextReview: String
}
struct LinkReading: Codable, Equatable {
    var day: String
    var reference: String
    var title: String?
}
struct LinkProtection: Codable, Equatable {
    var active: Bool
    var since: Date?
    var updatedAt: Date
}
struct LinkPartner: Codable, Equatable {
    var name: String
    var phone: String
    var updatedAt: Date
    var writer: String
}

enum HonorLinkJSON {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    static func recentActivity(_ values: [String: [String]], now: Date = Date(),
                               calendar: Calendar = .current) -> [String: [String]] {
        let today = calendar.startOfDay(for: now)
        let days = Set((0..<90).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .map { dayKey($0, calendar: calendar) })
        return values.filter { days.contains($0.key) }.mapValues {
            Array(Set($0.filter { ["reading", "memory", "lesson"].contains($0) })).sorted()
        }
    }
    static func newerPartner(_ remote: LinkPartner?, than local: LinkPartner?) -> LinkPartner? {
        guard let remote, ["reforged", "honor"].contains(remote.writer),
              local == nil || remote.updatedAt > local!.updatedAt else { return nil }
        return remote
    }
}

#if canImport(UIKit)
import UIKit
import Combine
import ManagedSettings
import DeviceActivity

@MainActor
final class HonorLink: ObservableObject {
    static let shared = HonorLink()
    // TODO: Replace with Honor's published App Store product URL when assigned.
    static let appStoreURL = URL(string: "https://apps.apple.com/")!
    @Published private(set) var isHonorInstalled = false
    @Published private(set) var protection: LinkProtection?
    @Published private(set) var installedAt: Date?
    @Published private(set) var faithfulDays: [String] = []
    @Published private(set) var fleeCountByDay: [String: Int] = [:]
    enum Prompt: String, Identifiable {
        case handoff, restore
        var id: String { rawValue }
    }
    @Published var prompt: Prompt?
    private var offeredRestoreThisLaunch = false
    private let defaults = UserDefaults(suiteName: HonorLinkKeys.suite)
    private var started = false
    private var dayObserver: NSObjectProtocol?

    static var blockingIsPaused: Bool {
        UserDefaults(suiteName: HonorLinkKeys.suite)?.bool(forKey: HonorLinkKeys.ownsBlocking) == true
    }
    private init() {}

    func start() {
        guard !started else { return }
        started = true
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(), { _, _, _, _, _ in
                Task { @MainActor in HonorLink.shared.reload() }
            }, HonorLinkKeys.changed as CFString, nil, .deliverImmediately)
        dayObserver = NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged,
            object: nil, queue: .main) { _ in
                Task { @MainActor in HonorLink.shared.publishReading() }
            }
        write(1, key: HonorLinkKeys.version)
        reload()
        publishMemoryVerses(AppState.shared.memoryVerses)
        publishReading()
        Self.publishActivity(ReadingStreakManager.shared.activityKindsByDate.mapValues { $0.map(\.rawValue) })
    }

    private func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? HonorLinkJSON.decode(type, from: data)
    }
    private nonisolated static func store<T: Encodable>(_ value: T, key: String) {
        guard let data = try? HonorLinkJSON.encode(value) else { return }
        UserDefaults(suiteName: HonorLinkKeys.suite)?.set(data, forKey: key)
        notify()
    }
    private func write<T: Encodable>(_ value: T, key: String) {
        Self.store(value, key: key)
    }
    private nonisolated static func notify() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(HonorLinkKeys.changed as CFString), nil, nil, true)
    }
    func reload() {
        isHonorInstalled = UIApplication.shared.canOpenURL(URL(string: "reforgedshield://")!)
        installedAt = read(Date.self, key: HonorLinkKeys.installedAt)
        protection = read(LinkProtection.self, key: HonorLinkKeys.protection)
        faithfulDays = read([String].self, key: HonorLinkKeys.faithfulDays) ?? []
        fleeCountByDay = read([String: Int].self, key: HonorLinkKeys.fleeCountByDay) ?? [:]
        let local = read(LinkPartner.self, key: HonorLinkKeys.localPartner)
        if let partner = HonorLinkJSON.newerPartner(read(LinkPartner.self, key: HonorLinkKeys.partner), than: local) {
            if let data = try? HonorLinkJSON.encode(partner) {
                defaults?.set(data, forKey: HonorLinkKeys.localPartner)
            }
            AccountabilityPartnerService.shared.adoptHonorPartner(partner)
        } else if local == nil {
            // Migrate existing partner only when no shared record exists.
            let service = AccountabilityPartnerService.shared
            if service.hasPartner { publishPartner(name: service.partnerName, phone: service.partnerPhone) }
        }
        if Self.blockingIsPaused {
            if (!isHonorInstalled || protection?.active == false), !offeredRestoreThisLaunch {
                offeredRestoreThisLaunch = true
                prompt = .restore
            }
        } else if isHonorInstalled, protection?.active == true,
                  defaults?.bool(forKey: HonorLinkKeys.prompted) != true {
            prompt = .handoff
        }
    }
    func openFlee() { open("flee") }
    func openCheckin() { open("checkin") }
    func openPlan() { open("plan") }
    func openHonor() { open("plan") }
    private func open(_ route: String) {
        let url = URL(string: "reforgedshield://\(route)")!
        guard UIApplication.shared.canOpenURL(url) else {
            UIApplication.shared.open(Self.appStoreURL)
            return
        }
        UIApplication.shared.open(url)
    }
    @discardableResult func handOffSOS() -> Bool {
        guard UIApplication.shared.canOpenURL(URL(string: "reforgedshield://")!) else { return false }
        openFlee()
        return true
    }
    nonisolated static func publishActivity(_ values: [String: [String]]) {
        store(HonorLinkJSON.recentActivity(values), key: HonorLinkKeys.activityKinds)
    }
    func publishMemoryVerses(_ verses: [MemoryVerse]) {
        let mapped = verses.sorted {
            $0.nextReviewDate == $1.nextReviewDate ? $0.reference < $1.reference : $0.nextReviewDate < $1.nextReviewDate
        }.prefix(50).map { verse in
            let translation = verse.translation ?? "ESV"
            return LinkMemoryVerse(reference: verse.reference,
                text: translation.uppercased() == "ESV" ? (verse.esvText ?? verse.text) : verse.text,
                translation: translation, level: verse.level,
                nextReview: HonorLinkJSON.dayKey(verse.nextReviewDate))
        }
        write(mapped, key: HonorLinkKeys.memoryVerses)
    }
    func publishReading() {
        let plans = ReadingPlanService.shared
        guard let plan = plans.activePlan, let entry = plans.activeEntry else {
            defaults?.removeObject(forKey: HonorLinkKeys.todayReading)
            Self.notify()
            return
        }
        write(LinkReading(day: HonorLinkJSON.dayKey(Date()), reference: entry.scriptureReference,
            title: plan.name), key: HonorLinkKeys.todayReading)
    }
    func publishPartner(name: String, phone: String) {
        let partner = LinkPartner(name: name, phone: phone, updatedAt: Date(), writer: "reforged")
        if let data = try? HonorLinkJSON.encode(partner) {
            defaults?.set(data, forKey: HonorLinkKeys.localPartner)
        }
        write(partner, key: HonorLinkKeys.partner)
    }
    func declineHandoff() {
        defaults?.set(true, forKey: HonorLinkKeys.prompted)
        prompt = nil
    }
    func acceptHandoff() {
        // Consent applies only while the installed app reports active protection.
        reload()
        guard isHonorInstalled, protection?.active == true else { prompt = nil; return }
        defaults?.set(true, forKey: HonorLinkKeys.prompted)
        defaults?.set(true, forKey: HonorLinkKeys.ownsBlocking)
        ScheduledBlockingService.shared.pauseForHonor()
        FocusSessionService.shared.pauseForHonor()
        SocialLimitService.shared.pauseForHonor()
        UnlockGateService.shared.pauseForHonor()
        ManagedSettingsStore(named: .init("reforged-shield")).clearAllSettings()
        prompt = nil
    }
    func restoreBlocking() {
        defaults?.set(false, forKey: HonorLinkKeys.ownsBlocking)
        FocusBlockingService.shared.applyBlockingIfEnabled()
        ScheduledBlockingService.shared.reconcileNow()
        SocialLimitService.shared.refresh()
        UnlockGateService.shared.refresh()
        // A handed-off focus session was ended; never resurrect an expired session.
        prompt = nil
    }
}
#endif
