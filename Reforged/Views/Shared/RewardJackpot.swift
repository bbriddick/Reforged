import SwiftUI
import UIKit
import CoreHaptics

// MARK: - Jackpot Haptics
//
// Memory-tab rewards are scored with Core Haptics rather than stacked
// UIFeedbackGenerator taps, so a celebration can *build* (drumroll), *land*
// (slam + rumble) and *pay out* (sparkle cascade, coin ticks) as one authored
// pattern. Devices without a Taptic Engine simply stay silent.

final class JackpotHaptics {
    static let shared = JackpotHaptics()

    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    private init() {
        guard supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.playsHapticsOnly = true
            engine.resetHandler = { [weak engine] in try? engine?.start() }
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    // MARK: Public patterns

    /// The full takeover score: an accelerating drumroll that crashes into a
    /// heavy slam at `slamAt`, then a shimmer of confetti landing.
    func jackpot(slamAt: TimeInterval = 0.55, sparkles: Int = 18) {
        var events = drumroll(duration: slamAt)
        events += slam(at: slamAt)
        events += sparkleCascade(count: sparkles, from: slamAt + 0.12, over: 1.3)
        play(events, curves: [drumrollSwell(duration: slamAt)])
    }

    /// Smaller score for gentler takeovers: no drumroll, a soft landing.
    func softLanding() {
        play([
            transient(0, 0.6, 0.35),
            continuous(0, duration: 0.25, intensity: 0.4, sharpness: 0.2),
        ] + sparkleCascade(count: 8, from: 0.15, over: 0.9, peak: 0.35))
    }

    /// One counter step — crisp and high, like a coin hitting a tray.
    func tick(_ progress: Double = 0.5) {
        play([transient(0, Float(0.35 + progress * 0.35), 0.95)])
    }

    /// A reel locking into place.
    func clunk() {
        play([
            transient(0, 0.9, 0.5),
            transient(0.055, 0.45, 0.95),
        ])
    }

    /// The +XP pop: a quick punch with a short body.
    func pop() {
        play([
            transient(0, 0.75, 0.8),
            continuous(0, duration: 0.1, intensity: 0.45, sharpness: 0.35),
        ])
    }

    /// Coins raining onto the screen when the payout lands.
    func payout() {
        play(sparkleCascade(count: 14, from: 0, over: 0.8, peak: 0.6))
    }

    /// Stand-alone confetti burst (Memory games, via `.arcadeConfetti`).
    func confettiPop() {
        play([
            transient(0, 0.95, 0.65),
            transient(0.05, 0.6, 1.0),
            continuous(0, duration: 0.2, intensity: 0.5, sharpness: 0.3),
        ] + sparkleCascade(count: 10, from: 0.15, over: 1.0))
    }

    /// CTA press — a satisfying chunk to close the loop.
    func claim() {
        play([
            transient(0, 1.0, 0.6),
            transient(0.07, 0.55, 0.9),
            transient(0.14, 0.3, 1.0),
        ])
    }

    // MARK: Building blocks

    private func drumroll(duration: TimeInterval, beats: Int = 16) -> [CHHapticEvent] {
        // sqrt spacing: beats crowd together as the slam approaches.
        (0..<beats).map { i in
            let p = Double(i) / Double(beats)
            let t = duration * sqrt(p)
            return transient(t, Float(0.28 + p * 0.55), Float(0.45 + p * 0.3))
        } + [continuous(0, duration: duration, intensity: 0.55, sharpness: 0.25)]
    }

    private func drumrollSwell(duration: TimeInterval) -> CHHapticParameterCurve {
        CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 0.1),
                .init(relativeTime: duration, value: 1.0),
                .init(relativeTime: duration + 0.05, value: 1.0),
                .init(relativeTime: duration + 0.5, value: 0.2),
            ],
            relativeTime: 0
        )
    }

    private func slam(at t: TimeInterval) -> [CHHapticEvent] {
        [
            transient(t, 1.0, 0.85),
            transient(t + 0.018, 1.0, 0.25),
            continuous(t, duration: 0.42, intensity: 0.85, sharpness: 0.12),
            transient(t + 0.16, 0.55, 0.55),
        ]
    }

    private func sparkleCascade(count: Int, from start: TimeInterval, over span: TimeInterval, peak: Float = 0.55) -> [CHHapticEvent] {
        (0..<count).map { i in
            // Denser at the start, thinning out like the last confetti landing.
            let p = Double(i) / Double(max(count - 1, 1))
            let t = start + span * pow(p, 1.35) + Double.random(in: -0.02...0.02)
            let intensity = peak * Float(1.0 - p * 0.6) * Float.random(in: 0.7...1.0)
            return transient(max(0, t), intensity, Float.random(in: 0.8...1.0))
        }
    }

    private func transient(_ t: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: min(max(intensity, 0), 1)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: min(max(sharpness, 0), 1)),
            ],
            relativeTime: t
        )
    }

    private func continuous(_ t: TimeInterval, duration: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: t,
            duration: duration
        )
    }

    private func play(_ events: [CHHapticEvent], curves: [CHHapticParameterCurve] = []) {
        guard supportsHaptics, let engine else { return }
        do {
            // Auto-shutdown parks the engine when idle; start() wakes it.
            try engine.start()
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are garnish; never let them break a celebration.
        }
    }
}

