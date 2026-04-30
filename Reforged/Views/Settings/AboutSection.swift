import SwiftUI

struct AboutSection: View {
    @Environment(\.colorScheme) var colorScheme

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            // App Info Card
            VStack(spacing: 16) {
                // App Icon and Name
                VStack(spacing: 12) {
                    Image("AppIconImage")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color.reforgedCharcoal.opacity(0.3), radius: 8, y: 4)

                    VStack(spacing: 4) {
                        Text("Reforged")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Text("Version \(appVersion)")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }

                // Mission Statement
                VStack(spacing: 8) {
                    Text("Our Mission")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedGold)

                    Text("Reforged is a Scripture learning app designed to help you grow in your knowledge of God's Word through interactive lessons, doctrine tracks, and Scripture memory. Our mission is to support your personal renewal and transformation through faithful engagement with the Bible.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
            )
            .padding(.vertical, 10)

            SettingsDivider()

            // Scripture Quotations
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))

                    Text("Scripture Quotations")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }

                ForEach(BibleTranslation.allCases) { translation in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(translation.fullName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Text(translation.attribution)
                            .font(.caption2)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .lineSpacing(3)
                    }

                    if translation != BibleTranslation.allCases.last {
                        Divider()
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.reforgedNavy.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.vertical, 10)

            SettingsDivider()

            // Word Study Data
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))

                    Text("Word Study Data")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Strong's Exhaustive Concordance")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text("Hebrew and Greek lexicon data is derived from Strong's Exhaustive Concordance by James Strong (1890), which is in the public domain. Digital lexicon data sourced from the Open Scriptures Hebrew/Greek lexicon project (CC BY-SA 4.0).")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineSpacing(3)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Brown-Driver-Briggs / Thayer's Lexicon")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text("Enriched word definitions provided by the Brown-Driver-Briggs Hebrew Lexicon and Thayer's Greek Lexicon via the Bolls.life Bible API. These reference works are in the public domain.")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineSpacing(3)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.reforgedNavy.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.vertical, 10)

            SettingsDivider()

            // Partner Ministry
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "cross.fill")
                        .font(.caption)
                        .foregroundStyle(Color.purple)

                    Text("Partner Ministry")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Southland Christian Ministries")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text("Walk Talks podcast episodes are provided in partnership with Southland Christian Camp in Ringgold, LA (southlandcamp.org). Walk Talks is an extension of Southland's ministry, designed to strengthen believers of all ages in their daily walk with God.")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineSpacing(3)

                    Button {
                        UIApplication.shared.open(URL(string: "https://www.southlandcamp.org")!)
                    } label: {
                        Text("southlandcamp.org →")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.purple)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.vertical, 10)

            SettingsDivider()

            // AI Features
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(Color.reforgedGold)

                    Text("AI Features")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Google Gemini")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text("Journal prompts, word study summaries, and Smart Search are powered by Google Gemini 2.0 Flash (gemini.google.com). AI-generated content is provided for reflection and study and may be imperfect; always verify insights with Scripture.")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineSpacing(3)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.reforgedGold.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.vertical, 10)

            SettingsDivider()

            // Image Assets
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))

                    Text("Image Assets")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Unsplash")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text("Background images for verse sharing are provided by Unsplash (unsplash.com). Photos are used under the Unsplash License. Individual photographer credits are displayed on each shared image.")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineSpacing(3)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Flaticon")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text("Sticky-note icon designed by laterunlabs from Flaticon (flaticon.com). Used under the Flaticon Free License.")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineSpacing(3)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.reforgedNavy.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.vertical, 10)

            // Made with love
            VStack(spacing: 8) {
                Text("Made with ❤️ for the glory of God")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                Text("\"All Scripture is breathed out by God and profitable for teaching, for reproof, for correction, and for training in righteousness.\"")
                    .font(.caption2)
                    .italic()
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.center)

                Text("— 2 Timothy 3:16")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.reforgedGold)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Help & Support View

