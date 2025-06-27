import Foundation
import SwiftUI
import Combine

class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var apiSettings = APISettings()
    @Published var voiceSettings = VoiceSettings()
    @Published var generalSettings = GeneralSettings()
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Initialization
    init() {
        loadSettings()
        setupObservers()
    }
    
    // MARK: - Settings Loading
    private func loadSettings() {
        loadAPISettings()
        loadVoiceSettings()
        loadGeneralSettings()
    }
    
    private func loadAPISettings() {
        if let data = userDefaults.data(forKey: "apiSettings"),
           let settings = try? JSONDecoder().decode(APISettings.self, from: data) {
            apiSettings = settings
        }
    }
    
    private func loadVoiceSettings() {
        if let data = userDefaults.data(forKey: "voiceSettings"),
           let settings = try? JSONDecoder().decode(VoiceSettings.self, from: data) {
            voiceSettings = settings
        }
    }
    
    private func loadGeneralSettings() {
        if let data = userDefaults.data(forKey: "generalSettings"),
           let settings = try? JSONDecoder().decode(GeneralSettings.self, from: data) {
            generalSettings = settings
        }
    }
    
    // MARK: - Settings Saving
    func saveSettings() {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        
        // Validate settings before saving
        guard validateSettings() else {
            isSaving = false
            return
        }
        
        do {
            saveAPISettings()
            saveVoiceSettings()
            saveGeneralSettings()
            
            successMessage = "Settings saved successfully"
            isSaving = false
            
            // Clear success message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.successMessage = nil
            }
        }
    }
    
    private func saveAPISettings() {
        if let data = try? JSONEncoder().encode(apiSettings) {
            userDefaults.set(data, forKey: "apiSettings")
        }
    }
    
    private func saveVoiceSettings() {
        if let data = try? JSONEncoder().encode(voiceSettings) {
            userDefaults.set(data, forKey: "voiceSettings")
        }
    }
    
    private func saveGeneralSettings() {
        if let data = try? JSONEncoder().encode(generalSettings) {
            userDefaults.set(data, forKey: "generalSettings")
        }
    }
    
    // MARK: - Settings Validation
    private func validateSettings() -> Bool {
        // Validate API settings
        if !apiSettings.baseURL.isEmpty {
            guard let url = URL(string: apiSettings.baseURL) else {
                errorMessage = "Invalid API base URL"
                return false
            }
            
            if !(url.scheme?.contains("http") ?? false) {
                errorMessage = "API URL must use HTTP or HTTPS"
                return false
            }
        }
        
        // Validate voice settings
        if voiceSettings.sensitivity < 0.0 || voiceSettings.sensitivity > 1.0 {
            errorMessage = "Voice sensitivity must be between 0.0 and 1.0"
            return false
        }
        
        if voiceSettings.timeout < 1.0 || voiceSettings.timeout > 30.0 {
            errorMessage = "Voice timeout must be between 1.0 and 30.0 seconds"
            return false
        }
        
        return true
    }
    
    // MARK: - Settings Reset
    func resetToDefaults() {
        apiSettings = APISettings()
        voiceSettings = VoiceSettings()
        generalSettings = GeneralSettings()
        
        saveSettings()
    }
    
    func resetAPISettings() {
        apiSettings = APISettings()
        saveAPISettings()
    }
    
    func resetVoiceSettings() {
        voiceSettings = VoiceSettings()
        saveVoiceSettings()
    }
    
    func resetGeneralSettings() {
        generalSettings = GeneralSettings()
        saveGeneralSettings()
    }
    
    // MARK: - Settings Import/Export
    func exportSettings() -> URL? {
        let settings = SettingsExport(
            apiSettings: apiSettings,
            voiceSettings: voiceSettings,
            generalSettings: generalSettings,
            exportDate: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(settings)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let exportURL = documentsPath.appendingPathComponent("jarvis_settings_\(Date().timeIntervalSince1970).json")
            
            try data.write(to: exportURL)
            return exportURL
        } catch {
            errorMessage = "Failed to export settings: \(error.localizedDescription)"
            return nil
        }
    }
    
    func importSettings(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let importedSettings = try JSONDecoder().decode(SettingsExport.self, from: data)
            
            // Validate imported settings
            guard validateImportedSettings(importedSettings) else {
                return
            }
            
            // Apply imported settings
            apiSettings = importedSettings.apiSettings
            voiceSettings = importedSettings.voiceSettings
            generalSettings = importedSettings.generalSettings
            
            saveSettings()
            successMessage = "Settings imported successfully"
        } catch {
            errorMessage = "Failed to import settings: \(error.localizedDescription)"
        }
    }
    
    private func validateImportedSettings(_ settings: SettingsExport) -> Bool {
        // Basic validation of imported settings
        if settings.apiSettings.baseURL.isEmpty {
            errorMessage = "Imported settings contain invalid API configuration"
            return false
        }
        
        return true
    }
    
    // MARK: - Observers
    private func setupObservers() {
        // Auto-save settings when they change
        Publishers.CombineLatest3(
            $apiSettings,
            $voiceSettings,
            $generalSettings
        )
        .debounce(for: .seconds(2.0), scheduler: RunLoop.main)
        .sink { _ in
            // Auto-save is disabled for now to prevent conflicts
            // We can use the parameters for validation or other purposes
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
    }
    
    func clearSuccess() {
        successMessage = nil
    }
    
    // MARK: - API Testing
    func testAPIConnection() {
        guard !apiSettings.baseURL.isEmpty else {
            errorMessage = "API base URL is required"
            return
        }
        
        // TODO: Implement actual API connection test
        // This will be implemented when we connect to the Python backend
        
        successMessage = "API connection test completed (placeholder)"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.successMessage = nil
        }
    }
    
    // MARK: - Voice Testing
    func testVoiceSettings() {
        // TODO: Implement voice settings test
        // This will be implemented when we connect to the Python backend
        
        successMessage = "Voice settings test completed (placeholder)"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.successMessage = nil
        }
    }
}

