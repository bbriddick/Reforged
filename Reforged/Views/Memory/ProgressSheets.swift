import SwiftUI

// MARK: - Shared tokens

private let freezeBlue = Color(red: 0.35, green: 0.62, blue: 0.95)
private let flameOrange = Color(red: 1.0, green: 0.5, blue: 0.0)

/// Gold dark enough to read as text on light paper (#B07F4E); plain gold in dark mode.
private func goldInk(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? .reforgedGold : Color(red: 0.69, green: 0.50, blue: 0.31)
}

private struct SheetSectionHeader: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

// MARK: - Level sheet

/// Opened from the Lv chip on the Memory tab. Shows where the user stands in the
/// Armor of God progression (LevelProgression), the verse for each piece, and
/// what the next levels bring.
struct LevelProgressSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringProgress: Double = 0
    @State private var emblemScale: CGFloat = 0.85
    @State private var selectedPiece: Int?

    private var info: LevelInfo { SampleData.getLevelInfo(xp: appState.user.lifetimeXP) }
    private var level: Int { info.level }
    private var currentPieceIndex: Int { LevelProgression.pieceIndex(for: level) }
    private var rank: Int { LevelProgression.rank(for: level) }
    private var isMaxLevel: Bool { level >= LevelProgression.maxLevel }
    private var shownPieceIndex: Int { selectedPiece ?? currentPieceIndex }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ReforgedTheme.spacingL) {
                    hero
                    rankTrack
                    armorRow
                    pieceCard
                    comingUp
                    waysToEarn
                }
                .padding(.horizontal, 20)
                .padding(.bottom, ReforgedTheme.spacingL)
                .readableContentWidth()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Your Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: animateIn)
    }

    private func animateIn() {
        let target = isMaxLevel ? 1 : info.progress
        guard !reduceMotion else {
            ringProgress = target
            emblemScale = 1
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { emblemScale = 1 }
        withAnimation(.easeOut(duration: 1.1).delay(0.15)) { ringProgress = target }
    }

    // MARK: Hero

    private var hero: some View {
        let piece = LevelProgression.piece(for: level)
        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.reforgedGold.opacity(0.18), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(Color.reforgedGold, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .fill(Color.reforgedGold.opacity(colorScheme == .dark ? 0.2 : 0.14))
                    .padding(16)
                Image(systemName: piece.icon)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(goldInk(colorScheme))
                    .scaleEffect(emblemScale)
            }
            .frame(width: 148, height: 148)
            .padding(.top, 8)
            .accessibilityHidden(true)

            Text(piece.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)

            Text("Level \(level) · Rank \(LevelProgression.romanRank(rank)) of V")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            Text(isMaxLevel
                 ? "Fully armored. Every piece is yours."
                 : "\(info.xpForNextLevel - info.xpInLevel) XP to level \(level + 1)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(goldInk(colorScheme))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Rank track

    private var rankTrack: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(1...LevelProgression.ranksPerPiece, id: \.self) { r in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.adaptiveChipBackground(colorScheme))
                            Capsule()
                                .fill(Color.reforgedGold)
                                .frame(width: geo.size.width * fill(forRank: r))
                        }
                    }
                    .frame(height: 8)
                }
            }
            HStack(spacing: 6) {
                ForEach(1...LevelProgression.ranksPerPiece, id: \.self) { r in
                    Text(LevelProgression.romanRank(r))
                        .font(.caption2.weight(r == rank ? .bold : .regular))
                        .foregroundStyle(r == rank ? goldInk(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(rank) of 5, \(Int(info.progress * 100)) percent to the next level")
    }

    private func fill(forRank r: Int) -> Double {
        if r < rank || isMaxLevel { return 1 }
        if r == rank { return ringProgress }
        return 0
    }

    // MARK: Armor row

    private var armorRow: some View {
        VStack(spacing: 10) {
            SheetSectionHeader(title: "Your armor")
            HStack(spacing: 8) {
                ForEach(Array(LevelProgression.pieces.enumerated()), id: \.offset) { index, piece in
                    armorTile(index: index, piece: piece)
                }
            }
        }
    }

    private func armorTile(index: Int, piece: LevelProgression.ArmorPiece) -> some View {
        let done = index < currentPieceIndex || (isMaxLevel && index == currentPieceIndex)
        let current = index == currentPieceIndex && !isMaxLevel
        let locked = index > currentPieceIndex
        let selected = index == shownPieceIndex

        return Button {
            HapticManager.shared.lightImpact()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedPiece = index == currentPieceIndex ? nil : index
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(locked ? Color.adaptiveChipBackground(colorScheme)
                                     : Color.reforgedGold.opacity(colorScheme == .dark ? 0.24 : 0.16))
                    if current {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.reforgedGold, lineWidth: 2)
                    }
                    Image(systemName: locked ? "lock.fill" : piece.icon)
                        .font(.system(size: locked ? 13 : 17, weight: .semibold))
                        .foregroundStyle(locked ? Color.adaptiveTextSecondary(colorScheme) : goldInk(colorScheme))
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(goldInk(colorScheme))
                            .background(Circle().fill(Color.adaptiveCardBackground(colorScheme)))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .offset(x: 4, y: -4)
                    }
                }
                .frame(height: 46)
                .scaleEffect(selected ? 1.06 : 1)

                Text(piece.shortName)
                    .font(.caption2.weight(selected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(selected ? Color.adaptiveText(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoBlobButtonStyle())
        .accessibilityLabel("\(piece.name), \(done ? "complete" : current ? "current" : "locked")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Piece card

    private var pieceCard: some View {
        let index = shownPieceIndex
        let piece = LevelProgression.pieces[index]
        let startLevel = index * LevelProgression.ranksPerPiece + 1
        let endLevel = startLevel + LevelProgression.ranksPerPiece - 1
        let status: String = {
            if index < currentPieceIndex || (isMaxLevel && index == currentPieceIndex) { return "Complete" }
            if index == currentPieceIndex { return "Levels \(startLevel)–\(endLevel)" }
            return "Unlocks at level \(startLevel)"
        }()
        let alreadyMemorizing = appState.memoryVerses.contains { $0.reference == piece.reference }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(piece.name)
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer(minLength: 8)
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            Text(piece.verseText)
                .font(.system(.body, design: .serif))
                .lineSpacing(5)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("\(piece.reference) · KJV")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(goldInk(colorScheme))
                Spacer()
                if alreadyMemorizing {
                    Label("In your verses", systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                } else {
                    Button {
                        memorize(piece)
                    } label: {
                        Text("Memorize")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(Capsule().fill(Color.reforgedCoral))
                    }
                    .buttonStyle(NoBlobButtonStyle())
                    .accessibilityHint("Adds \(piece.reference) to your memory verses")
                }
            }
        }
        .padding(18)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge + 4, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 8, y: 4)
        .id(index)
        .transition(.opacity)
    }

    private func memorize(_ piece: LevelProgression.ArmorPiece) {
        HapticManager.shared.success()
        appState.addMemoryVerse(MemoryVerse(
            id: UUID().uuidString,
            reference: piece.reference,
            text: piece.verseText,
            esvText: nil,
            category: "Strength",
            translation: BibleTranslation.kjv.rawValue,
            lastFetched: AppDateFormatters.iso8601.string(from: Date()),
            nextReviewDate: Date(),
            reviewCount: 0,
            easeFactor: 2.5,
            interval: 1,
            isLearning: true,
            accuracy: nil,
            modeStats: nil
        ))
    }

    // MARK: Coming up

    private struct Upcoming: Identifiable {
        let id: String
        let level: Int
        let icon: String
        let title: String
        let detail: String
    }

    private var upcoming: [Upcoming] {
        var items: [Upcoming] = []
        if !isMaxLevel {
            let next = level + 1
            let freezes = AppState.freezeReward(forLevel: next)
            items.append(Upcoming(id: "next", level: next, icon: "snowflake",
                                  title: LevelProgression.isNewPiece(next)
                                      ? "Take up the \(LevelProgression.piece(for: next).phrase)"
                                      : "\(LevelProgression.piece(for: level).name) rank \(LevelProgression.romanRank(LevelProgression.rank(for: next)))",
                                  detail: "+\(freezes) streak freeze\(freezes == 1 ? "" : "s")"))
        }
        let perks = SampleData.perks.compactMap { perk -> Upcoming? in
            guard case .level(let required) = perk.unlockCondition, required > level else { return nil }
            return Upcoming(id: perk.id, level: required, icon: perk.icon, title: perk.name, detail: perk.description)
        }
        .sorted { $0.level < $1.level }
        items.append(contentsOf: perks.prefix(2))
        return items
    }

    @ViewBuilder
    private var comingUp: some View {
        if !upcoming.isEmpty {
            VStack(spacing: 10) {
                SheetSectionHeader(title: "Coming up")
                VStack(spacing: 0) {
                    ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(item.icon == "snowflake" ? freezeBlue : goldInk(colorScheme))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.adaptiveChipBackground(colorScheme)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                            Spacer(minLength: 8)
                            Text("Lv \(item.level)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(goldInk(colorScheme))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .accessibilityElement(children: .combine)
                        if index < upcoming.count - 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))
            }
        }
    }

    // MARK: Ways to earn

    private var waysToEarn: some View {
        let rows: [(String, String, String)] = [
            ("book.fill", "Read a chapter", "+15"),
            ("brain.head.profile", "Review a verse", "+5 to 15"),
            ("checkmark.circle.fill", "Finish a review session", "+25"),
            ("waveform", "Say It Back", "+10 to 30"),
            ("square.grid.2x2.fill", "Matching game", "up to +200"),
            ("pencil", "Write a reflection", "+20"),
            ("sunrise.fill", "First activity of the day", "+10"),
        ]
        let streak = ReadingStreakManager.shared.currentStreak
        let multiplier = streak >= 30 ? "2×" : streak >= 7 ? "1.5×" : nil

        return VStack(spacing: 10) {
            SheetSectionHeader(title: "Ways to earn XP")
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 12) {
                        Image(systemName: row.0)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .frame(width: 22)
                        Text(row.1)
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Spacer()
                        Text(row.2)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(goldInk(colorScheme))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    if index < rows.count - 1 { Divider().padding(.leading, 50) }
                }
            }
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))

            Text(multiplier.map { "Your \(streak)-day streak is multiplying everything you earn by \($0)." }
                 ?? "Keep a 7-day streak for 1.5× XP, or 30 days for 2×.")
                .font(.footnote)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }
}

