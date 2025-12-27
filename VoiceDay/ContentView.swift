import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            // Focus tab - ADHD-friendly simplified view (primary entry point)
            FocusHomeView()
                .tabItem {
                    Label("Focus", systemImage: "scope")
                }
                .tag(0)

            RecordingView()
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }
                .tag(1)

            TasksListView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(2)

            GoalsView()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .tint(themeColors.accent)
        .id(themeColors.currentTheme.rawValue) // Force rebuild when theme changes
        .onAppear {
            if !appState.hasValidClaudeKey {
                appState.selectedTab = 4  // Settings tab
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
