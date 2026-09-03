import SwiftUI

/// Reader for Spurgeon's Morning & Evening devotional. Unlike the chapter-reading plans, this
/// presents the day's morning and evening readings directly (from `SpurgeonDevotionalService`)
/// and defaults to today's calendar date. Marking a day read is tracked via
/// `ReadingPlanService`, so it feeds plan progress and the reading streak like any other plan.
struct SpurgeonDevotionalView: View {
    let plan: BibleReadingPlan

    @StateObject private var service = ReadingPlanService.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedDay: Int = SpurgeonDevotionalService.shared.todayDayNumber()

    private var totalDays: Int { SpurgeonDevotionalService.shared.totalDays }
    private var todayDay: Int { SpurgeonDevotionalService.shared.todayDayNumber() }
    private var entry: SpurgeonDay? { SpurgeonDevotionalService.shared.day(selectedDay) }
    private var isComplete: Bool { service.isDayComplete(selectedDay, planId: plan.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                dayNavigator

                if let entry {
                    readingCard(entry.morning, icon: "sunrise.fill")
                    readingCard(entry.evening, icon: "moon.stars.fill")
                    markReadButton
                } else {
                    Text("This reading is unavailable.")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .padding(20)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if selectedDay != todayDay {
                    Button("Today") { withAnimation { selectedDay = todayDay } }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(plan.accentColor)
                }
            }
        }
    }

    // MARK: - Day navigator

    private var dayNavigator: some View {
        HStack {
            navButton(systemName: "chevron.left", enabled: selectedDay > 1) {
                if selectedDay > 1 { selectedDay -= 1 }
            }
            Spacer()
            VStack(spacing: 2) {
                Text(entry?.label ?? "Day \(selectedDay)")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text("Day \(selectedDay) of \(totalDays)")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            Spacer()
            navButton(systemName: "chevron.right", enabled: selectedDay < totalDays) {
                if selectedDay < totalDays { selectedDay += 1 }
            }
        }
        .padding(.horizontal, 4)
    }

    private func navButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation { action() } } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(enabled ? plan.accentColor : Color.adaptiveTextSecondary(colorScheme).opacity(0.4))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.adaptiveCardBackground(colorScheme)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Reading card

    private func readingCard(_ reading: SpurgeonReading, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(plan.accentColor)
                Text(reading.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }

            if !reading.verse.isEmpty {
                Text(reading.verse)
                    .font(.callout.italic())
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            if !reading.reference.isEmpty {
                LinkedScriptureText(text: reading.reference,
                                    font: .caption.weight(.semibold),
                                    baseColor: plan.accentColor,
                                    linkColor: plan.accentColor)
            }

            Divider()

            LinkedScriptureText(text: reading.body,
                                font: .body,
                                baseColor: Color.adaptiveText(colorScheme))
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 8, y: 3)
    }

    // MARK: - Mark read

    private var markReadButton: some View {
        Button {
            let completing = !isComplete
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                service.toggleDay(selectedDay, planId: plan.id)
            }
            if completing { HapticManager.shared.success() }
            else { HapticManager.shared.lightImpact() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                Text(isComplete ? "Read" : "Mark as Read")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(isComplete ? .white : plan.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isComplete ? plan.accentColor : plan.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
