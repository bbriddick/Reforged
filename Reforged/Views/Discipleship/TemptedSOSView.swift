import SwiftUI

// MARK: - Tempted SOS Flow
//
// Full-screen help for the moment of temptation. It follows the pattern biblical
// counselors teach rather than just distracting: slow down (Ps 46:10), name what is
// pulling and what it promises (Jas 1:14), fight with the Word the way Jesus did
// (Matt 4:4), put off and put on with one concrete step (Eph 4:22-24, Rom 12:21),
// then pray and tell someone (Heb 4:16, Jas 5:16). Scripture is the public-domain KJV.
// If the person already gave in, a separate path leads to confession and grace
// (1 John 1:9) instead of shame. Uses count as a positive stat
// (see AccountabilityPartnerService.recordSOSUse).

// MARK: Content

struct TemptationVerse {
    let text: String
    let reference: String
}

enum TemptationKind: String, CaseIterable, Identifiable {
    case lust, anger, anxiety, pride, numbing, lonely, bitter, other
    var id: String { rawValue }

    var title: String {
        switch self {
        case .lust: return "Lust or porn"
        case .anger: return "Anger"
        case .anxiety: return "Worry or fear"
        case .pride: return "Pride or comparison"
        case .numbing: return "Numbing out"
        case .lonely: return "Loneliness"
        case .bitter: return "Bitterness"
        case .other: return "Something else"
        }
    }

