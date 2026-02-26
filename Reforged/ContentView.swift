import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var selectedTab = 2 // Default to Bible
    @State private var showFreezeEncouragement = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Group {
                if !appState.user.onboardingCompleted {
                    OnboardingFlowView()
                } else {
                    AdaptiveNavigationView(selectedTab: $selectedTab)
                }
            }
            .environmentObject(appState)
            .environmentObject(themeManager)
            .environmentObject(settingsManager)
            .preferredColorScheme(themeManager.colorScheme)
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    // Refresh daily insight when app becomes active
                    appState.refreshDailyInsightIfNeeded()
                    // Update notification content based on today's progress
                    NotificationManager.shared.rescheduleWithSmartContent()
                    // Check if freeze encouragement should show
                    checkFreezeEncouragement()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchTab"))) { notification in
                if let tab = notification.userInfo?["tab"] as? Int {
                    selectedTab = tab
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToBibleVerse"))) { _ in
                selectedTab = 2
            }

            // Full-screen freeze encouragement overlay
            if showFreezeEncouragement {
                FreezeEncouragementView(isPresented: $showFreezeEncouragement)
                    .environmentObject(appState)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showFreezeEncouragement)
    }

    private func checkFreezeEncouragement() {
        guard appState.user.onboardingCompleted else { return }
        guard appState.user.streakFreezes == 0 else { return }
        guard appState.user.streak >= 3 else { return } // Only show if they have a streak worth protecting

        // Only show once per day
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        let lastShown = UserDefaults.standard.string(forKey: "lastFreezeEncouragementDate") ?? ""
        guard today != lastShown else { return }

        UserDefaults.standard.set(today, forKey: "lastFreezeEncouragementDate")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showFreezeEncouragement = true
        }
    }
}

// MARK: - Freeze Encouragement View

struct FreezeEncouragementView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showBuyConfirmation = false
    @State private var purchaseSuccess = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissView()
                }

            // Card
            VStack(spacing: 24) {
                // Warning icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: Color.blue.opacity(0.4), radius: 20)

                    Image(systemName: "snowflake")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(.white)
                }

                // Title and message
                VStack(spacing: 10) {
                    Text("Your Streak is Unprotected!")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .multilineTextAlignment(.center)

                    Text("You have no streak freezes left. If you miss a day of reading, your \(appState.user.streak)-day streak will be lost!")
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                // Visual empty freeze slots
                HStack(spacing: 6) {
                    ForEach(0..<8, id: \.self) { _ in
                        Circle()
                            .fill(Color.blue.opacity(0.08))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "snowflake")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.blue.opacity(0.2))
                            )
                    }
                }

                // Action buttons
                VStack(spacing: 10) {
                    // Buy freeze button
                    if appState.user.xp >= appState.freezePurchaseCost {
                        Button {
                            showBuyConfirmation = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "snowflake")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Get Streak Freeze")
                                    .font(.headline)
                                Spacer()
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11))
                                    Text("\(appState.freezePurchaseCost) XP")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    } else {
                        // Not enough XP message
                        VStack(spacing: 6) {
                            Text("Keep reading to earn XP for freezes!")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.adaptiveText(colorScheme))

                            Text("You need \(appState.freezePurchaseCost - appState.user.xp) more XP")
                                .font(.caption)
                                .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                        }
                        .padding(.vertical, 8)
                    }

                    // Dismiss button
                    Button {
                        dismissView()
                    } label: {
                        Text("I'll Take My Chances")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                            .padding(.vertical, 12)
                    }
                }
            }
            .padding(28)
            .background(Color.adaptiveCardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.2), radius: 30)
            .padding(32)
        }
        .alert("Buy Streak Freeze", isPresented: $showBuyConfirmation) {
            Button("Buy for \(appState.freezePurchaseCost) XP") {
                if appState.purchaseStreakFreeze() {
                    HapticManager.shared.lightImpact()
                    purchaseSuccess = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Spend \(appState.freezePurchaseCost) XP to protect your streak?\n\nYou have \(appState.user.xp) XP available.")
        }
        .alert("Freeze Purchased!", isPresented: $purchaseSuccess) {
            Button("OK") {
                dismissView()
            }
        } message: {
            Text("Your streak is now protected! You have \(appState.user.streakFreezes) streak freeze\(appState.user.streakFreezes == 1 ? "" : "s").")
        }
    }

    private func dismissView() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - Adaptive Navigation View (Sidebar on iPad/Mac, Tabs on iPhone)

struct AdaptiveNavigationView: View {
    @Binding var selectedTab: Int
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad / Mac: Use NavigationSplitView with sidebar
            SidebarNavigationView(selectedTab: $selectedTab)
        } else {
            // iPhone: Use TabView
            MainTabView(selectedTab: $selectedTab)
        }
    }
}

