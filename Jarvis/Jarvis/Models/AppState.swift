import Foundation
import SwiftUI

// MARK: - Global App State
class JarvisStateManager: ObservableObject {
    static let shared = JarvisStateManager()
    
    // MARK: - App Mode
    @Published var currentMode: AppMode = .chat
    @Published var previousMode: AppMode = .chat
    
    // MARK: - Chat State
    @Published var currentChatId: UUID?
    @Published var chatState: ChatState = .idle
    @Published var chatSettings = ChatSettings()
    
    // MARK: - Voice State
    @Published var voiceState: VoiceState = .idle
    @Published var isWakeWordEnabled: Bool = true
    @Published var audioLevel: Double = 0.0
    @Published var isRecording: Bool = false
    
    // MARK: - Connection State
    @Published var isConnected: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: String?
    
    // MARK: - UI State
    @Published var isLoading: Bool = false
    @Published var showSettings: Bool = false
    @Published var showOnboarding: Bool = false
    @Published var selectedTab: TabSelection? = .chat
    
    // MARK: - System State
    @Published var systemStatus: SystemStatus = .unknown
    @Published var availableModels: [ModelsResponse.ModelInfo] = []
    @Published var currentModel: String = "default"
    
    private init() {
        loadSettings()
        setupObservers()
    }
    
    // MARK: - Mode Management
    func switchMode(to mode: AppMode) {
        previousMode = currentMode
        currentMode = mode
        
        // Handle mode-specific transitions
        switch mode {
        case .chat:
            stopVoiceRecording()
        case .voice:
            prepareVoiceMode()
        }
        
        saveSettings()
    }
    
    func toggleMode() {
        switchMode(to: currentMode == .chat ? .voice : .chat)
    }
    
    // MARK: - Voice Management
    func startVoiceRecording() {
        guard currentMode == .voice else { return }
        voiceState = .recording
        isRecording = true
        // Additional voice recording logic will be implemented in VoiceViewModel
    }
    
    func stopVoiceRecording() {
        voiceState = .idle
        isRecording = false
        audioLevel = 0.0
        // Additional voice recording logic will be implemented in VoiceViewModel
    }
    
    private func prepareVoiceMode() {
        // Prepare voice mode - check permissions, initialize audio, etc.
        voiceState = .idle
    }
    
    // MARK: - Connection Management
    func updateConnectionStatus(_ status: ConnectionStatus) {
        connectionStatus = status
        isConnected = status == .connected
        
        if status == .connected {
            lastError = nil
        }
    }
    
    func setError(_ error: String) {
        lastError = error
        chatState = .error(error)
    }
    
    func clearError() {
        lastError = nil
        if case .error = chatState {
            chatState = .idle
        }
    }
    
    // MARK: - Settings Management
    private func loadSettings() {
        // Load settings from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "chatSettings"),
           let settings = try? JSONDecoder().decode(ChatSettings.self, from: data) {
            chatSettings = settings
        }
        
        isWakeWordEnabled = UserDefaults.standard.bool(forKey: "isWakeWordEnabled")
        currentModel = UserDefaults.standard.string(forKey: "currentModel") ?? "default"
    }
    
    private func saveSettings() {
        // Save settings to UserDefaults
        if let data = try? JSONEncoder().encode(chatSettings) {
            UserDefaults.standard.set(data, forKey: "chatSettings")
        }
        
        UserDefaults.standard.set(isWakeWordEnabled, forKey: "isWakeWordEnabled")
        UserDefaults.standard.set(currentModel, forKey: "currentModel")
    }
    
    // MARK: - Observers
    private func setupObservers() {
        // Setup observers for system events, notifications, etc.
    }
}

// MARK: - Enums
enum AppMode {
    case chat
    case voice
}

enum VoiceState: Equatable {
    case idle
    case listening
    case recording
    case processing
    case speaking
    case error(String)
}

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(String)
    
    static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected),
             (.reconnecting, .reconnecting):
            return true
        case let (.error(a), .error(b)):
            return a == b
        default:
            return false
        }
    }
}

enum SystemStatus {
    case unknown
    case healthy
    case warning
    case error
    case maintenance
}

enum TabSelection {
    case chat
    case voice
    case settings
    case search
}

// MARK: - Extensions
extension JarvisStateManager {
    var isInVoiceMode: Bool {
        return currentMode == .voice
    }
    
    var isInChatMode: Bool {
        return currentMode == .chat
    }
    
    var canRecordVoice: Bool {
        return currentMode == .voice && voiceState == VoiceState.idle && isConnected
    }
    
    var shouldShowVoiceUI: Bool {
        return currentMode == .voice
    }
    
    var shouldShowChatUI: Bool {
        return currentMode == .chat
    }
}

// MARK: - Preview Helper
extension JarvisStateManager {
    static var preview: JarvisStateManager {
        let manager = JarvisStateManager()
        manager.currentMode = .chat
        manager.isConnected = true
        manager.connectionStatus = .connected
        manager.currentChatId = UUID()
        return manager
    }
} 