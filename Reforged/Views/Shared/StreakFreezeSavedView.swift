import SwiftUI

/// Plays when streak freezes repaired a gap, on the next app open after it
/// happened (AppState persists the pending days until this is dismissed).
///
/// Sequence: the week appears with the missed day(s) empty and the flame dim →
/// a snowflake drops into each missed day → the day ices over with a burst of
/// frost → the flame reignites and the streak count lands. Reduce Motion jumps
/// straight to the final state.
struct StreakFreezeSavedView: View {
    let frozenDays: [String]
    @Binding var isPresented: Bool

    @ObservedObject private var appState = AppState.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0 missed · 1 snowflakes dropping · 2 iced · 3 flame reignited · 4 settled
    @State private var phase = 0
    @State private var flicker = false

    private let ice = Color(red: 0.35, green: 0.62, blue: 0.95)
    private let flame = Color(red: 1.0, green: 0.5, blue: 0.0)

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var frozenDates: Set<Date> {
        Set(frozenDays.compactMap { Self.dayKeyFormatter.date(from: $0) }
            .map { Calendar.current.startOfDay(for: $0) })
    }

    /// The seven days ending today — wide enough to show the repaired gap in context.
    private var windowDays: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0 - 6, to: today) }
    }

    private var coveredDescription: String {
        let sorted = frozenDates.sorted()
        if sorted.count == 1, let day = sorted.first {
            return "A streak freeze covered \(day.formatted(.dateTime.weekday(.wide)))."
        }
        if sorted.count == 2 {
            let names = sorted.map { $0.formatted(.dateTime.weekday(.wide)) }
            return "Streak freezes covered \(names[0]) and \(names[1])."
        }
        return "\(max(frozenDays.count, 1)) streak freezes covered the days you missed."
    }

    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { if phase >= 4 { dismiss() } }

                card
                    .padding(28)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
            .onAppear(perform: run)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    // MARK: Card

    private var card: some View {
        VStack(spacing: 22) {
            flameHero

            VStack(spacing: 6) {
                Text("Streak saved")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(coveredDescription)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .opacity(phase >= 3 ? 1 : 0)
            .offset(y: phase >= 3 ? 0 : 8)

            weekRow

            freezeCount
                .opacity(phase >= 3 ? 1 : 0)

            VStack(spacing: 8) {
                Button(action: dismiss) {
                    Text("Keep going")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().fill(Color.reforgedCoral))
                }
                .buttonStyle(NoBlobButtonStyle())

                if appState.user.streakFreezes == 0 {
                    Button(action: getAnother) {
                        Text("Get another freeze")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ice)
                            .frame(height: 40)
                    }
                    .buttonStyle(NoBlobButtonStyle())
                }
            }
            .opacity(phase >= 4 ? 1 : 0)
            .allowsHitTesting(phase >= 4)
        }
        .padding(26)
        .frame(maxWidth: 380)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
    }

    private var flameHero: some View {
        let lit = phase >= 3
        return ZStack {
            // Reignition ring
            Circle()
                .stroke(flame.opacity(0.35), lineWidth: 3)
                .frame(width: 96, height: 96)
                .scaleEffect(lit ? 1.6 : 0.8)
                .opacity(lit && phase < 4 ? 1 : 0)
            Circle()
                .fill((lit ? flame : Color.adaptiveTextSecondary(colorScheme)).opacity(0.14))
                .frame(width: 96, height: 96)
            Image(systemName: "flame.fill")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(lit ? flame : Color.adaptiveTextSecondary(colorScheme).opacity(0.55))
                .scaleEffect(lit ? 1 : (flicker ? 0.9 : 0.82))
            Text("\(appState.user.streak)")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Capsule().fill(lit ? flame : Color.adaptiveTextSecondary(colorScheme)))
                .offset(y: 44)
                .contentTransition(.numericText())
        }
        .frame(height: 118)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(appState.user.streak) day streak")
    }

    // MARK: Week

    private var weekRow: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let frozen = frozenDates
        let frozenOrder = frozen.sorted()
        let manager = ReadingStreakManager.shared

        return HStack(spacing: 6) {
            ForEach(windowDays, id: \.self) { day in
                let isFrozen = frozen.contains(day)
                let active = !manager.activityKinds(on: day).isEmpty
                let isToday = day == today
                let order = frozenOrder.firstIndex(of: day) ?? 0
                VStack(spacing: 6) {
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Color.adaptiveText(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
                    dayTile(isFrozen: isFrozen, active: active, isToday: isToday, order: order)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayTile(isFrozen: Bool, active: Bool, isToday: Bool, order: Int) -> some View {
        let iced = isFrozen && phase >= 2
        return ZStack {
            Circle()
                .fill(active ? flame.opacity(0.18) : Color.adaptiveChipBackground(colorScheme))
            if isFrozen && !iced {
                Circle().strokeBorder(Color.adaptiveTextSecondary(colorScheme).opacity(0.5),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
            if isToday && !active && !isFrozen {
                Circle().strokeBorder(Color.adaptiveTextSecondary(colorScheme).opacity(0.4), lineWidth: 1.5)
            }
            // Ice fill grows from the center
            Circle()
                .fill(ice)
                .scaleEffect(iced ? 1 : 0.01)
                .opacity(isFrozen ? 1 : 0)
            if isFrozen {
                FrostBurst(active: phase == 2, color: ice)
            }
            if active {
                Image(systemName: "flame.fill").font(.system(size: 13)).foregroundStyle(flame)
            }
            if isFrozen {
                // The falling snowflake lands and becomes the tile's mark.
                Image(systemName: "snowflake")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(iced ? .white : ice)
                    .rotationEffect(.degrees(phase >= 1 ? 0 : -200))
                    .offset(y: phase >= 1 ? 0 : -150)
                    .opacity(phase >= 1 ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.62)
                        .delay(Double(order) * 0.14), value: phase)
            }
        }
        .frame(width: 36, height: 36)
    }

    private var freezeCount: some View {
        let spent = max(frozenDays.count, 1)
        let left = appState.user.streakFreezes
        return HStack(spacing: 6) {
            Image(systemName: "snowflake")
                .font(.caption.weight(.bold))
            Text("−\(spent) used · \(left) left")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(ice)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(ice.opacity(0.12)))
    }

    // MARK: Sequence

    private func run() {
        guard !reduceMotion else {
            phase = 4
            return
        }
        withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { flicker = true }
        step(to: 1, after: 0.35) { HapticManager.shared.lightImpact() }
        step(to: 2, after: 1.0 + Double(max(frozenDates.count - 1, 0)) * 0.14) { HapticManager.shared.mediumImpact() }
        step(to: 3, after: 1.7 + Double(max(frozenDates.count - 1, 0)) * 0.14) { HapticManager.shared.success() }
        step(to: 4, after: 2.3 + Double(max(frozenDates.count - 1, 0)) * 0.14) {}
    }

    private func step(to value: Int, after delay: Double, haptic: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard isPresented else { return }
            haptic()
            withAnimation(value == 3 ? .spring(response: 0.45, dampingFraction: 0.5)
                                     : .spring(response: 0.5, dampingFraction: 0.75)) {
                phase = value
            }
        }
    }

    private func dismiss() {
        // Clear the persisted pending days here, at the one place the user
        // acknowledges the animation, so it never replays on the next launch.
        appState.freezeCelebrationSeen()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { isPresented = false }
    }

    private func getAnother() {
        dismiss()
        NotificationCenter.default.post(name: .switchTab, object: nil,
                                        userInfo: [AppNotificationUserInfoKey.tab: 3])
        appState.pendingFreezePrompt = true
    }
}

/// Eight frost crystals that shoot out from a tile as it ices over.
private struct FrostBurst: View {
    let active: Bool
    let color: Color
    @State private var burst = false

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(color)
                    .offset(y: burst ? -30 : -8)
                    .rotationEffect(.degrees(Double(i) * 45))
                    .opacity(burst ? 0 : (active ? 1 : 0))
            }
        }
        .onChange(of: active) { isActive in
            guard isActive else { return }
            burst = false
            withAnimation(.easeOut(duration: 0.7)) { burst = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
