import SwiftUI

struct ContentView: View {
    @EnvironmentObject var stateManager: JarvisStateManager
    @EnvironmentObject var dataController: DataController
    
    var body: some View {
        NavigationView {
            // Sidebar
            SidebarView()
                .frame(minWidth: 200, maxWidth: 300)
            
            // Main content area
            mainContentView
        }
        .navigationTitle("Jarvis")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    // Mode toggle button
                    Button(action: {
                        stateManager.toggleMode()
                    }) {
                        Image(systemName: stateManager.currentMode == .chat ? "mic.fill" : "keyboard")
                            .foregroundColor(.accentColor)
                    }
                    .help(stateManager.currentMode == .chat ? "Switch to Voice Mode" : "Switch to Chat Mode")
                    
                    // Settings button
                    Button(action: {
                        stateManager.showSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                    .help("Settings")
                }
            }
        }
        .sheet(isPresented: $stateManager.showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $stateManager.showOnboarding) {
            WelcomeView()
        }
        .onAppear {
            // Check if this is first launch
            if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
                stateManager.showOnboarding = true
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            }
        }
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        switch stateManager.selectedTab {
        case .chat:
            ChatView()
        case .voice:
            VoiceModeView()
        case .settings:
            SettingsView()
        case .search:
            SearchView()
        case .none:
            EmptyView()
        }
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DataController.preview)
            .environmentObject(JarvisStateManager.preview)
    }
} 