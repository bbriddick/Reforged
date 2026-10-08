import SwiftUI

// MARK: - Memory Journey (Duolingo-style themed curriculum path)
//
// The Memory tab's hero: one winding "skill-tree" path that walks the member
// through a themed Scripture-memory curriculum. It is REVIEW-FIRST: due verses surface in a priority banner and
// glow coral inline. Learning is woven with repetition — every unit sprinkles in
// "Quick recall" checkpoints and ends with a "Unit review" lesson.
//
// Node state is derived from the member's real SRS progress (matched by
// reference). Tapping a not-yet-started verse adds it (bundled public-domain KJV
// text) and launches its guided lesson. Visuals follow reforged-design: warm
// canvas, coral = due/action, gold = reward, green = mastered, per-unit accents;
// everything 3D and blocky via `Chunky3DButtonStyle` and extruded nodes.

// MARK: - Node status

enum JourneyStatus {
    case available   // in the curriculum, not yet started
    case due         // started and in the SRS queue now
    case learning    // started, maturing (level 1–4)
    case mastered    // level 5

    func tint(_ accent: PlanAccent, _ scheme: ColorScheme?) -> Color {
        switch self {
        case .available: return accent.color(scheme)
        case .due:       return .reforgedCoral
        case .learning:  return .reforgedGold
        case .mastered:  return Color(red: 0.20, green: 0.65, blue: 0.40)
        }
    }

    func bevel(_ accent: PlanAccent, _ scheme: ColorScheme?) -> Color {
        switch self {
        case .available: return accent.bevelColor(scheme)
        case .due:       return Color(red: 0.78, green: 0.20, blue: 0.32)
        case .learning:  return Color(red: 0.75, green: 0.58, blue: 0.10)
        case .mastered:  return Color(red: 0.13, green: 0.48, blue: 0.28)
        }
    }
}

enum CheckpointKind { case quickRecall, unitReview }

enum MemoryJourneyAnchor {
    static let current = "memory-journey-current"
    static let collections = "memory-collections"
}

// MARK: - Journey rows

private enum JourneyRow: Identifiable {
    case unitHeader(CurriculumUnit, learned: Int)
    case lockedUnit(CurriculumUnit)
    case verse(CurriculumVerse, CurriculumUnit, locked: Bool, xOffset: CGFloat, prevOffset: CGFloat?)
    case checkpoint(CurriculumUnit, CheckpointKind, unlocked: Bool, xOffset: CGFloat, prevOffset: CGFloat?)

    var id: String {
        switch self {
        case .unitHeader(let u, _): return "h-\(u.id)"
        case .lockedUnit(let u): return "l-\(u.id)"
        case .verse(let v, let u, _, _, _): return "v-\(u.id)-\(v.reference)"
        case .checkpoint(let u, let k, _, let x, _):
            return "c-\(u.id)-\(k == .quickRecall ? "q" : "r")-\(Int(x))"
        }
    }
}

// MARK: - Journey content

