import SwiftUI

/// Browse a commentary directly — pick a book, then a chapter, then read the entries — without
/// having to land on a specific verse first. Backed by `CommentaryService` browsing methods.
struct CommentaryReaderView: View {
    let source: CommentarySource

    @Environment(\.colorScheme) private var colorScheme
    private var books: [String] { CommentaryService.shared.books(for: source) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if books.isEmpty {
                    Text("This commentary isn't available yet. Download it from the Study Library.")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                } else {
                    ForEach(books, id: \.self) { book in
                        NavigationLink { CommentaryChaptersView(source: source, book: book) } label: {
                            HStack {
                                Text(book)
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
            }
            .padding(20)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle(source.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Chapter picker for a commentary + book.
struct CommentaryChaptersView: View {
    let source: CommentarySource
    let book: String

    @Environment(\.colorScheme) private var colorScheme
    private var chapters: [Int] { CommentaryService.shared.chapters(for: source, book: book) }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(chapters, id: \.self) { chapter in
                    NavigationLink {
                        CommentaryChapterView(source: source, book: book, chapter: chapter)
                    } label: {
                        Text("\(chapter)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.adaptiveCardBackground(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle(book)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The commentary text for one chapter, entry by entry.
struct CommentaryChapterView: View {
    let source: CommentarySource
    let book: String
    let chapter: Int

    @Environment(\.colorScheme) private var colorScheme
    private var entries: [(verse: Int, reference: String, text: String)] {
        CommentaryService.shared.chapterEntries(for: source, book: book, chapter: chapter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(source.displayName)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.reforgedGold)

                ForEach(entries, id: \.reference) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.reference)
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        LinkedScriptureText(text: entry.text,
                                            font: .body,
                                            baseColor: Color.adaptiveText(colorScheme))
                            .lineSpacing(4)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("\(book) \(chapter)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
