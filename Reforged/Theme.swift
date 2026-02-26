import SwiftUI



// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(currentMode.rawValue, forKey: "theme_mode")
            updateColorScheme()
        }
    }

    @Published var colorScheme: ColorScheme?

    private init() {
        let saved = UserDefaults.standard.string(forKey: "theme_mode") ?? "system"
        currentMode = ThemeMode(rawValue: saved) ?? .system
        updateColorScheme()
    }

    private func updateColorScheme() {
        switch currentMode {
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        case .system:
            colorScheme = nil
        }
    }
}

// MARK: - Reforged Theme Colors (Light/Dark Adaptive)

extension Color {
    // Primary Brand Colors (from logo)
    static let reforgedCharcoal = Color(red: 0.20, green: 0.20, blue: 0.20) // #333333 - dark charcoal from logo
    static let reforgedBrandCream = Color(red: 0.91, green: 0.89, blue: 0.86) // #E8E4DC - cream from logo

    // Primary Colors (updated to match brand)
    static let reforgedNavy = Color(red: 0.20, green: 0.20, blue: 0.22) // Updated to match charcoal theme
    static let reforgedDarkBlue = Color(red: 0.15, green: 0.15, blue: 0.17) // Darker variant

    // Accent Colors
    static let reforgedCoral = Color(red: 0.914, green: 0.271, blue: 0.376) // #e94560
    static let reforgedGold = Color(red: 0.831, green: 0.647, blue: 0.455) // #d4a574

    // Background Colors - Adaptive
    static let reforgedCream = Color("ReforgedCream")
    static let reforgedOffWhite = Color("ReforgedOffWhite")

    // Text Colors - Adaptive
    static let reforgedText = Color("ReforgedText")
    static let reforgedTextSecondary = Color("ReforgedTextSecondary")

    // Card Colors - Adaptive
    static let reforgedCardBackground = Color("ReforgedCardBackground")
    static let reforgedCardBorder = Color("ReforgedCardBorder")

    // Fallback colors for when asset catalog colors aren't available
    static func adaptiveBackground(_ scheme: ColorScheme?) -> Color {
        if scheme == .dark {
            return Color(red: 0.11, green: 0.11, blue: 0.12)
        }
        return Color(red: 0.980, green: 0.973, blue: 0.961)
    }

    static func adaptiveCardBackground(_ scheme: ColorScheme?) -> Color {
        if scheme == .dark {
            return Color(red: 0.17, green: 0.17, blue: 0.18)
        }
        return .white
    }

    static func adaptiveText(_ scheme: ColorScheme?) -> Color {
        if scheme == .dark {
            return Color(red: 0.93, green: 0.93, blue: 0.94)
        }
        return Color(red: 0.176, green: 0.176, blue: 0.176)
    }

    static func adaptiveTextSecondary(_ scheme: ColorScheme?) -> Color {
        if scheme == .dark {
            return Color(red: 0.6, green: 0.6, blue: 0.62)
        }
        return Color(red: 0.4, green: 0.4, blue: 0.4)
    }

    static func adaptiveBorder(_ scheme: ColorScheme?) -> Color {
        if scheme == .dark {
            return Color(red: 0.25, green: 0.25, blue: 0.27)
        }
        return Color(red: 0.9, green: 0.9, blue: 0.9)
    }

    /// Adaptive foreground variant of reforgedNavy — dark in light mode, light in dark mode
    static func adaptiveNavyText(_ scheme: ColorScheme?) -> Color {
        if scheme == .dark {
            return Color(red: 0.85, green: 0.85, blue: 0.90) // Light off-white with slight blue tint
        }
        return Color.reforgedNavy
    }
}

// MARK: - Track Display Color

extension Track {
    var displayColor: Color {
        switch color {
        case "blue": return .reforgedNavy
        case "red": return .reforgedCoral
        case "green": return Color(red: 0.2, green: 0.6, blue: 0.4)
        case "purple": return Color(red: 0.5, green: 0.3, blue: 0.6)
        case "indigo": return Color(red: 0.3, green: 0.3, blue: 0.6)
        case "orange": return .reforgedGold
        default: return .reforgedNavy
        }
    }
}

