import SwiftUI
import FamilyControls

// MARK: - Focus Session
//
// Start card + live countdown for on-demand timed blocking (FocusSessionService).
// Ending a strict session early routes through the parent's `guardedReduce`
// closure (partner PIN when the accountability lock is on); deep sessions have
// no early exit at all.
//
// The setup controls (duration, difficulty, app picker) live one push off the
// shield's main scroll — they're only needed when you're actually starting a
// session. A running session surfaces back on the main screen under "Active now".

/// Dedicated screen for starting / managing a focus session.
struct FocusSessionView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var sessionService: FocusSessionService
    let guardedReduce: (@escaping () -> Void) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                FocusSessionCard(sessionService: sessionService, guardedReduce: guardedReduce)

                Text("A session keeps running even if you close Reforged, and lifts on its own when the timer ends. Sessions must be at least \(FocusSessionKeys.durationsMinutes.first ?? 15) minutes.")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Focus Session")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FocusSessionCard: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var sessionService: FocusSessionService
    /// Parent's PIN gate for protection-lowering actions.
    let guardedReduce: (@escaping () -> Void) -> Void

    @State private var durationMinutes = 25
    @State private var difficulty: FocusSessionDifficulty = .normal
    @State private var selection = FamilyActivitySelection()
    @State private var showAppPicker = false

    private var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
        || !selection.categoryTokens.isEmpty
        || !selection.webDomainTokens.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.14))
                        .frame(width: 50, height: 50)
                    Image(systemName: "timer")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.teal)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Focus Session")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(sessionService.isSessionActive
                         ? "Distractions are shielded. Stay the course."
                         : "Block distractions for a set time while you read, pray, or work.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            if let session = sessionService.activeSession, sessionService.isSessionActive {
                activeSessionView(session)
            } else {
                startControls
            }
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 8, y: 3)
        .familyActivityPicker(isPresented: $showAppPicker, selection: $selection)
        .onAppear {
            // Sensible default: everything the user already considers distracting.
            if !hasSelection {
                var union = FocusBlockingService.shared.selection
                let social = FocusBlockingService.shared.socialSelection
                union.applicationTokens.formUnion(social.applicationTokens)
                union.categoryTokens.formUnion(social.categoryTokens)
                union.webDomainTokens.formUnion(social.webDomainTokens)
                selection = union
            }
        }
    }

    // MARK: - Start Controls

    private var startControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Duration", selection: $durationMinutes) {
                ForEach(FocusSessionKeys.durationsMinutes, id: \.self) { m in
                    Text("\(m)m").tag(m)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                ForEach(FocusSessionDifficulty.allCases) { level in
                    let isOn = difficulty == level
                    Button {
                        HapticManager.shared.selectionChanged()
                        difficulty = level
                    } label: {
                        VStack(spacing: 2) {
                            Text(level.title)
                                .font(.caption).fontWeight(.semibold)
                            Text(level.detail)
                                .font(.caption2)
                                .opacity(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isOn ? Color.reforgedGold : Color.adaptiveTextSecondary(colorScheme).opacity(0.12))
                        .foregroundStyle(isOn ? .white : Color.adaptiveText(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                HapticManager.shared.buttonTap()
                showAppPicker = true
            } label: {
                HStack {
                    Text("Apps to block")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    Text(selectionSummary)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .buttonStyle(.plain)

            Button {
                HapticManager.shared.success()
                sessionService.start(durationMinutes: durationMinutes,
                                     difficulty: difficulty,
                                     selection: selection)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Start Focus Session")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(hasSelection ? Color.reforgedNavy : Color.adaptiveTextSecondary(colorScheme).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!hasSelection)

            if !hasSelection {
                Text("Pick at least one app or category to block first.")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
    }

    private var selectionSummary: String {
        let apps = selection.applicationTokens.count
        let cats = selection.categoryTokens.count
        if apps == 0 && cats == 0 { return "Choose" }
        var parts: [String] = []
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Active Session

    private func activeSessionView(_ session: FocusSession) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, session.endsAt.timeIntervalSince(context.date))
            let total = session.endsAt.timeIntervalSince(session.startedAt)
            let fraction = total > 0 ? 1 - remaining / total : 1

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(timeString(remaining))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.teal)
                        .monospacedDigit()
                    Text("remaining")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Spacer()
                    Text(session.difficulty.title)
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.teal))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.adaptiveTextSecondary(colorScheme).opacity(0.18))
                        Capsule()
                            .fill(Color.teal)
                            .frame(width: max(0, geo.size.width * fraction))
                    }
                }
                .frame(height: 8)

                // Session hit zero while on screen: reconcile clears the shield.
                if remaining <= 0 {
                    Color.clear.frame(height: 0)
                        .onAppear { sessionService.reconcile() }
                }

                switch session.difficulty {
                case .normal:
                    endButton("End Session") {
                        sessionService.endEarly()
                    }
                case .strict:
                    endButton("End Session (PIN)") {
                        guardedReduce {
                            AccountabilityPartnerService.shared.record(.sessionEndedEarly, detail: "A strict focus session was ended before its timer ran out.")
                            sessionService.endEarly()
                        }
                    }
                case .deep:
                    Text("Deep focus — this session runs to the end. \"Let us run with endurance the race set before us.\"")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func endButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.buttonTap()
            action()
        } label: {
            Text(title)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(Color.reforgedCoral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.reforgedCoral.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval.rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
