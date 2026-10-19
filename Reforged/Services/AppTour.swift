import SwiftUI

// MARK: - App Tour
//
// A guided walkthrough of what Reforged can do, split into one section per main view
// (Bible, Memory, Discipleship, Home). Every step is a card that HOVERS over the screen
// (one overlay at the app root), so showing or dismissing it never moves the layout.
//
// • Connected: "Next" walks through a section's features and then carries on into the
//   next view, switching tabs for you. "Back" returns.
// • Resumes by view: closing the card (✕) skips only the CURRENT section. The next time
//   the user switches to a view whose section they haven't seen, the tour opens back up
//   and walks them through that view's features.
// • "Skip tour" turns it off entirely; Settings → "Take the app tour" starts it again.

enum TourSection: Int, CaseIterable {
    // Order = the order of the full walkthrough. rawValue is also the tab tag.
    case bible = 2, memory = 3, discipleship = 1, home = 0

    var name: String {
        switch self {
        case .bible: return "Bible"
        case .memory: return "Memory"
        case .discipleship: return "Discipleship"
        case .home: return "Home"
        }
    }
}

enum TourStep: Int, CaseIterable, Identifiable {
    // Bible
    case holdToDefine, tapVerse, studyVerse, search, translation, audio, textOptions, navigate, markRead
    // Memory
    case memoryOverview, memoryStats, memoryReview, memoryAdd, memoryPractice, memoryHelp
    // Discipleship
    case shield, tempted, learningPath, disciplines, resources
    // Home
    case homeSearch, homeToday, homeReading, homeProgress, homeDiscover, profile

    var id: Int { rawValue }

    var section: TourSection {
        switch self {
        case .holdToDefine, .tapVerse, .studyVerse, .search, .translation, .audio,
             .textOptions, .navigate, .markRead:
            return .bible
        case .memoryOverview, .memoryReview, .memoryAdd, .memoryPractice, .memoryHelp, .memoryStats:
            return .memory
        case .shield, .tempted, .learningPath, .disciplines, .resources:
            return .discipleship
        case .homeSearch, .homeToday, .homeReading, .homeProgress, .homeDiscover, .profile:
            return .home
        }
    }

    /// Tab tag (see ContentView) the step lives on.
    var tab: Int { section.rawValue }

    static func steps(in section: TourSection) -> [TourStep] {
        allCases.filter { $0.section == section }
    }

    var icon: String {
        switch self {
        case .holdToDefine:   return "hand.tap.fill"
        case .tapVerse:       return "text.quote"
        case .studyVerse:     return "text.magnifyingglass"
        case .search:         return "magnifyingglass"
        case .translation:    return "books.vertical.fill"
        case .audio:          return "headphones"
        case .textOptions:    return "textformat.size"
        case .navigate:       return "text.book.closed.fill"
        case .markRead:       return "checkmark.circle.fill"
        case .memoryOverview: return "brain.head.profile"
        case .memoryReview:   return "rectangle.stack.fill"
        case .memoryAdd:      return "plus.circle.fill"
        case .memoryPractice: return "mic.fill"
        case .memoryHelp:     return "questionmark.circle.fill"
        case .memoryStats:    return "flame.fill"
        case .shield:         return "shield.lefthalf.filled"
        case .tempted:        return "hand.raised.fill"
        case .learningPath:   return "map.fill"
        case .disciplines:    return "calendar.badge.clock"
        case .resources:      return "square.grid.2x2.fill"
        case .homeSearch:     return "magnifyingglass"
        case .homeToday:      return "sparkles"
        case .homeReading:    return "calendar"
        case .homeProgress:   return "chart.bar.fill"
        case .homeDiscover:   return "lightbulb.fill"
        case .profile:        return "person.crop.circle"
        }
    }

