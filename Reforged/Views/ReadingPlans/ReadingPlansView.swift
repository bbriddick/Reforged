import SwiftUI

// MARK: - Reading Plans Hub

struct ReadingPlansView: View {
    @StateObject private var service = ReadingPlanService.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                ForEach(BibleReadingPlans.all) { plan in
                    NavigationLink(destination: ReadingPlanDetailView(plan: plan)) {
                        ReadingPlanCard(plan: plan)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Reading Plans")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Plan Card

private struct ReadingPlanCard: View {
    let plan: BibleReadingPlan
    @StateObject private var service = ReadingPlanService.shared
    @Environment(\.colorScheme) var colorScheme

    private var progress: Double { service.progress(for: plan.id) }
    private var started: Bool { service.hasStarted(plan.id) }
    private var finished: Bool { service.isComplete(plan.id) }
    private var currentDay: Int { service.currentDay(for: plan.id) }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(plan.accentColor.opacity(0.15))
                    .frame(width: 54, height: 54)
                Image(systemName: plan.iconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(plan.accentColor)
            }

            // Text + progress
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(plan.name)
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)
                    Spacer()
                    if finished {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(plan.accentColor)
                    }
                }

                Text(plan.description)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if started && !finished {
                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.adaptiveChipBackground(colorScheme))
                                    .frame(height: 5)
                                Capsule()
                                    .fill(plan.accentColor)
                                    .frame(width: max(0, geo.size.width * progress), height: 5)
                            }
                        }
                        .frame(height: 5)

                        Text("Day \(currentDay)/\(plan.totalDays)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(plan.accentColor)
                            .fixedSize()
                    }
                } else if !started {
                    Text("\(plan.totalDays) days · \(plan.readingDays) readings")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                } else {
                    // finished
                    Text("Completed · \(plan.totalDays) days")
                        .font(.caption2)
                        .foregroundStyle(plan.accentColor)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, y: 3)
    }
}

// MARK: - Plan Detail View

struct ReadingPlanDetailView: View {
    let plan: BibleReadingPlan
    @StateObject private var service = ReadingPlanService.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var scrollToCurrentDay = false

    private var progress: Double { service.progress(for: plan.id) }
    private var currentDay: Int { service.currentDay(for: plan.id) }
    private var completedCount: Int { service.completedDays(for: plan.id).count }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    planHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 16)

                    dayList
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .onAppear {
                if service.hasStarted(plan.id) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            proxy.scrollTo("day-\(plan.id)-\(currentDay)", anchor: .center)
                        }
                    }
                }
            }
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private var planHeader: some View {
        VStack(spacing: 14) {
            // Progress circle + stats
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(plan.accentColor.opacity(0.2), lineWidth: 6)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(plan.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.5), value: progress)
                    VStack(spacing: 0) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.description)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        statPill(label: "\(completedCount) read", color: plan.accentColor)
                        statPill(label: "\(plan.totalDays - completedCount) left",
                                 color: Color.adaptiveTextSecondary(colorScheme))
                    }
                }
            }
            .padding(16)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 8, y: 3)
        }
    }

    private func statPill(label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: Day list

    private var dayList: some View {
        LazyVStack(spacing: 10) {
            ForEach(plan.entries) { entry in
                PlanDayRow(entry: entry,
                           plan: plan,
                           isCurrent: entry.day == currentDay && !service.isComplete(plan.id))
                    .id("day-\(plan.id)-\(entry.day)")
                    .onTapGesture {
                        openBibleAndMark(entry: entry)
                    }
            }
        }
    }

    // MARK: Navigation

    private func openBibleAndMark(entry: BiblePlanEntry) {
        guard let navRef = entry.navRef else { return }
        // Do NOT mark complete here — completion fires automatically once all
        // required chapters are marked as read in BibleView (via notifyChapterRead),
        // or the user can toggle the checkmark manually.
        appState.queueBibleVerseNavigation(navRef)
        NotificationCenter.default.post(
            name: .switchTab,
            object: nil,
            userInfo: ["tab": 2]
        )
    }
}

// MARK: - Plan Day Row

private struct PlanDayRow: View {
    let entry: BiblePlanEntry
    let plan: BibleReadingPlan
    let isCurrent: Bool
    @StateObject private var service = ReadingPlanService.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    private var isComplete: Bool { service.isDayComplete(entry.day, planId: plan.id) }

    var body: some View {
        HStack(spacing: 12) {
            // Day badge
            dayBadge

            // Content
            VStack(alignment: .leading, spacing: 3) {
                if entry.isReflectionDay {
                    Text(entry.scriptureReference)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                } else {
                    Text(entry.scriptureReference)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isComplete
                                         ? Color.adaptiveTextSecondary(colorScheme)
                                         : Color.adaptiveText(colorScheme))
                }
                Text(entry.refinementPrompt)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            // Right side: open button or checkmark
            if entry.isReflectionDay {
                // Toggle only
                checkmarkButton
            } else if isComplete {
                checkmarkButton
            } else {
                // Navigate to Bible
                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Open")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(plan.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(plan.accentColor.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isCurrent ? plan.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isCurrent {
            plan.accentColor.opacity(colorScheme == .dark ? 0.12 : 0.06)
        } else {
            Color.adaptiveCardBackground(colorScheme)
        }
    }

    private var dayBadge: some View {
        ZStack {
            Circle()
                .fill(isComplete
                      ? plan.accentColor.opacity(0.2)
                      : (isCurrent ? plan.accentColor.opacity(0.15) : Color.adaptiveChipBackground(colorScheme)))
                .frame(width: 36, height: 36)
            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(plan.accentColor)
            } else {
                Text("\(entry.day)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isCurrent ? plan.accentColor : Color.adaptiveTextSecondary(colorScheme))
            }
        }
    }

    private var checkmarkButton: some View {
        Button {
            service.toggleDay(entry.day, planId: plan.id)
        } label: {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isComplete ? plan.accentColor : Color.adaptiveTextSecondary(colorScheme).opacity(0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReadingPlansView()
            .environmentObject(AppState.shared)
    }
}
