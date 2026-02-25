import SwiftUI

// MARK: - Chapter Navigation Wheel

struct ChapterNavigationWheel: View {
    @Binding var currentChapter: Int
    let totalChapters: Int
    let onChapterSelected: (Int) -> Void
    @Binding var isPresented: Bool

    @State private var dragOffset: CGFloat = 0
    @State private var selectedIndex: Int = 0
    @GestureState private var isDragging: Bool = false

    private let itemHeight: CGFloat = 56
    private let visibleItems: Int = 9

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            isPresented = false
                        }
                    }

                // Wheel container - positioned on the right
                HStack {
                    Spacer()

                    ZStack {
                        // Background blur
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .frame(width: 100)

                        // Selection indicator
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.reforgedNavy)
                            .frame(width: 80, height: itemHeight)
                            .shadow(color: Color.reforgedNavy.opacity(0.3), radius: 8, y: 2)

                        // Chapter numbers
                        ScrollViewReader { proxy in
                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVStack(spacing: 0) {
                                    // Top padding
                                    Color.clear.frame(height: CGFloat(visibleItems / 2) * itemHeight)

                                    ForEach(1...totalChapters, id: \.self) { chapter in
                                        ChapterWheelItem(
                                            chapter: chapter,
                                            isSelected: chapter == currentChapter,
                                            itemHeight: itemHeight
                                        )
                                        .id(chapter)
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.3)) {
                                                currentChapter = chapter
                                                onChapterSelected(chapter)
                                            }
                                            // Haptic feedback
                                            let impact = UIImpactFeedbackGenerator(style: .light)
                                            impact.impactOccurred()
                                        }
                                    }

                                    // Bottom padding
                                    Color.clear.frame(height: CGFloat(visibleItems / 2) * itemHeight)
                                }
                            }
                            .frame(width: 100, height: CGFloat(visibleItems) * itemHeight)
                            .mask(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .clear,
                                        .black.opacity(0.3),
                                        .black,
                                        .black,
                                        .black,
                                        .black.opacity(0.3),
                                        .clear
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .onAppear {
                                proxy.scrollTo(currentChapter, anchor: .center)
                            }
                            .onChange(of: currentChapter) { newValue in
                                withAnimation(.spring(response: 0.3)) {
                                    proxy.scrollTo(newValue, anchor: .center)
                                }
                            }
                        }

                        // Navigation buttons
                        VStack {
                            // Previous chapter
                            Button {
                                if currentChapter > 1 {
                                    withAnimation(.spring(response: 0.3)) {
                                        currentChapter -= 1
                                        onChapterSelected(currentChapter)
                                    }
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                }
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.title3.bold())
                                    .foregroundStyle(currentChapter > 1 ? Color.reforgedNavy : Color.gray.opacity(0.5))
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.9))
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            }
                            .disabled(currentChapter <= 1)

                            Spacer()

                            // Next chapter
                            Button {
                                if currentChapter < totalChapters {
                                    withAnimation(.spring(response: 0.3)) {
                                        currentChapter += 1
                                        onChapterSelected(currentChapter)
                                    }
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.title3.bold())
                                    .foregroundStyle(currentChapter < totalChapters ? Color.reforgedNavy : Color.gray.opacity(0.5))
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.9))
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            }
                            .disabled(currentChapter >= totalChapters)
                        }
                        .padding(.vertical, 8)
                        .frame(height: CGFloat(visibleItems) * itemHeight)
                    }
                    .frame(width: 100, height: CGFloat(visibleItems) * itemHeight + 100)
                    .padding(.trailing, 8)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }
}

// MARK: - Chapter Wheel Item

struct ChapterWheelItem: View {
    let chapter: Int
    let isSelected: Bool
    let itemHeight: CGFloat
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text("\(chapter)")
            .font(.system(size: isSelected ? 24 : 18, weight: isSelected ? .bold : .medium, design: .rounded))
            .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme).opacity(0.6))
            .frame(width: 80, height: itemHeight)
            .contentShape(Rectangle())
    }
}

// MARK: - Book Navigation Wheel

struct BookNavigationWheel: View {
    @Binding var currentBook: String
    let books: [BibleBook]
    let onBookSelected: (BibleBook) -> Void
    @Binding var isPresented: Bool

    @State private var selectedTestament: BibleBook.Testament = .old

    private let itemHeight: CGFloat = 50

    var filteredBooks: [BibleBook] {
        books.filter { $0.testament == selectedTestament }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            isPresented = false
                        }
                    }

                // Wheel container
                VStack(spacing: 0) {
                    // Testament tabs
                    HStack(spacing: 0) {
                        TestamentTab(
                            title: "Old",
                            isSelected: selectedTestament == .old
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTestament = .old
                            }
                        }

                        TestamentTab(
                            title: "New",
                            isSelected: selectedTestament == .new
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTestament = .new
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 16)

                    // Books list
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 4) {
                                ForEach(filteredBooks) { book in
                                    BookWheelItem(
                                        book: book,
                                        isSelected: book.name == currentBook
                                    )
                                    .id(book.id)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3)) {
                                            currentBook = book.name
                                            onBookSelected(book)
                                            isPresented = false
                                        }
                                        let impact = UIImpactFeedbackGenerator(style: .medium)
                                        impact.impactOccurred()
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        .frame(height: min(CGFloat(filteredBooks.count) * itemHeight, geometry.size.height * 0.6))
                        .onAppear {
                            if let book = books.first(where: { $0.name == currentBook }) {
                                selectedTestament = book.testament
                                proxy.scrollTo(book.id, anchor: .center)
                            }
                        }
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .padding(.horizontal, 40)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

struct TestamentTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundStyle(isSelected ? .white : Color.white.opacity(0.6))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(isSelected ? Color.reforgedNavy : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct BookWheelItem: View {
    let book: BibleBook
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Text(book.name)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundStyle(isSelected ? .white : Color.adaptiveText(colorScheme))

            Spacer()

            Text("\(book.chapters)")
                .font(.caption)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? Color.reforgedNavy : Color.adaptiveCardBackground(colorScheme).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Swipe Navigation Gesture

struct SwipeNavigationModifier: ViewModifier {
    @Binding var showNavigationWheel: Bool
    let edgeWidth: CGFloat

    @GestureState private var dragState: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 20)
                    .updating($dragState) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        // Check if swipe started from right edge and moved left
                        let screenWidth = UIScreen.main.bounds.width
                        if value.startLocation.x > screenWidth - edgeWidth &&
                           value.translation.width < -50 {
                            withAnimation(.spring(response: 0.3)) {
                                showNavigationWheel = true
                            }
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        }
                    }
            )
    }
}

extension View {
    func swipeForNavigation(showWheel: Binding<Bool>, edgeWidth: CGFloat = 50) -> some View {
        modifier(SwipeNavigationModifier(showNavigationWheel: showWheel, edgeWidth: edgeWidth))
    }
}
