import SwiftUI

/// The app-wide reward layer.
///
/// XP, badges, level-ups and streak milestones are awarded from wherever the work
/// happens — the Bible reader, a lesson, the journal, a memory game. The celebration
/// for them lives here, at the root, so it plays over whatever tab earned it rather
/// than only over the tab that happens to host the overlay.
struct CelebrationOverlay: ViewModifier {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var streakManager = ReadingStreakManager.shared

    func body(content: Content) -> some View {
        ZStack {
            content

            // Sits above the tab bar rather than behind it.
            VStack {
                Spacer()
                XPGainView(
                    amount: appState.lastXPGain,
                    source: appState.lastXPSource,
                    isPresented: $appState.showXPGain
                )
                .padding(.bottom, 120)
            }

            LevelUpView(
                newLevel: appState.newLevel,
                isPresented: $appState.showLevelUp
            )

            StreakMilestoneView(
                streakCount: streakManager.milestoneDays,
                isPresented: $streakManager.showMilestoneCelebration
            )

            PerfectWeekView(isPresented: $streakManager.showPerfectWeekCelebration)

            // "Your streak was saved" notice, shown when freezes covered a gap
            FreezeUsedView(
                freezesSpent: appState.lastFreezesSpent,
                isPresented: $appState.showFreezeUsedNotice
            )

            if let badge = appState.earnedBadge {
                BadgeEarnedView(
                    badge: badge,
                    isPresented: $appState.showBadgeEarned
                )
                .onChange(of: appState.showBadgeEarned) { showing in
                    if !showing {
                        appState.earnedBadge = nil
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.showXPGain)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.showLevelUp)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: streakManager.showMilestoneCelebration)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: streakManager.showPerfectWeekCelebration)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.showFreezeUsedNotice)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.showBadgeEarned)
    }
}

extension View {
    /// Attach the app-wide reward layer. Apply once, at the root — a second
    /// attachment would race the first for the same `isPresented` bindings.
    func celebrationOverlay() -> some View {
        modifier(CelebrationOverlay())
    }
}