    var icon: String {
        switch self {
        case .lust: return "eye.slash.fill"
        case .anger: return "flame.fill"
        case .anxiety: return "cloud.rain.fill"
        case .pride: return "crown.fill"
        case .numbing: return "tv.fill"
        case .lonely: return "person.fill.questionmark"
        case .bitter: return "bolt.heart.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    /// How the temptation reads inside a prayer.
    var prayerName: String {
        switch self {
        case .lust: return "the pull toward lust"
        case .anger: return "my anger"
        case .anxiety: return "my worry"
        case .pride: return "pride"
        case .numbing: return "the urge to numb out"
        case .lonely: return "loneliness"
        case .bitter: return "bitterness"
        case .other: return "this temptation"
        }
    }

    /// Verses to fight with (KJV). One is shown per visit so it isn't always the same.
    var verses: [TemptationVerse] {
        switch self {
        case .lust:
            return [
                TemptationVerse(text: "Flee also youthful lusts: but follow righteousness, faith, charity, peace, with them that call on the Lord out of a pure heart.", reference: "2 Timothy 2:22"),
                TemptationVerse(text: "I made a covenant with mine eyes; why then should I think upon a maid?", reference: "Job 31:1"),
                TemptationVerse(text: "I will set no wicked thing before mine eyes: I hate the work of them that turn aside; it shall not cleave to me.", reference: "Psalm 101:3"),
            ]
        case .anger:
            return [
                TemptationVerse(text: "Be ye angry, and sin not: let not the sun go down upon your wrath: Neither give place to the devil.", reference: "Ephesians 4:26-27"),
                TemptationVerse(text: "A soft answer turneth away wrath: but grievous words stir up anger.", reference: "Proverbs 15:1"),
                TemptationVerse(text: "Wherefore, my beloved brethren, let every man be swift to hear, slow to speak, slow to wrath: For the wrath of man worketh not the righteousness of God.", reference: "James 1:19-20"),
            ]
        case .anxiety:
            return [
                TemptationVerse(text: "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God. And the peace of God, which passeth all understanding, shall keep your hearts and minds through Christ Jesus.", reference: "Philippians 4:6-7"),
                TemptationVerse(text: "Casting all your care upon him; for he careth for you.", reference: "1 Peter 5:7"),
                TemptationVerse(text: "Take therefore no thought for the morrow: for the morrow shall take thought for the things of itself. Sufficient unto the day is the evil thereof.", reference: "Matthew 6:34"),
            ]
        case .pride:
            return [
                TemptationVerse(text: "But he giveth more grace. Wherefore he saith, God resisteth the proud, but giveth grace unto the humble. Submit yourselves therefore to God. Resist the devil, and he will flee from you.", reference: "James 4:6-7"),
                TemptationVerse(text: "Pride goeth before destruction, and an haughty spirit before a fall.", reference: "Proverbs 16:18"),
                TemptationVerse(text: "Let nothing be done through strife or vainglory; but in lowliness of mind let each esteem other better than themselves.", reference: "Philippians 2:3"),
            ]
        case .numbing:
            return [
                TemptationVerse(text: "Trust in him at all times; ye people, pour out your heart before him: God is a refuge for us.", reference: "Psalm 62:8"),
                TemptationVerse(text: "Come unto me, all ye that labour and are heavy laden, and I will give you rest.", reference: "Matthew 11:28"),
                TemptationVerse(text: "God is our refuge and strength, a very present help in trouble.", reference: "Psalm 46:1"),
            ]
        case .lonely:
            return [
                TemptationVerse(text: "Let your conversation be without covetousness; and be content with such things as ye have: for he hath said, I will never leave thee, nor forsake thee.", reference: "Hebrews 13:5"),
                TemptationVerse(text: "The Lord is nigh unto them that are of a broken heart; and saveth such as be of a contrite spirit.", reference: "Psalm 34:18"),
                TemptationVerse(text: "Fear thou not; for I am with thee: be not dismayed; for I am thy God: I will strengthen thee; yea, I will help thee; yea, I will uphold thee with the right hand of my righteousness.", reference: "Isaiah 41:10"),
            ]
        case .bitter:
            return [
                TemptationVerse(text: "Forbearing one another, and forgiving one another, if any man have a quarrel against any: even as Christ forgave you, so also do ye.", reference: "Colossians 3:13"),
                TemptationVerse(text: "Let all bitterness, and wrath, and anger, and clamour, and evil speaking, be put away from you, with all malice: And be ye kind one to another, tenderhearted, forgiving one another, even as God for Christ's sake hath forgiven you.", reference: "Ephesians 4:31-32"),
                TemptationVerse(text: "Looking diligently lest any man fail of the grace of God; lest any root of bitterness springing up trouble you, and thereby many be defiled;", reference: "Hebrews 12:15"),
            ]
        case .other:
            return [
                TemptationVerse(text: "There hath no temptation taken you but such as is common to man: but God is faithful, who will not suffer you to be tempted above that ye are able; but will with the temptation also make a way to escape, that ye may be able to bear it.", reference: "1 Corinthians 10:13"),
                TemptationVerse(text: "Watch and pray, that ye enter not into temptation: the spirit indeed is willing, but the flesh is weak.", reference: "Matthew 26:41"),
                TemptationVerse(text: "But put ye on the Lord Jesus Christ, and make not provision for the flesh, to fulfil the lusts thereof.", reference: "Romans 13:14"),
            ]
        }
    }

    /// Forward-looking questions that help someone see where this leads (James 1:14-15).
    /// One is shown per visit so the screen doesn't read the same every time.
    var thinkAhead: [String] {
        switch self {
        case .lust:
            return ["Where will your mind be tonight if you give in?",
                    "An hour from now, will you feel free and clean, or ashamed and hiding?",
                    "Who are you becoming if you keep saying yes to this? Who do you want to become?"]
        case .anger:
            return ["How will you feel about what you say or send by dinner tonight?",
                    "Will the other person remember your words or your gentleness?",
                    "An hour from now, will you wish you had spoken, or wish you had waited?"]
        case .anxiety:
            return ["Will worrying change anything an hour from now, or only cost you your peace?",
                    "What would it look like to trust God with this one thing for the next hour?",
                    "Think of a time God carried you through before. What did he do?"]
        case .pride:
            return ["An hour from now, will this have made you more like Christ or less?",
                    "Who gets hurt or left out if you keep comparing?",
                    "What would humility look like in the next five minutes?"]
        case .numbing:
            return ["When the screen or snack is gone, what will still be waiting for you?",
                    "An hour from now, will you feel rested, or more weighed down?",
                    "What would you tell a friend who was about to numb out like this?"]
        case .lonely:
            return ["An hour from now, will this have brought you closer to people, or further away?",
                    "Who could you reach out to in the next five minutes?",
                    "What is the loneliness pointing to that God and his people can actually meet?"]
        case .bitter:
            return ["Will carrying this grudge tonight cost you more than it costs them?",
                    "What would it look like to hand this over to God for the next hour?",
                    "Picture yourself a year from now, free of this. What did you let go of?"]
        case .other:
            return ["Picture an hour from now. Will you be glad you gave in, or glad you waited?",
                    "Who will be affected by this choice besides you?",
                    "When you look back on today, what will you wish you had chosen?"]
        }
    }

    /// Concrete ways to put off the sin and put on something good, right now.
    var actions: [String] {
        switch self {
        case .lust:
            return ["Put the device away and leave the room",
                    "Move your body: walk outside or do push-ups",
                    "Call or text someone who knows your struggle"]
        case .anger:
            return ["Step away before you say or send anything",
                    "Pray for the person by name",
                    "Write down what happened, then wait before you reply"]
        case .anxiety:
            return ["Write down the worry, then pray it to God",
                    "Name three things you can thank God for right now",
                    "Do the next small, faithful thing in front of you"]
        case .pride:
            return ["Thank God for something someone else has",
                    "Send an honest word of encouragement to the person you compare yourself to",
                    "Ask God where you are relying on yourself"]
        case .numbing:
            return ["Put the screen or snack down and step outside",
                    "Tell God plainly what you are trying to escape",
                    "Do one small task you have been avoiding"]
        case .lonely:
            return ["Text or call a friend or family member",
                    "Go be around people, even for ten minutes",
                    "Read Psalm 23 out loud"]
        case .bitter:
            return ["Pray for the person who hurt you",
                    "Write what you can forgive, and give the rest to God",
                    "Do something kind for someone else"]
        case .other:
            return ["Leave the place or situation if you can",
                    "Pray out loud and ask God for help",
                    "Tell someone you trust what is happening"]
        }
    }
}

enum TemptationPromise: String, CaseIterable, Identifiable {
    case comfort, relief, wanted, control, pleasure, payback, escape
    var id: String { rawValue }

    var title: String {
        switch self {
        case .comfort: return "Comfort"
        case .relief: return "Relief from stress"
        case .wanted: return "Feeling wanted"
        case .control: return "Control"
        case .pleasure: return "Pleasure"
        case .payback: return "Getting even"
        case .escape: return "Escape"
        }
    }

    /// What is actually true, set against what the temptation promises.
    var truth: (line: String, reference: String) {
        switch self {
        case .comfort:
            return ("It won't comfort you for long. Jesus will.", "Matthew 11:28")
        case .relief:
            return ("It only postpones the stress and adds shame. Bring the weight to God instead.", "1 Peter 5:7")
        case .wanted:
            return ("In Christ you are already accepted and fully known.", "Ephesians 1:6")
        case .control:
            return ("You are not in control, and you don't have to be. God is.", "Proverbs 3:5")
        case .pleasure:
            return ("Sin's pleasure lasts a season. In God's presence is fullness of joy.", "Psalm 16:11")
        case .payback:
            return ("Vengeance belongs to the Lord. You can put it down.", "Romans 12:19")
        case .escape:
            return ("Escaping through sin traps you further. God is a refuge you can run to.", "Psalm 62:8")
        }
    }
}

/// Verses for "ask him for help now", rotated so the closing card isn't always the same.
let temptationHelpVerses: [(verse: TemptationVerse, caption: String)] = [
    (TemptationVerse(text: "Let us therefore come boldly unto the throne of grace, that we may obtain mercy, and find grace to help in time of need.", reference: "Hebrews 4:16"),
     "Jesus was tempted too. Ask him for help now."),
    (TemptationVerse(text: "For in that he himself hath suffered being tempted, he is able to succour them that are tempted.", reference: "Hebrews 2:18"),
     "He knows exactly what this is like. Ask him for help now."),
    (TemptationVerse(text: "God is our refuge and strength, a very present help in trouble.", reference: "Psalm 46:1"),
     "He is close right now. Run to him."),
    (TemptationVerse(text: "Blessed is the man that endureth temptation: for when he is tried, he shall receive the crown of life, which the Lord hath promised to them that love him.", reference: "James 1:12"),
     "Standing firm matters to God. Keep going."),
    (TemptationVerse(text: "And lead us not into temptation, but deliver us from evil:", reference: "Matthew 6:13"),
     "Jesus taught us to pray for this. Pray it now."),
]

// MARK: View

struct TemptedSOSView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    private enum Stage: Int {
        case breathe, name, truth, act, pray, reach, fallen
    }

    /// Stages that show in the progress bar.
    private let progressCount = 5

    @State private var stage: Stage = .breathe
    /// 0 = fully breathed out, 1 = fully breathed in. Everything on screen follows this.
    @State private var breathProgress: CGFloat = 0
    @State private var breathPhase: BreathPhase = .inhale
    @State private var breathStarted = false
    @State private var breathFinished = false
    @State private var breathMinutes = 1
    @State private var breathElapsed = 0
    @State private var phaseElapsed = 0
    /// The 988 note appears once per visit, not on both of the last two screens.
    @State private var crisisNoteShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var trigger: TemptationKind?
    @State private var promise: TemptationPromise?
    @State private var chosenAction: String?
    @State private var thinkAheadIndex = 0
    @State private var verseIndex = 0
    @State private var helpIndex = 0
    @State private var showMessageComposer = false
    @State private var showJournal = false
    @State private var showPartnerSetup = false

    private let breathTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Six breaths a minute (4 seconds in, 6 out): a slow, long exhale. Apple's Breathe
    /// and Calm both default to a similar unhurried pace.
    private enum BreathPhase {
        case inhale, exhale
        var label: String { self == .inhale ? "Breathe in" : "Breathe out" }
        var seconds: Int { self == .inhale ? 4 : 6 }
        var target: CGFloat { self == .inhale ? 1 : 0 }
        var next: BreathPhase { self == .inhale ? .exhale : .inhale }
    }

    private var breathSessionSeconds: Int { breathMinutes * 60 }
    private var breathSecondsLeft: Int { max(breathSessionSeconds - breathElapsed, 0) }

    private var kind: TemptationKind { trigger ?? .other }

    var body: some View {
        ZStack {
            Color.adaptiveBackground(colorScheme).ignoresSafeArea()

            if stage == .breathe {
                breatheStage
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
                        }
                        .accessibilityLabel("Close")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    if stage.rawValue < progressCount {
                        PracticeStepBar(total: progressCount, completed: stage.rawValue)
                            .padding(.top, 8)
                    }

                    Group {
                        switch stage {
                        case .breathe: EmptyView()
                        case .name:    nameStage
                        case .truth:   truthStage
                        case .act:     actStage
                        case .pray:    prayStage
                        case .reach:   reachStage
                        case .fallen:  fallenStage
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(stage == .breathe ? .dark : nil)
        .onAppear {
            AccountabilityPartnerService.shared.recordSOSUse()
        }
        .sheet(isPresented: $showMessageComposer) {
            MessageComposeView(
                recipients: AccountabilityPartnerService.shared.partnerPhone.isEmpty
                    ? [] : [AccountabilityPartnerService.shared.partnerPhone],
                body: stage == .fallen
                    ? "Hey, I gave in just now and I want to tell you instead of hiding it. Can we talk and pray?"
                    : tellMessage
            ) {
                showMessageComposer = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showJournal) {
            NavigationStack {
                JournalView()
            }
        }
        .sheet(isPresented: $showPartnerSetup) {
            NavigationStack {
                AccountabilityPartnerView()
            }
        }
    }

    private func advance(to next: Stage) {
        HapticManager.shared.buttonTap()
        if next == .truth {
            thinkAheadIndex = Int.random(in: 0..<3)
            verseIndex = Int.random(in: 0..<3)
            helpIndex = Int.random(in: 0..<temptationHelpVerses.count)
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            stage = next
        }
    }

    // MARK: Shared pieces

    private func heading(_ title: String, _ subtitle: String? = nil) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 28)
    }

    private func verseCard(_ verse: TemptationVerse, caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let caption {
                Text(caption.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            Text("\u{201C}\(verse.text)\u{201D}")
                .font(Font.custom("LibreBaskerville-Italic", size: 17))
                .lineSpacing(8)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text(verse.reference)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.reforgedGold)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .practiceCard(radius: 20)
    }

    private func chip(_ title: String, icon: String? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.selectionChanged()
            action()
        } label: {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(selected ? Color.white : Color.adaptiveText(colorScheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(selected ? Color.reforgedCoral : Color.adaptiveCardBackground(colorScheme),
                        in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.clear : Color.adaptiveBorder(colorScheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func quietLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 1. Be still (full-screen guided breathing)
    //
    // Modeled on the breathing exercises in Apple's Breathe and Calm: one calm shape that
    // grows as you breathe in and settles as you breathe out, a single text cue, a gentle
    // tap at each change, a short choice of length before you start, and nothing else.

    // Charcoal and warm golds in both light and dark mode: low-stimulation and calm.
    private var breathInk: Color { Color(red: 0.93, green: 0.90, blue: 0.85) }
    private var breathMuted: Color { breathInk.opacity(0.62) }
    private var breathGold: Color { Color(red: 0.83, green: 0.65, blue: 0.45) }
    private var breathGoldSoft: Color { Color(red: 0.93, green: 0.80, blue: 0.62) }
    private var breathGoldDeep: Color { Color(red: 0.65, green: 0.47, blue: 0.28) }

    private var breatheBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.10, green: 0.10, blue: 0.11), Color(red: 0.20, green: 0.20, blue: 0.20)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func breathChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.selectionChanged()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color(red: 0.15, green: 0.15, blue: 0.16) : breathInk)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(selected ? breathGold : Color.white.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func breathQuietLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(breathMuted)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func breathPrimary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title) }
            .buttonStyle(Chunky3DButtonStyle(
                backgroundColor: breathGold,
                bevelColor: breathGoldDeep,
                textColor: Color(red: 0.15, green: 0.15, blue: 0.16)))
            .padding(.horizontal)
    }

    /// Six overlapping circles that bloom outward on the inhale, like Apple's Breathe.
    private var breathFlower: some View {
        let petals = 6
        let petalSize: CGFloat = 170
        let bloom = 62 * breathProgress
        return ZStack {
            ForEach(0..<petals, id: \.self) { index in
                let angle = Double(index) / Double(petals) * 2 * .pi
                Circle()
                    .fill(
                        LinearGradient(
                            colors: index.isMultiple(of: 2)
                                ? [breathGoldSoft, breathGold]
                                : [breathGold, breathGoldDeep],
                            startPoint: .top, endPoint: .bottom)
                    )
                    .opacity(0.34)
                    .blendMode(.plusLighter)
                    .frame(width: petalSize, height: petalSize)
                    .offset(x: reduceMotion ? 0 : CGFloat(cos(angle)) * bloom,
                            y: reduceMotion ? 0 : CGFloat(sin(angle)) * bloom)
            }
        }
        .scaleEffect(reduceMotion ? 1 : 0.72 + 0.28 * breathProgress)
        .rotationEffect(.degrees(reduceMotion ? 0 : Double(breathProgress) * 36))
        // With Reduce Motion on, the shape fades instead of moving.
        .opacity(reduceMotion ? 0.35 + 0.65 * Double(breathProgress) : 1)
        .frame(width: 360, height: 360)
    }

    private var breatheStage: some View {
        ZStack {
            breatheBackground

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(breathMuted)
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if breathStarted && !breathFinished {
                    sessionBody
                } else if breathFinished {
                    finishedBody
                } else {
                    introBody
                }
            }
        }
        .onReceive(breathTimer) { _ in
            guard stage == .breathe, breathStarted, !breathFinished else { return }
            breathElapsed += 1
            phaseElapsed += 1
            if breathElapsed >= breathSessionSeconds, breathPhase == .exhale, phaseElapsed >= breathPhase.seconds {
                breathFinished = true
                HapticManager.shared.success()
            } else if phaseElapsed >= breathPhase.seconds {
                changeBreathPhase()
            }
        }
    }

    // Before starting: a short, calm choice, then Begin.
    private var introBody: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text("Take a minute to breathe")
                    .font(.title2.bold())
                    .foregroundStyle(breathInk)
                Text("A temptation rises, peaks, and passes. You don't have to obey it.")
                    .font(.subheadline)
                    .foregroundStyle(breathMuted)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.top, 24)

            Spacer()
            breathFlower
            Spacer()

            VStack(spacing: 18) {
                HStack(spacing: 10) {
                    ForEach([1, 2, 3], id: \.self) { minutes in
                        breathChip("\(minutes) min", selected: breathMinutes == minutes) { breathMinutes = minutes }
                    }
                }

                breathPrimary("Begin") { startBreathing() }

                breathQuietLink("Skip ahead") { advance(to: .name) }

                Text("\u{201C}Be still, and know that I am God.\u{201D} Psalm 46:10")
                    .font(Font.custom("LibreBaskerville-Italic", size: 13))
                    .foregroundStyle(breathGold)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    // During: one cue, the shape, the time left.
    private var sessionBody: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(breathPhase.label)
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .foregroundStyle(breathInk)
                .id(breathPhase)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.6), value: breathPhase)
                .padding(.bottom, 24)

            breathFlower

            Spacer()

            VStack(spacing: 12) {
                Text(timeString(breathSecondsLeft))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(breathMuted)
                breathQuietLink("Skip ahead") { advance(to: .name) }
            }
            .padding(.bottom, 24)
        }
    }

