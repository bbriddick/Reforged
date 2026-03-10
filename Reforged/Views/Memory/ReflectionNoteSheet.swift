import SwiftUI

struct ReflectionNoteSheet: View {
    let verse: MemoryVerse
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    @State private var noteText: String

    init(verse: MemoryVerse) {
        self.verse = verse
        _noteText = State(initialValue: verse.reflectionNote ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Verse preview header
                VStack(spacing: 6) {
                    Text(verse.reference)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))

                    Text("\"\(verse.text)\"")
                        .font(.caption)
                        .italic()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(3)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.adaptiveCardBackground(colorScheme))

                Divider()

                // Prompt
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Color.reforgedGold)
                            .font(.subheadline)
                        Text("Why does this verse matter to you?")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }

                    Text("Personal meaning creates stronger emotional memory. Write what this verse means in your own life.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .padding()

                // Text editor
                TextEditor(text: $noteText)
                    .font(.body)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 140)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .overlay(alignment: .topLeading) {
                        if noteText.isEmpty {
                            Text("e.g. This verse helped me through a difficult season...")
                                .font(.body)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
                                .padding(.horizontal, 28)
                                .padding(.top, 20)
                                .allowsHitTesting(false)
                        }
                    }

                Spacer()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Personal Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNote()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveNote() {
        guard let index = appState.memoryVerses.firstIndex(where: { $0.id == verse.id }) else { return }
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        appState.memoryVerses[index].reflectionNote = trimmed.isEmpty ? nil : trimmed
    }
}
