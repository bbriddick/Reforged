import SwiftUI

// MARK: - Read Together (cards inside the Friends tab)

struct ReadTogetherCards: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = SharedReadingsStore.shared
    @ObservedObject private var friends = FriendsStore.shared

    @State private var showPropose = false
    @State private var readingToEnd: SharedReading?

    private var requests: [SharedReading] { store.readings.filter(\.needsMyResponse) }
    private var active: [SharedReading] { store.readings.filter(\.isActive) }
    private var waiting: [SharedReading] { store.readings.filter { $0.isPending && $0.createdByMe } }

    var body: some View {
        VStack(spacing: FriendsLayout.sectionSpacing) {
            if !requests.isEmpty { requestsBlock }
            readBlock
        }
        .sheet(isPresented: $showPropose) { ProposeReadingSheet() }
        .alert("Stop reading together?", isPresented: Binding(get: { readingToEnd != nil }, set: { if !$0 { readingToEnd = nil } })) {
            Button("Stop sharing", role: .destructive) { if let r = readingToEnd { Task { await store.end(r) } } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(readingToEnd?.friendName ?? "Your friend") will no longer see your progress. Your own reading progress isn't affected.")
        }
    }

    // MARK: Requests

    private var requestsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            FriendsSectionHeader(title: "Reading requests")
            VStack(spacing: 0) {
                ForEach(Array(requests.enumerated()), id: \.element.id) { index, r in
                    if index > 0 { Divider() }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(r.friendName) wants to read \(store.title(for: r)) with you")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text(r.isPlan ? "\(r.totalDays)-day plan · each at your own pace" : "One passage")
                            .font(.footnote)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        HStack(spacing: 10) {
                            Button("Accept") { Task { await store.accept(r) } }
                                .buttonStyle(PillButtonStyle())
                            Button("Not now") { Task { await store.decline(r) } }
                                .buttonStyle(PillButtonStyle(filled: false))
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
            .friendsCard()
        }
    }

    // MARK: Active readings

    private var readBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            FriendsSectionHeader(title: "Read Together") {
                if !active.isEmpty || !waiting.isEmpty {
                    Button { showPropose = true } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.reforgedGold)
                            .frame(width: 44, height: 44)
                            .background(Color.reforgedGold.opacity(0.14), in: Circle())
                    }
                    .accessibilityLabel("Start reading together")
                }
            }

            if active.isEmpty && waiting.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.reforgedGold)
                    Text("Read the Bible side by side")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Pick a reading plan or a passage. Each of you reads at your own pace, ticks it off, and cheers the other on.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    Button { showPropose = true } label: {
                        Label("Choose a reading", systemImage: "plus")
                    }
                    .buttonStyle(PillButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .friendsCard(padding: 24)
            } else {
                ForEach(active) { r in readingCard(r) }
                ForEach(waiting) { r in
                    HStack(spacing: 12) {
                        Image(systemName: "hourglass").foregroundStyle(.secondary).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.title(for: r)).font(.body.weight(.semibold))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Text("Waiting for \(r.friendName)")
                                .font(.footnote)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        Spacer()
                        Button("Cancel") { Task { await store.end(r) } }
                            .buttonStyle(PillButtonStyle(filled: false))
                    }
                    .friendsCard()
                }
            }
        }
    }

    private func readingCard(_ r: SharedReading) -> some View {
        let mine = store.myDays(for: r)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.title(for: r))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("with \(r.friendName)")
                        .font(.footnote)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                Spacer(minLength: 8)
                if r.pairStreak > 0 {
                    Label("\(r.pairStreak)", systemImage: "flame.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10).frame(minHeight: 32)
                        .background(Color.orange.opacity(0.14), in: Capsule())
                }
                Menu {
                    Button { Task { await store.remind(r) } } label: { Label("Remind \(r.friendName)", systemImage: "bell") }
                    Button(role: .destructive) { readingToEnd = r } label: { Label("Stop sharing", systemImage: "xmark.circle") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .padding(.trailing, -10).padding(.top, -10)
            }

            HStack(alignment: .top, spacing: 16) {
                progressColumn(name: "You", done: mine, total: r.totalDays, readToday: r.iReadToday, isPlan: r.isPlan)
                progressColumn(name: r.friendName, done: r.friendDays ?? 0, total: r.totalDays, readToday: r.friendReadToday, isPlan: r.isPlan)
            }

            if r.isPlan, let next = store.nextDayProgress(for: r), mine < r.totalDays {
                HStack(spacing: 6) {
                    Image(systemName: "book.closed")
                        .font(.footnote)
                        .foregroundStyle(Color.reforgedGold)
                    Text("Next: \(next.label)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    if next.total > 1 {
                        Text("· \(next.read) of \(next.total) chapters read")
                            .font(.footnote)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                }
            }

            statusLine(r, mine: mine)

            if mine < r.totalDays {
                HStack(spacing: 10) {
                    Button { store.openToday(r) } label: {
                        Label(r.isPlan ? "Read now" : "Open passage", systemImage: "book.fill")
                    }
                    .buttonStyle(PillButtonStyle())
                    if r.isPlan && !store.canMarkDone(r) {
                        // One day per calendar day: the next one opens tomorrow.
                        Label("Done for today", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .frame(minHeight: 38)
                            .padding(.horizontal, 6)
                    } else {
                        Button {
                            Task { r.isPlan ? await store.markNextDayDone(r) : await store.markPassageRead(r) }
                        } label: {
                            Label(r.isPlan ? "Mark done" : "I read it", systemImage: "checkmark")
                        }
                        .buttonStyle(PillButtonStyle(filled: false))
                    }
                }
            }
        }
        .friendsCard()
    }

    private func progressColumn(name: String, done: Int, total: Int, readToday: Bool, isPlan: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .lineLimit(1)
                Image(systemName: readToday ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                    .foregroundStyle(readToday ? Color.green : Color.secondary.opacity(0.6))
            }
            Text(isPlan ? "Day \(min(done + (done < total ? 1 : 0), total)) of \(total)" : (done >= 1 ? "Read" : "Not yet"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.reforgedGold.opacity(0.15))
                    Capsule().fill(Color.reforgedGold)
                        .frame(width: geo.size.width * CGFloat(min(done, total)) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func statusLine(_ r: SharedReading, mine: Int) -> some View {
        if r.finishedTogether {
            Label("You both finished", systemImage: "checkmark.seal.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.reforgedGold)
        } else if r.iReadToday && r.friendReadToday {
            Label("You both read today", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.green)
        } else if !r.iReadToday && mine < r.totalDays {
            Text("Do today's reading to keep your streak going")
                .font(.footnote)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        } else if r.iReadToday {
            Text("Waiting on \(r.friendName) today")
                .font(.footnote)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
    }
}

// MARK: - Start a reading (styled like the Add Verse sheet)

struct ProposeReadingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var friends = FriendsStore.shared
    @ObservedObject private var store = SharedReadingsStore.shared

    private enum Mode: String, CaseIterable { case plan = "Reading plan", passage = "Passage" }

    @State private var friendId = ""
    @State private var mode: Mode = .plan
    @State private var planId = ""
    @State private var passage = ""
    @State private var sending = false
    @FocusState private var passageFocused: Bool

    private var friend: FriendActivity? { friends.friends.first { $0.friendId == friendId } }
    private var selectedPlan: BibleReadingPlan? { SharedReadingsStore.sharablePlans.first { $0.id == planId } }
    private var cleanPassage: String { passage.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var passageIsValid: Bool {
        cleanPassage.range(of: #"^[1-3]? ?[A-Za-z][A-Za-z .]{0,28} [0-9]{1,3}([:-][0-9]{1,3})?(-[0-9]{1,3}(:[0-9]{1,3})?)?$"#,
                           options: .regularExpression) != nil
    }

    private var canSend: Bool {
        guard friend != nil, !sending else { return false }
        return mode == .plan ? selectedPlan != nil : passageIsValid
    }

    private var sendTitle: String {
        guard canSend, let friend else { return "Send Invite" }
        let what = mode == .plan ? (selectedPlan?.name ?? "") : cleanPassage
        return "Invite \(friend.displayName) to read \(what)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ReforgedTheme.spacingL) {
                    friendSection
                    modePicker
                    if mode == .plan { planList } else { passageField }
                    Text("\(friend?.displayName ?? "Your friend") sees which reading it is and how far you are. Each of you reads in your own Bible, at your own pace.")
                        .font(.footnote)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, ReforgedTheme.spacingS)
                .padding(.bottom, ReforgedTheme.spacingL)
                .readableContentWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { sendBar }
            .navigationTitle("Read Together")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear {
                store.errorMessage = nil
                if friendId.isEmpty { friendId = friends.friends.first?.friendId ?? "" }
            }
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var friendSection: some View {
        if friends.friends.count > 1 {
            VStack(alignment: .leading, spacing: ReforgedTheme.spacingS + 4) {
                sectionLabel("With")
                chipRow(items: friends.friends.map { ($0.friendId, $0.displayName) }, selection: $friendId)
            }
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: ReforgedTheme.spacingS + 4) {
            sectionLabel("Read")
            chipRow(items: Mode.allCases.map { ($0.rawValue, $0.rawValue) },
                    selection: Binding(get: { mode.rawValue }, set: { mode = Mode(rawValue: $0) ?? .plan }))
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            .padding(.horizontal, 4)
    }

    private func chipRow(items: [(id: String, label: String)], selection: Binding<String>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReforgedTheme.spacingS) {
                ForEach(items, id: \.id) { item in
                    let selected = item.id == selection.wrappedValue
                    Button { selection.wrappedValue = item.id } label: {
                        Text(item.label)
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Color.adaptiveCardBackground(colorScheme) : Color.adaptiveText(colorScheme))
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(selected ? Color.adaptiveNavyText(colorScheme) : Color.adaptiveChipBackground(colorScheme))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(NoBlobButtonStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
    }

    private var planList: some View {
        VStack(alignment: .leading, spacing: ReforgedTheme.spacingS + 4) {
            sectionLabel("Choose a plan")
            VStack(spacing: 0) {
                let plans = SharedReadingsStore.sharablePlans
                ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                    let selected = plan.id == planId
                    Button { planId = plan.id } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.adaptiveText(colorScheme))
                                Text("\(plan.totalDays) days")
                                    .font(.caption)
                                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            }
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected ? Color.reforgedGold : Color.adaptiveTextSecondary(colorScheme).opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NoBlobButtonStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    if index < plans.count - 1 { Divider().padding(.leading, 16) }
                }
            }
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))
        }
    }

    private var passageField: some View {
        VStack(alignment: .leading, spacing: ReforgedTheme.spacingS + 4) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                TextField("Passage, e.g. Psalm 23 or John 1-3", text: $passage)
                    .font(.body)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($passageFocused)
                if !passage.isEmpty {
                    Button { passage = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear passage")
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReforgedTheme.cornerRadiusLarge, style: .continuous)
                    .stroke(passageFocused ? Color.reforgedCoral.opacity(0.55) : Color.adaptiveBorder(colorScheme), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 8, y: 4)

            if !cleanPassage.isEmpty && !passageIsValid {
                Text("Use a book and chapter, like Psalm 23, John 1-3, or Romans 8:1-17.")
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .padding(.horizontal, 4)
            }
            if let error = store.errorMessage {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .padding(.horizontal, 4)
            }
        }
    }

    private var sendBar: some View {
        Button { send() } label: {
            Text(sendTitle)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(Color.reforgedCoral))
                .opacity(canSend ? 1 : 0.4)
        }
        .buttonStyle(NoBlobButtonStyle())
        .disabled(!canSend)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .readableContentWidth()
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
    }

    private func send() {
        guard let friend else { return }
        sending = true
        Task {
            let ok: Bool
            if mode == .plan, let plan = selectedPlan {
                ok = await store.propose(to: friend, plan: plan)
            } else {
                ok = await store.propose(to: friend, passage: cleanPassage)
            }
            sending = false
            if ok { dismiss() }
        }
    }
}
