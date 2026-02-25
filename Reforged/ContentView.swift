import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var selectedTab = 2 // Default to Bible
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
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