struct MemoryJourneyView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    let launchLesson: (MemoryVerse) -> Void
    let reviewAll: () -> Void
    let reviewUnit: (CurriculumUnit) -> Void
    let onPractice: (MemoryVerse) -> Void
    let onAddCustom: () -> Void

    @State private var bounce = false
    @State private var collapsedUnitIDs: Set<String> = []

    // MARK: Progress lookups

    private var startedByRef: [String: MemoryVerse] {
        Dictionary(appState.memoryVerses.map { ($0.reference, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private var dueVerses: [MemoryVerse] {
        appState.memoryVerses.filter { $0.isDueForReview }
    }

    /// Custom verses the member added themselves (not part of the fixed curriculum)
    /// surface as a "My Verses" unit at the top of the journey, so they ride the
    /// same review + repetition loop.
    private var combinedUnits: [CurriculumUnit] {
        var units: [CurriculumUnit] = []
        let curriculumRefs = Set(MemoryCurriculum.allVerses.map { $0.reference })
        let custom = appState.memoryVerses.filter { !curriculumRefs.contains($0.reference) }
        if !custom.isEmpty {
            units.append(CurriculumUnit(
                id: "custom", title: "My Verses", theme: "Custom",
                subtitle: "Verses you've added yourself", icon: "star.fill", accent: .coral,
                verses: custom.map { CurriculumVerse(reference: $0.reference, text: $0.text) }))
        }
        units.append(contentsOf: MemoryCurriculum.units)
        return units
    }

    private var orderedRefs: [String] { combinedUnits.flatMap { $0.verses.map { $0.reference } } }

    /// The next unstarted verse in order — the frontier the member unlocks next.
    private var frontierRef: String? { orderedRefs.first { startedByRef[$0] == nil } }

    /// The unit index that holds the frontier; later units stay collapsed/locked.
    private var frontierUnitIndex: Int? {
        guard let f = frontierRef else { return nil }
        return combinedUnits.firstIndex { $0.verses.contains { $0.reference == f } }
    }

    private func status(for reference: String) -> JourneyStatus {
        guard let mv = startedByRef[reference] else { return .available }
        if mv.isDueForReview { return .due }
        if mv.level >= 5 { return .mastered }
        return .learning
    }

    /// Gradual unlock: a verse is playable only if it is already started or it is
    /// the single frontier verse. Everything beyond the frontier is locked.
    private func isLocked(_ reference: String) -> Bool {
        if startedByRef[reference] != nil { return false }
        return reference != frontierRef
    }

    /// The single node that carries the bouncing "START" bubble: the first due
    /// verse in order, else the frontier verse.
    private var currentRef: String? {
        if let due = orderedRefs.first(where: { startedByRef[$0]?.isDueForReview == true }) { return due }
        return frontierRef
    }

    private func offset(_ index: Int) -> CGFloat {
        CGFloat(sin(Double(index) * .pi / 3.0)) * 66
    }

    /// Flattens the (custom + curriculum) units into path rows. Units the member
    /// hasn't reached yet render as a single locked teaser header; reached units
    /// render fully: header → verse nodes (some locked) → a repetition checkpoint
    /// after every 2 verses → a unit-review checkpoint at the end. The short
    /// learn-learn-review rhythm keeps recall woven through progression.
    private var rows: [JourneyRow] {
        var out: [JourneyRow] = []
        var nodeIndex = 0
        for (unitIndex, unit) in combinedUnits.enumerated() {
            let started = unit.verses.filter { startedByRef[$0.reference] != nil }.count

            // A future unit (past the frontier, with nothing started) collapses.
            if let fi = frontierUnitIndex, unitIndex > fi, started == 0 {
                out.append(.lockedUnit(unit))
                continue
            }

            out.append(.unitHeader(unit, learned: started))

            if collapsedUnitIDs.contains(unit.id) {
                continue
            }

            var prev: CGFloat? = nil          // no connector into the first node of a unit
            var sinceCheckpoint = 0
            var startedSoFar = 0

            for (i, v) in unit.verses.enumerated() {
                let x = offset(nodeIndex)
                out.append(.verse(v, unit, locked: isLocked(v.reference), xOffset: x, prevOffset: prev))
                prev = x; nodeIndex += 1
                if startedByRef[v.reference] != nil { startedSoFar += 1 }
                sinceCheckpoint += 1

                if sinceCheckpoint == 2 && i < unit.verses.count - 1 {
                    let cx = offset(nodeIndex)
                    out.append(.checkpoint(unit, .quickRecall, unlocked: startedSoFar >= i + 1,
                                           xOffset: cx, prevOffset: prev))
                    prev = cx; nodeIndex += 1
                    sinceCheckpoint = 0
                }
            }

            let cx = offset(nodeIndex)
            out.append(.checkpoint(unit, .unitReview, unlocked: startedSoFar >= unit.verses.count,
                                   xOffset: cx, prevOffset: prev))
            nodeIndex += 1
        }
        return out
    }

    var body: some View {
        VStack(spacing: ReforgedTheme.spacingL) {
            if !dueVerses.isEmpty {
                ReviewPriorityBanner(dueCount: dueVerses.count, onReview: reviewAll)
            }

            // Plain VStack on purpose: a LazyVStack nested in MemoryView's
            // ScrollView > VStack mis-places rows when content above it changes
            // (e.g. the review banner disappearing after a review), drawing the
            // path over the header and shoving it under the status bar. Row count
            // is bounded — future units collapse to a single locked banner.
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    rowView(row)
                }

                addCustomButton
                    .padding(.top, 26)
            }
        }
    }

    // MARK: Row dispatch

    @ViewBuilder
    private func rowView(_ row: JourneyRow) -> some View {
        switch row {
        case .unitHeader(let unit, let learned):
            UnitHeaderBanner(
                unit: unit,
                isStarted: learned > 0,
                isCollapsed: collapsedUnitIDs.contains(unit.id),
                onToggle: {
                    HapticManager.shared.buttonTap()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        if collapsedUnitIDs.contains(unit.id) {
                            collapsedUnitIDs.remove(unit.id)
                        } else {
                            collapsedUnitIDs.insert(unit.id)
                        }
                    }
                }
            )
                .padding(.top, 22)
                .padding(.bottom, 4)

        case .lockedUnit(let unit):
            LockedUnitBanner(unit: unit)
                .padding(.top, 22)
                .padding(.bottom, 4)

        case .verse(let cv, let unit, let locked, let x, let prev):
            let st = status(for: cv.reference)
            CurriculumVerseNode(
                verse: cv,
                unit: unit,
                status: st,
                locked: locked,
                level: startedByRef[cv.reference]?.level ?? 0,
                isCurrent: cv.reference == currentRef,
                xOffset: x,
                prevOffset: prev,
                bounce: bounce,
                onTap: { startOrOpen(cv, unit, st) },
                onPractice: { if let mv = startedByRef[cv.reference] { onPractice(mv) } },
                onRemove: startedByRef[cv.reference] == nil ? nil : {
                    if let mv = startedByRef[cv.reference] {
                        withAnimation { appState.removeMemoryVerse(mv.id) }
                    }
                }
            )
            .id(cv.reference == currentRef ? MemoryJourneyAnchor.current : row.id)

        case .checkpoint(let unit, let kind, let unlocked, let x, let prev):
            CheckpointNode(
                unit: unit,
                kind: kind,
                unlocked: unlocked,
                xOffset: x,
                prevOffset: prev,
                onTap: {
                    HapticManager.shared.cardFlipEdgeThud()
                    reviewUnit(unit)
                }
            )
        }
    }

    // MARK: Actions

    private func startOrOpen(_ cv: CurriculumVerse, _ unit: CurriculumUnit, _ st: JourneyStatus) {
        HapticManager.shared.cardFlipEdgeThud()
        if let existing = startedByRef[cv.reference] {
            launchLesson(existing)
            return
        }
        // A brand-new curriculum verse launches a *transient* lesson — it is only
        // committed to the member's memory (and the next node unlocked) once the
        // lesson is finished. Abandoning it adds nothing, keeping progress gradual.
        let transient = MemoryVerse(
            id: UUID().uuidString,
            reference: cv.reference,
            text: cv.text,
            esvText: nil,
            category: unit.theme,
            translation: "KJV",
            lastFetched: AppDateFormatters.iso8601.string(from: Date()),
            nextReviewDate: Date(),
            reviewCount: 0,
            easeFactor: 2.5,
            interval: 1,
            isLearning: true,
            accuracy: nil,
            modeStats: nil
        )
        launchLesson(transient)
    }

    private var addCustomButton: some View {
        Button(action: { HapticManager.shared.buttonTap(); onAddCustom() }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add your own verse")
            }
            .font(.subheadline.bold())
            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Review-first banner (breathing coral glow)

struct ReviewPriorityBanner: View {
    let dueCount: Int
    let onReview: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.18)).frame(width: 40, height: 40)
                    Image(systemName: "bolt.heart.fill").font(.title3.bold()).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verses due today")
                        .font(.caption.bold()).tracking(1.0).foregroundStyle(.white.opacity(0.85))
                    Text("\(dueCount) ready to review")
                        .font(.title3.bold()).foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: dueCount)
                }
                Spacer()
            }
            Button {
                HapticManager.shared.cardFlipEdgeThud()
                onReview()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("REVIEW ALL NOW")
                }
            }
            .buttonStyle(Chunky3DButtonStyle(
                backgroundColor: .white,
                bevelColor: Color(red: 0.90, green: 0.86, blue: 0.82),
                textColor: .reforgedCoral
            ))
        }
        .padding(20)
        .background(
            LinearGradient(colors: [.reforgedCoral, Color(red: 0.82, green: 0.24, blue: 0.36)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        // A slow, warm coral breath draws the eye to the day's priority without
        // nagging. Static under Reduce Motion.
        .shadow(color: Color.reforgedCoral.opacity(breathe ? 0.55 : 0.32),
                radius: breathe ? 24 : 14, y: 6)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

// MARK: - Unit header banner

struct UnitHeaderBanner: View {
    let unit: CurriculumUnit
    let isStarted: Bool
    let isCollapsed: Bool
    let onToggle: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var accent: Color { unit.accent.color(colorScheme) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.9))
                    .frame(width: 48, height: 48)
                Image(systemName: unit.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(unit.title.uppercased())
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text(unit.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Button(action: onToggle) {
                Image(systemName: "chevron.up")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.16), in: Circle())
                    .rotationEffect(.degrees(isCollapsed ? 180 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isCollapsed)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCollapsed ? "Expand \(unit.title)" : "Collapse \(unit.title)")
        }
        .padding(16)
        .background(
            LinearGradient(colors: [accent, accent.opacity(0.7)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: accent.opacity(0.3), radius: 10, y: 5)
    }
}

// MARK: - Locked unit teaser (not yet reached)

struct LockedUnitBanner: View {
    let unit: CurriculumUnit
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.adaptiveTextSecondary(colorScheme).opacity(0.25))
                    .frame(width: 44, height: 44)
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(unit.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Text("Keep going to unlock")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.8))
            }
            Spacer()
        }
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
    }
}