// MARK: - Theme Configuration

struct ReforgedTheme {
    // Border radius values
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
    static let cornerRadiusXLarge: CGFloat = 24

    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48

    // Enhanced shadows for gamified look
    static let cardShadow = Color.black.opacity(0.06)
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 4

    // Stronger shadow for elevated cards
    static let elevatedShadow = Color.black.opacity(0.12)
    static let elevatedShadowRadius: CGFloat = 16
    static let elevatedShadowY: CGFloat = 8

    // Accent shadows (for colored cards)
    static let accentShadowOpacity: CGFloat = 0.25
    static let accentShadowRadius: CGFloat = 12

    // Animation durations
    static let animationFast: Double = 0.2
    static let animationMedium: Double = 0.3
    static let animationSlow: Double = 0.5
}

// MARK: - Bible Reading Settings

class BibleReadingSettings: ObservableObject {
    static let shared = BibleReadingSettings()

    @Published var fontSize: FontSize {
        didSet { save() }
    }

    @Published var fontType: FontType {
        didSet { save() }
    }

    @Published var lineSpacing: LineSpacingOption {
        didSet { save() }
    }

    @Published var verseByVerse: Bool {
        didSet { save() }
    }

    @Published var lastBook: String {
        didSet { save() }
    }

    @Published var lastChapter: Int {
        didSet { save() }
    }

    @Published var lastScrollPosition: CGFloat {
        didSet { save() }
    }

    enum FontSize: String, CaseIterable {
        case small, medium, large, extraLarge

        var displayName: String {
            switch self {
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            case .extraLarge: return "Extra Large"
            }
        }

        var size: CGFloat {
            switch self {
            case .small: return 15
            case .medium: return 17
            case .large: return 20
            case .extraLarge: return 24
            }
        }

        var verseNumberSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            case .extraLarge: return 16
            }
        }
    }

    enum FontType: String, CaseIterable {
        case serif, sansSerif

        var displayName: String {
            switch self {
            case .serif: return "Serif"
            case .sansSerif: return "Sans-serif"
            }
        }

        var design: Font.Design {
            switch self {
            case .serif: return .serif
            case .sansSerif: return .default
            }
        }
    }

    enum LineSpacingOption: String, CaseIterable {
        case tight, normal, relaxed, wide

        var displayName: String {
            switch self {
            case .tight: return "Tight"
            case .normal: return "Normal"
            case .relaxed: return "Relaxed"
            case .wide: return "Wide"
            }
        }

        var spacing: CGFloat {
            switch self {
            case .tight: return 4
            case .normal: return 6
            case .relaxed: return 10
            case .wide: return 14
            }
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        fontSize = FontSize(rawValue: defaults.string(forKey: "bible_font_size") ?? "medium") ?? .medium
        fontType = FontType(rawValue: defaults.string(forKey: "bible_font_type") ?? "serif") ?? .serif
        lineSpacing = LineSpacingOption(rawValue: defaults.string(forKey: "bible_line_spacing") ?? "normal") ?? .normal
        verseByVerse = defaults.bool(forKey: "bible_verse_by_verse")
        lastBook = defaults.string(forKey: "bible_last_book") ?? "John"
        let savedChapter = defaults.integer(forKey: "bible_last_chapter")
        lastChapter = savedChapter == 0 ? 3 : savedChapter
        lastScrollPosition = CGFloat(defaults.float(forKey: "bible_scroll_position"))
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(fontSize.rawValue, forKey: "bible_font_size")
        defaults.set(fontType.rawValue, forKey: "bible_font_type")
        defaults.set(lineSpacing.rawValue, forKey: "bible_line_spacing")
        defaults.set(verseByVerse, forKey: "bible_verse_by_verse")
        defaults.set(lastBook, forKey: "bible_last_book")
        defaults.set(lastChapter, forKey: "bible_last_chapter")
        defaults.set(Float(lastScrollPosition), forKey: "bible_scroll_position")
        // Notify iCloud sync of reading position changes
        NotificationCenter.default.post(name: .bibleDataDidChange, object: nil)
    }
}

