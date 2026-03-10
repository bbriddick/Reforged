import SwiftUI

// MARK: - Bible Progress View

struct BibleProgressView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showOldTestament = true

    // MARK: - Derived Data

    /// Dictionary of book name → set of chapter numbers read (unique)
    private var chaptersReadByBook: [String: Set<Int>] {
        var result: [String: Set<Int>] = [:]
        for entry in appState.user.chaptersRead {
            guard let lastSpace = entry.lastIndex(of: " "),
                  let chapter = Int(entry[entry.index(after: lastSpace)...]) else { continue }
            let bookName = String(entry[..<lastSpace])
            result[bookName, default: []].insert(chapter)
        }
        return result
    }

    private var totalRead: Int {
        chaptersReadByBook.values.reduce(0) { $0 + $1.count }
    }

    private let totalChapters = 1189

    private var displayedBooks: [BibleBook] {
        showOldTestament ? BibleData.oldTestament : BibleData.newTestament
    }

    private var otRead: Int {
        BibleData.oldTestament.reduce(0) { $0 + (chaptersReadByBook[$1.name]?.count ?? 0) }
    }

    private var ntRead: Int {
        BibleData.newTestament.reduce(0) { $0 + (chaptersReadByBook[$1.name]?.count ?? 0) }
    }

    private var otTotal: Int { BibleData.oldTestament.reduce(0) { $0 + $1.chapters } }
    private var ntTotal: Int { BibleData.newTestament.reduce(0) { $0 + $1.chapters } }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                overallCard
                testamentPicker
                booksGrid
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Reading Progress")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Overall Card

    private var overallCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bible Progress")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Text("\(totalRead) of \(totalChapters)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("chapters read")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer()
                BibleProgressRing(
                    progress: Double(totalRead) / Double(totalChapters),
                    size: 76,
                    lineWidth: 8,
                    color: Color.reforgedNavy
                )
            }

            VStack(spacing: 10) {
                progressRow(
                    label: "Old Testament",
                    read: otRead,
                    total: otTotal,
                    color: Color.reforgedNavy
                )
                progressRow(
                    label: "New Testament",
                    read: ntRead,
                    total: ntTotal,
                    color: Color.reforgedGold
                )
            }
        }
        .padding(20)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func progressRow(label: String, read: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Spacer()
                Text("\(read) / \(total)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(
                            width: total > 0
                                ? max(geo.size.width * CGFloat(read) / CGFloat(total), read > 0 ? 6 : 0)
                                : 0,
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Testament Picker

    private var testamentPicker: some View {
        Picker("Testament", selection: $showOldTestament) {
            Text("Old Testament").tag(true)
            Text("New Testament").tag(false)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Books Grid

    private var booksGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(displayedBooks) { book in
                NavigationLink {
                    BookChapterDetailView(
                        book: book,
                        chaptersRead: chaptersReadByBook[book.name] ?? []
                    )
                } label: {
                    BookProgressCell(
                        book: book,
                        chaptersRead: chaptersReadByBook[book.name]?.count ?? 0
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Book Progress Cell

struct BookProgressCell: View {
    let book: BibleBook
    let chaptersRead: Int
    @Environment(\.colorScheme) var colorScheme

    private var progress: Double {
        guard book.chapters > 0 else { return 0 }
        return Double(chaptersRead) / Double(book.chapters)
    }

    private var isComplete: Bool { chaptersRead >= book.chapters }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(book.abbreviation)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.reforgedNavy.opacity(0.12))
                        .frame(height: 5)
                    if progress > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isComplete ? Color.green : Color.reforgedNavy)
                            .frame(
                                width: max(geo.size.width * progress, 5),
                                height: 5
                            )
                    }
                }
            }
            .frame(height: 5)

            Text("\(chaptersRead)/\(book.chapters)")
                .font(.caption2)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(12)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Book Chapter Detail View

struct BookChapterDetailView: View {
    let book: BibleBook
    let chaptersRead: Set<Int>
    @Environment(\.colorScheme) var colorScheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    private var progress: Double {
        guard book.chapters > 0 else { return 0 }
        return Double(chaptersRead.count) / Double(book.chapters)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard
                chapterGrid
                legend
            }
            .padding()
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private var summaryCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(chaptersRead.count) of \(book.chapters) chapters")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text(chaptersRead.count == book.chapters
                    ? "Complete!"
                    : "\(book.chapters - chaptersRead.count) remaining")
                    .font(.subheadline)
                    .foregroundStyle(chaptersRead.count == book.chapters
                        ? Color.green
                        : Color.adaptiveTextSecondary(colorScheme))
            }
            Spacer()
            BibleProgressRing(progress: progress, size: 64, lineWidth: 6, color: Color.reforgedNavy)
        }
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var chapterGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chapters")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...book.chapters, id: \.self) { chapter in
                    ChapterDot(chapter: chapter, isRead: chaptersRead.contains(chapter))
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.reforgedNavy)
                    .frame(width: 12, height: 12)
                Text("Read")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.adaptiveCardBackground(colorScheme))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle().stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
                    )
                Text("Not yet read")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Chapter Dot

struct ChapterDot: View {
    let chapter: Int
    let isRead: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(isRead ? Color.reforgedNavy : Color.adaptiveCardBackground(colorScheme))
            if !isRead {
                Circle()
                    .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
            }
            Text("\(chapter)")
                .font(.system(size: 11, weight: isRead ? .semibold : .regular))
                .foregroundStyle(isRead ? .white : Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(width: 36, height: 36)
    }
}

// MARK: - Progress Ring

struct BibleProgressRing: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.18, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.6), value: progress)
    }
}

#Preview {
    NavigationStack {
        BibleProgressView()
            .environmentObject(AppState.shared)
    }
}