// MARK: - Burst Engine (particles)
//
// Particles are pure functions of time: each one stores its launch state and the
// Canvas solves its position analytically every frame (linear drag + gravity,
// with a flutter). Nothing mutates per frame, so hundreds of pieces stay cheap.

/// Brand-only celebration colors (see the Reforged design system): the logo's
/// charcoal + cream, coral for memory/action, gold for reward, plus the two
/// track accents used for perfect weeks and streak freezes.
enum JackpotPalette {
    static let charcoal = Color(red: 0.165, green: 0.165, blue: 0.165)   // hero surface
    static let charcoalDeep = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let cream = Color(red: 0.91, green: 0.89, blue: 0.86)         // #E8E4DC
    static let goldDeep = Color(red: 0.69, green: 0.50, blue: 0.31)      // #B07F4E
    static let coralDeep = Color(red: 0.76, green: 0.17, blue: 0.27)     // #C32C45
    static let green = Color(red: 0.20, green: 0.60, blue: 0.40)         // #339966
    static let indigo = Color(red: 0.30, green: 0.30, blue: 0.60)        // #4D4D99
    static let confetti: [Color] = [.reforgedGold, .reforgedGold, .reforgedCoral, cream, goldDeep, .white]
}

/// The one accent a celebration is keyed to. Everything else stays charcoal + cream.
enum JackpotAccent {
    case gold, coral, green, indigo, muted

    var color: Color {
        switch self {
        case .gold: return .reforgedGold
        case .coral: return .reforgedCoral
        case .green: return JackpotPalette.green
        case .indigo: return JackpotPalette.indigo
        case .muted: return JackpotPalette.cream
        }
    }

    /// The extruded base under the medallion, as on the journey path's nodes.
    var bevel: Color {
        switch self {
        case .gold: return JackpotPalette.goldDeep
        case .coral: return JackpotPalette.coralDeep
        case .green: return Color(red: 0.13, green: 0.42, blue: 0.28)
        case .indigo: return Color(red: 0.21, green: 0.21, blue: 0.43)
        case .muted: return Color(red: 0.60, green: 0.60, blue: 0.61)
        }
    }

    /// Glyph color on the medallion face — charcoal on light faces, white on saturated ones.
    var glyph: Color {
        switch self {
        case .gold, .muted: return JackpotPalette.charcoal
        case .coral, .green, .indigo: return .white
        }
    }
}

struct BurstParticle {
    enum Kind { case ribbon, dot, star, sparkle }

    var origin: UnitPoint
    var velocity: CGVector
    var gravity: CGFloat
    var drag: CGFloat
    var spin: Double
    var flip: Double
    var wobble: CGFloat
    var phase: Double
    var size: CGSize
    var color: Color
    var kind: Kind
    var born: TimeInterval
    var life: TimeInterval
}

final class BurstEngine: ObservableObject {
    enum Emitter {
        /// A cone of confetti. `angle` is degrees from straight up (negative = left).
        case cannon(from: UnitPoint, angle: Double, spread: Double, speed: ClosedRange<CGFloat>, count: Int)
        /// A ring blast from a point.
        case radial(at: UnitPoint, speed: ClosedRange<CGFloat>, count: Int)
        /// Pieces falling from above the top edge.
        case rain(count: Int, kinds: [BurstParticle.Kind])
    }

    @Published private(set) var generation = 0
    let epoch = Date()
    fileprivate(set) var particles: [BurstParticle] = []
    private var endsAt: TimeInterval = 0
    var densityScale: Double = 1

    var isIdle: Bool { Date().timeIntervalSince(epoch) > endsAt }