// MARK: - Custom View Modifiers

struct ReforgedCardStyle: ViewModifier {
    var hasBorder: Bool = true
    var elevated: Bool = false
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge)
                    .stroke(hasBorder ? Color.adaptiveBorder(colorScheme) : Color.clear, lineWidth: 1)
            )
            .shadow(
                color: elevated ? ReforgedTheme.elevatedShadow : ReforgedTheme.cardShadow,
                radius: elevated ? ReforgedTheme.elevatedShadowRadius : ReforgedTheme.cardShadowRadius,
                y: elevated ? ReforgedTheme.elevatedShadowY : ReforgedTheme.cardShadowY
            )
    }
}

// Gamified stat card with accent color
struct GamifiedStatCardStyle: ViewModifier {
    let accentColor: Color
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge)
                    .stroke(accentColor.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: accentColor.opacity(ReforgedTheme.accentShadowOpacity), radius: ReforgedTheme.accentShadowRadius, y: 6)
    }
}

// Hero card style with gradient background
struct HeroCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [Color.reforgedNavy, Color.reforgedDarkBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusXLarge))
            .shadow(color: Color.reforgedNavy.opacity(0.3), radius: 16, y: 8)
    }
}

struct ReforgedPrimaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.reforgedNavy)
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
    }
}

struct ReforgedSecondaryButtonStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.adaptiveBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium)
                    .stroke(Color.adaptiveNavyText(colorScheme), lineWidth: 2)
            )
    }
}

// MARK: - Responsive Layout Utilities

/// Device layout mode for adaptive UI
enum DeviceLayout {
    case compact    // iPhone portrait
    case regular    // iPhone landscape, iPad portrait
    case expanded   // iPad landscape, Mac

    static func current(horizontal: UserInterfaceSizeClass?, vertical: UserInterfaceSizeClass?) -> DeviceLayout {
        switch (horizontal, vertical) {
        case (.regular, .regular):
            return .expanded
        case (.regular, _):
            return .regular
        default:
            return .compact
        }
    }
}

/// Adaptive layout helper for responsive grid columns
struct AdaptiveLayout {
    /// Returns appropriate column count based on size class
    static func gridColumns(
        compact: Int,
        regular: Int,
        expanded: Int,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> Int {
        switch horizontalSizeClass {
        case .regular:
            #if os(macOS)
            return expanded
            #else
            return regular
            #endif
        default:
            return compact
        }
    }

    /// Returns adaptive grid items
    static func adaptiveGridItems(
        minWidth: CGFloat = 160,
        spacing: CGFloat = 16
    ) -> [GridItem] {
        [GridItem(.adaptive(minimum: minWidth), spacing: spacing)]
    }

    /// Returns fixed grid columns based on size class
    static func fixedGridItems(
        count: Int,
        spacing: CGFloat = 16
    ) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
    }

    /// Maximum content width for readability on large screens
    static func maxContentWidth(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        switch sizeClass {
        case .regular:
            return 800
        default:
            return .infinity
        }
    }

    /// Sidebar width for iPad/Mac
    static let sidebarWidth: CGFloat = 320

    /// Minimum detail view width
    static let minDetailWidth: CGFloat = 400
}

/// Environment key for tracking if we're in a sidebar navigation context
struct IsSidebarNavigationKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isSidebarNavigation: Bool {
        get { self[IsSidebarNavigationKey.self] }
        set { self[IsSidebarNavigationKey.self] = newValue }
    }
}

// MARK: - Responsive View Modifiers

/// Constrains content width for readability on large screens
struct ReadableContentWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: AdaptiveLayout.maxContentWidth(for: horizontalSizeClass))
    }
}

/// Adds responsive padding based on size class
struct ResponsivePadding: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let edges: Edge.Set

    var paddingAmount: CGFloat {
        switch horizontalSizeClass {
        case .regular:
            return ReforgedTheme.spacingXL
        default:
            return ReforgedTheme.spacingM
        }
    }

    func body(content: Content) -> some View {
        content
            .padding(edges, paddingAmount)
    }
}

