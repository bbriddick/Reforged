import SwiftUI

// MARK: - Prayer Prompt Sheet
//
// A short guided prayer for a moment of temptation. Shared by the Focus &
// Purity Shield launchpad and the Tempted SOS flow.

struct PrayerPromptSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    /// Called on "Amen" in place of plain dismissal (the SOS flow advances its
    /// own stages instead of closing a sheet).
    var onAmen: (() -> Void)? = nil

    private let prompts = [
        "Lord, give me strength to turn away. Set my eyes on what is pure and lovely.",
        "Father, in this moment of temptation, be my refuge and my way of escape.",
        "Jesus, capture my attention. Help me treasure You more than this fleeting pull.",
        "Holy Spirit, renew my mind right now and lead me into what is good.",
        "God, thank You for grace. Help me walk in the freedom You've already given me."
    ]

    // Chosen once on appear so the prayer doesn't re-roll on every re-render.
    @State private var prompt: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hands.and.sparkles.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.reforgedGold)

            Text("A prayer for this moment")
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text(prompt)
                .font(.system(.title3, design: .serif))
                .italic()
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineSpacing(6)
                .padding(.horizontal, 24)

            Spacer()

            Button {
                if let onAmen {
                    onAmen()
                } else {
                    dismiss()
                }
            } label: {
                Text("Amen")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.reforgedGold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear { prompt = prompts.randomElement() ?? prompts[0] }
    }
}