    func fire(_ emitters: [Emitter], palette: [Color] = JackpotPalette.confetti, delay: TimeInterval = 0) {
        let now = Date().timeIntervalSince(epoch) + delay
        particles.removeAll { now - $0.born > $0.life }

        for emitter in emitters {
            switch emitter {
            case let .cannon(from, angle, spread, speed, count):
                for _ in 0..<scaled(count) {
                    let a = (angle + Double.random(in: -spread / 2...spread / 2)) * .pi / 180
                    let v = CGFloat.random(in: speed)
                    particles.append(make(
                        origin: from,
                        velocity: CGVector(dx: sin(a) * v, dy: -cos(a) * v),
                        kind: [.ribbon, .ribbon, .ribbon, .dot, .star].randomElement()!,
                        palette: palette, born: now + .random(in: 0...0.08)
                    ))
                }
            case let .radial(at, speed, count):
                for i in 0..<scaled(count) {
                    let a = Double(i) / Double(max(scaled(count), 1)) * 2 * .pi + .random(in: -0.15...0.15)
                    let v = CGFloat.random(in: speed)
                    particles.append(make(
                        origin: at,
                        velocity: CGVector(dx: cos(a) * v, dy: sin(a) * v),
                        kind: [.star, .dot, .ribbon].randomElement()!,
                        palette: palette, born: now
                    ))
                }
            case let .rain(count, kinds):
                for _ in 0..<scaled(count) {
                    var p = make(
                        origin: UnitPoint(x: .random(in: 0.02...0.98), y: -0.04),
                        velocity: CGVector(dx: .random(in: -40...40), dy: .random(in: 60...220)),
                        kind: kinds.randomElement() ?? .ribbon,
                        palette: palette, born: now + .random(in: 0...0.9)
                    )
                    p.life = .random(in: 3.2...4.4)
                    particles.append(p)
                }
            }
        }

        endsAt = max(endsAt, (particles.map { $0.born + $0.life }.max() ?? now))
        generation += 1

        // Wake the view once the last piece lands so its TimelineView can pause.
        let remaining = endsAt - Date().timeIntervalSince(epoch) + 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + max(remaining, 0)) { [weak self] in
            self?.generation += 1
        }
    }

    private func scaled(_ count: Int) -> Int { max(1, Int(Double(count) * densityScale)) }

    private func make(origin: UnitPoint, velocity: CGVector, kind: BurstParticle.Kind, palette: [Color], born: TimeInterval) -> BurstParticle {
        let size: CGSize
        switch kind {
        case .ribbon: size = CGSize(width: .random(in: 7...12), height: .random(in: 3.5...5.5))
        case .dot: size = CGSize(width: .random(in: 5...8), height: 0)
        case .star: size = CGSize(width: .random(in: 9...15), height: 0)
        case .sparkle: size = CGSize(width: .random(in: 12...20), height: 0)
        }
        return BurstParticle(
            origin: origin,
            velocity: velocity,
            gravity: .random(in: 520...720),
            drag: .random(in: 1.4...2.4),
            spin: .random(in: -9...9),
            flip: .random(in: 6...14),
            wobble: .random(in: 6...22),
            phase: .random(in: 0...(2 * .pi)),
            size: size,
            color: kind == .sparkle ? [.reforgedGold, JackpotPalette.cream].randomElement()! : (palette.randomElement() ?? .reforgedGold),
            kind: kind,
            born: born,
            life: .random(in: 2.4...3.4)
        )
    }
}

struct BurstField: View {
    @ObservedObject var engine: BurstEngine

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: engine.isIdle)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(engine.epoch)
                for p in engine.particles {
                    draw(p, at: t, in: &ctx, size: size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ p: BurstParticle, at t: TimeInterval, in ctx: inout GraphicsContext, size: CGSize) {
        let age = t - p.born
        guard age >= 0, age < p.life else { return }

        let k = p.drag
        let decay = (1 - exp(-k * age)) / k
        let x = p.origin.x * size.width + p.velocity.dx * decay + sin(p.phase + age * 4) * p.wobble * min(age, 1)
        let y = p.origin.y * size.height + (p.velocity.dy - p.gravity / k) * decay + p.gravity * age / k
        guard y < size.height + 40 else { return }

        let fadeIn = min(age / 0.06, 1)
        let fadeOut = min((p.life - age) / (p.life * 0.25), 1)

        var c = ctx
        c.opacity = fadeIn * fadeOut
        c.translateBy(x: x, y: y)
        c.rotate(by: .radians(p.phase + p.spin * age))
        let flip = cos(p.phase + p.flip * age)

        switch p.kind {
        case .ribbon:
            c.scaleBy(x: 1, y: max(abs(flip), 0.12))
            let r = CGRect(x: -p.size.width / 2, y: -p.size.height / 2, width: p.size.width, height: p.size.height)
            c.fill(Path(roundedRect: r, cornerRadius: 1.2), with: .color(p.color))
        case .dot:
            let d = p.size.width
            c.fill(Path(ellipseIn: CGRect(x: -d / 2, y: -d / 2, width: d, height: d)), with: .color(p.color))
        case .star:
            let d = p.size.width
            c.fill(StarShape().path(in: CGRect(x: -d / 2, y: -d / 2, width: d, height: d)), with: .color(p.color))
        case .sparkle:
            // Four-point glint, the same family as the app's "sparkles" symbol.
            let d = p.size.width
            c.scaleBy(x: max(abs(flip), 0.35), y: 1)
            c.fill(SparkleShape().path(in: CGRect(x: -d / 2, y: -d / 2, width: d, height: d)), with: .color(p.color))
        }
    }
}

struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let w = r * 0.22
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: c.y - r))
        path.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + w, y: c.y - w))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + w, y: c.y + w))
        path.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - w, y: c.y + w))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - w, y: c.y - w))
        path.closeSubpath()
        return path
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.45
        var path = Path()
        for i in 0..<10 {
            let r = i.isMultiple(of: 2) ? outer : inner
            let a = Double(i) * .pi / 5 - .pi / 2
            let pt = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Sunburst

/// Slowly turning arcade rays behind the hero.
struct SunburstRays: View {
    var center: UnitPoint
    var rays: Int = 16
    var color: Color = JackpotPalette.cream.opacity(0.05)
    var spinning: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !spinning)) { timeline in
            Canvas { ctx, size in
                let c = CGPoint(x: center.x * size.width, y: center.y * size.height)
                let radius = hypot(size.width, size.height) * 1.2
                let turn = spinning ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 360) * 0.22 : 0
                let wedge = Double.pi / Double(rays)
                var path = Path()
                for i in 0..<rays {
                    let a = turn + Double(i) * 2 * wedge
                    path.move(to: c)
                    path.addArc(center: c, radius: radius, startAngle: .radians(a), endAngle: .radians(a + wedge), clockwise: false)
                    path.closeSubpath()
                }
                ctx.fill(path, with: .color(color))
            }
        }
        .mask(
            RadialGradient(
                colors: [.clear, .white, .white, .clear],
                center: center,
                startRadius: 30,
                endRadius: 620
            )
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Shake

struct JackpotShake: GeometryEffect {
    var progress: CGFloat
    var amplitude: CGFloat = 12

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard progress > 0, progress < 1 else { return ProjectionTransform(.identity) }
        let falloff = 1 - progress
        let dx = sin(progress * .pi * 9) * amplitude * falloff
        let dy = cos(progress * .pi * 7) * amplitude * 0.45 * falloff
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: dy))
    }
}

