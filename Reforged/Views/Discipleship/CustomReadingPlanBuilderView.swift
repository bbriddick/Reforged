import SwiftUI

/// Build-your-own reading plan. The member picks what to read — the whole Bible,
/// a Testament, the Gospels, a custom book range, a hand-picked set of books, or
/// a curated theme — and a daily pace; this generates a real
/// `CustomReadingPlanSpec` that shows up in Reading Plans and tracks through
/// `ReadingPlanService` like any built-in plan.
struct CustomReadingPlanBuilderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @StateObject private var store = CustomReadingPlanStore.shared

    @State private var name: String = ""
    @State private var scope: PlanScope = .wholeBible
    @State private var startBookIndex: Int = 0
    @State private var endBookIndex: Int = max(0, BibleData.books.count - 1)
    @State private var pickedBookIndices: Set<Int> = []
    @State private var themeIndex: Int = 0
    @State private var chaptersPerDay: Int = 3
    @State private var accent: PlanAccent = .teal

    enum PlanScope: String, CaseIterable, Identifiable {
        case wholeBible = "Whole Bible"
        case oldTestament = "Old Testament"
        case newTestament = "New Testament"
        case gospels = "Gospels"
        case chooseBooks = "Choose books"
        case theme = "By theme"
        case custom = "Custom range"
        var id: String { rawValue }
    }

    private var canSave: Bool { !generatedEntries.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                planSection
                contentSection
                if scope != .theme { paceSection } else { themePaceNote }
            }
            .scrollContentBackground(.hidden)
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Create a Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }.fontWeight(.semibold).disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Sections

    private var planSection: some View {
        Section("Plan") {
            TextField("Plan name", text: $name)
            HStack {
                Text("Color")
                Spacer()
                ForEach(PlanAccent.allCases.filter { $0 != .navy }) { a in
                    Circle().fill(a.color(colorScheme)).frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(Color.adaptiveText(colorScheme),
                                                       lineWidth: accent == a ? 2.5 : 0))
                        .onTapGesture { HapticManager.shared.buttonTap(); accent = a }
                }
            }
        }
        .listRowBackground(Color.adaptiveCardBackground(colorScheme))
    }

    @ViewBuilder
    private var contentSection: some View {
        Section("What to read") {
            Picker("Scope", selection: $scope) {
                ForEach(PlanScope.allCases) { Text($0.rawValue).tag($0) }
            }

            switch scope {
            case .custom:
                Picker("From", selection: $startBookIndex) {
                    ForEach(BibleData.books.indices, id: \.self) { i in
                        Text(BibleData.books[i].name).tag(i)
                    }
                }
                Picker("To", selection: $endBookIndex) {
                    ForEach(BibleData.books.indices, id: \.self) { i in
                        Text(BibleData.books[i].name).tag(i)
                    }
                }
            case .chooseBooks:
                NavigationLink {
                    BookMultiSelectView(selection: $pickedBookIndices)
                } label: {
                    HStack {
                        Text("Books")
                        Spacer()
                        Text(pickedBookIndices.isEmpty ? "None" : "\(pickedBookIndices.count) selected")
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }
            case .theme:
                Picker("Theme", selection: $themeIndex) {
                    ForEach(ReadingTheme.all.indices, id: \.self) { i in
                        Text(ReadingTheme.all[i].name).tag(i)
                    }
                }
                if ReadingTheme.all.indices.contains(themeIndex) {
                    Text(ReadingTheme.all[themeIndex].subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            default:
                EmptyView()
            }
        }
        .listRowBackground(Color.adaptiveCardBackground(colorScheme))
    }

    private var paceSection: some View {
        Section {
            Stepper(value: $chaptersPerDay, in: 1...5) {
                Text("\(chaptersPerDay) chapter\(chaptersPerDay == 1 ? "" : "s") per day")
            }
        } header: {
            Text("Pace")
        } footer: {
            Text(summaryText)
        }
        .listRowBackground(Color.adaptiveCardBackground(colorScheme))
    }

    private var themePaceNote: some View {
        Section {
            Text(summaryText)
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .listRowBackground(Color.adaptiveCardBackground(colorScheme))
    }

    // MARK: - Derived

    private var summaryText: String {
        let days = generatedEntries.count
        guard days > 0 else {
            return scope == .chooseBooks ? "Pick at least one book." : "Nothing selected yet."
        }
        let chapters = selectedChapters.count
        return "\(chapters) chapter\(chapters == 1 ? "" : "s") over \(days) day\(days == 1 ? "" : "s")."
    }

    private var defaultName: String {
        switch scope {
        case .theme:
            return ReadingTheme.all[safe: themeIndex]?.name ?? "Themed Plan"
        case .chooseBooks:
            let books = selectedBooks
            if books.count == 1 { return books[0].name }
            return "\(books.count) Books"
        case .custom:
            let a = BibleData.books[safe: startBookIndex]?.name ?? ""
            let b = BibleData.books[safe: endBookIndex]?.name ?? ""
            return a == b ? a : "\(a)–\(b)"
        default:
            return scope.rawValue
        }
    }

    /// Books involved (for book-based scopes; empty for themes).
    private var selectedBooks: [BibleBook] {
        let books = BibleData.books
        func range(_ from: String, _ to: String) -> [BibleBook] {
            guard let s = books.firstIndex(where: { $0.name == from }),
                  let e = books.firstIndex(where: { $0.name == to }), s <= e else { return [] }
            return Array(books[s...e])
        }
        switch scope {
        case .wholeBible:   return books
        case .oldTestament: return range("Genesis", "Malachi")
        case .newTestament: return range("Matthew", "Revelation")
        case .gospels:      return range("Matthew", "John")
        case .chooseBooks:  return pickedBookIndices.sorted().compactMap { books[safe: $0] }
        case .theme:        return []
        case .custom:
            let lo = min(startBookIndex, endBookIndex), hi = max(startBookIndex, endBookIndex)
            guard books.indices.contains(lo), books.indices.contains(hi) else { return [] }
            return Array(books[lo...hi])
        }
    }

    /// Ordered (book, chapter) list to read.
    private var selectedChapters: [(book: String, chapter: Int)] {
        if scope == .theme {
            return ReadingTheme.all[safe: themeIndex]?.chapters ?? []
        }
        return selectedBooks.flatMap { book in (1...book.chapters).map { (book.name, $0) } }
    }

    /// Chunks the chapter list into daily entries, merging up to `pace`
    /// consecutive chapters within the same book into one range reference (so a
    /// day never crosses a book and every reference parses cleanly). Themes read
    /// one entry per contiguous run.
    private var generatedEntries: [CustomReadingPlanSpec.Entry] {
        let chapters = selectedChapters
        let pace = scope == .theme ? 1 : chaptersPerDay
        var entries: [CustomReadingPlanSpec.Entry] = []
        var day = 1
        var i = 0
        while i < chapters.count {
            let book = chapters[i].book
            let startCh = chapters[i].chapter
            var endCh = startCh
            var count = 1
            var j = i + 1
            while j < chapters.count, count < pace,
                  chapters[j].book == book, chapters[j].chapter == endCh + 1 {
                endCh = chapters[j].chapter
                count += 1
                j += 1
            }
            let ref = endCh == startCh ? "\(book) \(startCh)" : "\(book) \(startCh)-\(endCh)"
            entries.append(.init(day: day, reference: ref, prompt: ""))
            day += 1
            i = j
        }
        return entries
    }

    // MARK: - Create

    private func create() {
        HapticManager.shared.success()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let spec = CustomReadingPlanSpec(
            id: "custom-\(UUID().uuidString)",
            name: trimmed.isEmpty ? defaultName : trimmed,
            planDescription: summaryText,
            iconName: scope == .theme ? "sparkles" : "book.closed.fill",
            accent: accent,
            entries: generatedEntries
        )
        store.add(spec)
        dismiss()
    }
}

// MARK: - Book multi-select

/// Tick any set of books; canonical order is preserved by the caller.
private struct BookMultiSelectView: View {
    @Binding var selection: Set<Int>
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        List {
            ForEach(BibleData.books.indices, id: \.self) { i in
                Button {
                    HapticManager.shared.buttonTap()
                    if selection.contains(i) { selection.remove(i) } else { selection.insert(i) }
                } label: {
                    HStack {
                        Text(BibleData.books[i].name)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Spacer()
                        if selection.contains(i) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.reforgedGold)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .listRowBackground(Color.adaptiveCardBackground(colorScheme))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Choose Books")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(selection.count == BibleData.books.count ? "None" : "All") {
                    if selection.count == BibleData.books.count { selection = [] }
                    else { selection = Set(BibleData.books.indices) }
                }
            }
        }
    }
}

// MARK: - Curated themes

/// A curated topical reading collection. `chapters` is an ordered list of
/// (book, chapter) pairs; book names match `BibleData.books` so references parse.
struct ReadingTheme {
    let name: String
    let subtitle: String
    let chapters: [(book: String, chapter: Int)]

    /// Helper: expand a book + chapter numbers into pairs.
    private static func ch(_ book: String, _ chapters: [Int]) -> [(book: String, chapter: Int)] {
        chapters.map { (book, $0) }
    }
    private static func range(_ book: String, _ r: ClosedRange<Int>) -> [(book: String, chapter: Int)] {
        r.map { (book, $0) }
    }

    static let all: [ReadingTheme] = [
        ReadingTheme(
            name: "Life of Jesus",
            subtitle: "Walk through the Gospel of John.",
            chapters: range("John", 1...21)
        ),
        ReadingTheme(
            name: "Wisdom",
            subtitle: "Proverbs & Ecclesiastes.",
            chapters: range("Proverbs", 1...31) + range("Ecclesiastes", 1...12)
        ),
        ReadingTheme(
            name: "Psalms of Comfort",
            subtitle: "Psalms for hard and hopeful days.",
            chapters: ch("Psalms", [23, 27, 34, 42, 46, 51, 63, 91, 103, 121, 130, 139, 145])
        ),
        ReadingTheme(
            name: "Prayer",
            subtitle: "How Scripture teaches us to pray.",
            chapters: ch("Matthew", [6]) + ch("Luke", [11]) + ch("John", [17])
                + ch("Psalms", [145]) + ch("Ephesians", [3]) + ch("Philippians", [4])
        ),
        ReadingTheme(
            name: "Identity in Christ",
            subtitle: "Who you are in the gospel.",
            chapters: range("Ephesians", 1...3) + ch("Romans", [8])
                + ch("Colossians", [3]) + ch("1 Peter", [2])
        ),
        ReadingTheme(
            name: "Hope & Endurance",
            subtitle: "Strength for the long walk.",
            chapters: ch("Romans", [5, 8]) + ch("2 Corinthians", [4])
                + range("Hebrews", 11...12) + ch("James", [1]) + ch("1 Peter", [1])
        ),
        ReadingTheme(
            name: "The Story of Redemption",
            subtitle: "Creation to new creation.",
            chapters: range("Genesis", 1...3) + ch("Genesis", [12]) + ch("Exodus", [12])
                + ch("Isaiah", [53]) + ch("Luke", [2]) + ch("John", [19, 20])
                + ch("Romans", [8]) + ch("Revelation", [21])
        )
    ]
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
