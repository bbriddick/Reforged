import SwiftUI
import UIKit
import AVKit
import WebKit

/// What a `LearnWebView` should display: a plain URL (Vimeo etc.) or an inline HTML document
/// (YouTube, which must be embedded via an iframe with a real page origin — loading the bare
/// `/embed/` URL yields player error 153).
private enum LearnWebContent: Equatable {
    case url(URL)
    case html(String, baseURL: URL?)
}

/// Minimal web view for embedding YouTube/Vimeo players (the app's WebView.swift
/// isn't in the build target).
private struct LearnWebView: UIViewRepresentable {
    let content: LearnWebContent

    func makeUIView(context: Context) -> WKWebView {
        // Inline playback so the video plays in place, not only fullscreen.
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: config)
        web.scrollView.isScrollEnabled = false
        web.isOpaque = false
        web.backgroundColor = .clear
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        guard context.coordinator.loaded != content else { return }
        context.coordinator.loaded = content
        switch content {
        case .url(let url):
            web.load(URLRequest(url: url))
        case .html(let html, let baseURL):
            web.loadHTMLString(html, baseURL: baseURL)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var loaded: LearnWebContent? }
}

// MARK: - Learn: published tracks → lessons → content blocks
//
// Read-side UI for the expanded track system. Entry point is `TracksListView`
// (pushed from the Groups tab). Reuses existing app features rather than
// reimplementing them: the Bible deep-link for readings, memory-add for memory
// verses, JournalView for prompts, and HandoutDetailView for handouts.

enum LearnLoadPhase: Equatable {
    case loading, loaded
    case error(String)
}

// MARK: - Tracks List