// MARK: - Header stat pill (compact, glanceable)

struct HeaderStatChip: View {
    let icon: String
    let value: String
    let tint: Color
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bump = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .scaleEffect(bump ? 1.28 : 1)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.6, dampingFraction: 0.85), value: value)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(colorScheme == .dark ? 0.22 : 0.13), in: Capsule())
        .scaleEffect(bump ? 1.07 : 1)
        .onChange(of: value) { _ in pulse() }
    }

    private func pulse() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) { bump = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { bump = false }
        }
    }
}

// MARK: - Curriculum verse node

struct CurriculumVerseNode: View {
    let verse: CurriculumVerse
    let unit: CurriculumUnit
    let status: JourneyStatus
    let locked: Bool
    let level: Int
    let isCurrent: Bool
    let xOffset: CGFloat
    let prevOffset: CGFloat?
    let bounce: Bool
    let onTap: () -> Void
    let onPractice: () -> Void
    let onRemove: (() -> Void)?

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false
    @State private var sheenPhase: Double = 0
    @State private var depthScale: CGFloat = 1
    @State private var depthOpacity: Double = 1
    @State private var attentionPulse = false

    private var lockedTint: Color { Color.adaptiveTextSecondary(colorScheme).opacity(0.5) }
    private var lockedBevel: Color { Color.adaptiveTextSecondary(colorScheme).opacity(0.3) }

