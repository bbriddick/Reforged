import SwiftUI

// MARK: - Strong's Definition Sheet

/// Bottom sheet showing Hebrew/Greek word study results for a tapped word.
///
/// Reading order: the word itself (hero) -> what it means (one entry card: definition, how the
/// KJV renders it, the long lexicon entry) -> an AI note -> dictionaries -> where to go next.
struct StrongsDefinitionSheet: View {
    let result: WordLookupResult
    /// When docked in the iPad tools rail (not a sheet) the environment dismiss is a no-op, so the
    /// host passes an explicit close; `onBack` returns to the panel this was opened from.
    var onClose: (() -> Void)? = nil
    var onBack: (() -> Void)? = nil
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @ObservedObject private var settings = SettingsManager.shared

    @State private var aiSummary: String? = nil
    @State private var aiSummaryLoading = false
    @State private var aiSummaryError: String? = nil
    @State private var expandedWorks: Set<String> = []
    @State private var lexiconExpanded = false

    @ScaledMetric(relativeTo: .largeTitle) private var originalSize: CGFloat = 40

    private var eastonEntry: ReferenceEntry? {
        ReferenceWorkService.shared.eastonEntry(for: result.tappedWord)
    }

    private var greekEntry: ReferenceEntry? {
        guard !result.isHebrew else { return nil }
        let lemma = result.lexicalForm.isEmpty ? result.originalWord : result.lexicalForm
        return ReferenceWorkService.shared.greekEntry(forLemma: lemma)
            ?? ReferenceWorkService.shared.greekEntry(forLemma: result.originalWord)
    }

    /// The Abbott-Smith entry is already the lexicon section when the study database supplied it,
    /// so it is not repeated under Dictionaries & Topics.
    private var referenceEntries: [ReferenceEntry] {
        let abbottShownAbove = result.detailedSourceLabel == "Abbott-Smith Lexicon"
        let greek = abbottShownAbove ? nil : greekEntry
        return [eastonEntry, greek].compactMap { $0 }
            + ReferenceWorkService.shared.topicalEntries(for: result.tappedWord)
    }