// MARK: - Jackpot Model

struct JackpotReel: Identifiable {
    let id = UUID()
    var icon: String
    var label: String
    var value: Int
    var prefix: String = "+"
    var suffix: String = ""
    var tint: Color = .reforgedGold
}

struct JackpotConfig {
    enum Hero {
        case symbol(String)
        case number(Int, caption: String)
    }

    enum Intensity { case max, big, gentle }

    struct Secondary {
        var label: String
        var icon: String
        var action: () -> Void
    }

    var hero: Hero
    var headline: String
    var title: String
    var subtitle: String? = nil
    var accent: JackpotAccent
    var reels: [JackpotReel] = []
    var cta: String = "Claim"
    var secondary: Secondary? = nil
    var intensity: Intensity = .max
}

// MARK: - Jackpot Stage

/// The full-screen Memory-tab celebration. Plays a scored sequence on the brand's
/// charcoal hero surface — reveal, drumroll, medallion lands, headline pops, reward
/// rows count up, confetti settles, then the button — and fast-forwards to the end
/// on any tap so it never holds anyone hostage.
struct JackpotStage: View {
    let config: JackpotConfig
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var burst = BurstEngine()

    @State private var reveal: CGFloat = 0
    @State private var heroIn = false
    @State private var heroLanded = false
    @State private var shake: CGFloat = 0
    @State private var shockwave: CGFloat = 0
    @State private var raysTurn: Double = -12
    @State private var headlineIn = false
    @State private var titleIn = false
    @State private var landedReels = 0
    @State private var ctaIn = false
    @State private var sequence: Task<Void, Never>?
    @State private var skipped = false

    private let heroAnchor = UnitPoint(x: 0.5, y: 0.3)
    private var accent: Color { config.accent.color }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // The charcoal surface opens outward from the medallion.
                let diameter = hypot(geo.size.width, geo.size.height) * 2
                surface
                    .mask(
                        Circle()
                            .frame(width: diameter, height: diameter)
                            .scaleEffect(max(reveal, 0.001))
                            .position(x: geo.size.width * heroAnchor.x, y: geo.size.height * heroAnchor.y)
                    )

                SunburstRays(center: heroAnchor)
                    .rotationEffect(.degrees(raysTurn), anchor: heroAnchor)
                    .opacity(heroLanded ? 1 : 0)

                shockwaveRing(in: geo.size)

                content(in: geo.size)
                    .modifier(JackpotShake(progress: shake))

