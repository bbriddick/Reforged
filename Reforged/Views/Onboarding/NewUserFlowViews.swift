import SwiftUI

// MARK: - New-user onboarding (Phase 2)
//
// Welcome → Your Bible → First verse → First review → First win → Walk Talks → Reminder
// → Keep it safe (account, deferred) → Bible, where the app tour begins.
//
// The point is the first review: a new person learns a real verse in about a minute
// instead of reading four feature slides and eight setup screens. Everything else
// (name, goals, display, AI, library) now appears in context later.

// MARK: Shared pieces

struct OnbDots: View {
    let index: Int
    let count: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i <= index ? Color.reforgedCoral.opacity(i == index ? 1 : 0.5)
                                     : Color.adaptiveTextSecondary(colorScheme).opacity(0.25))
                    .frame(width: i == index ? 22 : 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(index + 1) of \(count)")
    }
}

private struct OnbGhostButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(NoBlobButtonStyle())
    }
}

private struct OnbHeader: View {
    let title: String
    let lead: String?
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
            if let lead {
                Text(lead)
                    .font(.body)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 44)   // clear air under the back button and progress dots
    }
}

/// One verse offered in the first-verse step. KJV text is public domain and ships with the
/// app, so this works offline on a brand-new install.
struct OnbVerse: Identifiable, Equatable {
    let ref: String
    let theme: String
    let text: String
    var id: String { ref }

    static let options: [OnbVerse] = [
        OnbVerse(ref: "John 3:16", theme: "Salvation",
                 text: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life."),
        OnbVerse(ref: "Philippians 4:6", theme: "Peace",
                 text: "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God."),
        OnbVerse(ref: "Jeremiah 29:11", theme: "Hope",
                 text: "For I know the thoughts that I think toward you, saith the LORD, thoughts of peace, and not of evil, to give you an expected end.")
    ]
}

private let scriptureFont = Font.custom("LibreBaskerville-Regular", size: 17)

// MARK: Your Bible

struct YourBibleStepView: View {
    let onNext: () -> Void
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var previews: [BibleTranslation: String] = [:]
    @State private var failed: Set<BibleTranslation> = []

    private let translations = BibleTranslation.allCases.filter { !$0.isOriginalLanguage }
    private let kjvJohn316 = OnbVerse.options[0].text

    var body: some View {
        VStack(spacing: 0) {
            OnbDots(index: 0, count: 5).padding(.top, 24)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnbHeader(title: "Your Bible.",
                              lead: "\(settings.defaultTranslation.fullName) is selected. You can change it any time.")

                    // Compact pills instead of eight stacked rows: more air, and the verse stays on screen.
                    FlowLayout(spacing: 10, lineSpacing: 12) {
                        ForEach(translations) { t in
                            let selected = settings.defaultTranslation == t
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) { settings.defaultTranslation = t }
                                HapticManager.shared.buttonTap()
                            } label: {
                                Text(t.rawValue)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(selected ? Color.white : Color.adaptiveText(colorScheme))
                                    .padding(.horizontal, 20)
                                    .frame(minHeight: 48)
                                    .background(Capsule().fill(selected ? Color.reforgedCoral : Color.adaptiveChipBackground(colorScheme)))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(NoBlobButtonStyle())
                            .accessibilityLabel(t.fullName)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.top, 32)

                    preview
                        .padding(.top, 32)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
            ReturningPrimaryButton(title: "Continue", action: onNext)
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 36)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .task(id: settings.defaultTranslation) { await loadPreview(settings.defaultTranslation) }
    }

    private var preview: some View {
        let t = settings.defaultTranslation
        return VStack(alignment: .leading, spacing: 14) {
            Text("JOHN 3:16 · \(t.rawValue)")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.reforgedGold)
            Group {
                if let text = previews[t] {
                    Text(text)
                } else if failed.contains(t) {
                    Text("We couldn't load a preview right now. You can still pick this one and change it any time.")
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                } else {
                    Text("Loading…").foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .font(.custom("LibreBaskerville-Regular", size: 19))
            .lineSpacing(9)
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.adaptiveText(colorScheme))
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .padding(26)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 10, y: 5)
        .animation(.easeOut(duration: 0.25), value: previews[t])
    }