    private var hasEntry: Bool { result.isFromAPI }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    if hasEntry {
                        entryCard
                        if settings.aiEnabled {
                            aiSummaryCard
                        }
                        if settings.showOriginalLanguageText {
                            originalLanguageCard
                        }
                    } else if result.strongsEntries.isEmpty {
                        noResultsView
                    } else {
                        // Fallback: bundled dictionary entries
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(result.strongsEntries) { entry in
                                FallbackEntryCard(entry: entry, colorScheme: colorScheme)
                            }
                            matchQualityBadge(isExact: false)
                        }
                    }

                    if !referenceEntries.isEmpty {
                        referenceWorksSection
                    }

                    searchActionsSection

                    attributionSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Color.adaptiveBackground(colorScheme))
            .navigationTitle("Word Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onBack {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            onBack()
                        } label: {
                            Label("Verse Study", systemImage: "chevron.backward")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onClose?() ?? dismiss() }
                        .foregroundStyle(Color.reforgedGold)
                }
            }
        }
    }

    // MARK: - Hero

    /// The word itself, on the page rather than in a card: the original word as used in this
    /// verse leads; its dictionary form, sound, grammar and match quality hang off it.
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quiet metadata: language, Strong's number, where it was tapped.
            HStack(spacing: 8) {
                Text(languageLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                if hasEntry && !result.strongsNumber.isEmpty {
                    Text(result.strongsNumber)
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.adaptiveNavyText(colorScheme).opacity(0.1))
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 8)

                Text(result.verseReference)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.reforgedGold)
            }

            if hasEntry && !result.originalWord.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.originalWord)
                        .font(originalFont)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    if tappedWordIsEnglish {
                        Text("\u{201C}\(result.tappedWord)\u{201D} in this verse")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }

                lexemeLine
                grammarLine
                interlinearMatchBadge
            } else {
                Text("\u{201C}\(result.tappedWord)\u{201D}")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Ezra SIL sets pointed Hebrew (vowels and accents) properly; the system face does not.
    private var originalFont: Font {
        result.isHebrew
            ? .custom("Ezra SIL", size: originalSize * 1.15)
            : .system(size: originalSize, weight: .semibold)
    }

    private var lemmaFont: Font {
        result.isHebrew ? .custom("Ezra SIL", size: 24) : .title3.weight(.medium)
    }

    /// False when the "tapped word" is just the original word again (a study chip), where an
    /// English echo would only repeat the headline.
    private var tappedWordIsEnglish: Bool {
        func fold(_ s: String) -> String {
            s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        }
        return fold(result.tappedWord) != fold(result.originalWord)
    }

    private var languageLabel: String {
        result.isAramaic ? "Aramaic" : (result.isHebrew ? "Hebrew" : "Greek")
    }

    /// Dictionary form, transliteration and pronunciation as one line.
    @ViewBuilder
    private var lexemeLine: some View {
        let showLemma = !result.lexicalForm.isEmpty && result.lexicalForm != result.originalWord
        if showLemma || !result.transliteration.isEmpty || !result.pronunciation.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if showLemma {
                    Text(result.lexicalForm)
                        .font(lemmaFont)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }
                if !result.transliteration.isEmpty {
                    Text(result.transliteration)
                        .font(.subheadline.italic())
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                if !result.pronunciation.isEmpty {
                    Text("(\(result.pronunciation))")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Grammar of the exact word, e.g. "Noun · Nominative · Plural · Masculine  N-NPM".
    @ViewBuilder
    private var grammarLine: some View {
        if let expansion = result.morphExpansion, !expansion.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(expansion)
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                if !result.isHebrew, let code = result.morphCode, !code.isEmpty {
                    Text(code)
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.7))
                }
            }
        }
    }

    // MARK: - Entry card

    /// One surface for everything the lexicon says, in the order a reader needs it:
    /// the meaning, how the KJV renders the word, then the long entry on demand.
    private var entryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !result.strongsDefinition.isEmpty {
                entrySection {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Definition")
                        Text(result.strongsDefinition)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                        if let origin = originText {
                            Text(origin)
                                .font(.footnote)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if !result.translationCounts.isEmpty || !result.kjvUsage.isEmpty {
                entryDivider
                entrySection { kjvSection }
            }

            if !result.mounceDefinition.isEmpty {
                entryDivider
                entrySection {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Mounce's Dictionary")
                        Text(result.mounceDefinition)
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !result.detailedDefinition.isEmpty {
                entryDivider
                entrySection { lexiconSection }
            }
        }
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }

    /// "from δέω" -> "From δέω".
    private var originText: String? {
        let o = result.derivation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !o.isEmpty else { return nil }
        return o.prefix(1).uppercased() + o.dropFirst()
    }

    private var kjvSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel("In the KJV")
                Spacer()
                if result.occurrenceCount > 0 {
                    Text("\(result.occurrenceCount) occurrences")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }

            if !result.translationCounts.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(result.translationCounts.prefix(10).enumerated()), id: \.offset) { _, tc in
                        HStack(spacing: 4) {
                            Text(tc.word)
                                .font(.subheadline)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Text("\(tc.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.adaptiveNavyText(colorScheme).opacity(0.07))
                        .clipShape(Capsule())
                    }
                }
            }

            if !result.kjvUsage.isEmpty {
                Text("Strong\u{2019}s lists: \(result.kjvUsage)")
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The long lexicon entry is a reference, not the answer, so it opens on demand.
    private var lexiconSection: some View {
        let label = result.detailedSourceLabel ?? (result.isHebrew ? "Brown-Driver-Briggs" : "Thayer's Lexicon")
        let isLong = result.detailedDefinition.count > 280
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel(label)

            Text(result.detailedDefinition)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineSpacing(3)
                .lineLimit(lexiconExpanded || !isLong ? nil : 5)
                .fixedSize(horizontal: false, vertical: true)

            if isLong {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { lexiconExpanded.toggle() }
                } label: {
                    Text(lexiconExpanded ? "Show less" : "Read the full entry")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func entrySection<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var entryDivider: some View {
        Divider().padding(.leading, 16)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
    }

    // MARK: - AI Summary Card

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.reforgedGold)

                Text("AI summary")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                Spacer()

                Text("Gemini")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            if aiSummaryLoading {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Loading AI summary for this word...")
                        .font(.subheadline)
                    Text("Analyzing biblical usage and theological context.")
                        .font(.subheadline)
                    Text("One moment please.")
                        .font(.subheadline)
                }
                .redacted(reason: .placeholder)
            } else if let summary = aiSummary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let error = aiSummaryError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.reforgedGold.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.reforgedGold.opacity(0.25), lineWidth: 1)
        )
        .task {
            guard aiSummary == nil else { return }
            aiSummaryLoading = true
            do {
                aiSummary = try await GeminiService.shared.generateWordStudySummary(result)
            } catch {
                aiSummaryError = error.localizedDescription
                debugLog("[WordStudy] AI error: \(error)")
            }
            aiSummaryLoading = false
        }
    }

    // MARK: - Original Language Card (TR / WLC)

    /// With exact grammar from the study database the hero already carries the Greek word, so
    /// only the Hebrew verse (useful context) remains; the API path keeps the old Greek card.
    @ViewBuilder
    private var originalLanguageCard: some View {
        OriginalLanguageCardBuilder(result: result, colorScheme: colorScheme,
                                    showGreek: result.morphExpansion == nil)
            .onAppear {
                // Trigger lazy loading of TR/WLC data
                let bookNum = OriginalLanguageService.bookNumber(for: result.bookName) ?? 0
                if bookNum >= 40 {
                    OriginalLanguageService.shared.preloadTR()
                } else if bookNum >= 1 {
                    OriginalLanguageService.shared.preloadWLC()
                }
            }
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 40))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            Text("No entries found")
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("This word may not have a direct Hebrew/Greek equivalent, or it may be a common English connector word.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Match Quality

    /// Exact when the KJV word was tied to its Greek/Hebrew word by lemma or morphology; softer when
    /// only the Strong's number matched; hidden when the word position could not be confirmed.
    @ViewBuilder
    private var interlinearMatchBadge: some View {
        switch result.matchQuality {
        case .exact:
            matchQualityBadge(isExact: true)
        case .strongsOnly:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.caption)
                Text("Matched by Strong\u{2019}s number")
                    .font(.caption)
            }
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        case .none:
            EmptyView()
        }
    }

    private func matchQualityBadge(isExact: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isExact ? "checkmark.circle.fill" : "magnifyingglass.circle")
                .font(.caption)
            Text(isExact ? "Exact interlinear match" : "Possible matches from concordance")
                .font(.caption)
        }
        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
    }

    // MARK: - Dictionaries & Topics

    /// Dictionary, lexicon, and topical entries (Easton, Nave, Thompson, and Abbott-Smith when the
    /// lexicon section above is not already showing it).
    private var referenceWorksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Dictionaries & Topics")
                .padding(.leading, 4)

            groupedList {
                ForEach(Array(referenceEntries.enumerated()), id: \.element.id) { index, entry in
                    let isExpanded = expandedWorks.contains(entry.id)
                    if index > 0 { rowDivider }
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if isExpanded { expandedWorks.remove(entry.id) }
                                else { expandedWorks.insert(entry.id) }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.headword)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.adaptiveText(colorScheme))
                                    Text(entry.work.displayName)
                                        .font(.caption)
                                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if isExpanded {
                            LinkedScriptureText(text: entry.text,
                                                font: .caption,
                                                baseColor: Color.adaptiveTextSecondary(colorScheme))
                                .padding(.bottom, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Study Further

    /// One lead action (the concordance, the reason someone studies a word), then a quiet
    /// grouped list. Icons share one treatment; nothing here competes with the entry above.
    private var searchActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Study further")
                .padding(.leading, 4)

            groupedList {
                if hasEntry && !result.strongsNumber.isEmpty {
                    NavigationLink {
                        concordance(.strongsNumber)
                    } label: {
                        furtherRow(
                            title: "Find all \(result.occurrenceCount > 0 ? "\(result.occurrenceCount) " : "")uses of \(result.strongsNumber)",
                            subtitle: "Every verse that uses this word in the Bible",
                            icon: "number.square.fill",
                            lead: true
                        )
                    }

                    if !result.lexicalForm.isEmpty && result.lexicalForm != result.originalWord {
                        rowDivider
                        NavigationLink {
                            concordance(.lexicalForm)
                        } label: {
                            furtherRow(
                                title: "Search the dictionary form",
                                subtitle: "Verses that use \(result.lexicalForm)",
                                icon: "character.book.closed"
                            )
                        }
                    }

                    rowDivider
                    NavigationLink {
                        concordance(.kjvTranslations)
                    } label: {
                        furtherRow(
                            title: "Search KJV renderings",
                            subtitle: "Verses where the KJV translates it this way",
                            icon: "text.book.closed"
                        )
                    }
                } else if !result.isFromAPI, let entry = result.strongsEntries.first {
                    NavigationLink {
                        ConcordanceSearchView(
                            strongsNumber: entry.number,
                            originalWord: entry.lemma,
                            lexicalForm: entry.lemma,
                            englishWord: result.tappedWord,
                            isHebrew: entry.isHebrew,
                            occurrenceCount: 0,
                            translationCounts: [],
                            initialMode: .originalForm,
                            onSelectResult: handleConcordanceSelection
                        )
                    } label: {
                        furtherRow(
                            title: "Search \(entry.number)",
                            subtitle: "Browse occurrences for \(entry.lemma)",
                            icon: "text.magnifyingglass",
                            lead: true
                        )
                    }
                }

                if !result.tappedWord.isEmpty {
                    rowDivider
                    NavigationLink {
                        WordLocatorView(initialWord: result.tappedWord)
                    } label: {
                        furtherRow(
                            title: "Locate \u{201C}\(result.tappedWord)\u{201D}",
                            subtitle: "See where this word appears across the Bible",
                            icon: "chart.bar.xaxis"
                        )
                    }
                }

                rowDivider
                Button {
                    openBlueLetterBible()
                } label: {
                    furtherRow(
                        title: "Open in Blue Letter Bible",
                        subtitle: blbSubtitle,
                        icon: "arrow.up.right.square",
                        external: true
                    )
                }
            }
        }
    }

    private func concordance(_ mode: ConcordanceSearchMode) -> some View {
        ConcordanceSearchView(
            strongsNumber: result.strongsNumber,
            originalWord: result.originalWord,
            lexicalForm: result.lexicalForm,
            englishWord: result.tappedWord,
            isHebrew: result.isHebrew,
            occurrenceCount: result.occurrenceCount,
            translationCounts: result.translationCounts,
            initialMode: mode,
            onSelectResult: handleConcordanceSelection
        )
    }

    private var concordanceSubtitle: String {
        if result.occurrenceCount > 0 {
            return "Find all \(result.occurrenceCount) uses of \(result.strongsNumber) in the Bible"
        }
        return "Search \(result.strongsNumber) across the Bible"
    }

    private var blbSubtitle: String {
        if !result.strongsNumber.isEmpty {
            return "Look up \(result.strongsNumber) on blueletterbible.org"
        }
        if let entry = result.strongsEntries.first {
            return "Look up \(entry.number) on blueletterbible.org"
        }
        return "Search \"\(result.tappedWord)\" on blueletterbible.org"
    }

    private func furtherRow(title: String, subtitle: String, icon: String,
                            lead: Bool = false, external: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(lead ? Color.reforgedGold : Color.adaptiveNavyText(colorScheme))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(lead ? .semibold : .medium))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            if !external {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    /// One rounded surface holding a stack of rows, the iOS grouped-list shape.
    private func groupedList<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 56)
    }

    private func openBlueLetterBible() {
        let baseURL = "https://www.blueletterbible.org"
        var urlString: String

        // Prefer Strong's number for direct lookup
        if result.isFromAPI && !result.strongsNumber.isEmpty {
            // BLB uses format like /lexicon/g25 or /lexicon/h430
            let number = result.strongsNumber.lowercased()
            urlString = "\(baseURL)/lexicon/\(number)/kjv/wlc/0-1/"
        } else if let entry = result.strongsEntries.first {
            let number = entry.number.lowercased()
            urlString = "\(baseURL)/lexicon/\(number)/kjv/wlc/0-1/"
        } else {
            // Fallback: search the English word
            let query = result.tappedWord.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? result.tappedWord
            urlString = "\(baseURL)/search/search.cfm?Criteria=\(query)&t=KJV"
        }

        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    private func handleConcordanceSelection(_ selected: BibleSearchResult) {
        let targetTranslation = selected.translation.isTextSearchable ? selected.translation : selected.translation
        appState.queueBibleVerseNavigation(selected.reference, translation: targetTranslation)
        onClose?() ?? dismiss()
    }

    // MARK: - Attribution

    private var attributionSection: some View {
        Text("Lexical data: Strong\u{2019}s Concordance, Brown-Driver-Briggs and Abbott-Smith lexicons (public domain). Greek text: Textus Receptus. Hebrew text: Westminster Leningrad Codex.")
            .font(.caption2)
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }
}


