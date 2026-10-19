import SwiftUI

// MARK: - Coming from another Bible app

/// "Coming from YouVersion?": bring saved verses over as Memory verses and set your place in
/// a reading plan, so switching costs nothing. YouVersion offers no export, so this works
/// from text the person copies or shares out of that app (references or bible.com links).
struct SwitchFromYouVersionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var plans = ReadingPlanService.shared

    private struct FoundVerse: Identifiable {
        let reference: String
        var selected = true
        var id: String { reference }
    }

    @State private var pasted = ""
    @State private var found: [FoundVerse] = []
    @State private var hasSearched = false
    @State private var isAdding = false
    @State private var addProgress = 0
    @State private var addSummary: String?

    @State private var planId = BibleReadingPlans.all.first?.id ?? ""
    @State private var nextDay = 1
    @State private var planSummary: String?

    private var selectedCount: Int { found.filter(\.selected).count }

    private var selectedPlan: BibleReadingPlan? {
        BibleReadingPlans.all.first { $0.id == planId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                versesSection
                planSection
                carriesOverSection
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Coming from YouVersion?")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 6) {
            Text("Bring your verses with you")
                .font(.title2.bold())
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text("Keep what you saved and your place in a plan. It takes about a minute.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity)
    }

    private var versesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PracticeSectionLabel(text: "1. Your saved verses")

            Text("In YouVersion, share or copy your saved verses (links work too), then paste them here.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $pasted)
                    .frame(minHeight: 130)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .practiceCard(radius: 16)
                    .onChange(of: pasted) { _ in
                        hasSearched = false
                        addSummary = nil
                    }
                if pasted.isEmpty {
                    Text("John 3:16\nPsalm 23:1-4\nhttps://www.bible.com/bible/111/ROM.8.28")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }

            PracticeButton(title: "Find verses", enabled: !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                findVerses()
            }
            .padding(.horizontal, -16)

            if hasSearched {
                if found.isEmpty {
                    Text("No verses found. Try pasting the references as plain text, like \"John 3:16\".")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                } else {
                    foundList
                }
            }

            if let addSummary {
                Text(addSummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.practiceGreen)
            }
        }
    }

    private var foundList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Found \(found.count) \(found.count == 1 ? "verse" : "verses")")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                Button(selectedCount == found.count ? "Deselect all" : "Select all") {
                    let all = selectedCount != found.count
                    for index in found.indices { found[index].selected = all }
                }
                .font(.subheadline.weight(.semibold))
            }

            VStack(spacing: 0) {
                ForEach($found) { $verse in
                    Toggle(isOn: $verse.selected) {
                        Text(verse.reference)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                    .tint(Color.reforgedCoral)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    if verse.id != found.last?.id { Divider().padding(.leading, 16) }
                }
            }
            .practiceCard(radius: 16)

            Text("Verses are added in the King James text to start. You can change a verse's translation later.")
                .font(.footnote)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            PracticeButton(
                title: isAdding ? "Adding \(addProgress) of \(selectedCount)" : "Add \(selectedCount) to Memory",
                enabled: selectedCount > 0 && !isAdding
            ) { addSelected() }
            .padding(.horizontal, -16)
        }
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PracticeSectionLabel(text: "2. Your place in a plan")

            Text("Partway through a plan? Pick the same one and the day you are on, and earlier days are marked read.")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Plan").foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer(minLength: 8)
                    // A menu with a one-line label: the system Picker wraps long plan names.
                    Menu {
                        ForEach(BibleReadingPlans.all) { plan in
                            Button {
                                planId = plan.id
                                nextDay = min(nextDay, plan.totalDays)
                                planSummary = nil
                            } label: {
                                if plan.id == planId { Label(plan.name, systemImage: "checkmark") }
                                else { Text(plan.name) }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedPlan?.name ?? "Choose")
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.reforgedCoral)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)

                Divider().padding(.leading, 16)

                Stepper(value: $nextDay, in: 1...max(selectedPlan?.totalDays ?? 1, 1)) {
                    HStack {
                        Text("Today's reading is day").foregroundStyle(Color.adaptiveText(colorScheme))
                        Text("\(nextDay)").fontWeight(.bold).foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .onChange(of: nextDay) { _ in planSummary = nil }
            }
            .practiceCard(radius: 16)

            PracticeButton(title: "Set my place", enabled: nextDay > 1 && !planId.isEmpty) {
                setPlace()
            }
            .padding(.horizontal, -16)

            if let planSummary {
                Text(planSummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.practiceGreen)
            }
        }
    }

    private var carriesOverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PracticeSectionLabel(text: "What carries over")
            VStack(alignment: .leading, spacing: 14) {
                carryRow("brain.head.profile", "Saved verses become Memory verses, reviewed on a schedule so they stick.")
                carryRow("calendar", "Plans pick up from the day you choose. Earlier days are marked read without streak credit.")
                carryRow("flame.fill", "Your streak starts with your first reading here.")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .practiceCard(radius: 16)
        }
    }

    private func carryRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.reforgedCoral)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
        }
    }

    // MARK: Actions

    private func findVerses() {
        HapticManager.shared.lightImpact()
        found = YouVersionReferenceParser.references(in: pasted).map { FoundVerse(reference: $0) }
        hasSearched = true
        addSummary = nil
    }

    private func addSelected() {
        let chosen = found.filter(\.selected).map(\.reference)
        guard !chosen.isEmpty, !isAdding else { return }
        isAdding = true
        addProgress = 0
        addSummary = nil

        Task { @MainActor in
            var added = 0, alreadyThere = 0, failed = 0
            for (index, reference) in chosen.enumerated() {
                addProgress = index + 1
                if appState.memoryVerses.contains(where: { $0.reference == reference }) {
                    alreadyThere += 1
                    continue
                }
                do {
                    let text = try await VerseTextFetcher.kjv(reference: reference)
                    let verse = MemoryVerse(
                        id: UUID().uuidString, reference: reference, text: text, esvText: nil,
                        category: "General", translation: "KJV",
                        lastFetched: AppDateFormatters.iso8601.string(from: Date()),
                        nextReviewDate: Date(), reviewCount: 0, easeFactor: 2.5, interval: 1,
                        isLearning: true, accuracy: nil, modeStats: nil)
                    // Only the last verse pulls the Memory journey to it; the rest add quietly.
                    appState.addMemoryVerse(verse, revealInJourney: index == chosen.count - 1)
                    added += 1
                } catch {
                    failed += 1
                }
            }
            isAdding = false
            HapticManager.shared.success()
            var parts = ["Added \(added) to Memory"]
            if alreadyThere > 0 { parts.append("\(alreadyThere) already there") }
            if failed > 0 { parts.append("\(failed) couldn't be loaded, try again later") }
            addSummary = parts.joined(separator: ", ") + "."
        }
    }

    private func setPlace() {
        guard let plan = selectedPlan else { return }
        HapticManager.shared.success()
        plans.catchUp(planId: plan.id, nextDay: nextDay)
        planSummary = "Marked days 1 to \(nextDay - 1) of \(plan.name) as read."
    }
}