// MARK: - View Extensions

extension View {
    func reforgedCard(hasBorder: Bool = true, elevated: Bool = false) -> some View {
        modifier(ReforgedCardStyle(hasBorder: hasBorder, elevated: elevated))
    }

    /// Constrains content to readable width on large screens
    func readableContentWidth() -> some View {
        modifier(ReadableContentWidth())
    }

    /// Applies responsive padding based on device size
    func responsivePadding(_ edges: Edge.Set = .all) -> some View {
        modifier(ResponsivePadding(edges: edges))
    }

    /// Centers content with max width for large screens
    func centeredContent(maxWidth: CGFloat = 700) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }

    func gamifiedStatCard(accent: Color) -> some View {
        modifier(GamifiedStatCardStyle(accentColor: accent))
    }

    func heroCard() -> some View {
        modifier(HeroCardStyle())
    }

    func reforgedPrimaryButton() -> some View {
        modifier(ReforgedPrimaryButtonStyle())
    }

    func reforgedSecondaryButton() -> some View {
        modifier(ReforgedSecondaryButtonStyle())
    }

    // Smooth transition helper
    func smoothTransition() -> some View {
        self.transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        ))
    }
}

// MARK: - Haptic Feedback Manager

/// Centralized haptic feedback manager for consistent tactile responses throughout the app
class HapticManager {
    static let shared = HapticManager()

    private init() {}

    // MARK: - Impact Feedback

    /// Light impact - for subtle interactions like toggling, selections
    func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Medium impact - for confirmations, card flips, mode changes
    func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Heavy impact - for significant actions, achievements
    func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Soft impact - for gentle interactions
    func softImpact() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Rigid impact - for more defined touches
    func rigidImpact() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Notification Feedback

    /// Success feedback - for completed actions, saves, achievements
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Warning feedback - for caution situations
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Error feedback - for failed actions
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    // MARK: - Selection Feedback

    /// Selection changed - for picker changes, tab switches
    func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    // MARK: - Compound Feedback Patterns

    /// Card flip feedback - medium impact with slight delay
    func cardFlip() {
        mediumImpact()
    }

    /// Achievement unlocked - success with celebration feel
    func achievementUnlocked() {
        heavyImpact()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.success()
        }
    }

    /// Note saved - satisfying confirmation
    func noteSaved() {
        success()
    }

    /// Journal entry saved - celebratory confirmation
    func journalSaved() {
        success()
    }

    /// Verse highlighted - light confirmation
    func verseHighlighted() {
        lightImpact()
    }

    /// Memory practice correct answer
    func correctAnswer() {
        success()
    }

    /// Memory practice incorrect answer
    func incorrectAnswer() {
        error()
    }

    /// Streak milestone reached
    func streakMilestone() {
        achievementUnlocked()
    }

    /// XP earned
    func xpEarned() {
        lightImpact()
    }

    /// Button tap - general purpose
    func buttonTap() {
        lightImpact()
    }

    /// Long press activated
    func longPressActivated() {
        mediumImpact()
    }
}

// MARK: - Success Toast Overlay

/// A celebratory toast that appears briefly to confirm an action
struct SuccessToast: View {
    let message: String
    let icon: String
    let accentColor: Color
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if isPresented {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(accentColor)

                Text(message)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(Capsule())
            .shadow(color: accentColor.opacity(0.3), radius: 12, y: 4)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
            .onAppear {
                HapticManager.shared.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
            }
        }
    }
}

/// View modifier to show a success toast
struct SuccessToastModifier: ViewModifier {
    let message: String
    let icon: String
    let accentColor: Color
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        ZStack {
            content

            VStack {
                Spacer()
                SuccessToast(
                    message: message,
                    icon: icon,
                    accentColor: accentColor,
                    isPresented: $isPresented
                )
                .padding(.bottom, 100)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isPresented)
        }
    }
}