// MARK: - Original Language Card

/// Resolves and displays the TR (Greek) or WLC (Hebrew) text for the looked-up word.
struct OriginalLanguageCardBuilder: View {
    let result: WordLookupResult
    let colorScheme: ColorScheme
    /// False when the sheet's hero already shows the exact Greek word and its grammar.
    var showGreek: Bool = true
    @ObservedObject private var olService = OriginalLanguageService.shared

    var body: some View {
        let bookNum = OriginalLanguageService.bookNumber(for: result.bookName) ?? 0
        if bookNum >= 40 {
            if showGreek { greekCard(bookNum: bookNum) }
        } else if bookNum >= 1 {
            hebrewCard(bookNum: bookNum)
        }
    }

    @ViewBuilder
    private func greekCard(bookNum: Int) -> some View {
        if let token = OriginalLanguageService.shared.trToken(
            bookNumber: bookNum,
            chapter: result.chapterNumber,
            verse: result.verseNumber,
            strongsNumber: result.strongsNumber
        ) {
            let morphLine = token.morph.isEmpty ? nil : "\(token.morph)  ·  \(token.morphDescription)"
            originalTextCard(
                label: "Textus Receptus",
                badge: "Ελληνικά",
                mainText: token.word,
                verseText: nil,
                morphLine: morphLine,
                isHebrew: false
            )
        }
    }

