import SwiftUI

/// "Pick up where you are" — today's plan reading, or the last position. One tap opens it.
/// `compact` is the single-line form used inside the navigator.
struct ContinueReadingCard: View {
    let target: ContinueTarget
    var compact: Bool = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.reforgedGold.opacity(0.16))
                    Image(systemName: target.isPlan ? "calendar" : "bookmark.fill")
                        .font(.system(size: compact ? 14 : 16, weight: .semibold))
                        .foregroundStyle(Color.reforgedGold)
                }
                .frame(width: compact ? 32 : 40, height: compact ? 32 : 40)

                VStack(alignment: .leading, spacing: 1) {
                    Text(target.title)
                        .font(compact ? .subheadline.weight(.semibold) : .headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)
                    Text(target.subtitle)
                        .font(compact ? .caption : .subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, compact ? 8 : 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: compact ? 12 : ReforgedTheme.cornerRadiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 12 : ReforgedTheme.cornerRadiusLarge, style: .continuous)
                    .stroke(Color.reforgedGold.opacity(0.25), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the Bible here")
    }
}

/// Home's version: watches the plan so the card updates the moment a day is completed.
struct HomeContinueReadingCard: View {
    @StateObject private var planService = ReadingPlanService.shared

    var body: some View {
        // Reading `planService` keeps this view in step with plan progress.
        let _ = planService.completedDaysMap
        if let target = ContinueReading.current() {
            ContinueReadingCard(target: target) {
                HapticManager.shared.buttonTap()
                NotificationCenter.default.post(
                    name: .switchTab, object: nil,
                    userInfo: [AppNotificationUserInfoKey.tab: 2])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    NotificationCenter.default.post(
                        name: .navigateToBibleVerse, object: nil,
                        userInfo: [AppNotificationUserInfoKey.reference: target.reference])
                }
            }
        }
    }
}