    private var finishedBody: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 10) {
                Text("Well done")
                    .font(.largeTitle.bold())
                    .foregroundStyle(breathInk)
                Text("The wave has passed. Let's take the next step.")
                    .font(.title3)
                    .foregroundStyle(breathMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            breathFlower
            Spacer()
            breathPrimary("Continue") { advance(to: .name) }
                .padding(.bottom, 20)
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func startBreathing() {
        HapticManager.shared.buttonTap()
        breathElapsed = 0
        phaseElapsed = 0
        breathPhase = .inhale
        breathFinished = false
        breathProgress = 0
        withAnimation(.easeInOut(duration: 0.4)) { breathStarted = true }
        // Next runloop so the shape starts from rest before it grows.
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: Double(BreathPhase.inhale.seconds))) { breathProgress = 1 }
        }
        HapticManager.shared.lightImpact()
    }

    private func changeBreathPhase() {
        let next = breathPhase.next
        breathPhase = next
        phaseElapsed = 0
        HapticManager.shared.lightImpact()
        withAnimation(.easeInOut(duration: Double(next.seconds))) { breathProgress = next.target }
    }

    // MARK: - 2. Name it

    private var nameStage: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 26) {
                    heading("Name what's pulling at you",
                            "Temptation grows in the dark. Saying it plainly takes away some of its power.")
                        .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 12) {
                        PracticeSectionLabel(text: "What is it?")
                        FlowLayout(spacing: 10) {
                            ForEach(TemptationKind.allCases) { option in
                                chip(option.title, icon: option.icon, selected: trigger == option) {
                                    trigger = option
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        PracticeSectionLabel(text: "What is it promising you?")
                        FlowLayout(spacing: 10) {
                            ForEach(TemptationPromise.allCases) { option in
                                chip(option.title, selected: promise == option) {
                                    promise = option
                                }
                            }
                        }
                        Text("Every temptation makes a promise. It never keeps it.")
                            .font(.footnote)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            VStack(spacing: 2) {
                PracticeButton(title: "Continue", enabled: trigger != nil) { advance(to: .truth) }
                quietLink("I already gave in") { advance(to: .fallen) }
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - 3. Fight with the Word

    private var truthStage: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    heading("Fight with the Word",
                            "When Jesus was tempted he answered, \u{201C}It is written.\u{201D} Read this out loud.")
                        .padding(.top, 24)

                    verseCard(kind.verses[verseIndex % kind.verses.count])

                    if let promise {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("IT PROMISES \(promise.title.uppercased())")
                                .font(.caption2.weight(.bold))
                                .tracking(0.8)
                                .foregroundStyle(Color.reforgedCoral)
                            Text(promise.truth.line)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(promise.truth.reference)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.reforgedGold)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.reforgedCoral.opacity(colorScheme == .dark ? 0.16 : 0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Think ahead")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text(kind.thinkAhead[thinkAheadIndex % kind.thinkAhead.count])
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                    verseCard(temptationHelpVerses[helpIndex % temptationHelpVerses.count].verse,
                              caption: temptationHelpVerses[helpIndex % temptationHelpVerses.count].caption)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            PracticeButton(title: "Make a way out") { advance(to: .act) }
                .padding(.bottom, 16)
        }
    }

    // MARK: - 4. Put off, put on

    private var actStage: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    heading("Do the opposite, right now",
                            "God always provides a way out (1 Corinthians 10:13). Choose one step and do it before you tap continue.")
                        .padding(.top, 24)

                    VStack(spacing: 12) {
                        ForEach(kind.actions, id: \.self) { action in
                            actionRow(action)
                        }
                    }

                    Text("\u{201C}Be not overcome of evil, but overcome evil with good.\u{201D} Romans 12:21")
                        .font(Font.custom("LibreBaskerville-Italic", size: 14))
                        .foregroundStyle(Color.reforgedGold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            PracticeButton(title: "I'm doing it", enabled: chosenAction != nil) { advance(to: .pray) }
                .padding(.bottom, 16)
        }
    }

    private func actionRow(_ action: String) -> some View {
        let selected = chosenAction == action
        return Button {
            HapticManager.shared.selectionChanged()
            chosenAction = action
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.reforgedCoral : Color.adaptiveTextSecondary(colorScheme))
                Text(action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? Color.reforgedCoral : Color.clear, lineWidth: 2))
        }
        .buttonStyle(PracticeLipButtonStyle(
            face: Color.adaptiveCardBackground(colorScheme),
            lip: selected ? Color.reforgedCoral.opacity(0.5) : Color.adaptiveBorder(colorScheme),
            stroke: selected ? nil : Color.adaptiveBorder(colorScheme),
            cornerRadius: 16, depth: 4))
    }

    // MARK: - 5. Pray

    private var prayerText: String {
        var step = chosenAction ?? "turn away"
        if let first = step.first { step = first.lowercased() + step.dropFirst() }
        return "Lord Jesus, you were tempted in every way and never sinned, and you help those who are tempted. Right now I'm facing \(kind.prayerName). I don't want to obey it. I want you. Help me to \(step). Thank you that I am forgiven and that you are with me. Amen."
    }

    private var prayStage: some View {
        VStack(spacing: 22) {
            Spacer()

            heading("Pray it now",
                    "Say this out loud, or put it in your own words. God is not far from you.")

            Text(prayerText)
                .font(Font.custom("LibreBaskerville-Italic", size: 17))
                .lineSpacing(8)
                .multilineTextAlignment(.leading)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .practiceCard(radius: 22)
                .padding(.horizontal, 24)

            Spacer()

            PracticeButton(title: "Amen") { advance(to: .reach) }
                .padding(.bottom, 16)
        }
    }

    // MARK: - After: what to do next

    private var tellMessage: String {
        "Hey, I was tempted just now and I want to tell someone. Can you pray for me?"
    }

    private var reachStage: some View {
        let partner = AccountabilityPartnerService.shared
        let hasPartner = partner.hasPartner && !partner.partnerPhone.isEmpty

        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    heading("You held the line.",
                            "That took strength from God. Don't stop here. Do one of these while it's fresh.")
                        .padding(.top, 28)

                    HubGroup(title: "Do one of these now") {
                        tellRow(hasPartner: hasPartner, partnerName: partner.partnerName)
                        HubDivider()
                        nextRow(icon: "text.book.closed.fill", tint: Color.reforgedGold,
                                title: "Read the Bible",
                                subtitle: "Fill your mind with something true") { openTab(2) }
                        HubDivider()
                        nextRow(icon: "brain.head.profile", tint: Color.reforgedCoral,
                                title: "Memorize a verse",
                                subtitle: "Store up the Word for the next time") { openTab(3) }
                        HubDivider()
                        nextRow(icon: "square.and.pencil", tint: Color.practiceGreen,
                                title: "Write down what happened",
                                subtitle: "Note what led to it so you can plan ahead") {
                            HapticManager.shared.buttonTap()
                            showJournal = true
                        }
                    }

                    if !hasPartner {
                        Button {
                            HapticManager.shared.buttonTap()
                            showPartnerSetup = true
                        } label: {
                            Text("Set up an accountability partner")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.reforgedCoral)
                        }
                        .buttonStyle(.plain)
                    }

                    quietLink("I gave in") { advance(to: .fallen) }

                    crisisNote
                        .onAppear { crisisNoteShown = true }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            PracticeButton(title: "I'm okay for now") {
                HapticManager.shared.success()
                dismiss()
            }
            .padding(.bottom, 16)
        }
    }

    /// "Tell someone": texts the partner, or opens Messages for anyone, or shares as a fallback.
    @ViewBuilder
    private func tellRow(hasPartner: Bool, partnerName: String) -> some View {
        let title = hasPartner ? "Text \(partnerName)" : "Tell someone you trust"
        let subtitle = hasPartner ? "Let them know you were tempted" : "A friend, mentor, or pastor"
        if MessageComposeView.canSendText {
            Button {
                HapticManager.shared.buttonTap()
                showMessageComposer = true
            } label: {
                HubRowLabel(icon: "message.fill", tint: Color.reforgedCoral, title: title, subtitle: subtitle) { EmptyView() }
            }
            .buttonStyle(.plain)
        } else {
            ShareLink(item: tellMessage) {
                HubRowLabel(icon: "message.fill", tint: Color.reforgedCoral, title: title, subtitle: subtitle) { EmptyView() }
            }
            .buttonStyle(.plain)
        }
    }

    private func nextRow(icon: String, tint: Color, title: String, subtitle: String,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HubRowLabel(icon: icon, tint: tint, title: title, subtitle: subtitle) { EmptyView() }
        }
        .buttonStyle(.plain)
    }

    /// Closes the flow and lands on a tab.
    private func openTab(_ tab: Int) {
        HapticManager.shared.buttonTap()
        dismiss()
        NotificationCenter.default.post(
            name: .switchTab,
            object: nil,
            userInfo: [AppNotificationUserInfoKey.tab: tab]
        )
    }

    // MARK: - If they gave in

    private var fallenStage: some View {
        let partner = AccountabilityPartnerService.shared

        return ScrollView {
            VStack(spacing: 20) {
                heading("Get back up. Don't hide.",
                        "Falling doesn't cancel the gospel. Shame wants you to run from God. Grace says run to him.")
                    .padding(.top, 28)

                verseCard(TemptationVerse(
                    text: "If we confess our sins, he is faithful and just to forgive us our sins, and to cleanse us from all unrighteousness.",
                    reference: "1 John 1:9"))

                VStack(alignment: .leading, spacing: 16) {
                    stepLine(1, "Tell God plainly what you did. No excuses, no spiraling. He already knows and he already forgave it in Christ.")
                    stepLine(2, "Tell someone you trust today (James 5:16). Sin loses power in the light.")
                    stepLine(3, "Close the door that opened: remove the access, change the plan, or change the place.")
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .practiceCard(radius: 18)

                Text("\u{201C}For a just man falleth seven times, and riseth up again.\u{201D} Proverbs 24:16")
                    .font(Font.custom("LibreBaskerville-Italic", size: 14))
                    .foregroundStyle(Color.reforgedGold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                VStack(spacing: 12) {
                    let hasPartner = partner.hasPartner && !partner.partnerPhone.isEmpty
                    let tellTitle = hasPartner ? "Text \(partner.partnerName)" : "Tell someone you trust"
                    if MessageComposeView.canSendText {
                        PracticeButton(title: tellTitle, icon: "message.fill") {
                            showMessageComposer = true
                        }
                        .padding(.horizontal, -16)
                    } else {
                        ShareLink(item: "Hey, I gave in just now and I want to tell you instead of hiding it. Can we talk and pray?") {
                            Label(tellTitle, systemImage: "message.fill")
                                .font(.headline.bold())
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .practiceCard(radius: 16)
                        }
                        .buttonStyle(.plain)
                    }

                    PracticeButton(title: "I've confessed it to God", tint: Color.practiceGreen) {
                        HapticManager.shared.success()
                        dismiss()
                    }
                    .padding(.horizontal, -16)

                    // Already shown on the previous screen? Don't repeat it.
                    if !crisisNoteShown { crisisNote }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func stepLine(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.reforgedCoral, in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A short safety note: this screen is not a substitute for help in a crisis.
    private var crisisNote: some View {
        VStack(spacing: 4) {
            Text("If you are thinking about hurting yourself, you don't have to carry that alone.")
                .font(.footnote)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
            if let url = URL(string: "tel:988") {
                Link("Call or text 988 (US)", destination: url)
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(.top, 8)
    }

}
