import SwiftUI

struct AISettingsSection: View {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showCustomKeyField = false
    @State private var showAPIKey = false

    /// True when the user has a non-empty personal key saved.
    private var hasPersonalKey: Bool {
        !settings.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasManagedService: Bool {
        settings.hasManagedGeminiService
    }

    var body: some View {
        VStack(spacing: 0) {
            // Master toggle
            SettingsToggleRow(
                title: "Enable AI Features",
                subtitle: "Journal prompts, word study summaries, and Smart Search powered by Google Gemini",
                isOn: $settings.aiEnabled
            )

            if settings.aiEnabled {
                SettingsDivider()

                // Status row — always visible, shows whether AI is configured
                HStack(spacing: 8) {
                    Image(systemName: hasPersonalKey ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle((hasPersonalKey || hasManagedService) ? Color.green : Color.orange)
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text(statusDescription)
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    Spacer()
                }
                .padding(.vertical, 12)

                SettingsDivider()

                // Advanced: personal key override
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCustomKeyField.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Use your own API key")
                                .font(.subheadline)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Spacer()
                            Image(systemName: showCustomKeyField ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        .padding(.vertical, 12)
                    }

                    if showCustomKeyField {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Group {
                                    if showAPIKey {
                                        TextField("Paste your Gemini API key", text: $settings.geminiAPIKey)
                                    } else {
                                        SecureField("Paste your Gemini API key", text: $settings.geminiAPIKey)
                                    }
                                }
                                .font(.subheadline)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                                Button {
                                    showAPIKey.toggle()
                                } label: {
                                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                        .font(.caption)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                }
                            }
                            .padding(12)
                            .background(Color.adaptiveBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                            )

                            Text(hasManagedService
                                 ? "Optional override. Your key is stored only on this device and will be used instead of the managed AI service. Get a free key at aistudio.google.com."
                                 : "Required for AI features. Your key is stored only on this device. Get a free key at aistudio.google.com.")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                .lineSpacing(3)

                            if hasPersonalKey {
                                Button {
                                    settings.geminiAPIKey = ""
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle")
                                        Text("Clear personal key")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(Color.red.opacity(0.8))
                                }
                            }
                        }
                        .padding(.bottom, 12)
                    }
                }

                SettingsDivider()

                // Feature overview
                VStack(alignment: .leading, spacing: 12) {
                    Text("What AI Powers")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    featureRow(
                        icon: "book.closed.fill",
                        title: "Verse Journal Prompts",
                        description: "Tap 'Journal' on any selected verse to get 6 AI-generated reflection prompts specific to that passage."
                    )

                    Divider()

                    featureRow(
                        icon: "character.book.closed.fill",
                        title: "Word Study Summary",
                        description: "A concise AI summary appears at the top of every word study card, synthesizing the word's meaning and theological significance."
                    )

                    Divider()

                    featureRow(
                        icon: "sparkles",
                        title: "Smart Search",
                        description: "Switch to Smart mode in the search panel and ask natural-language questions like 'verses about forgiveness' or 'the Greek word for love'."
                    )
                }
                .padding(.vertical, 12)

                SettingsDivider()

                Text("AI responses are generated by Gemini and may be imperfect. Always verify insights with Scripture.")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineSpacing(3)
                    .padding(.vertical, 8)
            }
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.reforgedGold)
                .frame(width: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineSpacing(2)
            }
        }
    }

    private var statusTitle: String {
        if hasPersonalKey { return "Using your personal API key" }
        if hasManagedService { return "AI ready through secure server" }
        return "AI setup required"
    }

    private var statusDescription: String {
        if hasPersonalKey {
            return "AI features will use the Gemini key stored on this device."
        }
        if hasManagedService {
            return "Reforged is configured to use a secure Supabase-hosted Gemini proxy."
        }
        return "Add your Gemini API key below or configure the managed AI service to enable journal prompts, word study summaries, and Smart Search."
    }
}
