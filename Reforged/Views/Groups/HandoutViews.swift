import SwiftUI

// MARK: - Handouts (Sunday School lessons)
//
// Lists a group's published handouts and renders each as an interactive
// fill-in-the-blank lesson from the `segments` jsonb, plus a signed-URL download
// of the original file (private `handout-uploads` bucket, member-gated by RLS).

private let handoutUploadsBucket = "handout-uploads"

// MARK: - List

struct GroupHandoutsList: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var model: GroupsHubViewModel
    let group: GroupSummary

    var body: some View {
        LazyVStack(spacing: 12) {
            if model.handouts.isEmpty {
                GroupsMessageScaffold(
                    systemImage: "doc.text",
                    title: "No handouts yet",
                    message: "When your leader publishes a handout, it'll show up here as an interactive lesson."
                )
                .padding(.top, 40)
            } else {
                ForEach(model.handouts) { handout in
                    NavigationLink {
                        HandoutDetailView(handout: handout)
                    } label: {
                        HandoutRow(handout: handout)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct HandoutRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let handout: Handout

    private var blankCount: Int { (handout.segments ?? []).filter { $0.isBlank }.count }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .foregroundStyle(Color.reforgedGold)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(handout.title)
                    .font(.subheadline).bold()
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .lineLimit(2)
                if blankCount > 0 {
                    Text("\(blankCount) fill-in-the-blank\(blankCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption).bold()
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .padding(14)
        .background(Color.adaptiveCardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Detail (interactive lesson)

struct HandoutDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    let handout: Handout

    /// Typed answers keyed by blank index, and a reveal-all toggle.
    @State private var answers: [Int: String] = [:]
    @State private var showAnswers = false
    @State private var isDownloading = false
    @State private var downloadError: String?

    /// Parsed ONCE and held in state. If this were a computed property it would
    /// re-parse on every keystroke, minting new token identities and recreating
    /// the TextFields — which drops focus after each character typed.
    @State private var paragraphs: [[HandoutToken]]

    init(handout: Handout) {
        self.handout = handout
        _paragraphs = State(initialValue: HandoutToken.paragraphs(from: handout.segments ?? []))
    }

    private var totalBlanks: Int {
        paragraphs.flatMap { $0 }.reduce(0) { $0 + ($1.isBlank ? 1 : 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if totalBlanks > 0 { controlBar }

                if !paragraphs.isEmpty {
                    lesson
                } else if let body = handout.bodyText, !body.isEmpty {
                    // No segments → show the plain extracted text.
                    Text(body)
                        .font(.body)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }

                if handout.storagePath != nil { downloadButton }
                if let downloadError {
                    Text(downloadError).font(.caption).foregroundStyle(Color.reforgedCoral)
                }
            }
            .padding(20)
        }
        .navigationTitle(handout.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Blanks the reader has typed correctly (case/whitespace-insensitive).
    private var correctCount: Int {
        paragraphs.flatMap { $0 }.reduce(0) { acc, token in
            if case .blank(let answer) = token.kind, let idx = token.blankIndex, isCorrect(idx, answer) {
                return acc + 1
            }
            return acc
        }
    }

    private func isCorrect(_ idx: Int, _ answer: String) -> Bool {
        (answers[idx] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            .compare(answer.trimmingCharacters(in: .whitespacesAndNewlines), options: .caseInsensitive) == .orderedSame
    }

    private func answerBinding(_ idx: Int) -> Binding<String> {
        Binding(get: { answers[idx] ?? "" }, set: { answers[idx] = $0 })
    }

    private var controlBar: some View {
        HStack {
            Text("\(correctCount)/\(totalBlanks) correct")
                .font(.caption).bold()
                .foregroundStyle(correctCount == totalBlanks ? Color.reforgedGold : Color.adaptiveTextSecondary(colorScheme))
            Spacer()
            Button(showAnswers ? "Hide answers" : "Show answers") {
                HapticManager.shared.buttonTap()
                withAnimation(.easeInOut(duration: 0.15)) { showAnswers.toggle() }
            }
            .font(.subheadline).fontWeight(.semibold)
            .foregroundStyle(Color.reforgedGold)
        }
    }

    private var lesson: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, tokens in
                if tokens.isEmpty {
                    Spacer().frame(height: 6)   // blank line between paragraphs
                } else {
                    FlowLayout(spacing: 5, lineSpacing: 7) {
                        ForEach(tokens) { token in
                            tokenView(token)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func tokenView(_ token: HandoutToken) -> some View {
        switch token.kind {
        case .word(let text):
            Text(text)
                .font(.body)
                .foregroundStyle(Color.adaptiveText(colorScheme))
        case .blank(let answer):
            let idx = token.blankIndex ?? -1
            let width = max(56, CGFloat(answer.count) * 12 + 20)
            if showAnswers {
                // Answer key mode.
                Text(answer)
                    .font(.body).bold()
                    .foregroundStyle(Color.reforgedGold)
                    .frame(minWidth: width)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.reforgedGold.opacity(0.5)).frame(height: 1.5)
                    }
            } else {
                let typed = answers[idx] ?? ""
                let correct = isCorrect(idx, answer)
                let underline: Color = correct ? Color.reforgedGold
                    : (typed.isEmpty ? Color.adaptiveTextSecondary(colorScheme) : Color.reforgedCoral)
                TextField("", text: answerBinding(idx))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.next)
                    .frame(width: width)
                    .foregroundStyle(correct ? Color.reforgedGold : Color.adaptiveText(colorScheme))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(underline).frame(height: 1.5)
                    }
                    .overlay(alignment: .trailing) {
                        if correct {
                            Image(systemName: "checkmark")
                                .font(.caption2).bold()
                                .foregroundStyle(Color.reforgedGold)
                        }
                    }
            }
        }
    }

    private var downloadButton: some View {
        Button {
            Task { await download() }
        } label: {
            HStack {
                if isDownloading { ProgressView().tint(.white) }
                Image(systemName: "arrow.down.circle")
                Text(isDownloading ? "Preparing…" : "Download original")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.reforgedGold)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isDownloading)
        .padding(.top, 8)
    }

    private func download() async {
        guard let path = handout.storagePath else { return }
        isDownloading = true
        downloadError = nil
        defer { isDownloading = false }
        do {
            let url = try await GroupsService.shared.signedURL(bucket: handoutUploadsBucket, path: path)
            openURL(url)
        } catch {
            downloadError = "Couldn't prepare the download. Please try again."
        }
    }
}

// MARK: - Token model

/// A renderable unit of a handout paragraph: a plain word or a fill-in blank.
struct HandoutToken: Identifiable {
    enum Kind { case word(String); case blank(answer: String) }
    let id = UUID()
    let kind: Kind
    /// Sequential index across the whole handout, used to track reveal state.
    let blankIndex: Int?

    var isBlank: Bool { if case .blank = kind { return true }; return false }

    /// Flattens `segments` into paragraphs (split on newlines) of word/blank
    /// tokens, so blanks stay inline with the surrounding words.
    static func paragraphs(from segments: [HandoutSegment]) -> [[HandoutToken]] {
        var paragraphs: [[HandoutToken]] = []
        var current: [HandoutToken] = []
        var blankCounter = 0

        func pushParagraph() { paragraphs.append(current); current = [] }

        for segment in segments {
            if segment.isBlank {
                current.append(HandoutToken(kind: .blank(answer: segment.answer ?? ""),
                                            blankIndex: blankCounter))
                blankCounter += 1
            } else {
                let lines = (segment.value ?? "").components(separatedBy: "\n")
                for (i, line) in lines.enumerated() {
                    for word in line.split(whereSeparator: { $0 == " " || $0 == "\t" }) {
                        current.append(HandoutToken(kind: .word(String(word)), blankIndex: nil))
                    }
                    if i < lines.count - 1 { pushParagraph() } // newline => paragraph break
                }
            }
        }
        pushParagraph()
        return paragraphs
    }
}