// MARK: - Settings Models
struct APISettings: Codable {
    var baseURL: String = "http://localhost:5000"
    var apiKey: String = ""
    var timeout: Double = 30.0
    var retryCount: Int = 3
    var enableStreaming: Bool = true
    var enableWebSocket: Bool = true
    
    var isSecure: Bool {
        return baseURL.hasPrefix("https://")
    }
    
    var isValid: Bool {
        return !baseURL.isEmpty && URL(string: baseURL) != nil
    }
}

struct VoiceSettings: Codable {
    var ttsVoice: String = "default"
    var sensitivity: Double = 0.5
    var timeout: Double = 5.0
    var enableWakeWord: Bool = true
    var enableEchoCancellation: Bool = true
    var sampleRate: Int = 16000
    var channels: Int = 1
    
    var availableVoices: [String] {
        return ["default", "male", "female", "robot", "natural"]
    }
    
    var isValid: Bool {
        return sensitivity >= 0.0 && sensitivity <= 1.0 &&
               timeout >= 1.0 && timeout <= 30.0 &&
               sampleRate > 0 && channels > 0
    }
}

struct GeneralSettings: Codable {
    var theme: AppTheme = .system
    var enableNotifications: Bool = true
    var enableSoundEffects: Bool = true
    var enableKeyboardShortcuts: Bool = true
    var autoSaveInterval: Double = 30.0
    var maxChatHistory: Int = 1000
    var enableAnalytics: Bool = false
    var language: String = "en"
    
    var availableThemes: [AppTheme] {
        return [.system, .light, .dark]
    }
    
    var availableLanguages: [String] {
        return ["en", "es", "fr", "de", "ja", "zh"]
    }
    
    var isValid: Bool {
        return autoSaveInterval >= 5.0 && autoSaveInterval <= 300.0 &&
               maxChatHistory >= 100 && maxChatHistory <= 10000
    }
}

enum AppTheme: String, CaseIterable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}

// MARK: - Settings Export Model
struct SettingsExport: Codable {
    let apiSettings: APISettings
    let voiceSettings: VoiceSettings
    let generalSettings: GeneralSettings
    let exportDate: Date
    let version: String
    
    init(apiSettings: APISettings, voiceSettings: VoiceSettings, generalSettings: GeneralSettings, exportDate: Date) {
        self.apiSettings = apiSettings
        self.voiceSettings = voiceSettings
        self.generalSettings = generalSettings
        self.exportDate = exportDate
        self.version = "1.0"
    }
    
    var formattedExportDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: exportDate)
    }
}

// MARK: - Preview Helper
extension SettingsViewModel {
    static var preview: SettingsViewModel {
        let viewModel = SettingsViewModel()
        viewModel.apiSettings.baseURL = "http://localhost:5000"
        viewModel.voiceSettings.sensitivity = 0.7
        viewModel.generalSettings.theme = .dark
        return viewModel
    }
} 
