import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isSidebarNavigation) var isSidebarNavigation
    @State private var showEditProfile = false
    @State private var showLogoutAlert = false

    var levelInfo: LevelInfo {
        SampleData.getLevelInfo(xp: appState.user.xp)
    }

    var body: some View {
        Group {
            if isSidebarNavigation {
                profileContent
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: { showEditProfile = true }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                            }
                        }
                    }
            } else {
                NavigationStack {
                    profileContent
                        .navigationTitle("Profile")
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button(action: { showEditProfile = true }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title2)
                                }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet()
        }
        .alert("Sign Out?", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                AppleSignInService.shared.signOut()
                appState.resetToFreshState()
            }
        } message: {
            Text("Your progress is saved to the cloud.")
        }
    }

    var profileContent: some View {
        ScrollView {
            if horizontalSizeClass == .regular {
                // iPad/Mac: Two-column layout
                HStack(alignment: .top, spacing: 24) {
                    // Left column: Profile header and settings
                    VStack(spacing: 24) {
                        ProfileHeader(user: appState.user, levelInfo: levelInfo)
                        ProfileSettingsSection(showLogoutAlert: $showLogoutAlert)
                    }
                    .frame(maxWidth: 400)

                    // Right column: Stats, badges, perks
                    VStack(spacing: 24) {
                        StatsGrid(user: appState.user)
                        BadgesSection(badges: appState.user.badges)
                        PerksSection(perks: $appState.user.perks)
                    }
                    .frame(maxWidth: .infinity)
                }
                .responsivePadding(.horizontal)
                .padding(.vertical)
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity)
            } else {
                // iPhone: Single column
                VStack(spacing: 24) {
                    ProfileHeader(user: appState.user, levelInfo: levelInfo)
                    StatsGrid(user: appState.user)
                    BadgesSection(badges: appState.user.badges)
                    PerksSection(perks: $appState.user.perks)
                    ProfileSettingsSection(showLogoutAlert: $showLogoutAlert)
                }
                .padding()
            }
        }
        .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
    }
}

// MARK: - Profile Header

struct ProfileHeader: View {
    let user: UserProfile
    let levelInfo: LevelInfo
    @Environment(\.colorScheme) var colorScheme

    var profileBorderColor: Color {
        switch user.activeProfileBorder {
        case "border-gold": return Color.reforgedGold
        case "border-flame": return Color.reforgedCoral
        case "border-crown": return Color.purple
        case "border-diamond": return Color.cyan
        default: return Color.reforgedGold
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(user.avatar.isEmpty ? "🦁" : user.avatar)
                .font(.system(size: 70))
                .frame(width: 100, height: 100)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(profileBorderColor, lineWidth: 4)
                )
                .shadow(color: profileBorderColor.opacity(0.3), radius: user.activeProfileBorder.isEmpty ? 0 : 8)
            
            VStack(spacing: 4) {
                Text(user.displayName.isEmpty ? "Friend" : user.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Level \(levelInfo.level) • \(levelInfo.title)")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            
            // XP Progress
            VStack(spacing: 8) {
                ProgressView(value: levelInfo.progress)
                    .tint(Color.reforgedGold)

                Text("\(levelInfo.xpInLevel) / \(levelInfo.xpForNextLevel) XP to next level")
                    .font(.caption)
                    .foregroundStyle(Color.reforgedTextSecondary)
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .reforgedCard(hasBorder: false)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Stats Grid

struct StatsGrid: View {
    let user: UserProfile
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var columns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        } else {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ProfileStatCard(icon: "flame.fill", iconColor: .reforgedCoral, value: "\(user.streak)", label: "Day Streak")
            ProfileStatCard(icon: "trophy.fill", iconColor: .reforgedGold, value: "\(user.longestStreak)", label: "Best Streak")
            ProfileStatCard(icon: "star.fill", iconColor: .reforgedNavy, value: "\(user.xp)", label: "Total XP")
            ProfileStatCard(icon: "checkmark.circle.fill", iconColor: Color(red: 0.2, green: 0.6, blue: 0.4), value: "\(user.completedLessons.count)", label: "Lessons Done")
        }
    }
}

struct ProfileStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .reforgedCard(hasBorder: false)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Badges Section

struct BadgesSection: View {
    let badges: [Badge]
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme

    var earnedBadges: [Badge] {
        badges.filter { $0.isEarned }
    }

    var unearnedBadges: [Badge] {
        badges.filter { !$0.isEarned }
    }

    var badgeColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.adaptive(minimum: 80), spacing: 16)]
        } else {
            return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges")
                .font(.headline)

            if earnedBadges.isEmpty {
                Text("Complete lessons and activities to earn badges!")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .reforgedCard(hasBorder: false)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                LazyVGrid(columns: badgeColumns, spacing: 12) {
                    ForEach(earnedBadges) { badge in
                        BadgeItem(badge: badge)
                    }
                }
                .padding()
                .reforgedCard(hasBorder: false)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if !unearnedBadges.isEmpty {
                Text("Locked (\(unearnedBadges.count))")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                LazyVGrid(columns: badgeColumns, spacing: 12) {
                    ForEach(unearnedBadges.prefix(horizontalSizeClass == .regular ? 12 : 8)) { badge in
                        BadgeItem(badge: badge, locked: true)
                    }
                }
                .padding()
                .reforgedCard(hasBorder: false)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

struct BadgeItem: View {
    let badge: Badge
    var locked: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: locked ? "lock.fill" : badge.icon)
                .font(.title2)
                .foregroundStyle(locked ? Color.adaptiveTextSecondary(colorScheme) : Color.yellow)

            Text(badge.name)
                .font(.caption2)
                .foregroundStyle(locked ? Color.adaptiveTextSecondary(colorScheme) : Color.adaptiveText(colorScheme))
                .lineLimit(1)
        }
        .opacity(locked ? 0.5 : 1)
    }
}

// MARK: - Perks Section

struct PerksSection: View {
    @Binding var perks: [Perk]
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var unlockedPerks: [Perk] { perks.filter { $0.isUnlocked } }
    var lockedPerks: [Perk] { perks.filter { !$0.isUnlocked } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Perks")
                .font(.headline)

            if unlockedPerks.isEmpty {
                Text("Level up and build streaks to unlock perks!")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .reforgedCard(hasBorder: false)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 8) {
                    ForEach(unlockedPerks) { perk in
                        PerkRow(perk: perk, locked: false) {
                            togglePerk(perk)
                        }
                    }
                }
                .padding()
                .reforgedCard(hasBorder: false)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if !lockedPerks.isEmpty {
                Text("Locked (\(lockedPerks.count))")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))