                BurstField(engine: burst)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .contentShape(Rectangle())
        .onTapGesture { fastForward() }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear(perform: start)
        .onDisappear { sequence?.cancel() }
    }

    // MARK: Layers

    /// Brand hero surface: flat charcoal, with a single warm glow of the accent
    /// behind the medallion once it lands.
    private var surface: some View {
        ZStack {
            JackpotPalette.charcoal
            RadialGradient(
                colors: [accent.opacity(0.32), accent.opacity(0.08), .clear],
                center: heroAnchor,
                startRadius: 20,
                endRadius: 330
            )
            .opacity(heroLanded ? 1 : 0)
            LinearGradient(colors: [.clear, JackpotPalette.charcoalDeep.opacity(0.7)], startPoint: .center, endPoint: .bottom)
        }
    }

    private func shockwaveRing(in size: CGSize) -> some View {
        Circle()
            .stroke(accent.opacity(0.85), lineWidth: 8 * (1 - shockwave) + 1)
            .frame(width: 170, height: 170)
            .scaleEffect(0.8 + shockwave * 4.2)
            .opacity(shockwave > 0 && shockwave < 1 ? Double(1 - shockwave) : 0)
            .position(x: size.width * heroAnchor.x, y: size.height * heroAnchor.y)
            .allowsHitTesting(false)
    }

    private func content(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: size.height * heroAnchor.y - 85)

            hero
                .frame(width: 170, height: 170)

            PopLetters(
                text: config.headline,
                size: headlineSize(width: min(size.width, 520)),
                revealed: headlineIn,
                reduceMotion: reduceMotion
            )
            .padding(.top, 22)

            VStack(spacing: 8) {
                // Scripture voice for the line that says what happened.
                Text(config.title)
                    .font(.custom("LibreBaskerville-Italic", size: 18, relativeTo: .title3))
                    .lineSpacing(4)
                    .foregroundStyle(JackpotPalette.cream)
                    .multilineTextAlignment(.center)
                if let subtitle = config.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(JackpotPalette.cream.opacity(0.7))
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 10)
            .opacity(titleIn ? 1 : 0)
            .offset(y: titleIn ? 0 : 12)

            if !config.reels.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(config.reels.enumerated()), id: \.element.id) { index, reel in
                        JackpotReelRow(reel: reel, landed: index < landedReels, instant: skipped)
                    }
                }
                .frame(maxWidth: 380)
                .padding(.horizontal, 24)
                .padding(.top, 26)
            }

            Spacer(minLength: 16)

            VStack(spacing: 6) {
                Button {
                    JackpotHaptics.shared.claim()
                    dismiss()
                } label: {
                    Text(config.cta.uppercased())
                        .tracking(1.0)
                }
                .buttonStyle(Chunky3DButtonStyle(
                    backgroundColor: .reforgedCoral,
                    bevelColor: JackpotPalette.coralDeep,
                    cornerRadius: 16,
                    depth: 5,
                    textColor: .white
                ))

                if let secondary = config.secondary {
                    Button {
                        HapticManager.shared.lightImpact()
                        secondary.action()
                    } label: {
                        Label(secondary.label, systemImage: secondary.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JackpotPalette.cream)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }

                // Brand sign-off.
                Image("ReforgedMark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                    .foregroundStyle(JackpotPalette.cream.opacity(0.35))
                    .padding(.top, config.secondary == nil ? 14 : 4)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, max(24, size.height * 0.04))
            .opacity(ctaIn ? 1 : 0)
            .offset(y: ctaIn ? 0 : 36)
            .allowsHitTesting(ctaIn)
        }
        .frame(width: size.width, height: size.height)
    }

    /// Same extruded 3D node as the Memory journey path, scaled up: an accent
    /// face sitting on a darker bevel, inside a faint cream ring.
    private var hero: some View {
        ZStack {
            Circle()
                .stroke(JackpotPalette.cream.opacity(0.14), lineWidth: 6)

            Circle()
                .fill(config.accent.bevel)
                .frame(width: 136, height: 136)
                .offset(y: 9)

            Circle()
                .fill(accent)
                .frame(width: 136, height: 136)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.25), lineWidth: 2)
                        .padding(8)
                )

            Group {
                switch config.hero {
                case .symbol(let name):
                    Image(systemName: name)
                        .font(.system(size: 58, weight: .bold))
                case .number(let value, let caption):
                    VStack(spacing: -2) {
                        Text(caption)
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(2)
                            .opacity(0.8)
                        Text("\(value)")
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 22)
                }
            }
            .foregroundStyle(config.accent.glyph)
        }
        .scaleEffect(heroIn ? 1 : (reduceMotion ? 0.9 : 2.4))
        .rotationEffect(.degrees(heroIn ? 0 : (reduceMotion ? 0 : -14)))
        .opacity(heroIn ? 1 : 0)
        .accessibilityHidden(true)
    }

    private func headlineSize(width: CGFloat) -> CGFloat {
        let chars = max(CGFloat(config.headline.count), 1)
        return min(44, (width - 48) / (chars * 0.58))
    }

    // MARK: Sequence

    private func start() {
        burst.densityScale = reduceMotion ? 0.35 : (config.intensity == .gentle ? 0.5 : 1)
        UIAccessibility.post(notification: .announcement, argument: "\(config.headline). \(config.title)")

        let slamAt: TimeInterval = config.intensity == .gentle ? 0.3 : 0.55

        switch config.intensity {
        case .max, .big: JackpotHaptics.shared.jackpot(slamAt: slamAt, sparkles: config.intensity == .max ? 22 : 14)
        case .gentle: JackpotHaptics.shared.softLanding()
        }

        withAnimation(.easeOut(duration: 0.5)) { reveal = 1 }

        sequence = Task { @MainActor in
            await wait(slamAt - 0.2)
            withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .spring(response: 0.26, dampingFraction: 0.55)) {
                heroIn = true
            }
            await wait(0.2)
            land()

            await wait(0.18)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { headlineIn = true }

            await wait(0.3)
            withAnimation(.easeOut(duration: 0.4)) { titleIn = true }

            for index in config.reels.indices {
                await wait(index == 0 ? 0.35 : 0.6)
                guard !Task.isCancelled else { return }
                JackpotHaptics.shared.clunk()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.68)) { landedReels = index + 1 }
            }

            await wait(config.reels.isEmpty ? 0.35 : 0.7)
            guard !Task.isCancelled else { return }
            finale()
        }
    }

    /// The landing: shake, shockwave, confetti from both corners, a ring burst
    /// from the medallion, and one slow settle of the rays.
    private func land() {
        withAnimation(.easeOut(duration: 0.3)) { heroLanded = true }
        if !reduceMotion {
            withAnimation(.linear(duration: 0.4)) { shake = 1 }
            withAnimation(.easeOut(duration: 0.8)) { shockwave = 1 }
            withAnimation(.easeOut(duration: 2.4)) { raysTurn = 0 }
        }

        let heavy = config.intensity == .max
        var emitters: [BurstEngine.Emitter] = [
            .radial(at: heroAnchor, speed: 360...780, count: heavy ? 48 : 30),
        ]
        if config.intensity != .gentle {
            emitters += [
                .cannon(from: UnitPoint(x: -0.02, y: 1.02), angle: 28, spread: 26, speed: 1100...1650, count: heavy ? 90 : 60),
                .cannon(from: UnitPoint(x: 1.02, y: 1.02), angle: -28, spread: 26, speed: 1100...1650, count: heavy ? 90 : 60),
            ]
        }
        burst.fire(emitters, palette: palette)
    }

    /// Confetti in the celebration's accent, anchored by the brand gold and cream.
    private var palette: [Color] {
        [accent, accent, .reforgedGold, JackpotPalette.cream, JackpotPalette.goldDeep, .white]
    }

    /// Glints drift down and the button rises.
    private func finale() {
        if config.intensity != .gentle {
            burst.fire([.rain(count: config.intensity == .max ? 44 : 28, kinds: [.sparkle, .sparkle, .ribbon, .ribbon])], palette: palette)
            JackpotHaptics.shared.payout()
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { ctaIn = true }
    }

    private func fastForward() {
        guard !ctaIn else { return }
        sequence?.cancel()
        skipped = true
        if !heroLanded { land() }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            reveal = 1
            heroIn = true
            headlineIn = true
            titleIn = true
            landedReels = config.reels.count
            ctaIn = true
        }
        JackpotHaptics.shared.clunk()
    }

    private func dismiss() {
        sequence?.cancel()
        withAnimation(.easeIn(duration: 0.22)) { onDismiss() }
    }

    private func wait(_ seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - Headline letters

/// Headline pops in letter by letter on its own spring, left to right, in the
/// app's heavy UI face (cream on charcoal).
struct PopLetters: View {
    let text: String
    let size: CGFloat
    let revealed: Bool
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .font(.system(size: size, weight: .heavy))
                    .foregroundStyle(JackpotPalette.cream)
                    .scaleEffect(revealed || reduceMotion ? 1 : 0.1, anchor: .bottom)
                    .offset(y: revealed || reduceMotion ? 0 : size * 0.4)
                    .opacity(revealed ? 1 : 0)
                    .animation(
                        reduceMotion
                            ? .easeOut(duration: 0.25)
                            : .spring(response: 0.34, dampingFraction: 0.55).delay(Double(index) * 0.03),
                        value: revealed
                    )
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Reel row

/// One reward line: a brand stat tile on the charcoal surface. It lands, then
/// its number rolls up with a haptic tick per step so the value is felt as much
/// as read.
struct JackpotReelRow: View {
    let reel: JackpotReel
    let landed: Bool
    let instant: Bool

    @State private var shown = 0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: reel.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(reel.tint)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(reel.tint.opacity(0.16)))

            Text(reel.label)
                .font(.body.weight(.semibold))
                .foregroundStyle(JackpotPalette.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Text("\(reel.prefix)\(shown)\(reel.suffix)")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(reel.tint)
                .contentTransition(.numericText())
        }
        .padding(.leading, 10)
        .padding(.trailing, 18)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
        )
        .scaleEffect(landed ? 1 : 0.7)
        .offset(y: landed ? 0 : 50)
        .opacity(landed ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(reel.label): \(reel.prefix)\(reel.value)\(reel.suffix)")
        .task(id: landed) {
            guard landed else { return }
            if instant {
                shown = reel.value
                return
            }
            let steps = max(1, min(reel.value, 16))
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: 32_000_000)
                if Task.isCancelled { return }
                withAnimation(.spring(response: 0.18, dampingFraction: 0.9)) {
                    shown = Int((Double(reel.value) * Double(step) / Double(steps)).rounded())
                }
                JackpotHaptics.shared.tick(Double(step) / Double(steps))
            }
        }
    }
}

