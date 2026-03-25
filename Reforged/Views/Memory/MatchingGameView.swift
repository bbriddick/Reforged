import SwiftUI

// MARK: - Matching Game View

/// A reference-to-verse matching game.
/// Players tap a reference card then the matching verse snippet to make pairs.
/// XP = 50 + (pairs × 25) × streak multiplier
struct MatchingGameView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    // MARK: - Configuration
    private let pairCount: Int

    // MARK: - Game State
    @State private var referenceCards: [MatchCard] = []
    @State private var verseCards: [MatchCard] = []
    @State private var selectedReference: MatchCard? = nil
    @State private var selectedVerse: MatchCard? = nil
    @State private var matchedIDs: Set<String> = []
    @State private var wrongPairIDs: Set<String> = []
    @State private var isGameComplete = false
    @State private var xpEarned = 0
    @State private var errorShakeRef: String? = nil
    @State private var errorShakeVerse: String? = nil

    init(pairCount: Int = 5) {
        self.pairCount = min(max(pairCount, 4), 6)
    }

    // MARK: - XP

    var baseXP: Int { 50 + pairCount * 25 }

    var streakMultiplier: Double {
        if appState.user.streak >= 30 { return 2.0 }
        if appState.user.streak >= 7  { return 1.5 }
        return 1.0
    }

    var displayMultiplier: String {
        streakMultiplier == 1.0 ? "" : "×\(streakMultiplier == 2.0 ? "2" : "1.5")"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.adaptiveBackground(colorScheme).ignoresSafeArea()

                if isGameComplete {
                    completionView
                } else {
                    gameplayView
                }
            }
            .navigationTitle("Matching Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear { setupGame() }
    }

    // MARK: - Gameplay

    private var gameplayView: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressBar
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Instructions
            Text("Tap a reference, then its matching verse")
                .font(Font.custom("Roboto", size: 13))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .padding(.bottom, 12)

            // Cards layout
            GeometryReader { geo in
                HStack(alignment: .top, spacing: 12) {
                    // References column
                    VStack(spacing: 10) {
                        ForEach(referenceCards) { card in
                            referenceCardView(card)
                        }
                    }
                    .frame(width: (geo.size.width - 44) / 2)

                    // Verse snippets column
                    VStack(spacing: 10) {
                        ForEach(verseCards) { card in
                            verseCardView(card)
                        }
                    }
                    .frame(width: (geo.size.width - 44) / 2)
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(matchedIDs.count / 2) / \(pairCount) matched")
                    .font(Font.custom("Roboto", size: 13))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Spacer()
                Text("\(baseXP) XP\(displayMultiplier.isEmpty ? "" : " \(displayMultiplier)")")
                    .font(Font.custom("Roboto", size: 13).bold())
                    .foregroundStyle(Color.reforgedGold)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.adaptiveBorder(colorScheme))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.reforgedGold)
                        .frame(width: geo.size.width * CGFloat(matchedIDs.count / 2) / CGFloat(pairCount), height: 6)
                        .animation(.spring(response: 0.4), value: matchedIDs.count)
                }
            }
            .frame(height: 6)
        }
    }

    @ViewBuilder
    private func referenceCardView(_ card: MatchCard) -> some View {
        let isMatched = matchedIDs.contains(card.pairID)
        let isSelected = selectedReference?.id == card.id
        let isWrong = wrongPairIDs.contains(card.id)

        Button {
            handleReferenceTap(card)
        } label: {
            Text(card.text)
                .font(Font.custom("Roboto", size: 14).bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(isMatched ? .white : isSelected ? .white : Color.adaptiveText(colorScheme))
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isMatched ? Color.green.opacity(0.7) :
                              isWrong   ? Color.red.opacity(0.25) :
                              isSelected ? Color.reforgedNavy :
                              Color.adaptiveCardBackground(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isMatched ? Color.green :
                                isWrong   ? Color.red :
                                isSelected ? Color.reforgedNavy :
                                Color.adaptiveBorder(colorScheme), lineWidth: isSelected ? 2 : 1)
                )
        }
        .disabled(isMatched)
        .modifier(ShakeEffect(trigger: errorShakeRef == card.id))
        .animation(.easeInOut(duration: 0.2), value: isMatched)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private func verseCardView(_ card: MatchCard) -> some View {
        let isMatched = matchedIDs.contains(card.pairID)
        let isSelected = selectedVerse?.id == card.id
        let isWrong = wrongPairIDs.contains(card.id)

        Button {
            handleVerseTap(card)
        } label: {
            Text(card.text)
                .font(Font.custom("LibreBaskerville-Regular", size: 12))
                .multilineTextAlignment(.leading)
                .foregroundStyle(isMatched ? .white : isSelected ? .white : Color.adaptiveText(colorScheme))
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isMatched ? Color.green.opacity(0.7) :
                              isWrong   ? Color.red.opacity(0.25) :
                              isSelected ? Color.reforgedGold.opacity(0.8) :
                              Color.adaptiveCardBackground(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isMatched ? Color.green :
                                isWrong   ? Color.red :
                                isSelected ? Color.reforgedGold :
                                Color.adaptiveBorder(colorScheme), lineWidth: isSelected ? 2 : 1)
                )
        }
        .disabled(isMatched)
        .modifier(ShakeEffect(trigger: errorShakeVerse == card.id))
        .animation(.easeInOut(duration: 0.2), value: isMatched)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.reforgedGold)
                .scaleEffect(1.0)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {}
                }

            VStack(spacing: 8) {
                Text("All Matched!")
                    .font(Font.custom("LibreBaskerville-Regular", size: 28).bold())
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text("\(pairCount) pairs · \(pairCount == 4 ? "150" : pairCount == 5 ? "175" : "200") base XP")
                    .font(Font.custom("Roboto", size: 14))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            // XP earned card
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.reforgedGold)
                    Text("+\(xpEarned) XP earned")
                        .font(Font.custom("Roboto", size: 20).bold())
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }

                if streakMultiplier > 1.0 {
                    Text("\(appState.user.streak)-day streak · \(displayMultiplier) multiplier applied")
                        .font(Font.custom("Roboto", size: 13))
                        .foregroundStyle(Color.reforgedGold)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(Font.custom("Roboto", size: 16).bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.reforgedNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Button("Play Again") {
                setupGame()
                isGameComplete = false
            }
            .font(Font.custom("Roboto", size: 15))
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            Spacer()
        }
    }

    // MARK: - Game Logic

    private func handleReferenceTap(_ card: MatchCard) {
        guard !matchedIDs.contains(card.pairID) else { return }
        HapticManager.shared.lightImpact()
        selectedReference = card
        checkForMatch()
    }

    private func handleVerseTap(_ card: MatchCard) {
        guard !matchedIDs.contains(card.pairID) else { return }
        HapticManager.shared.lightImpact()
        selectedVerse = card
        checkForMatch()
    }

    private func checkForMatch() {
        guard let ref = selectedReference, let verse = selectedVerse else { return }

        if ref.pairID == verse.pairID {
            // Correct match
            HapticManager.shared.mediumImpact()
            _ = withAnimation(.spring(response: 0.3)) {
                matchedIDs.insert(ref.pairID)
            }
            selectedReference = nil
            selectedVerse = nil

            if matchedIDs.count == pairCount {
                finalizeGame()
            }
        } else {
            // Wrong match — flash red then clear
            errorShakeRef = ref.id
            errorShakeVerse = verse.id
            HapticManager.shared.errorFeedback()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { wrongPairIDs.insert(ref.id); wrongPairIDs.insert(verse.id) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation {
                        wrongPairIDs.remove(ref.id)
                        wrongPairIDs.remove(verse.id)
                        errorShakeRef = nil
                        errorShakeVerse = nil
                        selectedReference = nil
                        selectedVerse = nil
                    }
                }
            }
        }
    }

    private func finalizeGame() {
        let raw = 50 + pairCount * 25
        xpEarned = Int(Double(raw) * streakMultiplier)
        appState.addXP(raw, source: "matching_game")
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
            isGameComplete = true
        }
    }

    // MARK: - Setup

    private func setupGame() {
        matchedIDs = []
        wrongPairIDs = []
        selectedReference = nil
        selectedVerse = nil

        let pool = buildVersePool()
        let selected = Array(pool.shuffled().prefix(pairCount))

        let refCards = selected.map { MatchCard(pairID: $0.id, text: $0.reference, isReference: true) }
        let snippets = selected.map { v -> MatchCard in
            let snippet = snippetText(from: v.text, maxWords: 8)
            return MatchCard(pairID: v.id, text: snippet, isReference: false)
        }

        referenceCards = refCards.shuffled()
        verseCards     = snippets.shuffled()
    }

    private func buildVersePool() -> [VerseItem] {
        var pool: [VerseItem] = []

        // User's memory verses first
        for mv in appState.memoryVerses where !mv.text.isEmpty {
            pool.append(VerseItem(id: mv.reference, reference: mv.reference, text: mv.text))
        }

        // Pad with suggested verses if needed
        if pool.count < pairCount {
            let needed = pairCount * 3
            let suggested = SuggestedVersesData.allVerses
                .filter { sv in !pool.contains { $0.reference == sv.reference } }
                .shuffled()
                .prefix(needed)
            for sv in suggested {
                pool.append(VerseItem(id: sv.reference, reference: sv.reference, text: sv.text))
            }
        }

        return pool
    }

    private func snippetText(from text: String, maxWords: Int) -> String {
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if words.count <= maxWords { return text }
        return words.prefix(maxWords).joined(separator: " ") + "…"
    }
}

// MARK: - Supporting Types

private struct MatchCard: Identifiable {
    let id = UUID().uuidString
    let pairID: String
    let text: String
    let isReference: Bool
}

private struct VerseItem {
    let id: String
    let reference: String
    let text: String
}

// MARK: - Shake Effect Modifier

struct ShakeEffect: ViewModifier {
    let trigger: Bool
    @State private var shaking = false

    func body(content: Content) -> some View {
        content
            .offset(x: shaking ? -6 : 0)
            .onChange(of: trigger) { newVal in
                guard newVal else { return }
                withAnimation(.easeInOut(duration: 0.07).repeatCount(4, autoreverses: true)) {
                    shaking = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shaking = false }
            }
    }
}

// MARK: - HapticManager extension (error)

extension HapticManager {
    func errorFeedback() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.error)
    }
}
