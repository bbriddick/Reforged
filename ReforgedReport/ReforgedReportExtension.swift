import DeviceActivity
import SwiftUI

// MARK: - Device Activity Report Extension
//
// Renders REAL usage for the user's social selection inside a sandboxed view
// the host app embeds (data never leaves this process — an iOS guarantee).
// Compares actual usage against the daily allowance from the App Group to
// frame the result as "time reclaimed".
//
// Known platform caveat: report views can load slowly or fail intermittently
// on iOS 17+. The host view (ShieldInsightsView) treats this as best-effort.

@main
struct ReforgedReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TimeReclaimedReport { summary in
            TimeReclaimedView(summary: summary)
        }
    }
}

extension DeviceActivityReport.Context {
    /// Must match the context used by the host app's DeviceActivityReport view.
    static let timeReclaimed = Self("timeReclaimed")
}

struct TimeReclaimedSummary {
    let usedMinutes: Int
    let allowanceMinutes: Int?

    var reclaimedMinutes: Int? {
        guard let allowance = allowanceMinutes else { return nil }
        return max(0, allowance - usedMinutes)
    }
}

struct TimeReclaimedReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .timeReclaimed
    let content: (TimeReclaimedSummary) -> TimeReclaimedView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TimeReclaimedSummary {
        var total: TimeInterval = 0
        for await result in data {
            for await segment in result.activitySegments {
                total += segment.totalActivityDuration
            }
        }

        let defaults = UserDefaults(suiteName: "group.com.reforged.app")
        let allowance = defaults?.object(forKey: "socialAllowanceMinutes") as? Int

        return TimeReclaimedSummary(
            usedMinutes: Int(total / 60),
            allowanceMinutes: allowance
        )
    }
}

struct TimeReclaimedView: View {
    let summary: TimeReclaimedSummary
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(summary.usedMinutes)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.20, green: 0.55, blue: 0.55))
                Text("min on social today")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if let allowance = summary.allowanceMinutes, allowance > 0 {
                let fraction = min(1, Double(summary.usedMinutes) / Double(allowance))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.18))
                        Capsule()
                            .fill(Color(red: 0.20, green: 0.55, blue: 0.55))
                            .frame(width: max(0, geo.size.width * fraction))
                    }
                }
                .frame(height: 8)

                if let reclaimed = summary.reclaimedMinutes {
                    Text(reclaimed > 0
                         ? "\(reclaimed) min of your \(allowance)-min allowance reclaimed for what matters."
                         : "You've used your full \(allowance)-min allowance today.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Turn on the Daily Social Limit to see time reclaimed against your allowance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(4)
    }
}