// MARK: - XP Burst (tier 1, non-blocking)

/// Routine +XP: the whole screen lights up from below and sparks fountain out of
/// a counter that rolls up with haptic ticks. It never takes a touch, so reading
/// carries on underneath it.
struct XPBurst: View {
    let amount: Int
    let multiplier: String?
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var burst = BurstEngine()
    @State private var glow = 0.0
    @State private var popped = false
    @State private var shown = 0
    @State private var multiplierIn = false
    @State private var leaving = false

    private let bottomInset: CGFloat = 120

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, Color.reforgedGold.opacity(0.18), Color.reforgedGold.opacity(0.5)],
                    startPoint: .init(x: 0.5, y: 0.35),
                    endPoint: .bottom
                )
                .opacity(glow)

                BurstField(engine: burst)

                pill
                    .padding(.bottom, bottomInset)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear { run(in: geo.size) }
        }
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Plus \(amount) XP")
    }

    private var pill: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color.reforgedGold)
                .rotationEffect(.degrees(popped && !reduceMotion ? 360 : 0))

            Text("+\(shown)")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text("XP")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.reforgedGold)

            if let multiplier {
                Text(multiplier)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.reforgedCoral))
                    .scaleEffect(multiplierIn ? 1 : 2.2)
                    .opacity(multiplierIn ? 1 : 0)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color(red: 0.13, green: 0.12, blue: 0.11))
                .overlay(Capsule().stroke(Color.reforgedGold, lineWidth: 2))
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        )
        .scaleEffect(popped ? (leaving ? 0.9 : 1) : 0.3)
        .offset(y: leaving ? -70 : 0)
        .opacity(leaving ? 0 : (popped ? 1 : 0))
    }

    private func run(in size: CGSize) {
        burst.densityScale = reduceMotion ? 0.35 : 1
        JackpotHaptics.shared.pop()

        let origin = UnitPoint(x: 0.5, y: (size.height - bottomInset - 28) / max(size.height, 1))
        burst.fire([
            .cannon(from: origin, angle: 0, spread: 80, speed: 520...1050, count: 44),
            .radial(at: origin, speed: 180...360, count: 14),
        ], palette: [.reforgedGold, JackpotPalette.cream, .white, .reforgedCoral])

        withAnimation(.easeOut(duration: 0.25)) { glow = 1 }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { popped = true }

        Task { @MainActor in
            let steps = max(1, min(amount, 12))
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: 38_000_000)
                withAnimation(.spring(response: 0.16, dampingFraction: 0.9)) {
                    shown = Int((Double(amount) * Double(step) / Double(steps)).rounded())
                }
                JackpotHaptics.shared.tick(Double(step) / Double(steps))
            }
            if multiplier != nil {
                JackpotHaptics.shared.clunk()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) { multiplierIn = true }
            }
            withAnimation(.easeOut(duration: 0.9)) { glow = 0 }
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeIn(duration: 0.45)) { leaving = true }
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            onFinished()
        }
    }
}

