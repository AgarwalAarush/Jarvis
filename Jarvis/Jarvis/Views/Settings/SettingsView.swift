import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var stateManager: JarvisStateManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationView {
            List {
                Section("General") {
                    NavigationLink("API Settings") {
                        APISettingsView(viewModel: viewModel)
                    }
                    
                    NavigationLink("Voice Settings") {
                        VoiceSettingsView(viewModel: viewModel)
                    }
                    
                    NavigationLink("General Settings") {
                        GeneralSettingsView(viewModel: viewModel)
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
                
                Section("Actions") {
                    Button("Test API Connection") {
                        viewModel.testAPIConnection()
                    }
                    
                    Button("Test Voice Settings") {
                        viewModel.testVoiceSettings()
                    }
                    
                    Button("Export Settings") {
                        exportSettings()
                    }
                    
                    Button("Import Settings") {
                        importSettings()
                    }
                    
                    Button("Reset to Defaults") {
                        viewModel.resetToDefaults()
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
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        viewModel.saveSettings()
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
            Button("OK") {
                viewModel.clearSuccess()
            }
        } message: {
            if let successMessage = viewModel.successMessage {
                Text(successMessage)
            }
        }
    }
    
    private func exportSettings() {
        if let url = viewModel.exportSettings() {
            // Show success message
            viewModel.successMessage = "Settings exported to: \(url.lastPathComponent)"
        }
    }
    
    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                viewModel.importSettings(from: url)
            }
        }
    }
}

// MARK: - Enhanced API Settings View
struct APISettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section("API Configuration") {
                TextField("API Base URL", text: $viewModel.apiSettings.baseURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField("API Key (Optional)", text: $viewModel.apiSettings.apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack {
                    Text("Timeout")
                    Spacer()
                    TextField("30.0", value: $viewModel.apiSettings.timeout, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                    Text("seconds")
                }
                
                HStack {
                    Text("Retry Count")
                    Spacer()
                    TextField("3", value: $viewModel.apiSettings.retryCount, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }
            }
            
            Section("Features") {
                Toggle("Enable Streaming", isOn: $viewModel.apiSettings.enableStreaming)
                Toggle("Enable WebSocket", isOn: $viewModel.apiSettings.enableWebSocket)
            }
            
            Section("Connection Info") {
                HStack {
                    Text("Security")
                    Spacer()
                    Text(viewModel.apiSettings.isSecure ? "HTTPS" : "HTTP")
                        .foregroundColor(viewModel.apiSettings.isSecure ? .green : .orange)
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    Text(viewModel.apiSettings.isValid ? "Valid" : "Invalid")
                        .foregroundColor(viewModel.apiSettings.isValid ? .green : .red)
                }
            }
            
            Section("Actions") {
                Button("Test Connection") {
                    viewModel.testAPIConnection()
                }
                
                Button("Reset to Defaults") {
                    viewModel.resetAPISettings()
                }
            }
        }
        .navigationTitle("API Settings")
        .formStyle(GroupedFormStyle())
    }
}

// MARK: - Enhanced Voice Settings View
struct VoiceSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section("Voice Configuration") {
                Picker("TTS Voice", selection: $viewModel.voiceSettings.ttsVoice) {
                    ForEach(viewModel.voiceSettings.availableVoices, id: \.self) { voice in
                        Text(voice.capitalized).tag(voice)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Microphone Sensitivity")
                    Slider(value: $viewModel.voiceSettings.sensitivity, in: 0...1)
                    Text("\(Int(viewModel.voiceSettings.sensitivity * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading) {
                    Text("Recording Timeout")
                    Slider(value: $viewModel.voiceSettings.timeout, in: 1...30)
                    Text("\(viewModel.voiceSettings.timeout, specifier: "%.1f") seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Audio Quality") {
                Picker("Sample Rate", selection: $viewModel.voiceSettings.sampleRate) {
                    Text("8 kHz").tag(8000)
                    Text("16 kHz").tag(16000)
                    Text("44.1 kHz").tag(44100)
                }
                
                Picker("Channels", selection: $viewModel.voiceSettings.channels) {
                    Text("Mono").tag(1)
                    Text("Stereo").tag(2)
                }
            }
            
            Section("Features") {
                Toggle("Enable Wake Word", isOn: $viewModel.voiceSettings.enableWakeWord)
                Toggle("Enable Echo Cancellation", isOn: $viewModel.voiceSettings.enableEchoCancellation)
            }
            
            Section("Validation") {
                HStack {
                    Text("Settings Status")
                    Spacer()
                    Text(viewModel.voiceSettings.isValid ? "Valid" : "Invalid")
                        .foregroundColor(viewModel.voiceSettings.isValid ? .green : .red)
                }
            }
            
            Section("Actions") {
                Button("Test Voice Settings") {
                    viewModel.testVoiceSettings()
                }
                
                Button("Reset to Defaults") {
                    viewModel.resetVoiceSettings()
                }
            }
        }
        .navigationTitle("Voice Settings")
        .formStyle(GroupedFormStyle())
    }
}

// MARK: - Enhanced General Settings View
struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $viewModel.generalSettings.theme) {
                    ForEach(viewModel.generalSettings.availableThemes, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                
                Picker("Language", selection: $viewModel.generalSettings.language) {
                    ForEach(viewModel.generalSettings.availableLanguages, id: \.self) { language in
                        Text(language.uppercased()).tag(language)
                    }
                }
            }
            
            Section("Notifications") {
                Toggle("Enable Notifications", isOn: $viewModel.generalSettings.enableNotifications)
                Toggle("Enable Sound Effects", isOn: $viewModel.generalSettings.enableSoundEffects)
            }
            
            Section("Performance") {
                Toggle("Enable Keyboard Shortcuts", isOn: $viewModel.generalSettings.enableKeyboardShortcuts)
                
                VStack(alignment: .leading) {
                    Text("Auto Save Interval")
                    Slider(value: $viewModel.generalSettings.autoSaveInterval, in: 5...300)
                    Text("\(Int(viewModel.generalSettings.autoSaveInterval)) seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Max Chat History")
                    Spacer()
                    TextField("1000", value: $viewModel.generalSettings.maxChatHistory, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                }
            }
            
            Section("Privacy") {
                Toggle("Enable Analytics", isOn: $viewModel.generalSettings.enableAnalytics)
            }
            
            Section("Validation") {
                HStack {
                    Text("Settings Status")
                    Spacer()
                    Text(viewModel.generalSettings.isValid ? "Valid" : "Invalid")
                        .foregroundColor(viewModel.generalSettings.isValid ? .green : .red)
                }
            }
            
            Section("Actions") {
                Button("Reset to Defaults") {
                    viewModel.resetGeneralSettings()
                }
            }
        }
        .navigationTitle("General Settings")
        .formStyle(GroupedFormStyle())
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(JarvisStateManager.preview)
    }
} 