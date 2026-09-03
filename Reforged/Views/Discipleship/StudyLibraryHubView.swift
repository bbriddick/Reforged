import SwiftUI

/// Hub for all the offline study data and tools: the Bible Atlas, Word Locator, Spurgeon's
/// Morning & Evening, the bundled dictionaries/lexicon/topical works, and the downloadable
/// commentaries. Reached from the "Study Library" tile in Discipleship.
struct StudyLibraryHubView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAtlas = false

    private let accent = Color(red: 0.55, green: 0.35, blue: 0.7)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Tools that read their own bundled data.
                NavigationLink { WordLocatorView() } label: {
                    hubRow(icon: "chart.bar.xaxis", tint: Color.reforgedGold,
                           title: "Word Locator",
                           subtitle: "See where any word appears across the whole Bible")
                }
                .buttonStyle(.plain)

                Button { showAtlas = true } label: {
                    hubRow(icon: "map.fill", tint: Color(red: 0.2, green: 0.6, blue: 0.5),
                           title: "Bible Atlas",
                           subtitle: "~1,300 biblical places mapped, with the verses that mention them")
                }
                .buttonStyle(.plain)

                NavigationLink { SpurgeonDevotionalView(plan: BibleReadingPlans.spurgeonMorningEvening) } label: {
                    hubRow(icon: "sun.and.horizon.fill", tint: accent,
                           title: "Morning & Evening",
                           subtitle: "Spurgeon's classic daily devotional")
                }
                .buttonStyle(.plain)

                NavigationLink { ReferenceWorkBrowserView() } label: {
                    hubRow(icon: "character.book.closed.fill", tint: Color(red: 0.85, green: 0.45, blue: 0.15),
                           title: "Dictionaries & Topics",
                           subtitle: "Easton's Dictionary, Abbott-Smith Greek Lexicon, Nave's & Thompson topics")
                }
                .buttonStyle(.plain)

                NavigationLink { CommentaryLibraryScreen() } label: {
                    hubRow(icon: "text.book.closed.fill", tint: Color(red: 0.1, green: 0.65, blue: 0.8),
                           title: "Commentaries",
                           subtitle: "Scofield built in; download Matthew Henry, Barnes, Calvin & more")
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Study Library")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAtlas) { BibleAtlasView() }
    }

    private func hubRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, y: 3)
    }
}

/// Commentaries screen: read what's available (browse book → chapter → text) and download more.
private struct CommentaryLibraryScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var downloads = CommentaryDownloadManager.shared

    private var readable: [CommentarySource] { CommentaryService.shared.availableSources() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Read what's on device.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Read")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    ForEach(readable) { source in
                        NavigationLink { CommentaryReaderView(source: source) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "text.book.closed.fill")
                                    .foregroundStyle(Color.reforgedGold)
                                Text(source.displayName)
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                            .padding(14)
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Download more.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add More")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Text("Download these classic public-domain commentaries for offline reading — remove them anytime.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    StudyLibraryView()
                }
            }
            .padding(20)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Commentaries")
        .navigationBarTitleDisplayMode(.inline)
        // Re-read `readable` when a download finishes.
        .id(downloads.downloaded.count)
    }
}

// MARK: - Reference entry detail

/// Full-size reader for a single dictionary/lexicon/topical entry, so its whole context is
/// readable. Presented from the search bars.
struct ReferenceEntryDetailView: View {
    let entry: ReferenceEntry
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(entry.work.displayName)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedGold)
                    LinkedScriptureText(text: entry.text,
                                        font: .body,
                                        baseColor: Color.adaptiveText(colorScheme))
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle(entry.headword)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Dictionary / topical browser

/// Searchable browser over the bundled reference works (Easton, Abbott-Smith, Nave, Thompson).
struct ReferenceWorkBrowserView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var query = ""
    @State private var results: [ReferenceEntry] = []
    @State private var expanded: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                searchField

                if query.trimmingCharacters(in: .whitespaces).count < 2 {
                    Text("Search Easton's Bible Dictionary, the Abbott-Smith Greek Lexicon, and Nave's & Thompson topical works.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(.top, 8)
                } else if results.isEmpty {
                    Text("No entries found for “\(query)”.")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(.top, 8)
                } else {
                    ForEach(results) { entry in
                        entryRow(entry)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Dictionaries & Topics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            TextField("Search entries", text: $query)
                .autocorrectionDisabled()
                .onChange(of: query) { _ in
                    results = ReferenceWorkService.shared.search(query, limit: 30)
                }
            if !query.isEmpty {
                Button { query = ""; results = [] } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
    }

    private func entryRow(_ entry: ReferenceEntry) -> some View {
        let isExpanded = expanded.contains(entry.id)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded { expanded.remove(entry.id) } else { expanded.insert(entry.id) }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.headword)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text(entry.work.displayName)
                            .font(.caption2)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                LinkedScriptureText(text: entry.text, font: .caption,
                                    baseColor: Color.adaptiveTextSecondary(colorScheme))
            }
        }
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1))
    }
}