// MARK: - Arcade reward views (Memory tab only)
//
// The arcade treatment is scoped to the Memory tab: its games and sessions, and
// the root takeovers while Memory is the selected tab. The rest of the app keeps
// the calmer overlays in Theme.swift.

// MARK: - Arcade Confetti

/// Memory-tab game confetti (matching game, complete-the-verse, collections). Rendered by the
/// shared Canvas `BurstEngine`: twin cannons from the bottom corners plus a rain,
/// scored with a confetti-pop haptic. Full-screen takeovers use `JackpotStage`
/// and their own haptics, so this never doubles up with them.
struct ArcadeConfettiView: View {
    @Binding var isActive: Bool

    let intensity: ConfettiView.ConfettiIntensity

    private var cannonCount: Int {
        switch intensity {
        case .low: return 22
        case .medium: return 45
        case .high: return 80
        case .extreme: return 120
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var burst = BurstEngine()

    var body: some View {
        BurstField(engine: burst)
            .ignoresSafeArea()
            .onChange(of: isActive) { newValue in
                guard newValue else { return }
                fire()
            }
            .onAppear {
                if isActive { fire() }
            }
    }

    private func fire() {
        burst.densityScale = reduceMotion ? 0.35 : 1
        let n = cannonCount
        burst.fire([
            .cannon(from: UnitPoint(x: -0.02, y: 1.02), angle: 26, spread: 24, speed: 1000...1600, count: n),
            .cannon(from: UnitPoint(x: 1.02, y: 1.02), angle: -26, spread: 24, speed: 1000...1600, count: n),
            .rain(count: n / 2, kinds: [.ribbon, .ribbon, .sparkle, .dot]),
        ])
        JackpotHaptics.shared.confettiPop()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            isActive = false
        }
    }
}

extension View {
    /// Arcade confetti for Memory-tab games. Elsewhere, use `.confetti`.
    func arcadeConfetti(isActive: Binding<Bool>, intensity: ConfettiView.ConfettiIntensity = .medium) -> some View {
        ZStack {
            self
            ArcadeConfettiView(isActive: isActive, intensity: intensity)
        }
    }
}

// MARK: - XP Gain (tier 1: non-blocking burst)

struct ArcadeXPGainView: View {
    let amount: Int
    let source: String
    @Binding var isPresented: Bool

    private var multiplier: String? {
        let streak = AppState.shared.user.streak
        if streak >= 30 { return "2x" }
        if streak >= 7 { return "1.5x" }
        return nil
    }