// MARK: - Streak sheet

/// Opened from the flame chip, or from the "streak unprotected" notification
/// (`highlightFreeze`), which scrolls to and pulses the freeze section.
struct StreakProgressSheet: View {
    var highlightFreeze = false

    @EnvironmentObject var appState: AppState
    @ObservedObject private var streak = ReadingStreakManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flameScale: CGFloat = 0.8
    @State private var pulseFreeze = false
    @State private var confirmPurchase = false
    @State private var justBoughtIndex: Int?

    private var current: Int { streak.currentStreak }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: ReforgedTheme.spacingL) {
                        hero
                        weekStrip
                        MonthReadingCalendarCard()
                        milestone
                        bonusLadder
                        freezeSection.id("freeze")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, ReforgedTheme.spacingL)
                    .readableContentWidth()
                }
                .onAppear {
                    animateIn()
                    guard highlightFreeze else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo("freeze", anchor: .center) }
                        startFreezePulse()
                    }
                }
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Your Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Get a streak freeze?", isPresented: $confirmPurchase, titleVisibility: .visible) {
                Button("Spend \(appState.freezePurchaseCost) XP") { buyFreeze() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have \(appState.user.xp) XP to spend. Spending XP never lowers your level.")
            }
        }
    }

    private func animateIn() {
        guard !reduceMotion else { flameScale = 1; return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { flameScale = 1 }
    }

    private func startFreezePulse() {
        guard !reduceMotion else { pulseFreeze = true; return }
        withAnimation(.easeInOut(duration: 0.7).repeatCount(5, autoreverses: true)) { pulseFreeze = true }
        HapticManager.shared.lightImpact()
    }

    // MARK: Hero

    private var hero: some View {
        let doneToday = streak.hasActivityToday
        let status: String
        if doneToday {
            status = "Today's done. See you tomorrow."
        } else if current > 0 {
            status = "Review a verse or read a chapter today to keep it going."
        } else {
            status = "One review or one chapter starts a new streak."
        }

        return VStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(current > 0 ? flameOrange : Color.adaptiveTextSecondary(colorScheme).opacity(0.5))
                .scaleEffect(flameScale)
                .padding(.top, 12)
                .accessibilityHidden(true)
            Text("\(current)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .contentTransition(.numericText())
            Text("day streak")
                .font(.headline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            Text(status)
                .font(.subheadline)
                .foregroundStyle(!doneToday && current > 0 ? Color.reforgedCoral : Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            Text("Best: \(max(streak.longestStreak, current)) days")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Week

    private var weekStrip: some View {
        let dates = streak.currentWeekDates()
        let today = Calendar.current.startOfDay(for: Date())
        let letters = Calendar.current.veryShortWeekdaySymbols

        return HStack(spacing: 6) {
            ForEach(dates, id: \.self) { date in
                let day = Calendar.current.startOfDay(for: date)
                let frozen = streak.wasFrozen(on: date)
                let active = !streak.activityKinds(on: date).isEmpty || (streak.didRead(on: date) && !frozen)
                let isToday = day == today
                let future = day > today
                VStack(spacing: 6) {
                    Text(letters[Calendar.current.component(.weekday, from: date) - 1])
                        .font(.caption2.weight(isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Color.adaptiveText(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
                    ZStack {
                        Circle()
                            .fill(active ? flameOrange.opacity(0.18)
                                  : frozen ? freezeBlue.opacity(0.18)
                                  : Color.adaptiveChipBackground(colorScheme).opacity(future ? 0.5 : 1))
                        if isToday && !active {
                            Circle().strokeBorder(Color.adaptiveTextSecondary(colorScheme).opacity(0.5),
                                                  style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        }
                        if active {
                            Image(systemName: "flame.fill").font(.system(size: 14)).foregroundStyle(flameOrange)
                        } else if frozen {
                            Image(systemName: "snowflake").font(.system(size: 14, weight: .semibold)).foregroundStyle(freezeBlue)
                        }
                    }
                    .frame(width: 36, height: 36)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide))): \(active ? "active" : frozen ? "covered by a freeze" : future ? "upcoming" : "missed")")
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))
    }

    // MARK: Milestone

    @ViewBuilder
    private var milestone: some View {
        if let next = streak.nextMilestone {
            let previous = ReadingStreakManager.milestones.last { $0 <= current } ?? 0
            let progress = Double(current - previous) / Double(max(next - previous, 1))
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Next milestone")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    Text("\(next - current) day\(next - current == 1 ? "" : "s") to \(next)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(flameOrange)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(flameOrange.opacity(0.15))
                        Capsule().fill(flameOrange).frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 8)
            }
            .padding(16)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: XP bonus

    private var bonusLadder: some View {
        let tiers: [(label: String, detail: String, active: Bool)] = [
            ("1×", "0–6 days", current < 7),
            ("1.5×", "7+ days", current >= 7 && current < 30),
            ("2×", "30+ days", current >= 30),
        ]
        return VStack(spacing: 10) {
            SheetSectionHeader(title: "Streak XP bonus")
            HStack(spacing: 8) {
                ForEach(tiers, id: \.label) { tier in
                    VStack(spacing: 2) {
                        Text(tier.label)
                            .font(.headline)
                            .foregroundStyle(tier.active ? goldInk(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
                        Text(tier.detail)
                            .font(.caption2)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(tier.active ? Color.reforgedGold.opacity(colorScheme == .dark ? 0.22 : 0.14)
                                              : Color.adaptiveCardBackground(colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(tier.active ? Color.reforgedGold : .clear, lineWidth: 1.5)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(tier.active ? .isSelected : [])
                }
            }
        }
    }

    // MARK: Freezes

    private var freezeSection: some View {
        let owned = appState.user.streakFreezes
        let cap = appState.maxStreakFreezes
        let canAfford = appState.user.xp >= appState.freezePurchaseCost
        let atCap = owned >= cap

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Streak freezes")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                Text("\(owned) of \(cap)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(freezeBlue)
            }

            if owned == 0 && current > 0 {
                Label("Your streak has no freeze protecting it.", systemImage: "exclamationmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.reforgedCoral)
            }

            HStack(spacing: 8) {
                ForEach(0..<max(cap, owned), id: \.self) { i in
                    let filled = i < owned
                    Image(systemName: "snowflake")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(filled ? .white : freezeBlue.opacity(0.35))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(filled ? freezeBlue : freezeBlue.opacity(0.1)))
                        .scaleEffect(justBoughtIndex == i ? 1.25 : 1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(owned) of \(cap) streak freezes")

            Text("A freeze covers a day you miss, automatically, so one busy day can't break your streak.")
                .font(.footnote)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            VStack(alignment: .leading, spacing: 6) {
                earnRow("arrow.up.circle.fill", "+1 every level up, +2 for a new piece of armor")
                earnRow("graduationcap.fill", "+1 every 5 lessons")
                earnRow("calendar", "Topped up to 4 at the start of each month")
            }

            Button {
                confirmPurchase = true
            } label: {
                HStack {
                    Image(systemName: "snowflake")
                    Text(atCap ? "You're fully stocked" : "Get a freeze")
                    Spacer()
                    if !atCap {
                        Text("\(appState.freezePurchaseCost) XP")
                            .font(.subheadline.weight(.bold))
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 50)
                .background(Capsule().fill(freezeBlue))
                .opacity(atCap || !canAfford ? 0.45 : 1)
            }
            .buttonStyle(NoBlobButtonStyle())
            .disabled(atCap || !canAfford)

            if !atCap && !canAfford {
                Text("You need \(appState.freezePurchaseCost - appState.user.xp) more XP to buy one.")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            Toggle(isOn: Binding(
                get: { settings.streakFreezeReminders },
                set: { on in
                    settings.streakFreezeReminders = on
                    if on { NotificationManager.shared.requestAuthorization() }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me when I'm out")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("At most once every few days")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .tint(freezeBlue)
        }
        .padding(18)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge + 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge + 4, style: .continuous)
                .stroke(freezeBlue, lineWidth: 2.5)
                .opacity(pulseFreeze ? 1 : 0)
        )
        .shadow(color: freezeBlue.opacity(pulseFreeze ? 0.35 : 0), radius: 14, y: 4)
        .scaleEffect(pulseFreeze && !reduceMotion ? 1.015 : 1)
    }

    private func earnRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(freezeBlue)
                .frame(width: 18)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
    }

    private func buyFreeze() {
        guard appState.purchaseStreakFreeze() else { return }
        HapticManager.shared.success()
        let index = appState.user.streakFreezes - 1
        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { justBoughtIndex = index }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { justBoughtIndex = nil }
        }
        withAnimation { pulseFreeze = false }
    }
}
