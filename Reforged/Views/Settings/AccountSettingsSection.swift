import SwiftUI

struct AccountSettingsSection: View {
    @StateObject private var settings = SettingsManager.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    @State private var showSignOutConfirmation = false
    @State private var showClearCacheConfirmation = false
    @State private var showResetConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showDeleteAccountFinalConfirmation = false
    @State private var showDeleteError = false
    @State private var isDeletingAccount = false
    @State private var isSyncing = false
    @State private var cacheCleared = false

    private let appleSignIn = AppleSignInService.shared

    var body: some View {
        VStack(spacing: 0) {
            accountHeader
            SettingsDivider()
            syncSection
            SettingsDivider()
            storageSection
            dangerZone
        }
        .alert("Sign Out?", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) { signOut() }
        } message: {
            Text("Your local data will be preserved. Sign back in to sync across devices.")
        }
        .alert("Clear Cache?", isPresented: $showClearCacheConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { clearCache() }
        } message: {
            Text("This will clear all cached Bible data. You'll need to download chapters again when reading.")
        }
        .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetSettings() }
        } message: {
            Text("This will reset all settings to their default values. Your progress and memory verses will not be affected.")
        }
        .alert("Delete Account?", isPresented: $showDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Account", role: .destructive) {
                showDeleteAccountFinalConfirmation = true
            }
        } message: {
            Text("This will permanently delete your account and all associated data, including your reading progress, memory verses, highlights, and notes. This action cannot be undone.")
        }
        .alert("Are you sure?", isPresented: $showDeleteAccountFinalConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Permanently Delete", role: .destructive) { deleteAccount() }
        } message: {
            Text("All your data will be permanently removed from all devices. You will need to create a new account to use Reforged again.")
        }
        .alert("Account Deleted", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your local data has been cleared, but we couldn't reach iCloud to delete your cloud data. It will be removed the next time you connect.")
        }
    }

    // MARK: - Account Header

    @ViewBuilder
    private var accountHeader: some View {
        if appleSignIn.isSignedIn {
            HStack(spacing: 14) {
                ProfileAvatarView(size: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.user.displayName.isEmpty ? appState.user.firstName : appState.user.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text(appleSignIn.userEmail ?? "Apple ID")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Signed in with Apple")
                            .font(.caption2)
                            .foregroundStyle(Color.green)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 12)
        } else {
            signInPrompt
        }
    }

    private var signInPrompt: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.12))
                        .frame(width: 54, height: 54)
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundStyle(Color.teal)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Not Signed In")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Sign in to sync your progress across devices")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }

                Spacer()
            }

            Button(action: { appState.user.onboardingCompleted = false }) {
                HStack(spacing: 6) {
                    Image(systemName: "apple.logo")
                    Text("Sign In with Apple")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Sync Section

    @ViewBuilder
    private var syncSection: some View {
        SettingsToggleRow(
            title: "Sync Data",
            subtitle: "Keep your progress synced across all your devices",
            isOn: $settings.syncEnabled
        )

        if appleSignIn.isSignedIn && settings.syncEnabled {
            HStack {
                Spacer()
                Button(action: syncNow) {
                    HStack(spacing: 6) {
                        if isSyncing {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(isSyncing ? "Syncing…" : "Sync Now")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSyncing ? Color.adaptiveTextSecondary(colorScheme) : Color.teal)
                }
                .disabled(isSyncing)
            }
            .padding(.bottom, 10)
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { showClearCacheConfirmation = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Clear Local Cache")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                        Text("Free up storage by clearing cached Bible data")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    Spacer()
                    cacheClearedIndicator
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 12)

            if cacheCleared {
                Text("Cache cleared successfully")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: cacheCleared)
    }

    private var cacheClearedIndicator: some View {
        Group {
            if cacheCleared {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            dangerZoneHeader
            dangerZoneCard
        }
        .padding(.bottom, 10)
    }

    private var dangerZoneHeader: some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
            Text("Danger Zone")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(Color.red.opacity(0.75))
        .padding(.top, 8)
    }

    private var dangerZoneCard: some View {
        VStack(spacing: 0) {
            dangerRow(
                title: "Reset All Settings",
                icon: "arrow.counterclockwise",
                color: .reforgedCoral
            ) { showResetConfirmation = true }

            if appleSignIn.isSignedIn {
                Divider().padding(.horizontal, 14)

                dangerRow(
                    title: "Sign Out",
                    icon: "rectangle.portrait.and.arrow.right",
                    color: .reforgedCoral
                ) { showSignOutConfirmation = true }

                Divider().padding(.horizontal, 14)

                deleteAccountRow
            }
        }
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.18), lineWidth: 1)
        )
    }

    private func dangerRow(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
        }
        .buttonStyle(.plain)
    }

    private var deleteAccountRow: some View {
        Button(action: { showDeleteAccountConfirmation = true }) {
            HStack(spacing: 10) {
                if isDeletingAccount {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 20)
                } else {
                    Image(systemName: "trash.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.red)
                        .frame(width: 20)
                }
                Text(isDeletingAccount ? "Deleting Account…" : "Delete Account")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.red)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
        }
        .buttonStyle(.plain)
        .disabled(isDeletingAccount)
    }

    // MARK: - Actions

    func signOut() {
        appleSignIn.signOut()
        appState.user.loggedIn = false
    }

    func syncNow() {
        isSyncing = true
        Task {
            await appState.performFullSync()
            isSyncing = false
        }
    }

    func clearCache() {
        settings.clearLocalCache()
        cacheCleared = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            cacheCleared = false
        }
    }

    func resetSettings() {
        withAnimation {
            settings.resetAllSettings()
        }
    }

    func deleteAccount() {
        isDeletingAccount = true
        Task {
            do {
                try await appState.deleteAccount()
            } catch {
                showDeleteError = true
                print("⚠️ Cloud deletion failed (local data cleared): \(error)")
            }
            isDeletingAccount = false
        }
    }
}

#Preview {
    ScrollView {
        AccountSettingsSection()
            .padding()
    }
    .environmentObject(AppState.shared)
}
