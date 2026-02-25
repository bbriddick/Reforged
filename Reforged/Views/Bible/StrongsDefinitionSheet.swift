import SwiftUI

// MARK: - Strong's Definition Sheet

/// Bottom sheet showing Hebrew/Greek word study results for a tapped word.
struct StrongsDefinitionSheet: View {
    let result: WordLookupResult
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

                    if result.isFromAPI {
                        interlinearCard
                    } else if result.strongsEntries.isEmpty {
                        noResultsView
                    } else {
                        // Fallback: bundled dictionary entries
                        ForEach(result.strongsEntries) { entry in
                            FallbackEntryCard(entry: entry, colorScheme: colorScheme)
                        }
                        matchQualityBadge(isExact: false)
                    }

                    // Search & external study actions
                    searchActionsSection

                    attributionSection
                }
                .padding()
            }
            .background(Color.adaptiveBackground(colorScheme))
            .navigationTitle("Word Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.reforgedGold)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.isHebrew ? "Hebrew" : "Greek")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.reforgedGold.opacity(0.2))
                    .foregroundStyle(Color.reforgedGold)
                    .clipShape(Capsule())

                if result.isFromAPI && !result.strongsNumber.isEmpty {
                    Text(result.strongsNumber)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.adaptiveNavyText(colorScheme).opacity(0.15))
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        .clipShape(Capsule())
                }

                Spacer()

                Text(result.verseReference)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            // English word → original word mapping
            if result.isFromAPI && !result.originalWord.isEmpty {
                HStack(spacing: 8) {
                    Text("\"\(result.tappedWord)\"")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(Color.reforgedGold)

                    Text(result.originalWord)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }
            } else {
                Text("\"\(result.tappedWord)\"")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
        }
    }

    // MARK: - Interlinear Card (API result)

    private var interlinearCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Original word as used in text
            if !result.originalWord.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("As Used in Text")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedGold)

                    Text(result.originalWord)
                        .font(.system(size: 32))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }
            }

            // Lexical/root form
            if !result.lexicalForm.isEmpty && result.lexicalForm != result.originalWord {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lexical Form")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedGold)

                    Text(result.lexicalForm)
                        .font(.system(size: 26))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }
            }

            // Transliteration + pronunciation
            if !result.transliteration.isEmpty || !result.pronunciation.isEmpty {
                HStack(spacing: 8) {
                    if !result.transliteration.isEmpty {
                        Text(result.transliteration)
                            .font(.subheadline)
                            .italic()
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                    if !result.pronunciation.isEmpty {
                        Text("(\(result.pronunciation))")
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }
            }

            Divider()

            // Strong's definition
            if !result.strongsDefinition.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Definition")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    Text(result.strongsDefinition)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Mounce's definition (if available, mainly Greek)
            if !result.mounceDefinition.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mounce's Dictionary")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    Text(result.mounceDefinition)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Detailed definition (BDB for Hebrew, Thayer's for Greek)
            if !result.detailedDefinition.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.isHebrew ? "Brown-Driver-Briggs" : "Thayer's Lexicon")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    Text(result.detailedDefinition)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
            }

            // KJV Usage / English translations
            if !result.kjvUsage.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("KJV Translations")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    Text(result.kjvUsage)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Translation counts
            if !result.translationCounts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Usage Frequency")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    FlowLayout(spacing: 6) {
                        ForEach(Array(result.translationCounts.prefix(10).enumerated()), id: \.offset) { _, tc in
                            HStack(spacing: 4) {
                                Text(tc.word)
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Text("(\(tc.count))")
                                    .font(.caption2)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.adaptiveNavyText(colorScheme).opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Occurrences + Derivation
            HStack {
                if result.occurrenceCount > 0 {
                    Label("\(result.occurrenceCount) occurrences", systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Spacer()
            }

            if !result.derivation.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Origin")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    Text(result.derivation)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            matchQualityBadge(isExact: true)
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
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

    private func matchQualityBadge(isExact: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isExact ? "checkmark.circle.fill" : "magnifyingglass.circle")
                .font(.caption)
            Text(isExact ? "Exact interlinear match" : "Possible matches from concordance")
                .font(.caption)
        }
        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        .padding(.top, 4)
    }

    // MARK: - Search Actions

    private var searchActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Study Further")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            // "See all occurrences" — concordance search button
            if result.isFromAPI && !result.strongsNumber.isEmpty {
                NavigationLink {
                    ConcordanceSearchView(
                        strongsNumber: result.strongsNumber,
                        originalWord: result.originalWord,
                        lexicalForm: result.lexicalForm,
                        englishWord: result.tappedWord,
                        isHebrew: result.isHebrew,
                        occurrenceCount: result.occurrenceCount,
                        translationCounts: result.translationCounts
                    )
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.body)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.reforgedGold)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("See All Occurrences")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.adaptiveText(colorScheme))

                            Text(concordanceSubtitle)
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding(12)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.reforgedGold.opacity(0.3), lineWidth: 1)
                    )
                }
            } else if !result.isFromAPI, let entry = result.strongsEntries.first {
                // Fallback: search by bundled entry
                NavigationLink {
                    ConcordanceSearchView(
                        strongsNumber: entry.number,
                        originalWord: entry.lemma,
                        lexicalForm: entry.lemma,
                        englishWord: result.tappedWord,
                        isHebrew: entry.isHebrew,
                        occurrenceCount: 0,
                        translationCounts: []
                    )
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.body)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.reforgedGold)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("See All Occurrences")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.adaptiveText(colorScheme))

                            Text("Search \"\(result.tappedWord)\" across the Bible")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding(12)
                    .background(Color.adaptiveCardBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.reforgedGold.opacity(0.3), lineWidth: 1)
                    )
                }
            }

            Divider()
                .padding(.vertical, 4)

            // Blue Letter Bible link
            Button {
                openBlueLetterBible()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "book.pages")
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color(red: 0.15, green: 0.25, blue: 0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open in Blue Letter Bible")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Text(blbSubtitle)
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .padding(12)
                .background(Color.adaptiveCardBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                )
            }
        }
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

    // MARK: - Attribution

    private var attributionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            Text("Data from Complete Study Bible via Strong's Concordance, BDB & Thayer's Lexicons (public domain)")
                .font(.caption2)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(.top, 8)
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
