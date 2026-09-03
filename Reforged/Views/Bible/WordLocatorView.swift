import SwiftUI

/// Shows where an English word occurs across the whole Bible — a per-book distribution
/// strip plus a tappable list of every verse — powered by `WordLocatorService` (KJV).
/// Native counterpart to openbible.info's "Bible Word Locator" (lab #2).
struct WordLocatorView: View {
    let initialWord: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var query: String
    @State private var result: WordLocatorResult?
    @State private var isSearching = false

    /// Cap the rendered occurrence list; common words appear thousands of times.
    private let maxListed = 250

    init(initialWord: String = "") {
        self.initialWord = initialWord
        _query = State(initialValue: initialWord)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                searchField

                if isSearching {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if let result {
                    if result.totalOccurrences == 0 {
                        emptyState(for: result.word)
                    } else {
                        summary(result)
                        distribution(result)
                        occurrences(result)
                    }
                }
            }
            .padding()
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Word Locator")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !initialWord.isEmpty { await runSearch() }
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            TextField("Find a word across the Bible", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { Task { await runSearch() } }
            if !query.isEmpty {
                Button { query = ""; result = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
        )
    }

    private func runSearch() async {
        let word = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { result = nil; return }
        isSearching = true
        let found = await Task.detached(priority: .userInitiated) {
            WordLocatorService.shared.locate(word)
        }.value
        result = found
        isSearching = false
    }

    // MARK: - Result sections

    private func summary(_ result: WordLocatorResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("“\(result.word)”")
                .font(.title3).bold()
                .foregroundStyle(Color.reforgedGold)
            Text("\(result.totalOccurrences) occurrence\(result.totalOccurrences == 1 ? "" : "s") in \(result.verseCount) verse\(result.verseCount == 1 ? "" : "s") (KJV)")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
    }

    /// A 66-bar strip across the whole Bible, with an OT/NT divider.
    private func distribution(_ result: WordLocatorResult) -> some View {
        let maxCount = max(result.perBook.map(\.count).max() ?? 1, 1)
        let ntStartIndex = BibleData.books.firstIndex { $0.testament == .new } ?? 39
        return VStack(alignment: .leading, spacing: 8) {
            Text("Distribution")
                .font(.caption).bold()
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            Canvas { context, size in
                let count = result.perBook.count
                guard count > 0 else { return }
                let gap: CGFloat = 1.5
                let barWidth = (size.width - gap * CGFloat(count - 1)) / CGFloat(count)
                for (index, book) in result.perBook.enumerated() {
                    let x = CGFloat(index) * (barWidth + gap)
                    let normalized = CGFloat(book.count) / CGFloat(maxCount)
                    let barHeight = book.count == 0 ? 1 : max(2, normalized * size.height)
                    let rect = CGRect(x: x, y: size.height - barHeight, width: barWidth, height: barHeight)
                    let color = book.count == 0
                        ? Color.adaptiveTextSecondary(colorScheme).opacity(0.15)
                        : Color.reforgedGold.opacity(0.55 + 0.45 * normalized)
                    context.fill(Path(rect), with: .color(color))
                }
                // OT / NT divider
                let dividerX = CGFloat(ntStartIndex) * (barWidth + gap) - gap / 2
                var line = Path()
                line.move(to: CGPoint(x: dividerX, y: 0))
                line.addLine(to: CGPoint(x: dividerX, y: size.height))
                context.stroke(line, with: .color(Color.adaptiveTextSecondary(colorScheme).opacity(0.4)),
                               style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
            .frame(height: 80)

            HStack {
                Text("Old Testament")
                Spacer()
                Text("New Testament")
            }
            .font(.system(size: 10))
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            // Top books by count.
            let top = result.perBook.filter { $0.count > 0 }.sorted { $0.count > $1.count }.prefix(5)
            if !top.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(Array(top)) { book in
                        Text("\(book.bookName) · \(book.count)")
                            .font(.caption2).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.adaptiveChipBackground(colorScheme))
                            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func occurrences(_ result: WordLocatorResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Occurrences")
                .font(.caption).bold()
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(result.references.prefix(maxListed)) { ref in
                    Button { navigate(to: ref.reference) } label: {
                        occurrenceRow(ref)
                    }
                    .buttonStyle(.plain)
                }
            }

            if result.references.count > maxListed {
                Text("Showing first \(maxListed) of \(result.references.count) verses.")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
    }

    private func occurrenceRow(_ ref: WordReference) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(ref.reference)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.reforgedGold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            Text(ref.text)
                .font(.caption)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .lineLimit(2)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func emptyState(for word: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            Text("No occurrences of “\(word)” found in the KJV.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func navigate(to reference: String) {
        NotificationCenter.default.post(
            name: .navigateToBibleVerse,
            object: nil,
            userInfo: [
                AppNotificationUserInfoKey.reference: reference,
                AppNotificationUserInfoKey.translation: BibleTranslation.kjv.rawValue
            ]
        )
    }
}