struct HelpAndSupportView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var showWhatsNew = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse = false

    var body: some View {
        VStack(spacing: 0) {
            listRow(icon: "sparkles", iconColor: Color.reforgedGold, title: "What's New", subtitle: "See the latest features and improvements") {
                showWhatsNew = true
            }
            Divider().padding(.leading, 62)
            listRow(icon: "lock.shield.fill", iconColor: Color.reforgedNavy, title: "Privacy Policy", subtitle: "How we handle your data") {
                showPrivacyPolicy = true
            }
            Divider().padding(.leading, 62)
            listRow(icon: "doc.text.fill", iconColor: Color.reforgedNavy, title: "Terms of Use", subtitle: "Terms and conditions for using Reforged") {
                showTermsOfUse = true
            }
            Divider().padding(.leading, 62)
            listRow(icon: "envelope.fill", iconColor: Color.reforgedNavy, title: "Contact Support", subtitle: "Get help or send feedback") {
                openSupportEmail()
            }
            Divider().padding(.leading, 62)
            externalRow(emoji: "☕", iconColor: Color.reforgedGold, title: "Support Reforged", subtitle: "Buy the developer a coffee") {
                UIApplication.shared.open(URL(string: "https://buymeacoffee.com/reforgedapp")!)
            }
            Divider().padding(.leading, 62)
            NavigationLink(destination: ScrollView { AboutSection().padding() }
                .navigationTitle("About")
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            ) {
                navRowLabel(icon: "info.circle.fill", iconColor: Color.gray, title: "About", subtitle: "Attributions, version info, and more")
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView(isPresented: $showWhatsNew)
                .environmentObject(SettingsManager.shared)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PolicyView(title: "Privacy Policy", content: privacyPolicyContent)
        }
        .sheet(isPresented: $showTermsOfUse) {
            PolicyView(title: "Terms of Use", content: termsOfUseContent)
        }
    }

    @ViewBuilder
    private func listRow(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            navRowLabel(icon: icon, iconColor: iconColor, title: title, subtitle: subtitle, chevron: "chevron.right")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func externalRow(emoji: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Text(emoji).font(.system(size: 16))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func navRowLabel(icon: String, iconColor: Color, title: String, subtitle: String, chevron: String = "chevron.right") -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            Spacer()
            Image(systemName: chevron)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func openSupportEmail() {
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
        let email = "support@reforgedapp.org"
        let subject = "Reforged Support Request"
        let body = "App Version: \(appVersion)\n\nDescribe your issue or feedback:\n\n"
        let enc = { (s: String) in s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "" }
        if let url = URL(string: "mailto:\(email)?subject=\(enc(subject))&body=\(enc(body))") {
            UIApplication.shared.open(url)
        }
    }

    private var privacyPolicyContent: String {
        """
        Privacy Policy for Reforged

        Last updated: February 2025

        1. Information We Collect

        Reforged collects the following information to provide and improve our services:
        • Account information (email address, name)
        • Bible reading progress and bookmarks
        • Memory verse progress and review history
        • Learning track progress
        • App settings and preferences

        2. How We Use Your Information

        We use your information to:
        • Sync your progress across devices
        • Provide personalized recommendations
        • Send optional reminders and notifications
        • Improve our app and services

        3. Data Storage and Security

        Your data is securely stored using industry-standard encryption. We use Apple's iCloud and CloudKit for backend services, which provides enterprise-grade security.

        4. Data Sharing

        We do not sell, trade, or rent your personal information to third parties. We may share anonymized, aggregated data for analytics purposes.

        5. Your Rights

        You have the right to:
        • Access your personal data
        • Request deletion of your data
        • Export your data
        • Opt out of marketing communications

        6. Contact Us

        If you have questions about this Privacy Policy, please contact us at support@reforgedapp.org.
        """
    }

    private var termsOfUseContent: String {
        """
        Terms of Use for Reforged

        Last updated: February 2025

        1. Acceptance of Terms

        By downloading or using Reforged, you agree to be bound by these Terms of Use. If you do not agree to these terms, please do not use the app.

        2. Description of Service

        Reforged is a Bible study and Scripture memorization app. We provide access to multiple Bible translations including the ESV, KJV, CSB, NKJV, NASB, and RVR1960 under license from their respective publishers.

        3. User Accounts

        You may create an account to sync your progress across devices. You are responsible for maintaining the confidentiality of your account credentials.

        4. Acceptable Use

        You agree to use Reforged only for lawful purposes and in accordance with these Terms. You agree not to:
        • Use the app in any way that violates applicable laws
        • Attempt to gain unauthorized access to our systems
        • Interfere with the proper working of the app

        5. Intellectual Property

        Scripture quotations are from the ESV® Bible (© 2001 Crossway), KJV (Public Domain), CSB® (© 2017 Holman Bible Publishers), NKJV® (© 1982 Thomas Nelson), NASB® (© 1995 The Lockman Foundation), and Reina-Valera 1960® (© Sociedades Bíblicas en América Latina, 1960; © Renovado Sociedades Bíblicas Unidas, 1988). Used by permission. All rights reserved. Hebrew and Greek word study data is derived from Strong's Exhaustive Concordance (public domain) and the Open Scriptures lexicon project (CC BY-SA 4.0). Enriched definitions from Brown-Driver-Briggs and Thayer's lexicons (public domain) via Bolls.life. All other content and features are owned by Reforged.

        6. Disclaimer of Warranties

        Reforged is provided "as is" without warranties of any kind, either express or implied.

        7. Limitation of Liability

        In no event shall Reforged be liable for any indirect, incidental, special, or consequential damages.

        8. Changes to Terms

        We may modify these Terms at any time. Continued use of the app after changes constitutes acceptance of the new Terms.

        9. Contact Us

        If you have questions about these Terms, please contact us at support@reforgedapp.org.
        """
    }
}

// MARK: - Policy View

struct PolicyView: View {
    let title: String
    let content: String
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineSpacing(4)
                    .padding()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        AboutSection()
            .padding()
    }
}