    @ViewBuilder
    private func hebrewCard(bookNum: Int) -> some View {
        let words = OriginalLanguageService.shared.wlcWords(
            bookNumber: bookNum,
            chapter: result.chapterNumber,
            verse: result.verseNumber
        )
        if !words.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("The verse in Hebrew")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                Text(highlightedVerse(words))
                    .lineSpacing(8)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
            )
        }
    }

    /// The verse with the studied word picked out in gold, matched on consonants so cantillation
    /// and vowel-point differences between the two Hebrew sources do not matter.
    private func highlightedVerse(_ words: [String]) -> AttributedString {
        let target = OriginalLanguageService.stripCantillation(result.originalWord)
        let stripped = words.map { OriginalLanguageService.stripCantillation($0) }
        var hits = Set(stripped.indices.filter { !target.isEmpty && stripped[$0] == target })
        if hits.isEmpty, let first = stripped.firstIndex(where: {
            !target.isEmpty && ($0.contains(target) || target.contains($0)) && !$0.isEmpty
        }) {
            hits = [first]
        }

        var out = AttributedString()
        for (i, word) in words.enumerated() {
            var run = AttributedString(word + (i < words.count - 1 ? " " : ""))
            run.font = Font.custom("Ezra SIL", size: 24)
            if hits.contains(i) {
                run.foregroundColor = Color.reforgedGold
            } else {
                run.foregroundColor = Color.adaptiveText(colorScheme)
            }
            out.append(run)
        }
        return out
    }

    private func originalTextCard(
        label: String,
        badge: String,
        mainText: String?,
        verseText: String?,
        morphLine: String?,
        isHebrew: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Spacer()
                Text(badge)
                    .font(.caption2)
                    .foregroundStyle(Color.reforgedGold.opacity(0.85))
            }

            if let mainText {
                Text(mainText)
                    .font(Font.custom("Roboto", size: 30))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }

            if let verseText {
                Text(verseText)
                    .font(Font.custom("Ezra SIL", size: 22))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
            }

            if let morphLine {
                Text(morphLine)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.reforgedGold.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.reforgedGold.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Fallback Entry Card (bundled dictionary)

struct FallbackEntryCard: View {
    let entry: StrongsEntry
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(entry.number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.reforgedGold.opacity(0.2))
                    .foregroundStyle(Color.reforgedGold)
                    .clipShape(Capsule())

                Text(entry.languageLabel)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                Spacer()

                if !entry.partOfSpeech.isEmpty {
                    Text(entry.partOfSpeech)
                        .font(.caption2)
                        .italic()
                        .foregroundStyle(Color.reforgedGold)
                }
            }

            Text(entry.lemma)
                .font(.system(size: 28))
                .foregroundStyle(Color.adaptiveText(colorScheme))

            HStack(spacing: 8) {
                if !entry.transliteration.isEmpty {
                    Text(entry.transliteration)
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }
                if !entry.pronunciation.isEmpty {
                    Text("(\(entry.pronunciation))")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }

            Divider()

            if !entry.shortDefinition.isEmpty {
                Text(entry.shortDefinition)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }

            if !entry.definition.isEmpty && entry.definition != entry.shortDefinition {
                Text(entry.definition)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !entry.usage.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("English Translations")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Text(entry.usage)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }

            if !entry.source.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Origin")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Text(entry.source)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }
}