    private var tint: Color { locked ? lockedTint : status.tint(unit.accent, colorScheme) }
    private var bevel: Color { locked ? lockedBevel : status.bevel(unit.accent, colorScheme) }
    private var levelFraction: CGFloat { CGFloat(min(level, 5)) / 5.0 }
    private var isGhost: Bool { !locked && status == .available }
    private var showRing: Bool { !locked && status != .available }

    private var icon: String {
        if locked { return "lock.fill" }
        switch status {
        case .available: return unit.icon
        case .due:       return "arrow.triangle.2.circlepath"
        case .learning:  return "book.fill"
        case .mastered:  return "crown.fill"
        }
    }

    private var caption: String {
        if locked { return "Locked" }
        switch status {
        case .available: return "Tap to learn"
        case .due:       return "Due for review"
        case .learning:  return "Learning"
        case .mastered:  return "Mastered"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            if let prev = prevOffset {
                JourneyConnector(fromX: prev, toX: xOffset, tint: tint.opacity(isGhost || locked ? 0.5 : 1))
            }

            VStack(spacing: 8) {
                if isCurrent && !locked {
                    startBubble
                }

                Button(action: fireTap) {
                    // Centered stack so the level ring stays concentric with the
                    // face; the darker base sits 7pt lower to extrude downward
                    // (light-from-above), and the face presses onto it.
                    ZStack {
                        Circle().fill(bevel).frame(width: 78, height: 78).offset(y: 7)

                        if isCurrent && !locked {
                            Circle()
                                .stroke(tint.opacity(attentionPulse ? 0.18 : 0.7), lineWidth: 4)
                                .frame(width: 98, height: 98)
                                .scaleEffect(attentionPulse ? 1.14 : 1)
                                .allowsHitTesting(false)
                        }

                        if showRing {
                            Circle()
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 5)
                                .frame(width: 90, height: 90).offset(y: pressed ? 7 : 0)
                            Circle()
                                .trim(from: 0, to: levelFraction)
                                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 90, height: 90).offset(y: pressed ? 7 : 0)
                        }

                        Circle()
                            .fill(isGhost ? Color.adaptiveCardBackground(colorScheme) : tint)
                            .overlay(
                                Circle().strokeBorder(tint, lineWidth: isGhost ? 3 : 0)
                            )
                            .frame(width: 78, height: 78)
                            .overlay(
                                Image(systemName: icon)
                                    .font(.system(size: isGhost ? 28 : (locked ? 24 : 28), weight: .bold))
                                    .foregroundStyle(isGhost ? tint : (status == .learning && !locked ? .black : .white))
                            )
                            .overlay(sheenBand)          // one-shot specular sweep on tap
                            .clipShape(Circle())
                            .offset(y: pressed ? 7 : 0)
                    }
                    .frame(width: 110, height: 110)
                    .contentShape(Circle())
                    .scaleEffect(pressed && !locked ? 0.965 : 1)   // firm token compression
                    .shadow(color: tint.opacity(pressed ? 0.1 : (isGhost || locked ? 0.15 : 0.3)),
                            radius: pressed ? 3 : 8, y: pressed ? 2 : 5)
                    .animation(.spring(response: 0.33, dampingFraction: 0.5), value: pressed)  // release overshoot
                }
                .buttonStyle(PressReportingStyle(isPressed: $pressed))
                .frame(width: 110, height: 110)
                .contentShape(Circle())
                .accessibilityLabel("\(verse.reference), \(caption)")
                .contextMenu {
                    if !locked {
                        Button(action: onTap) {
                            Label(isGhost ? "Start learning" : "Open lesson", systemImage: "play.fill")
                        }
                        if !isGhost {
                            Button(action: onPractice) {
                                Label("Practice modes", systemImage: "square.grid.2x2.fill")
                            }
                        }
                        if let onRemove {
                            Button(role: .destructive, action: onRemove) {
                                Label("Remove verse", systemImage: "trash")
                            }
                        }
                    }
                }

                VStack(spacing: 1) {
                    Text(verse.reference)
                        .font(.subheadline.bold())
                        .foregroundStyle(locked ? Color.adaptiveTextSecondary(colorScheme)
                            : Color.adaptiveText(colorScheme))
                    Text(caption)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(status == .due && !locked ? Color.reforgedCoral
                            : Color.adaptiveTextSecondary(colorScheme))
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .offset(x: xOffset)
            .scaleEffect(depthScale)
            .opacity(depthOpacity)
            .background(depthProbe)
        }
        .padding(.vertical, 6)
        .onAppear {
            guard isCurrent, !locked, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                attentionPulse = true
            }
        }
    }

    // A thin diagonal highlight that sweeps across the face once, driven by
    // `sheenPhase` (0→1). Opacity peaks mid-sweep so the reset at phase 1 is unseen.
    private var sheenBand: some View {
        LinearGradient(colors: [.clear, Color.white.opacity(0.6), .clear],
                       startPoint: .leading, endPoint: .trailing)
            .frame(width: 32)
            .rotationEffect(.degrees(20))
            .offset(x: -70 + 130 * sheenPhase)
            .opacity(4 * sheenPhase * (1 - sheenPhase))
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    // Scroll-linked focus depth: nodes near the vertical center of the screen sit
    // full and bright; those drifting toward the edges recede a touch. Very subtle,
    // and identity under Reduce Motion.
    private var depthProbe: some View {
        GeometryReader { geo in
            let midY = geo.frame(in: .global).midY
            Color.clear
                .onChange(of: midY) { updateDepth($0) }
                .onAppear { updateDepth(midY) }
        }
    }

    private func fireTap() {
        guard !locked else { HapticManager.shared.buttonTap(); return }
        if !reduceMotion {
            sheenPhase = 0
            withAnimation(.easeInOut(duration: 0.5)) { sheenPhase = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { sheenPhase = 0 }
        }
        onTap()
    }

    private func updateDepth(_ midY: CGFloat) {
        guard !reduceMotion else { depthScale = 1; depthOpacity = 1; return }
        let screenH = UIScreen.main.bounds.height
        let norm = min(1, abs(midY - screenH * 0.5) / (screenH * 0.5))  // 0 center → 1 edge
        depthScale = 1 - 0.05 * norm
        depthOpacity = 1 - 0.16 * norm
    }

    private var startBubble: some View {
        Text("START")
            .font(.caption.bold()).tracking(1.0).foregroundStyle(tint)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(tint, lineWidth: 2))
            .overlay(alignment: .bottom) {
                Triangle().fill(tint).frame(width: 12, height: 7)
                    .rotationEffect(.degrees(180)).offset(y: 6)
            }
            .shadow(color: tint.opacity(0.25), radius: 6, y: 3)
    }
}

