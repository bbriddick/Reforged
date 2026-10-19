import SwiftUI

// MARK: - Hashable Conformance for Navigation

extension Lesson: Hashable {
    static func == (lhs: Lesson, rhs: Lesson) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Path Data Types

enum LessonNodeState {
    case completed
    case current
    case locked
}

enum PathItem: Identifiable {
    case sectionHeader(track: Track, phaseNumber: Int, phaseName: String)
    case lessonNode(lesson: Lesson, globalIndex: Int, track: Track)

    var id: String {
        switch self {
        case .sectionHeader(let track, _, _):
            return "header-\(track.id)"
        case .lessonNode(let lesson, _, _):
            return lesson.id
        }
    }
}

// MARK: - Learning Path View

struct LearningPathView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var selectedLesson: Lesson?
    @State private var navigateToLesson = false
    @State private var hasScrolledToCurrentOnAppear = false

    // Phase mapping for each track
    private static let phaseMap: [String: (Int, String)] = [
        "doctrine-bible": (1, "Scripture Foundation"),
        "doctrine-trinity": (2, "Know Your God"),
        "doctrine-father": (2, "Know Your God"),
        "doctrine-son": (2, "Know Your God"),
        "doctrine-spirit": (2, "Know Your God"),
        "doctrine-creation": (3, "Creation, Fall & Redemption"),
        "doctrine-man": (3, "Creation, Fall & Redemption"),
        "doctrine-salvation": (3, "Creation, Fall & Redemption"),
        "doctrine-satan": (3, "Creation, Fall & Redemption"),
        "devotional-foundations": (4, "Devotional Living"),
        "devotional-faithful-living": (4, "Devotional Living"),
        "devotional-christian-community": (4, "Devotional Living"),
    ]

    var pathItems: [PathItem] {
        var items: [PathItem] = []
        var globalIndex = 0
        for track in appState.tracks {
            let phase = Self.phaseMap[track.id] ?? (0, "")
            items.append(.sectionHeader(track: track, phaseNumber: phase.0, phaseName: phase.1))
            for lesson in track.lessons {
                items.append(.lessonNode(lesson: lesson, globalIndex: globalIndex, track: track))
                globalIndex += 1
            }
        }
        return items
    }

    var currentLessonGlobalIndex: Int {
        var globalIndex = 0
        for track in appState.tracks {
            for lesson in track.lessons {
                if !lesson.isCompleted {
                    return globalIndex
                }
                globalIndex += 1
            }
        }
        return globalIndex
    }

    var currentLessonId: String? {
        for track in appState.tracks {
            for lesson in track.lessons {
                if !lesson.isCompleted {
                    return lesson.id
                }
            }
        }
        return nil
    }

    func nodeState(for lesson: Lesson, globalIndex: Int) -> LessonNodeState {
        if lesson.isCompleted {
            return .completed
        } else if globalIndex == currentLessonGlobalIndex {
            return .current
        } else {
            return .locked
        }
    }

    /// The Memory journey's gentle sine winding, so both paths feel like one system.
    func xOffset(for globalIndex: Int, containerWidth: CGFloat) -> CGFloat {
        CGFloat(sin(Double(globalIndex) * .pi / 3.0)) * 66
    }

    var body: some View {
        NavigationStack {
            GeometryReader { outerGeo in
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 16)

                            let items = pathItems
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                switch item {
                                case .sectionHeader(let track, let phaseNum, let phaseName):
                                    PathSectionHeader(
                                        track: track,
                                        phaseNumber: phaseNum,
                                        phaseName: phaseName
                                    )
                                    .padding(.horizontal, 16)
                                    .padding(.top, index == 0 ? 8 : 28)
                                    .padding(.bottom, 12)

                                case .lessonNode(let lesson, let globalIdx, let track):
                                    let state = nodeState(for: lesson, globalIndex: globalIdx)
                                    let offset = xOffset(for: globalIdx, containerWidth: effectiveWidth(from: outerGeo.size.width))

                                    // Connector line to previous lesson node
                                    if let prevOffset = previousLessonOffset(before: index, in: items, containerWidth: effectiveWidth(from: outerGeo.size.width)) {
                                        let prevCompleted = isPreviousLessonCompleted(before: index, in: items)
                                        JourneyConnector(
                                            fromX: prevOffset,
                                            toX: offset,
                                            tint: prevCompleted ? track.displayColor
                                                : Color.adaptiveTextSecondary(colorScheme).opacity(0.5)
                                        )
                                    }

                                    PathLessonNode(
                                        lesson: lesson,
                                        track: track,
                                        state: state,
                                        xOffset: offset,
                                        onTap: {
                                            guard state != .locked else {
                                                HapticManager.shared.buttonTap()
                                                return
                                            }
                                            HapticManager.shared.cardFlipEdgeThud()
                                            selectedLesson = lesson
                                            navigateToLesson = true
                                        }
                                    )
                                    .id(lesson.id)
                                }
                            }

                            Spacer().frame(height: 120)
                        }
                        .frame(width: effectiveWidth(from: outerGeo.size.width))
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .onAppear {
                        guard !hasScrolledToCurrentOnAppear else { return }
                        hasScrolledToCurrentOnAppear = true
                        if let currentId = currentLessonId {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeOut(duration: 0.5)) {
                                    proxy.scrollTo(currentId, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Learning Path")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToLesson) {
                if let lesson = selectedLesson {
                    LessonView(lesson: lesson)
                }
            }
        }
    }