// MARK: - Challenge sheet (opened from a "memorize this with me" link)

struct VerseChallengeSheet: View {
    let invite: VerseChallengeInvite
    let onStart: (MemoryVerse) -> Void
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var text: String?
    @State private var loadFailed = false

    private var alreadyMemorizing: Bool {
        appState.memoryVerses.contains { $0.reference == invite.reference }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            Image(systemName: "person.2.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color.reforgedCoral, in: Circle())

            VStack(spacing: 6) {
                Text(invite.from.isEmpty ? "A friend challenged you" : "\(invite.from) challenged you")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                Text("Memorize \(invite.reference)")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }

            Group {
                if let text {
                    Text("\u{201C}\(text)\u{201D}")
                        .font(Font.custom("LibreBaskerville-Italic", size: 16))
                        .lineSpacing(6)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                } else if loadFailed {
                    Text("Couldn't load the verse text right now. You can still start.")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                } else {
                    ProgressView()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .practiceCard(radius: 18)
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 8) {
                PracticeButton(title: alreadyMemorizing ? "Already in your Memory" : "Start memorizing",
                               enabled: !alreadyMemorizing && text != nil) {
                    start()
                }
                Button("Not now") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .task {
            do { text = try await VerseTextFetcher.kjv(reference: invite.reference) }
            catch { loadFailed = true }
        }
    }

    private func start() {
        guard let text else { return }
        // A transient verse, like a new curriculum node: it joins Memory when the lesson finishes.
        let verse = MemoryVerse(
            id: UUID().uuidString, reference: invite.reference, text: text, esvText: nil,
            category: "General", translation: "KJV",
            lastFetched: AppDateFormatters.iso8601.string(from: Date()),
            nextReviewDate: Date(), reviewCount: 0, easeFactor: 2.5, interval: 1,
            isLearning: true, accuracy: nil, modeStats: nil)
        dismiss()
        onStart(verse)
    }
}

// MARK: - Switch kit (a shareable poster to send friends)

struct SwitchKitCard: View {
    private let canvas = Color(red: 250/255, green: 248/255, blue: 245/255)
    private let ink = Color(red: 45/255, green: 45/255, blue: 45/255)
    private let secondary = Color(red: 102/255, green: 102/255, blue: 102/255)
    private let hairline = Color(red: 229/255, green: 229/255, blue: 229/255)
    private let coral = Color(red: 233/255, green: 69/255, blue: 96/255)
    private let goldText = Color(red: 176/255, green: 127/255, blue: 78/255)

    var body: some View {
        ZStack {
            canvas

            VStack(alignment: .leading, spacing: 0) {
                Image("ReforgedMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)

                Spacer(minLength: 48)

                Text("FOR YOUR BIBLE READING")
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(28 * 0.12)
                    .foregroundStyle(goldText)

                VStack(alignment: .leading, spacing: 8) {
                    Text("READ IT.").foregroundStyle(ink)
                    Text("MEMORIZE IT.").foregroundStyle(ink)
                    Text("LIVE IT.").foregroundStyle(coral)
                }
                .font(.custom("ArchivoBlack-Regular", size: 132))
                .tracking(-2.5)
                .lineLimit(1)
                .minimumScaleFactor(0.35)
                .padding(.top, 24)

                Text("Reforged turns the Bible you read into Scripture you actually keep.")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(secondary)
                    .lineSpacing(6)
                    .padding(.top, 32)

                VStack(alignment: .leading, spacing: 28) {
                    featureRow("brain.head.profile", "Spaced repetition that makes verses stick")
                    featureRow("flame.fill", "A daily streak that keeps you coming back")
                    featureRow("person.2.fill", "Memorize alongside your friends")
                }
                .padding(48)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(hairline, lineWidth: 2))
                .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
                .padding(.top, 56)

                Spacer(minLength: 48)

                Rectangle().fill(hairline).frame(height: 2)

                HStack {
                    Text("Bring your verses over in a minute")
                    Spacer(minLength: 24)
                    Text("@reforgedapp")
                }
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(secondary)
                .padding(.top, 32)
            }
            .padding(96)
        }
        .frame(width: 1080, height: 1350)
        .clipped()
        .environment(\.colorScheme, .light)
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(coral, in: Circle())
            Text(text)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SwitchKitView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var renderedImage: UIImage?
    @State private var showShareSheet = false
    @State private var showSaved = false

    private let shareText = """
    Reforged helps you memorize the Bible you read. It's free, and if you're coming from YouVersion you can bring your verses over in a minute. https://reforgedapp.org @reforgedapp
    """

    var body: some View {
        VStack(spacing: 24) {
            GeometryReader { geo in
                let scale = min(geo.size.width / 1080, geo.size.height / 1350)
                SwitchKitCard()
                    .scaleEffect(scale)
                    .frame(width: 1080 * scale, height: 1350 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack(spacing: 8) {
                PracticeButton(title: "Send to a friend", icon: "square.and.arrow.up") {
                    HapticManager.shared.mediumImpact()
                    renderImage()
                    showShareSheet = true
                }

                Button {
                    HapticManager.shared.lightImpact()
                    renderImage()
                    if let image = renderedImage {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        showSaved = true
                    }
                } label: {
                    Label("Save to Photos", systemImage: "photo.on.rectangle")
                        .font(.headline.bold())
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(PracticeLipButtonStyle(
                    face: Color.adaptiveCardBackground(colorScheme),
                    lip: Color.adaptiveBorder(colorScheme),
                    stroke: Color.adaptiveBorder(colorScheme),
                    cornerRadius: 16, depth: 5))
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
        .navigationTitle("Switch kit")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let image = renderedImage {
                ShareSheet(activityItems: [image, shareText])
            }
        }
        .alert("Saved!", isPresented: $showSaved) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The poster has been saved to your photo library.")
        }
    }

    @MainActor
    private func renderImage() {
        guard renderedImage == nil else { return }
        let renderer = ImageRenderer(content: SwitchKitCard())
        renderer.scale = 2.0
        renderedImage = renderer.uiImage
    }
}