// MARK: - Checkpoint node (repetition + unit review)

struct CheckpointNode: View {
    let unit: CurriculumUnit
    let kind: CheckpointKind
    let unlocked: Bool
    let xOffset: CGFloat
    let prevOffset: CGFloat?
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var pressed = false

    private var tint: Color {
        unlocked ? .reforgedGold : Color.adaptiveTextSecondary(colorScheme).opacity(0.5)
    }
    private var bevel: Color {
        unlocked ? Color(red: 0.75, green: 0.58, blue: 0.10)
                 : Color.adaptiveTextSecondary(colorScheme).opacity(0.35)
    }
    private var icon: String {
        if !unlocked { return "lock.fill" }
        return kind == .quickRecall ? "bolt.fill" : "trophy.fill"
    }
    private var title: String { kind == .quickRecall ? "Quick recall" : "Unit review" }

    var body: some View {
        VStack(spacing: 8) {
            if let prev = prevOffset {
                JourneyConnector(fromX: prev, toX: xOffset, tint: tint.opacity(0.7))
            }

            VStack(spacing: 8) {
                Button(action: fireTap) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(bevel).frame(width: 74, height: 74).offset(y: 7)
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(tint).frame(width: 74, height: 74)
                            .overlay(
                                Image(systemName: icon)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(y: pressed ? 7 : 0)
                    }
                    .frame(height: 96)
                    .scaleEffect(pressed && unlocked ? 0.955 : 1)
                    .shadow(color: tint.opacity(pressed ? 0.1 : 0.3), radius: pressed ? 3 : 8, y: pressed ? 2 : 5)
                    .animation(.spring(response: 0.33, dampingFraction: 0.5), value: pressed)
                }
                .buttonStyle(PressReportingStyle(isPressed: $pressed))
                .contentShape(Rectangle())

                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(unlocked ? Color.adaptiveText(colorScheme)
                        : Color.adaptiveTextSecondary(colorScheme))
                    // Checkpoint labels are landmarks. Keep their position and
                    // rendering completely static while the button animates.
                    .transaction { transaction in
                        transaction.animation = nil
                    }
            }
            .frame(maxWidth: .infinity)
            .offset(x: xOffset)
        }
        .padding(.vertical, 6)
    }

    private func fireTap() {
        guard unlocked else { HapticManager.shared.buttonTap(); return }
        onTap()
    }
}