extension View {
    /// Shows a celebratory toast message
    func successToast(
        _ message: String,
        icon: String = "checkmark.circle.fill",
        accentColor: Color = .reforgedGold,
        isPresented: Binding<Bool>
    ) -> some View {
        modifier(SuccessToastModifier(
            message: message,
            icon: icon,
            accentColor: accentColor,
            isPresented: isPresented
        ))
    }
}

// MARK: - Confetti Particle

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var color: Color
    var rotation: Double
    var scale: CGFloat
    var velocity: CGPoint
    var rotationSpeed: Double
    var shape: ConfettiShape

    enum ConfettiShape: CaseIterable {
        case circle, square, triangle, star
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @Binding var isActive: Bool
    let intensity: ConfettiIntensity

    enum ConfettiIntensity {
        case low      // 20 particles
        case medium   // 40 particles
        case high     // 80 particles
        case extreme  // 120 particles

        var particleCount: Int {
            switch self {
            case .low: return 20
            case .medium: return 40
            case .high: return 80
            case .extreme: return 120
            }
        }
    }

    @State private var particles: [ConfettiParticle] = []
    @State private var timer: Timer?

    private let confettiColors: [Color] = [
        .reforgedGold,
        .reforgedCoral,
        Color(red: 0.4, green: 0.8, blue: 0.4), // Green
        Color(red: 0.4, green: 0.6, blue: 1.0), // Blue
        Color(red: 0.9, green: 0.5, blue: 0.9), // Purple
        Color(red: 1.0, green: 0.8, blue: 0.3), // Yellow
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiParticleView(particle: particle)
                }
            }
            .onChange(of: isActive) { newValue in
                if newValue {
                    startConfetti(in: geometry.size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func startConfetti(in size: CGSize) {
        // Generate particles
        particles = (0..<intensity.particleCount).map { _ in
            ConfettiParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: -20
                ),
                color: confettiColors.randomElement() ?? .reforgedGold,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.2),
                velocity: CGPoint(
                    x: CGFloat.random(in: -100...100),
                    y: CGFloat.random(in: 200...500)
                ),
                rotationSpeed: Double.random(in: -360...360),
                shape: ConfettiParticle.ConfettiShape.allCases.randomElement() ?? .circle
            )
        }

        // Haptic feedback
        HapticManager.shared.achievementUnlocked()

        // Animate particles
        var elapsed: Double = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { t in
            elapsed += 1/60
            let gravity: CGFloat = 400

            withAnimation(.linear(duration: 1/60)) {
                for i in particles.indices {
                    particles[i].position.x += particles[i].velocity.x * (1/60)
                    particles[i].position.y += particles[i].velocity.y * (1/60)
                    particles[i].velocity.y += gravity * (1/60)
                    particles[i].velocity.x *= 0.99 // Air resistance
                    particles[i].rotation += particles[i].rotationSpeed * (1/60)
                }
            }

            // Stop after 3 seconds
            if elapsed > 3.0 {
                t.invalidate()
                particles = []
                isActive = false
            }
        }
    }
}

struct ConfettiParticleView: View {
    let particle: ConfettiParticle