    var title: String {
        switch self {
        case .holdToDefine:   return "Hold any word to define it"
        case .tapVerse:       return "Tap a verse for its tools"
        case .studyVerse:     return "Study any verse in depth"
        case .search:         return "Search the whole Bible"
        case .translation:    return "Switch translations anytime"
        case .audio:          return "Listen to the chapter"
        case .textOptions:    return "Make it comfortable to read"
        case .navigate:       return "Jump to any book or chapter"
        case .markRead:       return "Track what you've read"
        case .memoryOverview: return "Memorize Scripture that sticks"
        case .memoryReview:   return "Review what's due"
        case .memoryAdd:      return "Add a verse"
        case .memoryPractice: return "Practice your way"
        case .memoryHelp:     return "How it works"
        case .memoryStats:    return "Your streak, level, and crowns"
        case .shield:         return "Protect your time"
        case .tempted:        return "Help when you're tempted"
        case .learningPath:   return "Follow a learning path"
        case .disciplines:    return "Build your daily checklist"
        case .resources:      return "More to explore"
        case .homeSearch:     return "Search Scripture, topics, words"
        case .homeToday:      return "What to do next"
        case .homeReading:    return "Today's reading and routines"
        case .homeProgress:   return "Streaks, levels, and progress"
        case .homeDiscover:   return "Keep learning"
        case .profile:        return "Your profile and settings"
        }
    }

    var message: String {
        switch self {
        case .holdToDefine:
            return "Press and hold a word in the text for its meaning — and the Greek or Hebrew behind it."
        case .tapVerse:
            return "Tap any verse to open its tools: highlight it, add a note, bookmark it, save it to memory, study it, or copy it."
        case .studyVerse:
            return "Select a verse and choose Study for commentaries, cross-references, and the original-language words behind it."
        case .search:
            return "Tap the magnifying glass to find a word or phrase, or jump straight to a reference like John 3:16."
        case .translation:
            return "Tap the version name (like KJV) to compare translations — or read the original Greek and Hebrew."
        case .audio:
            return "Tap the headphones to have the chapter read aloud while you drive, walk, or get ready."
        case .textOptions:
            return "Tap AA to change the font, text size, spacing, and verse-by-verse layout."
        case .navigate:
            return "Tap the book and chapter at the top left (like Psalms 20) to move anywhere in the Bible."
        case .markRead:
            return "Mark chapters as read at the bottom of each chapter. It builds your reading progress and keeps your daily streak alive."
        case .memoryOverview:
            return "Add verses, review them on a spaced schedule, and level up through exercises that get harder as you learn."
        case .memoryReview:
            return "Verses that are due glow on your path. Swipe through quick flashcards first, then try exercises that get harder as a verse sticks."
        case .memoryAdd:
            return "Tap the + button at the bottom right to add any verse. Type a reference and Reforged fetches the text for you."
        case .memoryPractice:
            return "The bar along the bottom has Practice, Speak, Match, Fill and Loop — different ways to lock a verse into memory."
        case .memoryHelp:
            return "Tap the ? at the top right any time for a quick explanation of how spaced repetition works."
        case .memoryStats:
            return "Up top: your daily streak, your level, and your crowns. They grow every time you read, review, or learn."
        case .shield:
            return "Focus Shield can block distracting or harmful apps and sites — on a schedule, or whenever you need to focus."
        case .tempted:
            return "\"I'm Being Tempted\" gives you a quick way to pause, breathe, and take hold of Scripture in the moment."
        case .learningPath:
            return "My Learning Path walks you through lessons step by step. Tap Continue to pick up right where you left off."
        case .disciplines:
            return "My Disciplines lets you add habits to build or avoid, set reminders, and create your own reading plans."
        case .resources:
            return "Scroll down for more: resources like the Walk Talks podcast, and tools to help you share the gospel."
        case .homeSearch:
            return "The search bar up top finds Scripture, topics, and words across the whole app."
        case .homeToday:
            return "This card picks your next step each time you open Reforged — verses due for review, today's reading, or your next lesson."
        case .homeReading:
            return "Just below you'll find today's reading plan and a guided morning, afternoon, or evening routine."
        case .homeProgress:
            return "Scroll down to see your daily streak, level, chapters read, and a calendar of your reading."
        case .homeDiscover:
            return "Daily Insight, Continue Learning, and Quick Actions help you pick up a lesson, read, or share the gospel."
        case .profile:
            return "Tap your picture for badges, progress, and all app settings. You can replay this tour from Settings anytime."
        }
    }