                VStack(spacing: 8) {
                    ForEach(lockedPerks.prefix(5)) { perk in
                        PerkRow(perk: perk, locked: true, onToggle: nil)
                    }
                }
                .padding()
                .reforgedCard(hasBorder: false)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func togglePerk(_ perk: Perk) {
        guard let index = perks.firstIndex(where: { $0.id == perk.id }) else { return }

        // For profile borders: deactivate others of same type first
        if perk.type == .profileBorder || perk.type == .themeUnlock {
            for i in perks.indices where perks[i].type == perk.type {
                perks[i].isActive = false
            }
        }

        perks[index].isActive.toggle()

        // Apply profile border
        if perk.type == .profileBorder {
            appState.user.activeProfileBorder = perks[index].isActive ? perk.id : ""
        }
        if perk.type == .themeUnlock {
            appState.user.activeTheme = perks[index].isActive ? perk.id : ""
        }
    }
}

struct PerkRow: View {
    let perk: Perk
    let locked: Bool
    let onToggle: (() -> Void)?
    @Environment(\.colorScheme) var colorScheme

    var unlockDescription: String {
        switch perk.unlockCondition {
        case .level(let n): return "Reach Level \(n)"
        case .streak(let n): return "\(n)-day streak"
        case .badge(let id): return "Earn \(id) badge"
        case .xp(let n): return "Earn \(n) XP"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: locked ? "lock.fill" : perk.icon)
                .font(.title3)
                .foregroundStyle(locked ? Color.adaptiveTextSecondary(colorScheme) : Color.reforgedGold)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(perk.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(locked ? Color.adaptiveTextSecondary(colorScheme) : Color.adaptiveText(colorScheme))

                Text(locked ? unlockDescription : perk.description)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }

            Spacer()

            if !locked, let onToggle = onToggle {
                // Activation toggle for applicable perks
                if perk.type == .profileBorder || perk.type == .themeUnlock || perk.type == .streakFreeze || perk.type == .xpMultiplier {
                    Button(action: onToggle) {
                        Text(perk.isActive ? "Active" : "Use")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(perk.isActive ? .white : Color.reforgedNavy)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(perk.isActive ? Color.reforgedNavy : Color.reforgedNavy.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .opacity(locked ? 0.6 : 1)
    }
}

// MARK: - Settings Section

struct ProfileSettingsSection: View {
    @Binding var showLogoutAlert: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            VStack(spacing: 0) {
                NavigationLink(destination: SettingsView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                            .frame(width: 30)

                        Text("App Settings")
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                    }
                    .padding()
                }

                Divider().padding(.leading, 50)

                SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", color: .blue) {
                    openSupportEmail()
                }

                Divider().padding(.leading, 50)

                SettingsRow(icon: "rectangle.portrait.and.arrow.right.fill", title: "Sign Out", color: .red) {
                    showLogoutAlert = true
                }
            }
            .reforgedCard(hasBorder: false)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    func openSupportEmail() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let email = "support@reforgedapp.com"
        let subject = "Reforged Support Request"
        let body = "App Version: \(appVersion)\n\nDescribe your issue or feedback:\n\n"

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 30)

                Text(title)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding()
        }
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var displayName = ""
    @State private var selectedAvatar = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Display Name", text: $displayName)
                }
                
                Section("Avatar") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 12)], spacing: 12) {
                        ForEach(avatarOptions) { avatar in
                            Text(avatar.emoji)
                                .font(.largeTitle)
                                .frame(width: 50, height: 50)
                                .background(selectedAvatar == avatar.emoji ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(selectedAvatar == avatar.emoji ? Color.blue : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedAvatar = avatar.emoji
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                }
            }
            .onAppear {
                firstName = appState.user.firstName
                lastName = appState.user.lastName
                displayName = appState.user.displayName
                selectedAvatar = appState.user.avatar
            }
        }
    }
    
    func saveProfile() {
        appState.user.firstName = firstName
        appState.user.lastName = lastName
        appState.user.displayName = displayName
        appState.user.avatar = selectedAvatar
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState.shared)
}
