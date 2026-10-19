import SwiftUI

// MARK: - Returning users: recognition + restore
//
// The fast lane. A returning person (new device, reinstall, or an email account on a
// fresh phone) never sees goals, name, avatar, translation, display, AI or library
// setup: those are already in their account. They see who we found, then a calm
// "Welcome back" screen that shows exactly what is coming back, then Home.

enum ReturningStage: Equatable {
    case recognized(name: String)
    case restore
    case signIn
}

// MARK: Restore service

@MainActor
final class AccountRestoreService: ObservableObject {
    enum RowState { case pending, working, done }

    struct Row: Identifiable {
        let id: Int
        let title: String
        var detail: String?
        var state: RowState
    }

    @Published private(set) var rows: [Row] = []
    @Published private(set) var note: String?
    @Published private(set) var profileReady = false
    @Published private(set) var finished = false

    private var started = false

    private func setRow(_ id: Int, detail: String?, state: RowState) {
        guard let i = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[i].detail = detail
        rows[i].state = state
    }

    private func plural(_ n: Int, _ one: String, _ many: String) -> String { n == 1 ? "1 \(one)" : "\(n) \(many)" }

    func run(appState: AppState) async {
        guard !started else { return }
        started = true
        appState.isRestoringAccount = true

        let supa = SupabaseAuthService.shared
        let includeFriends = supa.isSignedIn && AgeGateManager.shared.status == .allowed
        rows = [
            Row(id: 0, title: "Your profile", detail: nil, state: .working),
            Row(id: 1, title: "Reading streak", detail: nil, state: .pending),
            Row(id: 2, title: "Memory verses", detail: nil, state: .pending),
            Row(id: 3, title: "Notes and highlights", detail: nil, state: .pending),
            Row(id: 4, title: "Study progress", detail: nil, state: .pending)
        ] + (includeFriends ? [Row(id: 5, title: "Friends", detail: nil, state: .pending)] : [])

        // Supabase identity (email or Apple-minted session): merge the account profile first.
        if supa.isSignedIn, let uid = supa.userId {
            _ = await appState.restoreSupabaseProfile(userId: uid, email: supa.userEmail ?? appState.user.email ?? "")
        }
        appState.user.loggedIn = true

        await appState.performFullSync { [weak self] stage in self?.handle(stage, appState: appState) }

        // Anything the cloud pass didn't report (no iCloud, or no cloud identity) still resolves.
        if rows.contains(where: { $0.state != .done }) {
            if !profileReady { handle(.profile, appState: appState) }
            for r in rows where r.state != .done && r.id != 5 { setRow(r.id, detail: "Needs iCloud", state: .done) }
        }

        // Preferences: cloud profile first, then the Supabase copy for people without iCloud.
        var prefs = appState.restoredPreferences
        if prefs == nil, supa.isSignedIn { prefs = await supa.fetchPreferences() }
        if let prefs { prefs.applyForRestore() } else { AppTour.shared.markSeenForRestoredAccount() }
        DeviceSetup.shared.activate(reminders: prefs?.reminders)

        if includeFriends {
            await FriendsStore.shared.refresh()
            setRow(5, detail: plural(FriendsStore.shared.friends.count, "friend", "friends"), state: .done)
        }
        if supa.isSignedIn { FriendsOnboarding.markDone(for: supa.userId) }

        try? await Task.sleep(nanoseconds: 350_000_000)
        finished = true
    }

    private func handle(_ stage: RestoreStage, appState: AppState) {
        switch stage {
        case .profile:
            profileReady = true
            let name = appState.user.firstName.isEmpty ? appState.user.displayName : appState.user.firstName
            setRow(0, detail: name.isEmpty ? "Done" : name, state: .done)
            setRow(1, detail: plural(appState.user.streak, "day", "days"), state: .done)
            setRow(2, detail: nil, state: .working)
        case .memory:
            setRow(2, detail: plural(appState.memoryVerses.count, "verse", "verses"), state: .done)
            setRow(3, detail: nil, state: .working)
        case .notes:
            let count = BibleReadingState.shared.highlights.count + BibleReadingState.shared.notes.count
            setRow(3, detail: plural(count, "item", "items"), state: .done)
            setRow(4, detail: nil, state: .working)
        case .tracks:
            setRow(4, detail: plural(appState.user.completedLessons.count, "lesson", "lessons"), state: .done)
        case .unavailable:
            note = "iCloud isn't available on this device, so only your profile came back. Sign in to iCloud in Settings to restore your verses and notes."
        }
    }
}