// MARK: - Sidebar Navigation (iPad/Mac)

struct SidebarNavigationView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            List {
                Section {
                    NavigationRow(icon: "house.fill", title: "Home", tag: 0, selectedTab: $selectedTab)
                    NavigationRow(icon: "book.fill", title: "Learn", tag: 1, selectedTab: $selectedTab)
                    NavigationRow(icon: "text.book.closed.fill", title: "Bible", tag: 2, selectedTab: $selectedTab)
                    NavigationRow(icon: "brain.head.profile", title: "Memory", tag: 3, selectedTab: $selectedTab)
                } header: {
                    Text("Reforged")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveNavyText(colorScheme))
                        .padding(.bottom, 8)
                }

                Section {
                    NavigationRow(icon: "person.fill", title: "Profile", tag: 4, selectedTab: $selectedTab)
                    NavigationRow(icon: "gearshape.fill", title: "Settings", tag: 5, selectedTab: $selectedTab)
                } header: {
                    Text("Account")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("")
            #if os(macOS)
            .frame(minWidth: 200)
            #endif
        } detail: {
            // Detail view based on selection
            switch selectedTab {
            case 0:
                HomeView()
                    .environment(\.isSidebarNavigation, true)
            case 1:
                LearningPathView()
                    .environment(\.isSidebarNavigation, true)
            case 2:
                BibleView()
                    .environment(\.isSidebarNavigation, true)
            case 3:
                MemoryView()
                    .environment(\.isSidebarNavigation, true)
            case 4:
                ProfileView()
                    .environment(\.isSidebarNavigation, true)
            case 5:
                SettingsView()
                    .environment(\.isSidebarNavigation, true)
            default:
                BibleView()
                    .environment(\.isSidebarNavigation, true)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Color.reforgedGold)
    }
}

// MARK: - Navigation Row for Sidebar

struct NavigationRow: View {
    let icon: String
    let title: String
    let tag: Int
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) var colorScheme

    var isSelected: Bool {
        selectedTab == tag
    }

    var body: some View {
        Button {
            selectedTab = tag
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.adaptiveNavyText(colorScheme) : Color.adaptiveTextSecondary(colorScheme))
                    .frame(width: 28)

                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.adaptiveText(colorScheme) : Color.adaptiveTextSecondary(colorScheme))

                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                isSelected
                    ? Color.reforgedNavy.opacity(0.1)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Main Tab View (iPhone)

struct MainTabView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            LearningPathView()
                .tabItem {
                    Label("Learn", systemImage: "book.fill")
                }
                .tag(1)

            BibleView()
                .tabItem {
                    Label("Bible", systemImage: "text.book.closed.fill")
                }
                .tag(2)

            MemoryView()
                .tabItem {
                    Label("Memory", systemImage: "brain.head.profile")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        .tint(Color.reforgedGold)
        .background(Color.adaptiveBackground(colorScheme))
    }
}

#Preview {
    ContentView()
}