struct TracksListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var tracks: [LearnTrack] = []
    @State private var phase: LearnLoadPhase = .loading

    // Embeddable (no own ScrollView) — the Groups hub provides the scroll.
    var body: some View {
        Group {
            switch phase {
            case .loading:
                GroupsLoadingView(message: "Loading lessons…").frame(minHeight: 220)
            case .error(let message):
                GroupsErrorView(message: message) { Task { await load() } }.frame(minHeight: 220)
            case .loaded where tracks.isEmpty:
                GroupsMessageScaffold(
                    systemImage: "books.vertical",
                    title: "Nothing assigned yet",
                    message: "When your leader publishes a lesson track, it'll appear here."
                )
                .padding(.top, 24)
            case .loaded:
                LazyVStack(spacing: 14) {
                    ForEach(tracks) { track in
                        NavigationLink { LearnTrackDetailView(track: track) } label: {
                            LearnTrackCard(track: track)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .task { await load() }
        // Foreground refresh so newly published tracks appear without reload.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await load() }
        }
    }

    private func load() async {
        do {
            tracks = try await TracksRepository.shared.fetchTracksForCurrentUser()
            phase = .loaded
        } catch {
            phase = .error(errorMessage(error))
        }
    }
}

private struct LearnTrackCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let track: LearnTrack
    @State private var lessonCount: Int?

    var body: some View {
        HStack(spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(track.title)
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(2)
                    if track.isNew {
                        Text("NEW")
                            .font(.caption2).bold()
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.reforgedCoral)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                if let summary = track.summary ?? track.description, !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .lineLimit(2)
                }
                Text(lessonCount.map { "\($0) lesson\($0 == 1 ? "" : "s")" } ?? "View lessons")
                    .font(.caption).bold()
                    .foregroundStyle(Color.reforgedGold)
            }

            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption).bold()
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task {
            lessonCount = (try? await TracksRepository.shared.fetchLessons(trackId: track.id, includeDrafts: false))?.count
        }
    }

    /// Small square thumbnail: the cover image if present, else a tidy branded
    /// icon tile (not a full-bleed gradient banner).
    private var thumbnail: some View {
        Group {
            if let path = track.coverImagePath, !path.isEmpty {
                SignedAsyncImage(bucket: "group-covers", path: path)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.reforgedGold.opacity(0.15))
                    Image(systemName: "book.closed.fill")
                        .font(.title2)
                        .foregroundStyle(Color.reforgedGold)
                }
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Track Detail (lessons)

struct LearnTrackDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    let track: LearnTrack

    @State private var lessons: [TrackLesson] = []
    @State private var itemCounts: [String: Int] = [:]
    @State private var phase: LearnLoadPhase = .loading

    private var isOwner: Bool { track.ownerId != nil && track.ownerId == SupabaseAuthService.shared.userId }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                switch phase {
                case .loading:
                    GroupsLoadingView(message: "Loading lessons…").frame(height: 160)
                case .error(let message):
                    GroupsErrorView(message: message) { Task { await load() } }.frame(height: 200)
                case .loaded where lessons.isEmpty:
                    GroupsMessageScaffold(systemImage: "list.bullet.rectangle",
                                          title: "No lessons published yet",
                                          message: "Check back when your leader adds lessons.")
                case .loaded:
                    ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                        NavigationLink {
                            LessonDetailView(lesson: lesson, isOwner: isOwner)
                        } label: {
                            LearnLessonRow(number: index + 1, lesson: lesson, itemCount: itemCounts[lesson.id])
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(track.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let path = track.coverImagePath, !path.isEmpty {
                ZStack(alignment: .bottomLeading) {
                    SignedAsyncImage(bucket: "group-covers", path: path)
                        .frame(height: 180).frame(maxWidth: .infinity).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                        .frame(height: 180)
                    Text(track.title).font(.title).bold()
                        .foregroundStyle(.white).shadow(radius: 4).padding(16)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LESSON TRACK")
                        .font(.caption2).bold().tracking(1)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Text(track.title).font(.title).bold()
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }

            if let desc = track.description ?? track.summary, !desc.isEmpty {
                Text(desc).font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .padding(.horizontal, 16)
            }

            if case .loaded = phase, !lessons.isEmpty {
                Text("\(lessons.count) lesson\(lessons.count == 1 ? "" : "s")")
                    .font(.caption).bold()
                    .foregroundStyle(Color.reforgedGold)
                    .padding(.horizontal, 16)
            }
        }
    }

    private func load() async {
        do {
            let fetched = try await TracksRepository.shared.fetchLessons(trackId: track.id, includeDrafts: isOwner)
            lessons = fetched
            phase = .loaded
            for lesson in fetched {
                itemCounts[lesson.id] = (try? await TracksRepository.shared.fetchItems(lessonId: lesson.id))?.count
            }
        } catch {
            phase = .error(errorMessage(error))
        }
    }
}

private struct LearnLessonRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let number: Int
    let lesson: TrackLesson
    let itemCount: Int?

    var body: some View {
        HStack(spacing: 14) {
            if let path = lesson.coverImagePath, !path.isEmpty {
                SignedAsyncImage(bucket: "group-covers", path: path)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text("\(number)")
                    .font(.headline).bold()
                    .foregroundStyle(Color.reforgedGold)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.reforgedGold.opacity(0.15)))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title ?? "Lesson \(number)")
                    .font(.subheadline).bold()
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                if lesson.publishedAt == nil {
                    Text("Draft").font(.caption2).bold().foregroundStyle(Color.reforgedCoral)
                } else if let count = itemCount {
                    Text("\(count) item\(count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).bold()
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Lesson Detail (content blocks)

struct LessonDetailView: View {
    let lesson: TrackLesson
    let isOwner: Bool

    @State private var blocks: [LessonBlock] = []
    @State private var phase: LearnLoadPhase = .loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch phase {
                case .loading:
                    GroupsLoadingView(message: "Loading lesson…").frame(height: 200)
                case .error(let message):
                    GroupsErrorView(message: message) { Task { await load() } }.frame(height: 200)
                case .loaded where blocks.isEmpty:
                    GroupsMessageScaffold(systemImage: "doc.plaintext",
                                          title: "This lesson is empty",
                                          message: "No content blocks yet.")
                case .loaded:
                    ForEach(blocks) { block in
                        BlockView(block: block, isPrivileged: isOwner)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle(lesson.title ?? "Lesson")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do {
            blocks = try await TracksRepository.shared.fetchItems(lessonId: lesson.id)
            phase = .loaded
        } catch {
            phase = .error(errorMessage(error))
        }
    }
}

// MARK: - Block dispatcher

private struct BlockView: View {
    let block: LessonBlock
    let isPrivileged: Bool

    var body: some View {
        switch block.payload {
        case let .reading(reference, translation, body):   ReadingBlockView(reference: reference, translation: translation, inlineBody: body)
        case let .memory(reference, translation, text):    MemoryBlockView(reference: reference, translation: translation, text: text)
        case let .prompt(question, guidance):              PromptBlockView(question: question, guidance: guidance)
        case let .video(url, title, provider):             VideoBlockView(url: url, title: title, provider: provider)
        case let .audio(url, title, duration):             AudioBlockView(url: url, title: title, durationSeconds: duration)
        case let .handout(handoutId, title):               HandoutBlockView(handoutId: handoutId, title: title)
        case let .question(question, answerType, choices): QuestionBlockView(blockId: block.id, question: question, answerType: answerType, choices: choices)
        case let .discussion(prompt, notes):               DiscussionBlockView(prompt: prompt, notes: notes, showNotes: isPrivileged)
        case let .notes(body):                             NotesBlockView(markdownBody: body)
        case let .unknown(type):                           UnknownBlockView(type: type)
        }
    }
}

// MARK: - Shared block chrome

private struct BlockCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(label, systemImage: icon)
                .font(.caption).bold()
                .foregroundStyle(Color.reforgedGold)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private func openBible(_ reference: String) {
    NotificationCenter.default.post(name: .switchTab, object: nil,
                                    userInfo: [AppNotificationUserInfoKey.tab: 2])
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        NotificationCenter.default.post(name: .navigateToBibleVerse, object: nil,
                                        userInfo: [AppNotificationUserInfoKey.reference: reference])
    }
}

// MARK: - Reading

private struct ReadingBlockView: View {
    @Environment(\.colorScheme) private var colorScheme
    let reference: String?
    let translation: String?
    let inlineBody: String?

    var body: some View {
        BlockCard(icon: "book.fill", label: "Reading") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reference ?? "Passage").font(.title3).bold()
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    if let translation, !translation.isEmpty {
                        Text(translation).font(.caption).foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }
                Spacer()
            }
            if let inlineBody, !inlineBody.isEmpty {
                Text(inlineBody).font(.body).foregroundStyle(Color.adaptiveText(colorScheme))
            }
            if let reference, !reference.isEmpty {
                Button { openBible(reference) } label: {
                    Label("Open in Bible", systemImage: "arrow.up.forward")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedGold)
                }
            }
        }
    }
}

// MARK: - Memory

private struct MemoryBlockView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let reference: String?
    let translation: String?
    let text: String?
    @State private var added = false

    var body: some View {
        BlockCard(icon: "brain.head.profile", label: "Memory Verse") {
            Text(reference ?? "Memory Verse").font(.title3).bold()
                .foregroundStyle(Color.adaptiveText(colorScheme))
            if let text, !text.isEmpty {
                Text("“\(text)”").font(.body).italic()
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            Button {
                practice()
            } label: {
                Label(added ? "Added to Memory" : "Practice", systemImage: added ? "checkmark" : "plus.circle")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.reforgedGold)
            }
            .disabled(added)
        }
    }

    private func practice() {
        guard let text, !text.isEmpty else {
            if let reference { openBible(reference) }   // no verse text → open reader to add there
            return
        }
        let t = BibleTranslation(rawValue: translation ?? "") ?? .esv
        let verse = MemoryVerse(
            id: UUID().uuidString, reference: reference ?? "Memory Verse", text: text,
            esvText: t == .esv ? text : nil, category: "Group", translation: t.rawValue,
            lastFetched: AppDateFormatters.iso8601.string(from: Date()),
            nextReviewDate: Date(), reviewCount: 0, easeFactor: 2.5, interval: 1,
            isLearning: true, accuracy: nil, modeStats: nil)
        appState.addMemoryVerse(verse)
        added = true
        HapticManager.shared.success()
        NotificationCenter.default.post(name: .switchTab, object: nil,
                                        userInfo: [AppNotificationUserInfoKey.tab: 3])
    }
}