    private func loadPreview(_ t: BibleTranslation) async {
        guard previews[t] == nil else { return }
        if t == .kjv { previews[t] = kjvJohn316; return }
        failed.remove(t)
        do {
            let result = try await VerseTextFetcher.fetch(reference: "John 3:16", translation: t)
            if result.text.isEmpty { failed.insert(t) } else { previews[t] = result.text }
        } catch {
            failed.insert(t)
        }
    }
}

// MARK: First verse

struct FirstVerseStepView: View {
    let onPick: (OnbVerse) -> Void
    let onSkip: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            OnbDots(index: 1, count: 5).padding(.top, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    OnbHeader(title: "Start with one verse.",
                              lead: "Pick one. We'll bring it back right before you'd forget it.")
                        .padding(.bottom, 10)
                    ForEach(OnbVerse.options) { verse in
                        Button { onPick(verse) } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(verse.theme.uppercased())
                                        .font(.caption.weight(.bold))
                                        .tracking(1)
                                        .foregroundStyle(Color.reforgedGold)
                                    Text(verse.ref)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .font(.title2)
                                    .foregroundStyle(Color.reforgedGold)
                            }
                            .padding(18)
                            .frame(minHeight: 72)
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 8, y: 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(NoBlobButtonStyle())
                        .accessibilityHint("Adds this verse and starts your first review")
                    }
                }
                .padding(.horizontal, 24)
            }
            OnbGhostButton(title: "Skip for now", action: onSkip)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }
}

// MARK: First review

struct FirstReviewStepView: View {
    let verse: OnbVerse
    let onGotIt: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var revealed = false
    @State private var triedAgain = false

    var body: some View {
        VStack(spacing: 0) {
            OnbDots(index: 1, count: 5).padding(.top, 20)
            Text("YOUR FIRST REVIEW")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.reforgedGold)
                .padding(.top, 52)

            Button { withAnimation(.easeOut(duration: 0.25)) { revealed = true } } label: {
                VStack(spacing: 14) {
                    Text("KJV")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.reforgedGold)
                    Text(verse.ref)
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    if revealed {
                        Text(verse.text)
                            .font(.custom("LibreBaskerville-Regular", size: 19))
                            .lineSpacing(7)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .padding(.top, 6)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Text(triedAgain ? "One more try. Say it, then tap to check." : "Try saying it, then tap to check")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 36)
                            .overlay(Capsule().strokeBorder(Color.adaptiveTextSecondary(colorScheme).opacity(0.35),
                                                            style: StrokeStyle(lineWidth: 1.5, dash: [4])))
                            .padding(.top, 8)
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .accessibilityLabel(revealed ? "\(verse.ref). \(verse.text)" : "\(verse.ref). Tap to reveal the verse")

            VStack(spacing: 8) {
                if revealed {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation { revealed = false; triedAgain = true }
                        } label: {
                            Text("Not yet")
                                .font(.headline)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(Capsule().fill(Color.adaptiveChipBackground(colorScheme)))
                        }
                        .buttonStyle(NoBlobButtonStyle())
                        ReturningPrimaryButton(title: "Got it", action: onGotIt)
                    }
                    Text("How it went decides when it comes back.")
                        .font(.footnote)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                } else {
                    ReturningPrimaryButton(title: "Show the verse") {
                        withAnimation(.easeOut(duration: 0.25)) { revealed = true }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }
}

// MARK: First win

struct FirstWinStepView: View {
    let verseRef: String
    let elapsed: String?
    let onNext: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var popped = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.reforgedGold.opacity(0.18))
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(Color.reforgedGold)
                }
                .frame(width: 112, height: 112)
                .scaleEffect(popped ? 1 : 0.5)
                .opacity(popped ? 1 : 0)
                .shadow(color: Color.reforgedGold.opacity(0.25), radius: 14, y: 6)

