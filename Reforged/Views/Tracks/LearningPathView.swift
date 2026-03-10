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

    /// S-curve x-offset: repeating [center, left, center, right, center]
    func xOffset(for globalIndex: Int, containerWidth: CGFloat) -> CGFloat {
        let pattern: [CGFloat] = [0, -1, 0, 1, 0]
        let direction = pattern[globalIndex % pattern.count]
        let maxSwing = (containerWidth / 2) - 54
        return direction * maxSwing
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
                                    .padding(.top, index == 0 ? 8 : 28)
                                    .padding(.bottom, 12)

                                case .lessonNode(let lesson, let globalIdx, let track):
                                    let state = nodeState(for: lesson, globalIndex: globalIdx)
                                    let offset = xOffset(for: globalIdx, containerWidth: effectiveWidth(from: outerGeo.size.width))

                                    // Connector line to previous lesson node
                                    if let prevOffset = previousLessonOffset(before: index, in: items, containerWidth: effectiveWidth(from: outerGeo.size.width)) {
                                        let prevCompleted = isPreviousLessonCompleted(before: index, in: items)
                                        PathSegmentLine(
                                            fromXOffset: prevOffset,
                                            toXOffset: offset,
                                            isCompleted: prevCompleted,
                                            trackColor: track.displayColor
                                        )
                                    }

                                    PathLessonNode(
                                        lesson: lesson,
                                        track: track,
                                        state: state,
                                        xOffset: offset
                                    )
                                    .id(lesson.id)
                                    .onTapGesture {
                                        guard state != .locked else { return }
                                        HapticManager.shared.lightImpact()
                                        selectedLesson = lesson
                                        navigateToLesson = true
                                    }
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

// MARK: - Section Header

struct PathSectionHeader: View {
    let track: Track
    let phaseNumber: Int
    let phaseName: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(track.displayColor.opacity(0.3))
                    .frame(height: 2)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [track.displayColor, track.displayColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: track.displayColor.opacity(0.3), radius: 6, y: 3)

                    Image(systemName: track.icon.isEmpty ? "book.fill" : track.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Rectangle()
                    .fill(track.displayColor.opacity(0.3))
                    .frame(height: 2)
            }
            .padding(.horizontal, 32)

            Text(track.name)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("Phase \(phaseNumber): \(phaseName)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(track.displayColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(track.displayColor.opacity(0.1))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Lesson Node

struct PathLessonNode: View {
    let lesson: Lesson
    let track: Track
    let state: LessonNodeState
    let xOffset: CGFloat
    @Environment(\.colorScheme) var colorScheme

    private let nodeSize: CGFloat = 60

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Static glow for current node
                if state == .current {
                    Circle()
                        .fill(Color.reforgedGold.opacity(0.25))
                        .frame(width: nodeSize + 24, height: nodeSize + 24)
                        .blur(radius: 10)
                }

                // Main circle
                circleView

                // Icon
                nodeIcon
            }

            // Show title only on current node
            if state == .current {
                Text(lesson.title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 110)
            }
        }
        .offset(x: xOffset)
    }

    @ViewBuilder
    var circleView: some View {
        switch state {
        case .completed:
            Circle()
                .fill(
                    LinearGradient(
                        colors: [track.displayColor, track.displayColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: track.displayColor.opacity(0.3), radius: 8, y: 4)
        case .current:
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.reforgedGold, Color.reforgedGold.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: Color.reforgedGold.opacity(0.4), radius: 10, y: 4)
        case .locked:
            Circle()
                .fill(Color.adaptiveTextSecondary(colorScheme).opacity(0.25))
                .frame(width: nodeSize, height: nodeSize)
                .overlay(
                    Circle()
                        .stroke(Color.adaptiveTextSecondary(colorScheme).opacity(0.3), lineWidth: 2)
                )
        }
    }

    @ViewBuilder
    var nodeIcon: some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
        case .current:
            Image(systemName: "play.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
        }
    }
}

// MARK: - Connector Line Between Nodes

struct PathSegmentLine: View {
    let fromXOffset: CGFloat
    let toXOffset: CGFloat
    let isCompleted: Bool
    let trackColor: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let centerX = geo.size.width / 2
                let startX = centerX + fromXOffset
                let endX = centerX + toXOffset
                let height = geo.size.height

                path.move(to: CGPoint(x: startX, y: 0))
                let midY = height / 2
                path.addCurve(
                    to: CGPoint(x: endX, y: height),
                    control1: CGPoint(x: startX, y: midY),
                    control2: CGPoint(x: endX, y: midY)
                )
            }
            .stroke(
                isCompleted ? trackColor.opacity(0.5) : Color.adaptiveTextSecondary(colorScheme).opacity(0.25),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
        }
        .frame(height: 28)
    }
}
