import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var themeColors = ThemeColors.shared
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var checkoutService = CheckoutChecklistService.shared

    @State private var showCheckoutChecklist = false
    @State private var checkoutLocation: LocationService.SavedLocation?

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
        // Location exit trigger
        .onChange(of: locationService.locationExitTriggered) { _, triggeredLocation in
            if let location = triggeredLocation {
                checkoutLocation = location
                showCheckoutChecklist = true
            }
        }
        .fullScreenCover(isPresented: $showCheckoutChecklist) {
            if let location = checkoutLocation {
                CheckoutChecklistView(
                    location: location,
                    onComplete: {
                        showCheckoutChecklist = false
                        checkoutLocation = nil
                        locationService.clearExitTrigger()
                        checkoutService.completeCheckout()
                    },
                    onDismiss: {
                        showCheckoutChecklist = false
                        checkoutLocation = nil
                        locationService.clearExitTrigger()
                        checkoutService.dismissCheckout()
                    }
                )
                .environmentObject(appState)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