// MARK: - Connector (dotted trail between two nodes)

struct JourneyConnector: View {
    let fromX: CGFloat
    let toX: CGFloat
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            ForEach(0..<3, id: \.self) { i in
                let t = CGFloat(i + 1) / 4.0
                Circle()
                    .fill(tint.opacity(0.35))
                    .frame(width: 7, height: 7)
                    .position(x: cx + fromX + (toX - fromX) * t, y: geo.size.height * t)
            }
        }
        .frame(height: 26)
    }
}

// MARK: - Accent bevel helper

extension PlanAccent {
    /// A darker shade of the accent for 3D extruded bases.
    func bevelColor(_ scheme: ColorScheme?) -> Color {
        switch self {
        case .gold:   return Color(red: 0.75, green: 0.58, blue: 0.10)
        case .coral:  return Color(red: 0.78, green: 0.20, blue: 0.32)
        case .purple: return Color(red: 0.40, green: 0.24, blue: 0.52)
        case .teal:   return Color(red: 0.00, green: 0.34, blue: 0.43)
        case .blue:   return Color(red: 0.06, green: 0.45, blue: 0.58)
        case .green:  return Color(red: 0.13, green: 0.48, blue: 0.28)
        case .navy:   return Color.adaptiveNavyText(scheme).opacity(0.6)
        }
    }
}