    /// Whether the card hovers at the bottom (so it doesn't cover what it describes).
    var onBottom: Bool {
        switch self {
        case .shield, .tempted, .homeSearch, .homeToday: return true
        default: return false
        }
    }

    /// Horizontal position (0–1 across the screen) of the control the card points at,
    /// for steps about a button in the top bar. `nil` = no arrow.
    var pointerX: CGFloat? {
        switch self {
        case .navigate:    return 0.20
        case .translation: return 0.46
        case .search:      return 0.67
        case .audio:       return 0.79
        case .textOptions: return 0.91
        case .memoryHelp:  return 0.93
        case .profile:     return 0.90
        default:           return nil
        }
    }
}

@MainActor
final class AppTour: ObservableObject {
    static let shared = AppTour()
    private init() {}

    private static let startedKey = "appTourStarted"
    private static let disabledKey = "appTourDisabled"
    private static let doneKey = "appTourDoneSections"

    /// The step on screen right now; `nil` = nothing showing.
    @Published private(set) var step: TourStep?

    private var started: Bool {
        get { UserDefaults.standard.bool(forKey: Self.startedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.startedKey) }
    }
    private var disabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.disabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.disabledKey) }
    }
    private var doneSections: Set<Int> {
        get { Set(UserDefaults.standard.array(forKey: Self.doneKey) as? [Int] ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: Self.doneKey) }
    }

    // MARK: Account sync (so a restored account does not replay the tour)

    func exportPreferences() -> SyncedPreferences.TourPreferences {
        SyncedPreferences.TourPreferences(started: started, disabled: disabled, doneSections: Array(doneSections).sorted())
    }

    /// Restores the tour state saved with the account. With nothing saved, a restored
    /// account counts as having seen the tour (Settings and the device checklist still
    /// offer it on request).
    func restore(from saved: SyncedPreferences.TourPreferences?) {
        if let saved, saved.started {
            started = true
            disabled = saved.disabled
            doneSections = Set(saved.doneSections)
        } else {
            markSeenForRestoredAccount()
        }
    }

    func markSeenForRestoredAccount() {
        started = true
        doneSections = Set(TourSection.allCases.map(\.rawValue))
    }

    // MARK: Entry points

    /// From Settings: replay everything from the top, in the Bible.
    func start() {
        disabled = false
        doneSections = []
        started = true
        present(.holdToDefine, navigate: true)
    }

    /// App launch (main UI on screen). First ever launch begins the tour in the Bible;
    /// later launches pick up any section the user hasn't seen on the view they land on.
    func launchCheck(currentTab: Int) {
        guard !disabled else { return }
        if !started {
            started = true
            present(.holdToDefine, navigate: true)
        } else {
            tabChanged(to: currentTab)
        }
    }

    /// The user moved to another view. If its section is unseen, open the walkthrough
    /// for that view; if the card is still showing a different view's step, put it away.
    func tabChanged(to tab: Int) {
        guard started, !disabled else { return }
        if let step, step.tab == tab { return }
        if !doneSections.contains(tab),
           let section = TourSection(rawValue: tab),
           let first = TourStep.steps(in: section).first {
            present(first, navigate: false)
        } else if step != nil {
            dismiss()
        }
    }

    // MARK: Controls

    func next() {
        guard let step else { return }
        if let target = TourStep(rawValue: step.rawValue + 1) {
            let crossing = target.tab != step.tab
            if crossing { markDone(step.section) }
            present(target, navigate: crossing)
        } else {
            markDone(step.section)
            dismiss()
        }
    }

    func back() {
        guard let step, let target = TourStep(rawValue: step.rawValue - 1) else { return }
        present(target, navigate: target.tab != step.tab)
    }

    /// ✕ — skip just this view's walkthrough. Other views still open theirs when visited.
    func skipSection() {
        if let step { markDone(step.section) }
        dismiss()
    }

    /// "Skip tour" — turn the whole thing off.
    func skipAll() {
        disabled = true
        doneSections = Set(TourSection.allCases.map(\.rawValue))
        dismiss()
    }

    /// Where "Next" leads: the section name when it crosses into another view.
    func nextDestination(from step: TourStep) -> String? {
        guard let target = TourStep(rawValue: step.rawValue + 1), target.section != step.section else { return nil }
        return target.section.name
    }

    var isLastStep: Bool { step.map { TourStep(rawValue: $0.rawValue + 1) == nil } ?? false }

    // MARK: Internals

    private func markDone(_ section: TourSection) {
        var done = doneSections
        done.insert(section.rawValue)
        doneSections = done
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.2)) { step = nil }
    }

    private func present(_ target: TourStep, navigate: Bool) {
        if navigate {
            NotificationCenter.default.post(
                name: .switchTab,
                object: nil,
                userInfo: [AppNotificationUserInfoKey.tab: target.tab]
            )
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { step = target }
    }
}