    var body: some View {
        Group {
            switch particle.shape {
            case .circle:
                Circle()
                    .fill(particle.color)
                    .frame(width: 8 * particle.scale, height: 8 * particle.scale)
            case .square:
                Rectangle()
                    .fill(particle.color)
                    .frame(width: 8 * particle.scale, height: 8 * particle.scale)
            case .triangle:
                Triangle()
                    .fill(particle.color)
                    .frame(width: 10 * particle.scale, height: 10 * particle.scale)
            case .star:
                Image(systemName: "star.fill")
                    .font(.system(size: 8 * particle.scale))
                    .foregroundStyle(particle.color)
            }
        }
        .rotationEffect(.degrees(particle.rotation))
        .position(particle.position)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Confetti Modifier

struct ConfettiModifier: ViewModifier {
    @Binding var isActive: Bool
    let intensity: ConfettiView.ConfettiIntensity

    func body(content: Content) -> some View {
        ZStack {
            content
            ConfettiView(isActive: $isActive, intensity: intensity)
        }
    }
}

extension View {
    /// Adds confetti celebration overlay
    func confetti(isActive: Binding<Bool>, intensity: ConfettiView.ConfettiIntensity = .medium) -> some View {
        modifier(ConfettiModifier(isActive: isActive, intensity: intensity))
    }
}

// MARK: - XP Gain Animation

struct XPGainView: View {
    let amount: Int
    let source: String
    @Binding var isPresented: Bool
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 0.5

    var body: some View {
        if isPresented {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.reforgedGold)

                Text("+\(amount) XP")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.reforgedGold)

                if AppState.shared.user.streak >= 7 {
                    Text(AppState.shared.user.streak >= 30 ? "2x" : "1.5x")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.reforgedCoral))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.reforgedGold.opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke(Color.reforgedGold.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(scale)
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                HapticManager.shared.xpEarned()

                // Scale in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.0
                }

                // Float up and fade out
                withAnimation(.easeOut(duration: 1.5).delay(0.5)) {
                    offset = -60
                    opacity = 0
                }

                // Reset after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    isPresented = false
                    offset = 0
                    opacity = 1
                    scale = 0.5
                }
            }
        }
    }
}

// MARK: - Streak Milestone Celebration

struct StreakMilestoneView: View {
    let streakCount: Int
    @Binding var isPresented: Bool
    @State private var showConfetti = false
    @State private var showShareStreak = false
    @Environment(\.colorScheme) var colorScheme

    var milestoneMessage: String {
        switch streakCount {
        case 7: return "One Week Strong!"
        case 14: return "Two Weeks of Dedication!"
        case 21: return "Three Weeks of Growth!"
        case 30: return "One Month Champion!"
        case 50: return "50 Day Warrior!"
        case 100: return "Century Achiever!"
        case 365: return "One Year Legend!"
        default: return "\(streakCount) Day Streak!"
        }
    }

    var milestoneIcon: String {
        switch streakCount {
        case 7: return "flame"
        case 14: return "flame.fill"
        case 21: return "star.fill"
        case 30: return "crown"
        case 50: return "crown.fill"
        case 100: return "trophy"
        case 365: return "trophy.fill"
        default: return "flame"
        }
    }

