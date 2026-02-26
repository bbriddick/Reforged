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
            // Account Info
            if appleSignIn.isSignedIn {
                HStack(spacing: 14) {
                    ProfileAvatarView(size: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.user.displayName.isEmpty ? appState.user.firstName : appState.user.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Text(appleSignIn.userEmail ?? "Apple ID")
                            .font(.caption)
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
                .padding(.vertical, 10)
            } else {
                // Sign In Prompt
                VStack(spacing: 12) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.reforgedNavy.opacity(0.15))
                                .frame(width: 50, height: 50)

                            Image(systemName: "person.circle")
                                .font(.title2)
                                .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Not Signed In")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.adaptiveText(colorScheme))

                            Text("Sign in to sync your progress across devices")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }

                        Spacer()
                    }

                    Button(action: {
                        // Navigate to sign in
                        appState.user.onboardingCompleted = false
                    }) {
                        Text("Sign In")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.reforgedNavy)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.vertical, 10)
            }

            SettingsDivider()

            // Sync Settings
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
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(isSyncing ? "Syncing..." : "Sync Now")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSyncing ? Color.adaptiveTextSecondary(colorScheme) : Color.adaptiveNavyText(colorScheme))
                    }
                    .disabled(isSyncing)
                }
                .padding(.bottom, 10)
            }

            SettingsDivider()

            // Clear Cache
            SettingsNavigationRow(
                title: "Clear Local Cache",
                subtitle: "Free up storage by clearing cached Bible data"
            ) {
                showClearCacheConfirmation = true
            }

            if cacheCleared {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Cache cleared successfully")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding(.bottom, 10)
            }

            SettingsDivider()

            // Reset All Settings
            SettingsButtonRow(
                title: "Reset All Settings",
                icon: "arrow.counterclockwise",
                color: .reforgedCoral
            ) {
                showResetConfirmation = true
            }

            if appleSignIn.isSignedIn {
                SettingsDivider()

                // Sign Out
                SettingsButtonRow(
                    title: "Sign Out",
                    icon: "rectangle.portrait.and.arrow.right",
                    color: .reforgedCoral
                ) {
                    showSignOutConfirmation = true
                }

                SettingsDivider()

                // Delete Account
                SettingsButtonRow(
                    title: isDeletingAccount ? "Deleting Account..." : "Delete Account",
                    icon: "trash.fill",
                    color: .red
                ) {
                    showDeleteAccountConfirmation = true
                }
                .disabled(isDeletingAccount)
            }
        }
        .alert("Sign Out?", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Your local data will be preserved. Sign back in to sync across devices.")
        }
        .alert("Clear Cache?", isPresented: $showClearCacheConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will clear all cached Bible data. You'll need to download chapters again when reading.")
        }
        .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetSettings()
            }
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
            Button("Permanently Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("All your data will be permanently removed from all devices. You will need to create a new account to use Reforged again.")
        }
        .alert("Account Deleted", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your local data has been cleared, but we couldn't reach iCloud to delete your cloud data. It will be removed the next time you connect.")
        }
    }

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

        // Reset the success message after a delay
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
                // Local data was still cleared; cloud deletion failed
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