// MARK: - Overlay

/// One floating card, attached once at the app root. Only the card itself takes touches —
/// everything around it stays live, so the user can poke at the app mid-tour.
struct AppTourOverlay: View {
    @ObservedObject private var tour = AppTour.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            if let step = tour.step {
                VStack(spacing: 0) {
                    if step.onBottom { Spacer(minLength: 0) }
                    card(for: step, screenWidth: geo.size.width)
                        .padding(.horizontal, 16)
                        .padding(step.onBottom ? .bottom : .top, step.onBottom ? 70 : 56)
                    if !step.onBottom { Spacer(minLength: 0) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .move(edge: step.onBottom ? .bottom : .top)))
                .id(step)
            }
        }
    }

    private func card(for step: TourStep, screenWidth: CGFloat) -> some View {
        let siblings = TourStep.steps(in: step.section)
        let position = (siblings.firstIndex(of: step) ?? 0) + 1

        return VStack(spacing: 0) {
            // Arrow toward the control the step is about.
            if let fraction = step.pointerX {
                HStack(spacing: 0) {
                    TourArrow()
                        .fill(Color.adaptiveCardBackground(colorScheme))
                        .frame(width: 20, height: 10)
                        .offset(x: max(8, min(screenWidth - 32 - 28, screenWidth * fraction - 16 - 10)))
                    Spacer(minLength: 0)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: step.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                        .frame(width: 40, height: 40)
                        .background(Color.reforgedGold.opacity(0.15), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(step.section.name.uppercased()) · \(position) OF \(siblings.count)")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.0)
                            .foregroundStyle(Color.reforgedGold)
                        Text(step.title)
                            .font(.headline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Button {
                        tour.skipSection()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .frame(width: 28, height: 28)
                            .background(Color.adaptiveTextSecondary(colorScheme).opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Skip this part of the tour")
                }

                Text(step.message)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    if step != TourStep.allCases.first {
                        Button {
                            HapticManager.shared.buttonTap()
                            tour.back()
                        } label: {
                            Text("Back")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 11)
                                .background(Color.adaptiveTextSecondary(colorScheme).opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        HapticManager.shared.buttonTap()
                        tour.next()
                    } label: {
                        Text(nextTitle(for: step))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.reforgedGold, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    tour.skipAll()
                } label: {
                    Text("Skip tour")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.adaptiveCardBackground(colorScheme))
            )
        }
        .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
    }

    private func nextTitle(for step: TourStep) -> String {
        if tour.isLastStep { return "Done" }
        if let destination = tour.nextDestination(from: step) { return "Next: \(destination)" }
        return "Next"
    }
}

private struct TourArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Feature usage (first use)

enum Feature: String, CaseIterable {
    case wordLookup, verseSelect, search, translationSwitch, audio, textOptions
    case memoryTab, memoryVerseAdded, reviewStarted
    case disciplines, shield, streakCard, profile
}

/// Local, private record of when each feature was first used. Handy for seeing which
/// features a person has never touched. Nothing leaves the device.
enum FeatureUsage {
    private static func key(_ f: Feature) -> String { "featureFirstUse.\(f.rawValue)" }

    static func record(_ f: Feature) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key(f)) == nil else { return }
        defaults.set(Date(), forKey: key(f))
    }

    static func has(_ f: Feature) -> Bool {
        UserDefaults.standard.object(forKey: key(f)) != nil
    }

    static func firstUse(_ f: Feature) -> Date? {
        UserDefaults.standard.object(forKey: key(f)) as? Date
    }
}