    var body: some View {
        if isPresented {
            ZStack {
                // Dimmed background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }

                // Milestone card
                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.reforgedGold, Color.reforgedGold.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: Color.reforgedGold.opacity(0.5), radius: 20)

                        Image(systemName: milestoneIcon)
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                    }

                    // Text
                    VStack(spacing: 8) {
                        Text("Milestone Reached!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                        Text(milestoneMessage)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .multilineTextAlignment(.center)

                        Text("\(streakCount) days of faithful reading")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }

                    // Buttons
                    VStack(spacing: 10) {
                        // Share Your Streak button (primary)
                        Button {
                            showShareStreak = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Share Your Streak!")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.reforgedCoral, Color.reforgedCoral.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Continue button (secondary)
                        Button {
                            dismiss()
                        } label: {
                            Text("Keep Going!")
                                .font(.headline)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.adaptiveText(colorScheme).opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(32)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: Color.black.opacity(0.2), radius: 30)
                .padding(40)
                .transition(.scale.combined(with: .opacity))
            }
            .confetti(isActive: $showConfetti, intensity: .high)
            .onAppear {
                HapticManager.shared.streakMilestone()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showConfetti = true
                }
            }
            .sheet(isPresented: $showShareStreak) {
                StreakShareSheet()
            }
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - Level Up Celebration

struct LevelUpView: View {
    let newLevel: Int
    @Binding var isPresented: Bool
    @State private var showConfetti = false
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 1
    @Environment(\.colorScheme) var colorScheme

    var levelTitle: String {
        let info = SampleData.getLevelInfo(level: newLevel)
        return info.title
    }

    var body: some View {
        if isPresented {
            ZStack {
                // Dimmed background
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                // Expanding rings
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.reforgedGold.opacity(0.3), lineWidth: 2)
                        .scaleEffect(ringScale + CGFloat(i) * 0.2)
                        .opacity(ringOpacity - Double(i) * 0.2)
                }

                // Level up card
                VStack(spacing: 28) {
                    // Badge
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(Color.reforgedGold.opacity(0.2))
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)

                        // Main circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.reforgedNavy, Color.reforgedNavy.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 110, height: 110)
                            .overlay(
                                Circle()
                                    .stroke(Color.reforgedGold, lineWidth: 4)
                            )
                            .shadow(color: Color.reforgedGold.opacity(0.5), radius: 15)

                        // Level number
                        VStack(spacing: 2) {
                            Text("LVL")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.reforgedGold)

                            Text("\(newLevel)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }

                    // Text
                    VStack(spacing: 8) {
                        Text("LEVEL UP!")
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundStyle(Color.reforgedGold)
                            .tracking(2)

                        Text("You are now a \(levelTitle)")
                            .font(.headline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }

                    // Continue button
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Continue")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.reforgedNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                }
                .padding(32)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: Color.black.opacity(0.3), radius: 30)
                .padding(32)
                .transition(.scale.combined(with: .opacity))
            }
            .confetti(isActive: $showConfetti, intensity: .extreme)
            .onAppear {
                HapticManager.shared.achievementUnlocked()

                // Animate rings
                withAnimation(.easeOut(duration: 1.5)) {
                    ringScale = 3.0
                    ringOpacity = 0
                }

                // Trigger confetti
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showConfetti = true
                }
            }
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - Badge Earned Celebration

struct BadgeEarnedView: View {
    let badge: Badge
    @Binding var isPresented: Bool
    @State private var showConfetti = false
    @State private var iconScale: CGFloat = 0.3
    @State private var glowOpacity: Double = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    // Badge icon with glow
                    ZStack {
                        Circle()
                            .fill(Color.reforgedGold.opacity(0.25))
                            .frame(width: 140, height: 140)
                            .blur(radius: 25)
                            .opacity(glowOpacity)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.reforgedGold, Color.reforgedGold.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: Color.reforgedGold.opacity(0.5), radius: 15)

                        Image(systemName: badge.icon)
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(iconScale)

                    VStack(spacing: 8) {
                        Text("BADGE EARNED!")
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundStyle(Color.reforgedGold)
                            .tracking(2)

                        Text(badge.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Text(badge.description)
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                            Text("Awesome!")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.reforgedGold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                }
                .padding(32)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: Color.black.opacity(0.3), radius: 30)
                .padding(32)
                .transition(.scale.combined(with: .opacity))
            }
            .confetti(isActive: $showConfetti, intensity: .extreme)
            .onAppear {
                HapticManager.shared.achievementUnlocked()

                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    iconScale = 1.0
                }
                withAnimation(.easeIn(duration: 0.8)) {
                    glowOpacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showConfetti = true
                }
            }
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - Practice Complete Celebration

struct PracticeCompleteCelebration: View {
    let score: Int // 1-5 quality rating
    let xpEarned: Int
    @Binding var isPresented: Bool
    @State private var showConfetti = false
    @State private var iconScale: CGFloat = 0.3
    @State private var textOpacity: Double = 0
    @Environment(\.colorScheme) var colorScheme

    var celebrationMessage: String {
        switch score {
        case 5: return "Perfect!"
        case 4: return "Great Job!"
        case 3: return "Good Work!"
        case 2: return "Keep Practicing!"
        default: return "Don't Give Up!"
        }
    }

    var celebrationIcon: String {
        switch score {
        case 5: return "star.circle.fill"
        case 4: return "hand.thumbsup.circle.fill"
        case 3: return "checkmark.circle.fill"
        case 2: return "arrow.clockwise.circle.fill"
        default: return "heart.circle.fill"
        }
    }

    var celebrationColor: Color {
        switch score {
        case 5: return .reforgedGold
        case 4: return .green
        case 3: return .blue
        case 2: return .orange
        default: return .reforgedCoral
        }
    }

    var body: some View {
        if isPresented {
            VStack(spacing: 20) {
                // Icon
                Image(systemName: celebrationIcon)
                    .font(.system(size: 60))
                    .foregroundStyle(celebrationColor)
                    .scaleEffect(iconScale)
                    .shadow(color: celebrationColor.opacity(0.4), radius: 10)

                // Message
                VStack(spacing: 8) {
                    Text(celebrationMessage)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.reforgedGold)
                        Text("+\(xpEarned) XP")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.reforgedGold)
                    }
                    .font(.headline)
                }
                .opacity(textOpacity)
            }
            .padding(40)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.15), radius: 20)
            .confetti(isActive: $showConfetti, intensity: score >= 4 ? .medium : .low)
            .onAppear {
                // Haptic based on score
                if score >= 4 {
                    HapticManager.shared.correctAnswer()
                } else {
                    HapticManager.shared.lightImpact()
                }

                // Animate icon
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    iconScale = 1.0
                }

