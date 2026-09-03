import SwiftUI
import Charts
import DeviceActivity
import FamilyControls

// Must match the context declared in ReforgedReport/ReforgedReportExtension.swift.
private extension DeviceActivityReport.Context {
    static let timeReclaimed = Self("timeReclaimed")
}

// MARK: - Shield Insights
//
// "Temptations turned away" — the day-keyed shield-hit counts written by the
// shield extension, alongside SOS uses (a positive stat: moments the user
// reached for help). Framed as victories, never shame metrics.

struct ShieldInsightsView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var streakService = ShieldStreakService.shared

    private enum Range: String, CaseIterable, Identifiable {
        case week = "7 days"
        case month = "30 days"

        var id: String { rawValue }
        var days: Int { self == .week ? 7 : 30 }
    }

    private struct DayStat: Identifiable {
        let day: Date
        let hits: Int
        let sosUses: Int
        var id: Date { day }
    }

    @State private var range: Range = .week

    private let defaults = UserDefaults(suiteName: "group.com.reforged.app")

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                statTiles

                chartCard

                if SocialLimitService.shared.isEnabled && SocialLimitService.shared.hasSelection {
                    usageReportCard
                }

                framingFooter
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Shield Insights")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { streakService.recompute() }
    }

    // MARK: - Data

    private func loadCounts(_ key: String) -> [String: Int] {
        guard let data = defaults?.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private var stats: [DayStat] {
        let hits = loadCounts("shieldHitsByDay")
        let sos = loadCounts("sosUsesByDay")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<range.days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = formatter.string(from: day)
            return DayStat(day: day, hits: hits[key] ?? 0, sosUses: sos[key] ?? 0)
        }
    }

    // MARK: - Tiles

    private var statTiles: some View {
        let data = stats
        let totalHits = data.reduce(0) { $0 + $1.hits }
        let totalSOS = data.reduce(0) { $0 + $1.sosUses }

        return HStack(spacing: 12) {
            statTile(value: "\(streakService.currentStreak)",
                     label: "protected days",
                     icon: "flame.fill", color: Color.reforgedGold)
            statTile(value: "\(totalHits)",
                     label: "turned away",
                     icon: "shield.fill", color: Color(red: 0.12, green: 0.22, blue: 0.48))
            statTile(value: "\(totalSOS)",
                     label: "times you paused",
                     icon: "hand.raised.brakesignal", color: Color(red: 0.20, green: 0.55, blue: 0.55))
        }
    }

    private func statTile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Temptations turned away")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            Chart(stats) { stat in
                BarMark(
                    x: .value("Day", stat.day, unit: .day),
                    y: .value("Turned away", stat.hits)
                )
                .foregroundStyle(Color.reforgedGold)
                .cornerRadius(3)

                if stat.sosUses > 0 {
                    PointMark(
                        x: .value("Day", stat.day, unit: .day),
                        y: .value("Paused", stat.hits)
                    )
                    .symbol(.circle)
                    .foregroundStyle(Color(red: 0.20, green: 0.55, blue: 0.55))
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: range == .week)
                }
            }

            HStack(spacing: 14) {
                legendDot(color: Color.reforgedGold, label: "Shield encounters")
                legendDot(color: Color(red: 0.20, green: 0.55, blue: 0.55), label: "You hit \u{201C}I'm tempted\u{201D}")
            }
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
    }

    // MARK: - Real Usage (DeviceActivityReport)

    /// Real screen-time for the social selection, rendered by the sandboxed
    /// ReforgedReport extension. Best-effort: the report API is known to load
    /// slowly or fail intermittently on iOS 17+, so it sits in a fixed-height
    /// container with honest caveat copy — everything above works without it.
    private var usageReportCard: some View {
        let selection = FocusBlockingService.shared.socialSelection
        let today = Calendar.current.startOfDay(for: Date())
        let filter = DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: today, end: Date())),
            users: .all,
            devices: .init([.iPhone, .iPad]),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens
        )

        return VStack(alignment: .leading, spacing: 10) {
            Text("Social time today (measured)")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            DeviceActivityReport(.timeReclaimed, filter: filter)
                .frame(height: 110)

            Text("Measured by iOS Screen Time. If this stays blank, the system report service is being slow — the stats above don't depend on it.")
                .font(.caption2)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
    }

    // MARK: - Footer

    private var framingFooter: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 18))
                .foregroundStyle(Color.reforgedGold)
            Text("Every bar is a moment the shield stood between you and a pull — a temptation turned away, not a failure. Keep going.")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
    }
}
