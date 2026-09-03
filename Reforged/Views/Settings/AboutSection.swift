import SwiftUI

// MARK: - Help & Support View (unified Help, About, and Credits)

struct HelpAndSupportView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) var openURL
    @State private var showWhatsNew = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse = false

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"]            as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: App Info Card
            VStack(spacing: 16) {
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
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
            .padding(.vertical, 10)

            SettingsDivider()

            // MARK: Help & Support Actions
            sectionHeader(icon: "questionmark.circle.fill", color: .blue, title: "Help & Support")

            VStack(spacing: 0) {
                actionRow(icon: "sparkles", iconColor: Color.reforgedGold, title: "What's New", subtitle: "Latest features and improvements") {
                    showWhatsNew = true
                }
                Divider().padding(.leading, 58)
                actionRow(icon: "envelope.fill", iconColor: Color.reforgedNavy, title: "Contact Support", subtitle: "Get help or send feedback") {
                    openSupportEmail()
                }
                Divider().padding(.leading, 58)
                externalRow(icon: "cup.and.saucer.fill", iconColor: Color.reforgedGold, title: "Support Reforged", subtitle: "Buy the developer a coffee") {
                    if let url = URL(string: "https://buymeacoffee.com/reforgedapp") { openURL(url) }
                }
            }
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
            .padding(.vertical, 10)

            SettingsDivider()

            // MARK: Legal
            sectionHeader(icon: "doc.text.fill", color: Color.reforgedNavy, title: "Legal")

            VStack(spacing: 0) {
                actionRow(icon: "lock.shield.fill", iconColor: Color.reforgedNavy, title: "Privacy Policy", subtitle: "How we handle your data") {
                    showPrivacyPolicy = true
                }
                Divider().padding(.leading, 58)
                actionRow(icon: "doc.text.fill", iconColor: Color.reforgedNavy, title: "Terms of Use", subtitle: "Terms and conditions for using Reforged") {
                    showTermsOfUse = true
                }
            }
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
            .padding(.vertical, 10)

            SettingsDivider()

            // MARK: Scripture Quotations
            attributionCard(icon: "book.closed.fill", iconColor: Color.adaptiveNavyText(colorScheme), title: "Scripture Quotations") {
                ForEach(BibleTranslation.allCases) { translation in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(translation.fullName)
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text(translation.attribution)
                            .font(.caption2)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .lineSpacing(3)
                    }
                    if translation != BibleTranslation.allCases.last { Divider() }
                }
            }

            SettingsDivider()

            // MARK: Word Study Data
            attributionCard(icon: "character.book.closed.fill", iconColor: Color.adaptiveNavyText(colorScheme), title: "Word Study Data") {
                attributionEntry(
                    title: "Strong's Exhaustive Concordance",
                    body: "Hebrew and Greek lexicon data is derived from Strong's Exhaustive Concordance by James Strong (1890), which is in the public domain. Digital lexicon data sourced from the Open Scriptures Hebrew/Greek lexicon project (CC BY-SA 4.0)."
                )
                Divider()
                attributionEntry(
                    title: "Brown-Driver-Briggs / Thayer's Lexicon",
                    body: "Enriched word definitions provided by the Brown-Driver-Briggs Hebrew Lexicon and Thayer's Greek Lexicon via the Bolls.life Bible API. These reference works are in the public domain."
                )
            }

            SettingsDivider()

            // MARK: Cross References, Topics & Places
            attributionCard(icon: "arrow.triangle.branch", iconColor: Color.adaptiveNavyText(colorScheme), title: "Cross References, Topics & Places") {
                attributionEntry(
                    title: "Treasury of Scripture Knowledge",
                    body: "Verse cross-reference data is drawn primarily from the Treasury of Scripture Knowledge, provided by openbible.info under a Creative Commons Attribution license (CC BY 4.0)."
                )
                attributionEntry(
                    title: "Topical Bible",
                    body: "Topic-to-verse data, ranked by community votes, is drawn from the openbible.info Topical Bible under a Creative Commons Attribution license (CC BY 4.0)."
                )
                attributionEntry(
                    title: "Bible Geocoding",
                    body: "Place locations in the Bible Atlas are drawn from the openbible.info Bible Geocoding project under a Creative Commons Attribution license (CC BY 4.0)."
                )
            }

            SettingsDivider()

            // MARK: Commentaries & Study Resources
            attributionCard(icon: "text.book.closed.fill", iconColor: Color.adaptiveNavyText(colorScheme), title: "Commentaries & Study Resources") {
                attributionEntry(
                    title: "Public-Domain Works via CrossWire",
                    body: "Commentary, dictionary, lexicon, and topical study data is derived from public-domain works distributed as SWORD modules by the CrossWire Bible Society (crosswire.org): Scofield Reference Notes, Matthew Henry's Commentary, Barnes' Notes, Spurgeon's Treasury of David, Calvin's Commentaries, Easton's Bible Dictionary, the Abbott-Smith Manual Greek Lexicon, Nave's Topical Bible, and Thompson Chain topics."
                )
                attributionEntry(
                    title: "Morning & Evening",
                    body: "The Morning & Evening reading plan is C. H. Spurgeon's public-domain daily devotional, distributed as a SWORD module by CrossWire (crosswire.org) from the Christian Classics Ethereal Library (CCEL)."
                )
            }

            SettingsDivider()

            // MARK: Partner Ministry
            attributionCard(icon: "cross.fill", iconColor: .purple, title: "Partner Ministry", bgOpacity: 0.05, bgColor: .purple) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Southland Christian Ministries")
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Walk Talks podcast episodes are provided in partnership with Southland Christian Camp in Ringgold, LA (southlandcamp.org). Walk Talks is an extension of Southland's ministry, designed to strengthen believers of all ages in their daily walk with God.")
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineSpacing(3)
                    Button {
                        if let url = URL(string: "https://www.southlandcamp.org") { openURL(url) }
                    } label: {
                        Text("southlandcamp.org →")
                            .font(.caption2).fontWeight(.medium)
                            .foregroundStyle(Color.purple)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }

            SettingsDivider()

            // MARK: AI Features
            attributionCard(icon: "sparkles", iconColor: Color.reforgedGold, title: "AI Features", bgOpacity: 0.05, bgColor: Color.reforgedGold) {
                attributionEntry(
                    title: "Google Gemini",
                    body: "Journal prompts, word study summaries, and Smart Search are powered by Google Gemini 2.0 Flash (gemini.google.com). AI-generated content is provided for reflection and study and may be imperfect; always verify insights with Scripture."
                )
            }

            SettingsDivider()

            // MARK: Image Assets
            attributionCard(icon: "photo.fill", iconColor: Color.adaptiveNavyText(colorScheme), title: "Image Assets") {
                attributionEntry(
                    title: "Unsplash",
                    body: "Background images for verse sharing are provided by Unsplash (unsplash.com). Photos are used under the Unsplash License. Individual photographer credits are displayed on each shared image."
                )
                Divider()
                attributionEntry(
                    title: "Flaticon",
                    body: "Sticky-note icon designed by laterunlabs from Flaticon (flaticon.com). Used under the Flaticon Free License."
                )
            }

            // MARK: Footer
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
                    .font(.caption2).fontWeight(.medium)
                    .foregroundStyle(Color.reforgedGold)
            }
            .padding()
            .frame(maxWidth: .infinity)
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

    // MARK: - Helpers

    private func sectionHeader(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func actionRow(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func externalRow(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func attributionCard<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        bgOpacity: Double = 0.05,
        bgColor: Color = Color.reforgedNavy,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgColor.opacity(bgOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.vertical, 10)
    }

    private func attributionEntry(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2).fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text(body)
                .font(.caption2)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .lineSpacing(3)
        }
    }

    private func openSupportEmail() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let email   = "support@reforgedapp.org"
        let subject = "Reforged Support Request"
        let body    = "App Version: \(version)\n\nDescribe your issue or feedback:\n\n"
        let enc     = { (s: String) in s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "" }
        if let url = URL(string: "mailto:\(email)?subject=\(enc(subject))&body=\(enc(body))") {
            openURL(url)
        }
    }

    // MARK: - Legal Content

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

        Scripture quotations are from the ESV® Bible (© 2001 Crossway), KJV (Public Domain), CSB® (© 2017 Holman Bible Publishers), NKJV® (© 1982 Thomas Nelson), NASB® (© 1995 The Lockman Foundation), and Reina-Valera 1960® (© Sociedades Bíblicas en América Latina, 1960; © Renovado Sociedades Bíblicas Unidas, 1988). Used by permission. All rights reserved. Hebrew and Greek word study data is derived from Strong's Exhaustive Concordance (public domain) and the Open Scriptures lexicon project (CC BY-SA 4.0). Enriched definitions from Brown-Driver-Briggs and Thayer's lexicons (public domain) via Bolls.life. Verse cross-reference data is drawn from the Treasury of Scripture Knowledge, topical verse data from the Topical Bible, and place locations from the Bible Geocoding project, all via openbible.info (CC BY 4.0). All other content and features are owned by Reforged.

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
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            HelpAndSupportView()
                .padding()
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}