// MARK: - Prompt

private struct PromptBlockView: View {
    @Environment(\.colorScheme) private var colorScheme
    let question: String?
    let guidance: String?
    @State private var showJournal = false

    var body: some View {
        BlockCard(icon: "square.and.pencil", label: "Reflection Prompt") {
            Text(question ?? "Reflect").font(.body).bold()
                .foregroundStyle(Color.adaptiveText(colorScheme))
            if let guidance, !guidance.isEmpty {
                Text(guidance).font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            Button { showJournal = true } label: {
                Label("Journal this", systemImage: "square.and.pencil")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.reforgedGold)
            }
        }
        .sheet(isPresented: $showJournal) {
            NavigationStack { JournalView() }
        }
    }
}

// MARK: - Video

private struct VideoBlockView: View {
    @Environment(\.colorScheme) private var colorScheme
    let url: String?
    let title: String?
    let provider: String?

    var body: some View {
        BlockCard(icon: "play.rectangle.fill", label: title ?? "Video") {
            if let raw = url, let u = URL(string: raw) {
                if (provider ?? "").lowercased() == "mp4" {
                    VideoPlayer(player: AVPlayer(url: u))
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    LearnWebView(content: webContent(for: u))
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Text("Video unavailable.").font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
    }

    /// YouTube must be embedded as an iframe served from a page with a real origin — otherwise
    /// the player fails with error 153. Everything else (Vimeo, direct embeds) loads by URL.
    private func webContent(for url: URL) -> LearnWebContent {
        if let id = Self.youTubeID(from: url) {
            return .html(Self.youTubeEmbedHTML(id: id),
                         baseURL: URL(string: "https://www.youtube.com"))
        }
        return .url(url)
    }

    /// Extracts the 11-ish char video id from watch, youtu.be, embed, or shorts URLs.
    private static func youTubeID(from url: URL) -> String? {
        let s = url.absoluteString
        guard s.contains("youtube.com") || s.contains("youtu.be") else { return nil }
        if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "v" })?.value, !id.isEmpty {
            return id
        }
        // youtu.be/<id>, /embed/<id>, /shorts/<id>
        let parts = url.pathComponents.filter { $0 != "/" }
        if s.contains("youtu.be/") { return parts.last }
        if let idx = parts.firstIndex(where: { $0 == "embed" || $0 == "shorts" }),
           idx + 1 < parts.count {
            return parts[idx + 1]
        }
        return nil
    }

    private static func youTubeEmbedHTML(id: String) -> String {
        // The iframe host matches the baseURL (www.youtube.com) so the /embed/ request carries
        // a valid same-origin Referer — that's what satisfies YouTube's embed check. Do NOT add
        // an `origin=` param here: it's only valid with `enablejsapi=1` and otherwise trips the
        // 152/153 "video unavailable" errors.
        """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>*{margin:0;padding:0;background:transparent}html,body{height:100%}
        .wrap{position:relative;width:100%;height:100%;overflow:hidden}
        iframe{position:absolute;top:0;left:0;width:100%;height:100%;border:0}</style>
        </head><body><div class="wrap">
        <iframe src="https://www.youtube.com/embed/\(id)?playsinline=1&rel=0&modestbranding=1"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
        allowfullscreen></iframe></div></body></html>
        """
    }
}

// MARK: - Audio

private struct AudioBlockView: View {
    @Environment(\.colorScheme) private var colorScheme
    let url: String?
    let title: String?
    let durationSeconds: Int?
    @State private var player: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        BlockCard(icon: "waveform", label: "Audio") {
            HStack(spacing: 14) {
                Button {
                    toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.reforgedGold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title ?? "Audio").font(.subheadline).bold()
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    if let d = durationSeconds {
                        Text(formatted(d)).font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }
                Spacer()
            }
        }
        .onDisappear { player?.pause() }
    }