                // Fade in text
                withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                    textOpacity = 1.0
                }

                // Show confetti for good scores
                if score >= 4 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showConfetti = true
                    }
                }

                // Auto dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Animated Counter

struct AnimatedCounter: View {
    let value: Int
    let font: Font
    let color: Color

    @State private var displayValue: Int = 0

    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .onChange(of: value) { newValue in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    displayValue = newValue
                }
            }
            .onAppear {
                displayValue = value
            }
    }
}

// MARK: - Pulse Animation Modifier

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .animation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    func pulsing() -> some View {
        modifier(PulseModifier())
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.4),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Reforged Logo Mark Shape

/// Custom Shape that draws the Reforged "R" logo mark - exact match to brand logo
struct ReforgedLogoMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // The Reforged R logo is a geometric stylized R with:
        // - A vertical left stem
        // - A top horizontal bar
        // - A curved bowl on the right
        // - A diagonal leg extending to bottom right

        // Start from top-left corner, draw the outer perimeter clockwise
        path.move(to: CGPoint(x: 0, y: 0))

        // Top edge - goes right to where the bowl starts
        path.addLine(to: CGPoint(x: w * 0.65, y: 0))

        // Bowl outer curve (top-right, going down)
        path.addQuadCurve(
            to: CGPoint(x: w * 0.65, y: h * 0.5),
            control: CGPoint(x: w * 0.95, y: h * 0.25)
        )

        // Junction point where bowl meets diagonal leg
        path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.5))

        // Diagonal leg - goes to bottom right
        path.addLine(to: CGPoint(x: w, y: h))

        // Bottom of diagonal leg - goes back left
        path.addLine(to: CGPoint(x: w * 0.65, y: h))

        // Inner diagonal going back up to the bowl
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.58))

        // Inner edge of left stem going down
        path.addLine(to: CGPoint(x: w * 0.35, y: h))

        // Bottom left corner
        path.addLine(to: CGPoint(x: 0, y: h))

        // Close back to start (left edge going up)
        path.closeSubpath()

        // Now cut out the bowl's inner curve (negative space)
        // This creates the hole in the R
        var bowlCutout = Path()
        bowlCutout.move(to: CGPoint(x: w * 0.35, y: h * 0.15))
        bowlCutout.addLine(to: CGPoint(x: w * 0.5, y: h * 0.15))
        bowlCutout.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.4),
            control: CGPoint(x: w * 0.7, y: h * 0.275)
        )
        bowlCutout.addLine(to: CGPoint(x: w * 0.35, y: h * 0.4))
        bowlCutout.closeSubpath()

        // Combine paths - the main shape minus the cutout
        path.addPath(bowlCutout)

        return path
    }
}

/// Simplified Reforged R Logo View - geometric version matching the brand
struct ReforgedRLogo: View {
    var color: Color = .reforgedBrandCream

    var body: some View {
        ReforgedLogoMark()
            .fill(color, style: FillStyle(eoFill: true))
    }
}

// MARK: - Feature Card Component

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.reforgedGold)
                .frame(width: 50, height: 50)
                .background(Color.adaptiveBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusMedium))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .reforgedCard()
    }
}
