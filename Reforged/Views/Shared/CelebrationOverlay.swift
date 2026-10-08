import SwiftUI

/// The app-wide reward layer.
///
/// XP, badges, level-ups and streak milestones are awarded from wherever the work
/// happens — the Bible reader, a lesson, the journal, a memory game. The celebration
/// for them lives here, at the root, so it plays over whatever tab earned it rather
/// than only over the tab that happens to host the overlay.
struct CelebrationOverlay: ViewModifier {
    /// Arcade jackpot takeovers are scoped to the Memory tab; everywhere else
    /// keeps the calmer cards.
    let arcade: Bool

    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var streakManager = ReadingStreakManager.shared

    /// Full-screen takeovers play one at a time. When several land together
    /// (XP → level-up → badge), the highest-priority one plays first and the rest
    /// queue behind it simply by still being `true` when it dismisses.
    private enum Takeover { case levelUp, badge, streak, perfectWeek, freeze }

    private var activeTakeover: Takeover? {
        if appState.showLevelUp { return .levelUp }
        if appState.showBadgeEarned, appState.earnedBadge != nil { return .badge }
        if streakManager.showMilestoneCelebration { return .streak }
        if streakManager.showPerfectWeekCelebration { return .perfectWeek }
        if appState.showFreezeUsedNotice { return .freeze }
        return nil
    }

    func body(content: Content) -> some View {
        ZStack {
            content

            // Crown awards: a small non-blocking toast at the top.
            if activeTakeover == nil {
                VStack {
                    CrownGainToast(amount: appState.lastCrownGain, reason: appState.lastCrownReason,
                                   isPresented: $appState.showCrownGain)
                        .padding(.top, 8)
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            // Tier 1: routine +XP. Non-blocking, so it yields to any takeover.
            if activeTakeover == nil {
                if arcade {
                    ArcadeXPGainView(amount: appState.lastXPGain, source: appState.lastXPSource, isPresented: $appState.showXPGain)
                } else {
                    VStack {
                        Spacer()
                        XPGainView(amount: appState.lastXPGain, source: appState.lastXPSource, isPresented: $appState.showXPGain)
                            .padding(.bottom, 120)
                    }
                }
            }

            // Tier 2: celebrations, one at a time.
            switch activeTakeover {
            case .levelUp:
                if arcade {
                    ArcadeLevelUpView(newLevel: appState.newLevel, isPresented: $appState.showLevelUp)
                } else {
                    LevelUpView(newLevel: appState.newLevel, isPresented: $appState.showLevelUp)
                }
            case .badge:
                if let badge = appState.earnedBadge {
                    if arcade {
                        ArcadeBadgeEarnedView(badge: badge, isPresented: $appState.showBadgeEarned)
                    } else {
                        BadgeEarnedView(badge: badge, isPresented: $appState.showBadgeEarned)
                    }
                }
            case .streak:
                if arcade {
                    ArcadeStreakMilestoneView(streakCount: streakManager.milestoneDays, isPresented: $streakManager.showMilestoneCelebration)
                } else {
                    StreakMilestoneView(streakCount: streakManager.milestoneDays, isPresented: $streakManager.showMilestoneCelebration)
                }
            case .perfectWeek:
                if arcade {
                    ArcadePerfectWeekView(isPresented: $streakManager.showPerfectWeekCelebration)
                } else {
                    PerfectWeekView(isPresented: $streakManager.showPerfectWeekCelebration)
                }
            case .freeze:
                // One bespoke animation everywhere: the frost sealing the missed
                // day is the whole point, so it isn't split into calm/arcade cards.
                StreakFreezeSavedView(frozenDays: appState.lastFrozenDays,
                                      isPresented: $appState.showFreezeUsedNotice)
            case nil:
                EmptyView()
            }
        }
        .onChange(of: appState.showBadgeEarned) { showing in
            if !showing { appState.earnedBadge = nil }
        }
        .animation(.easeOut(duration: 0.25), value: activeTakeover)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.showXPGain)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: appState.showCrownGain)
    }
}

extension View {
    /// Attach the app-wide reward layer. Apply once, at the root — a second
    /// attachment would race the first for the same `isPresented` bindings.
    func celebrationOverlay(arcade: Bool = false) -> some View {
        modifier(CelebrationOverlay(arcade: arcade))
    }
}