    private func toggle() {
        if player == nil, let raw = url, let u = URL(string: raw) {
            // Background-capable playback (app already declares the audio mode
            // for Bible audio); route to playback so it continues when backgrounded.
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player = AVPlayer(url: u)
        }
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Handout

private struct HandoutBlockView: View {
    @Environment(\.colorScheme) private var colorScheme
    let handoutId: String?
    let title: String?
    @State private var handout: Handout?
    @State private var loading = false
    @State private var failed = false

    var body: some View {
        BlockCard(icon: "doc.text.fill", label: "Handout") {
            Text(title ?? handout?.title ?? "Handout").font(.subheadline).bold()
                .foregroundStyle(Color.adaptiveText(colorScheme))
            if let handout {
                NavigationLink { HandoutDetailView(handout: handout) } label: {
                    Label("Open handout", systemImage: "arrow.up.forward")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.reforgedGold)
                }
            } else if loading {
                ProgressView()
            } else if failed {
                Text("Couldn't load this handout.").font(.caption).foregroundStyle(Color.reforgedCoral)
            }
        }
        .task { await fetch() }
    }

    private func fetch() async {
        guard handout == nil, let id = handoutId, !id.isEmpty else { failed = (handoutId?.isEmpty ?? true); return }
        loading = true; defer { loading = false }
        handout = try? await TracksRepository.shared.handout(id: id)
        failed = (handout == nil)
    }
}

// MARK: - Question (responses persisted locally — TODO: backend write)

private struct QuestionBlockView: View {
    @Environment(\.colorScheme) private var colorScheme
    let blockId: String
    let question: String?
    let answerType: String?
    let choices: [String]?
    @State private var answer = ""

