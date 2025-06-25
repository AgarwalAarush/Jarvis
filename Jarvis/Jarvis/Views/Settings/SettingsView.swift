import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var stateManager: JarvisStateManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("General") {
                    NavigationLink("API Settings") {
                        APISettingsView()
                    }
                    
                    NavigationLink("Voice Settings") {
                        VoiceSettingsView()
                    }
                    
                    NavigationLink("General Settings") {
                        GeneralSettingsView()
                    }
                }
                
                Section("Chat") {
                    Toggle("Enable Markdown", isOn: $stateManager.chatSettings.enableMarkdown)
                    Toggle("Enable Code Highlighting", isOn: $stateManager.chatSettings.enableCodeHighlighting)
                    Toggle("Auto Scroll", isOn: $stateManager.chatSettings.autoScroll)
                    Toggle("Show Timestamps", isOn: $stateManager.chatSettings.showTimestamps)
                }
                
                Section("Voice") {
                    Toggle("Enable Wake Word", isOn: $stateManager.isWakeWordEnabled)
                }
                
                Section("Connection") {
                    HStack {
                        Text("Status")
                        Spacer()
                        if case .connected = stateManager.connectionStatus {
                            Text("Connected").foregroundColor(.green)
                        } else {
                            Text("Disconnected").foregroundColor(.red)
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

// MARK: - API Settings View (Placeholder)
struct APISettingsView: View {
    @State private var apiUrl = "http://localhost:5000"
    @State private var apiKey = ""
    
    var body: some View {
        Form {
            Section("API Configuration") {
                TextField("API URL", text: $apiUrl)
                SecureField("API Key", text: $apiKey)
            }
            
            Section("Models") {
                Text("Available models will be loaded from the API")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("API Settings")
    }
}

// MARK: - Voice Settings View (Placeholder)
struct VoiceSettingsView: View {
    @State private var selectedVoice = "Default"
    @State private var sensitivity = 0.5
    
    var body: some View {
        Form {
            Section("Voice Configuration") {
                Picker("TTS Voice", selection: $selectedVoice) {
                    Text("Default").tag("Default")
                    Text("Male").tag("Male")
                    Text("Female").tag("Female")
                }
                
                VStack(alignment: .leading) {
                    Text("Microphone Sensitivity")
                    Slider(value: $sensitivity, in: 0...1)
                    Text("\(Int(sensitivity * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Voice Settings")
    }
}

// MARK: - General Settings View (Placeholder)
struct GeneralSettingsView: View {
    @State private var autoStart = false
    @State private var startMinimized = false
    
    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Start at Login", isOn: $autoStart)
                Toggle("Start Minimized", isOn: $startMinimized)
            }
            
            Section("Theme") {
                Text("Theme settings will be implemented")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("General Settings")
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(JarvisStateManager.preview)
    }
} 