    var body: some View {
        if isPresented {
            XPBurst(amount: amount, multiplier: multiplier) {
                isPresented = false
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Streak Milestone Celebration

struct ArcadeStreakMilestoneView: View {
    let streakCount: Int
    @Binding var isPresented: Bool
    @State private var showShareStreak = false

    var milestoneMessage: String {
        switch streakCount {
        case 7: return "One week strong"
        case 14: return "Two weeks of dedication"
        case 21: return "Three weeks of growth"
        case 30: return "One month champion"
        case 50: return "50-day warrior"
        case 100: return "Century achiever"
        case 365: return "One year legend"
        default: return "\(streakCount)-day streak"
        }
    }

    var milestoneIcon: String {
        switch streakCount {
        case 7, 14: return "flame.fill"
        case 21: return "star.fill"
        case 30, 50: return "crown.fill"
        case 100, 365: return "trophy.fill"
        default: return "flame.fill"
        }
    }

    var body: some View {
        if isPresented {
            JackpotStage(
                config: JackpotConfig(
                    hero: .number(streakCount, caption: "DAYS"),
                    headline: "Streak milestone",
                    title: milestoneMessage,
                    subtitle: "\(streakCount) days of faithful reading",
                    accent: .coral,
                    reels: [
                        JackpotReel(icon: milestoneIcon, label: "Day streak", value: streakCount, prefix: "", tint: .reforgedCoral),
                    ],
                    cta: "Keep going",
                    secondary: .init(label: "Share your streak", icon: "square.and.arrow.up") {
                        showShareStreak = true
                    },
                    intensity: .max
                ),
                onDismiss: { isPresented = false }
            )
            .transition(.opacity)
            .sheet(isPresented: $showShareStreak) {
                StreakShareSheet()
            }
        }
    }
}

// MARK: - Perfect Week Celebration

struct ArcadePerfectWeekView: View {
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            JackpotStage(
                config: JackpotConfig(
                    hero: .symbol("checkmark.seal.fill"),
                    headline: "Perfect week",
                    title: "All seven days. Well done.",
                    accent: .green,
                    reels: [
                        JackpotReel(icon: "calendar", label: "Days covered", value: 7, prefix: "", suffix: "/7", tint: JackpotPalette.green),
                    ],
                    cta: "Keep going",
                    intensity: .big
                ),
                onDismiss: { isPresented = false }
            )
            .transition(.opacity)
        }
    }
}

// MARK: - Freeze Used Notice

/// Shown when freezes were spent to repair a gap. The user needs to know the
/// streak survived *and* that it cost them something, or the freeze economy is
/// invisible and the inventory drop looks like a bug.
struct ArcadeFreezeUsedView: View {
    let freezesSpent: Int
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            JackpotStage(
                config: JackpotConfig(
                    hero: .symbol("snowflake"),
                    headline: "Streak saved",
                    title: freezesSpent == 1
                        ? "A streak freeze covered the day you missed."
                        : "\(freezesSpent) streak freezes covered the days you missed.",
                    subtitle: "Your streak lives on: \(AppState.shared.user.streak) days",
                    accent: .indigo,
                    reels: [
                        JackpotReel(icon: "snowflake", label: "Freezes used", value: freezesSpent, prefix: "−", tint: Color(red: 0.60, green: 0.60, blue: 0.85)),
                    ],
                    cta: "Keep going",
                    intensity: .big
                ),
                onDismiss: { isPresented = false }
            )
            .transition(.opacity)
        }
    }
}

// MARK: - Level Up Celebration

struct ArcadeLevelUpView: View {
    let newLevel: Int
    @Binding var isPresented: Bool

    var levelTitle: String {
        SampleData.getLevelInfo(level: newLevel).title
    }

    var body: some View {
        if isPresented {
            JackpotStage(
                config: JackpotConfig(
                    hero: .number(newLevel, caption: "LEVEL"),
                    headline: "Level up",
                    title: LevelProgression.levelUpLine(for: newLevel),
                    subtitle: LevelProgression.freezeRewardLine(AppState.shared.lastLevelUpFreezes)
                        .map { "\($0) to protect your streak" }
                        ?? "Keep reading, remembering, and living the Word.",
                    accent: .gold,
                    reels: [
                        JackpotReel(icon: "arrow.up.circle.fill", label: "New level", value: newLevel, prefix: "", tint: .reforgedGold),
                    ],
                    cta: "Continue",
                    intensity: .max
                ),
                onDismiss: { isPresented = false }
            )
            .transition(.opacity)
        }
    }
}

// MARK: - Badge Earned Celebration

struct ArcadeBadgeEarnedView: View {
    let badge: Badge
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            JackpotStage(
                config: JackpotConfig(
                    hero: .symbol(badge.icon),
                    headline: "Badge earned",
                    title: badge.name,
                    subtitle: badge.description,
                    accent: .gold,
                    cta: "Awesome",
                    intensity: .max
                ),
                onDismiss: { isPresented = false }
            )
            .transition(.opacity)
        }
    }
}

// MARK: - Practice Complete Celebration

/// Memory practice/drill finish. Scales the takeover to the score: a strong
/// recall gets the full jackpot, a rough one still gets a warm, gentler landing.
struct PracticeCompleteCelebration: View {
    let score: Int // 1-5 quality rating
    let xpEarned: Int
    @Binding var isPresented: Bool

    var celebrationMessage: String {
        switch score {
        case 5: return "Perfect recall"
        case 4: return "Great job"
        case 3: return "Nice work"
        case 2: return "Keep going"
        default: return "Don't give up"
        }
    }

    var celebrationIcon: String {
        switch score {
        case 5: return "star.fill"
        case 4: return "hand.thumbsup.fill"
        case 3: return "checkmark"
        case 2: return "arrow.clockwise"
        default: return "heart.fill"
        }
    }

    var body: some View {
        if isPresented {
            JackpotStage(
                config: JackpotConfig(
                    hero: .symbol(celebrationIcon),
                    headline: celebrationMessage,
                    title: score >= 3 ? "That verse is sinking in." : "Each time you return, it takes deeper root.",
                    accent: score >= 5 ? .gold : (score >= 3 ? .coral : .muted),
                    reels: [
                        JackpotReel(icon: "star.fill", label: "XP earned", value: xpEarned, tint: .reforgedGold),
                        JackpotReel(icon: "brain.head.profile", label: "Recall score", value: score, prefix: "", suffix: "/5", tint: .reforgedCoral),
                    ],
                    cta: "Continue",
                    intensity: score >= 4 ? .max : (score >= 3 ? .big : .gentle)
                ),
                onDismiss: { isPresented = false }
            )
            .transition(.opacity)
        }
    }
}