    // MARK: - Connector Helpers

    /// Effective container width: full screen on iPhone, middle third on iPad
    func effectiveWidth(from totalWidth: CGFloat) -> CGFloat {
        horizontalSizeClass == .regular ? totalWidth / 3 : totalWidth
    }

    /// Find the x-offset of the previous lesson node (skipping section headers)
    func previousLessonOffset(before index: Int, in items: [PathItem], containerWidth: CGFloat) -> CGFloat? {
        var i = index - 1
        while i >= 0 {
            if case .lessonNode(_, let prevGlobalIdx, _) = items[i] {
                return xOffset(for: prevGlobalIdx, containerWidth: containerWidth)
            }
            i -= 1
        }
        return nil
    }

    /// Check if the previous lesson node is completed
    func isPreviousLessonCompleted(before index: Int, in items: [PathItem]) -> Bool {
        var i = index - 1
        while i >= 0 {
            if case .lessonNode(let lesson, _, _) = items[i] {
                return lesson.isCompleted
            }
            i -= 1
        }
        return false
    }
}

// MARK: - Section Header (banner, like the Memory journey's unit headers)

struct PathSectionHeader: View {
    let track: Track
    let phaseNumber: Int
    let phaseName: String
    @Environment(\.colorScheme) var colorScheme

    private var completed: Int { track.lessons.filter { $0.isCompleted }.count }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: track.icon.isEmpty ? "book.fill" : track.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(track.name.uppercased())
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Phase \(phaseNumber): \(phaseName)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer(minLength: 8)

            Text("\(completed)/\(track.lessons.count)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.18), in: Capsule())
        }
        .padding(16)
        .background(
            LinearGradient(colors: [track.displayColor, track.displayColor.opacity(0.7)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0), lineWidth: 1)
        )
        .shadow(color: track.displayColor.opacity(0.3), radius: 10, y: 5)
    }
}

// MARK: - Lesson Node (extruded token, like the Memory journey's verse nodes)

struct PathLessonNode: View {
    let lesson: Lesson
    let track: Track
    let state: LessonNodeState
    let xOffset: CGFloat
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var pressed = false

    private static let faceDiameter: CGFloat = 72
    private static let depth: CGFloat = 7

    private var tint: Color {
        switch state {
        case .completed: return track.displayColor
        case .current: return Color.reforgedGold
        case .locked: return Color.adaptiveTextSecondary(colorScheme).opacity(0.5)
        }
    }

    private var bevel: Color {
        state == .locked ? Color.adaptiveTextSecondary(colorScheme).opacity(0.3) : tint.practiceBevel()
    }

    private var icon: String {
        switch state {
        case .completed: return "checkmark"
        case .current: return "play.fill"
        case .locked: return "lock.fill"
        }
    }

    private var caption: String {
        switch state {
        case .completed: return "Completed"
        case .current: return "Tap to start"
        case .locked: return "Locked"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            if state == .current {
                startBubble
            }

            Button(action: onTap) {
                ZStack {
                    Circle().fill(bevel)
                        .frame(width: Self.faceDiameter, height: Self.faceDiameter)
                        .offset(y: Self.depth)
                    Circle().fill(tint)
                        .frame(width: Self.faceDiameter, height: Self.faceDiameter)
                        .overlay(Circle().stroke(Color.white.opacity(colorScheme == .dark && state == .completed ? 0.15 : 0), lineWidth: 1))
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .offset(y: pressed ? Self.depth : 0)
                }
                .frame(width: 100, height: 100)
                .contentShape(Circle())
                .scaleEffect(pressed && state != .locked ? 0.965 : 1)
                .shadow(color: tint.opacity(pressed ? 0.1 : (state == .locked ? 0.15 : 0.3)),
                        radius: pressed ? 3 : 8, y: pressed ? 2 : 5)
                .animation(.spring(response: 0.33, dampingFraction: 0.5), value: pressed)
            }
            .buttonStyle(PressReportingStyle(isPressed: $pressed))
            .accessibilityLabel("\(lesson.title), \(caption)")

            VStack(spacing: 1) {
                Text(lesson.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(state == .locked ? Color.adaptiveTextSecondary(colorScheme)
                                     : Color.adaptiveText(colorScheme))
                    .lineLimit(2)
                Text(caption)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .multilineTextAlignment(.center)
            .frame(width: 170)
        }
        .padding(.vertical, 6)
        .offset(x: xOffset)
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