                Text("Your first verse.")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Label("+15 XP", systemImage: "sparkles")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Color.reforgedGold)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 34)
                    .background(Capsule().fill(Color.reforgedGold.opacity(0.16)))
                Text("\(verseRef) is yours to keep. It comes back tomorrow, right when you're about to forget it.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .padding(.horizontal, 36)
                if let elapsed {
                    Text("You did that in \(elapsed).")
                        .font(.footnote)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.8))
                }
            }
            Spacer()
            ReturningPrimaryButton(title: "Continue", action: onNext)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { popped = true } }
    }
}

// MARK: Daily reminder

struct ReminderStepView: View {
    let onNext: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    /// 0...2 are presets, 3 is "Custom".
    @State private var selected = 1
    @State private var asking = false
    @State private var customTime: Date = {
        var c = DateComponents(); c.hour = 20; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()

    private let presets: [(label: String, hour: Int, minute: Int)] = [
        ("6:30 AM", 6, 30), ("7:30 AM", 7, 30), ("12:00 PM", 12, 0)
    ]
    private var isCustom: Bool { selected == presets.count }

    /// The chosen time as a label plus hour and minute.
    private var current: (label: String, hour: Int, minute: Int) {
        if !isCustom { return presets[selected] }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: customTime)
        return (customTime.formatted(date: .omitted, time: .shortened), comps.hour ?? 20, comps.minute ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            OnbDots(index: 3, count: 5).padding(.top, 24)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnbHeader(title: "Set a daily reminder.",
                              lead: "A reminder to read and review your verse. Pick a time that fits your day, and change it or turn it off any time.")

                    let parts = current.label.split(separator: " ")
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(parts.first ?? ""))
                            .font(.system(size: 60, weight: .heavy))
                        Text(String(parts.last ?? ""))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 34)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(0...presets.count, id: \.self) { i in
                            let label = i < presets.count ? presets[i].label : "Custom"
                            Button { withAnimation(.easeOut(duration: 0.2)) { selected = i } } label: {
                                HStack(spacing: 6) {
                                    if i == presets.count { Image(systemName: "clock") }
                                    Text(label)
                                }
                                .font(.headline)
                                .foregroundStyle(selected == i ? Color.adaptiveBackground(colorScheme) : Color.adaptiveText(colorScheme))
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Capsule().fill(selected == i ? Color.adaptiveText(colorScheme) : Color.adaptiveChipBackground(colorScheme)))
                            }
                            .buttonStyle(NoBlobButtonStyle())
                            .accessibilityAddTraits(selected == i ? .isSelected : [])
                        }
                    }
                    .padding(.top, 24)

                    if isCustom {
                        DatePicker("Reminder time", selection: $customTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 24)
            }
            VStack(spacing: 4) {
                ReturningPrimaryButton(title: asking ? "One moment..." : "Remind me at \(current.label)", action: enable)
                    .disabled(asking)
                OnbGhostButton(title: "Not now", action: decline)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    private func enable() {
        asking = true
        let t = current
        NotificationManager.shared.requestAuthorization { granted in
            asking = false
            if granted {
                let s = SettingsManager.shared
                var c = DateComponents(); c.hour = t.hour; c.minute = t.minute
                s.dailyReminderTime = Calendar.current.date(from: c) ?? s.dailyReminderTime
                s.notificationsEnabled = true
                s.readingPlanReminders = true
                s.dailyMemoryReminders = true
                s.memoryReviewReminders = true
                NotificationManager.shared.scheduleDailyReminder()
            }
            onNext()
        }
    }

    /// "Not now" still honors an earlier yes: if they turned on Walk Talks episode alerts,
    /// this is the one place the system permission prompt appears.
    private func decline() {
        if SettingsManager.shared.podcastNewEpisodeNotifications {
            NotificationManager.shared.requestAuthorization { _ in onNext() }
        } else {
            onNext()
        }
    }
}