// MARK: Recognition (reinstall / restored backup)

struct RecognizedStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppState
    let name: String
    let onContinue: () -> Void
    let onNotYou: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                ReturningAvatar(initial: String(name.prefix(1)).uppercased(), emoji: appState.user.avatar, size: 96)
                Text("Welcome back, \(name).")
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text("We found your Reforged account on this device.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .padding(.horizontal, 32)
            }
            Spacer()
            VStack(spacing: 6) {
                ReturningPrimaryButton(title: "Continue as \(name)", action: onContinue)
                Button("Not you?", action: onNotYou)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }
}

// MARK: Welcome back / restore

struct RestoreStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppState
    @StateObject private var service = AccountRestoreService()
    @State private var advanced = false
    let onFinish: () -> Void

    private var displayName: String {
        appState.user.firstName.isEmpty ? appState.user.displayName : appState.user.firstName
    }

    private var progress: Double {
        guard !service.rows.isEmpty else { return 0 }
        return Double(service.rows.filter { $0.state == .done }.count) / Double(service.rows.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReturningAvatar(initial: String(displayName.prefix(1)).uppercased(), emoji: appState.user.avatar, size: 72)
                .padding(.top, 56)
            Text(displayName.isEmpty ? "Welcome back." : "Welcome back, \(displayName).")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .padding(.top, 18)
            Text("Getting everything ready.")
                .font(.body)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                .padding(.top, 4)

            ProgressTrack(value: progress)
                .padding(.top, 18)

            VStack(spacing: 0) {
                ForEach(service.rows) { row in
                    HStack(spacing: 14) {
                        Text(row.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Spacer()
                        if let detail = row.detail {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                                .transition(.opacity)
                        }
                        stateIcon(row.state)
                    }
                    .frame(minHeight: 52)
                    .opacity(row.state == .pending ? 0.45 : 1)
                    .overlay(alignment: .bottom) { Divider().opacity(0.6) }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 14)
            .animation(.easeOut(duration: 0.3), value: service.rows.map(\.detail))

            if let note = service.note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .padding(.top, 14)
            }

            Spacer()

            VStack(spacing: 8) {
                ReturningPrimaryButton(title: service.finished ? "Go to Home" : "Continue now", action: finish)
                    .opacity(service.profileReady ? 1 : 0.4)
                    .disabled(!service.profileReady)
                Text(service.finished ? "All set." : "The rest finishes in the background.")
                    .font(.footnote)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .task { await service.run(appState: appState) }
        .onChange(of: service.finished) { done in
            guard done else { return }
            // Let the finished state register, then carry on unless they already did.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { finish() }
        }
    }

    private func finish() {
        guard !advanced else { return }
        advanced = true
        onFinish()
    }

    @ViewBuilder
    private func stateIcon(_ state: AccountRestoreService.RowState) -> some View {
        switch state {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color(red: 0.2, green: 0.6, blue: 0.4))
                .transition(.scale.combined(with: .opacity))
        case .working:
            ProgressView().controlSize(.small).frame(width: 22, height: 22)
        case .pending:
            Image(systemName: "circle.dashed")
                .font(.title3)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme).opacity(0.6))
        }
    }
}

// MARK: Shared pieces

private struct ProgressTrack: View {
    @Environment(\.colorScheme) private var colorScheme
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.adaptiveChipBackground(colorScheme))
                Capsule().fill(Color.reforgedCoral)
                    .frame(width: max(8, geo.size.width * value))
                    .animation(.easeOut(duration: 0.5), value: value)
            }
        }
        .frame(height: 6)
    }
}

struct ReturningPrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Capsule().fill(Color.reforgedCoral))
        }
        .buttonStyle(NoBlobButtonStyle())
    }
}

private struct ReturningAvatar: View {
    let initial: String
    let emoji: String
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(Color.reforgedGold.opacity(0.18))
            if !emoji.isEmpty {
                Text(emoji).font(.system(size: size * 0.5))
            } else {
                Text(initial).font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(Color.reforgedGold)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