    private var storeKey: String { "learn.answer.\(blockId)" }

    var body: some View {
        BlockCard(icon: "questionmark.circle.fill", label: "Question") {
            Text(question ?? "Question").font(.body).bold()
                .foregroundStyle(Color.adaptiveText(colorScheme))

            switch (answerType ?? "short").lowercased() {
            case "multiple_choice":
                ForEach(choices ?? [], id: \.self) { choice in
                    Button { answer = choice; persist() } label: {
                        HStack {
                            Image(systemName: answer == choice ? "largecircle.fill.circle" : "circle")
                            Text(choice)
                            Spacer()
                        }
                        .foregroundStyle(answer == choice ? Color.reforgedGold : Color.adaptiveText(colorScheme))
                    }
                }
            case "long":
                TextEditor(text: $answer)
                    .frame(minHeight: 90)
                    .padding(8)
                    .background(Color.adaptiveSecondaryBackground(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onChange(of: answer) { _ in persist() }
            default: // short
                TextField("Your answer", text: $answer)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: answer) { _ in persist() }
            }
        }
        .onAppear { answer = UserDefaults.standard.string(forKey: storeKey) ?? "" }
    }

    // Local-only for now; backend write is a follow-up.
    private func persist() { UserDefaults.standard.set(answer, forKey: storeKey) }
}

// MARK: - Discussion

private struct DiscussionBlockView: View {
    @Environment(\.colorScheme) private var colorScheme
    let prompt: String?
    let notes: String?
    let showNotes: Bool

    var body: some View {
        BlockCard(icon: "bubble.left.and.bubble.right.fill", label: "Discussion") {
            Text(prompt ?? "Discuss").font(.body).bold()
                .foregroundStyle(Color.adaptiveText(colorScheme))
            if showNotes, let notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Leader notes").font(.caption2).bold()
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Text(notes).font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }
                .padding(10)
                .background(Color.reforgedGold.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// MARK: - Notes (markdown)

private struct NotesBlockView: View {
    @Environment(\.colorScheme) private var colorScheme
    let markdownBody: String?

    var body: some View {
        BlockCard(icon: "note.text", label: "Notes") {
            Text(BibleReferenceScanner.addingLinks(to: markdown(markdownBody ?? "")))
                .font(.body)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .tint(Color.reforgedGold)
                .environment(\.openURL, OpenURLAction { url in
                    guard url.scheme == "bibleverse",
                          let encoded = url.host,
                          let reference = encoded.removingPercentEncoding else { return .systemAction }
                    openBible(reference)
                    return .handled
                })
        }
    }

    private func markdown(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }
}

// MARK: - Unknown

private struct UnknownBlockView: View {
    @Environment(\.colorScheme) private var colorScheme
    let type: String

    var body: some View {
        BlockCard(icon: "questionmark.square.dashed", label: "Unsupported") {
            Text("This content type (“\(type)”) isn't supported in this version — please update the app.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
    }
}

// MARK: - Error helper

private func errorMessage(_ error: Error) -> String {
    if case let GroupsError.badResponse(status, message) = error {
        if status == 401 { return "Your session expired. Please sign in again from Settings." }
        return message ?? "The server returned an error (status \(status))."
    }
    return (error as? GroupsError)?.errorDescription ?? error.localizedDescription
}
