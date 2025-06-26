import Foundation
import AVFoundation
import AppKit
import Combine

class PermissionsManager: ObservableObject {
    // MARK: - Published Properties
    @Published var microphonePermission: PermissionStatus = .unknown
    @Published var accessibilityPermission: PermissionStatus = .unknown
    @Published var automationPermission: PermissionStatus = .unknown
    @Published var notificationPermission: PermissionStatus = .unknown
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        checkAllPermissions()
        setupObservers()
    }
    
    // MARK: - Permission Checking
    func checkAllPermissions() {
        checkMicrophonePermission()
        checkAccessibilityPermission()
        checkAutomationPermission()
        checkNotificationPermission()
    }
    
    func checkMicrophonePermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            microphonePermission = .granted
        case .denied:
            microphonePermission = .denied
        case .undetermined:
            microphonePermission = .notDetermined
        @unknown default:
            microphonePermission = .unknown
        }
    }
    
    func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        accessibilityPermission = trusted ? .granted : .denied
    }
    
    func checkAutomationPermission() {
        // Check if we can run AppleScript
        let testScript = """
        tell application "System Events"
            return "test"
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: testScript) {
            let result = scriptObject.executeAndReturnError(&error)
            automationPermission = error == nil ? .granted : .denied
        } else {
            automationPermission = .denied
        }
    }
    
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self?.notificationPermission = .granted
                case .denied:
                    self?.notificationPermission = .denied
                case .notDetermined:
                    self?.notificationPermission = .notDetermined
                @unknown default:
                    self?.notificationPermission = .unknown
                }
            }
        }
    }
    
    // MARK: - Permission Requesting
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.microphonePermission = granted ? .granted : .denied
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        accessibilityPermission = trusted ? .granted : .denied
        return trusted
    }
    
    func requestAutomationPermission() -> Bool {
        // Request automation permission by trying to run a simple script
        let testScript = """
        tell application "System Events"
            return "test"
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: testScript) {
            let result = scriptObject.executeAndReturnError(&error)
            let granted = error == nil
            automationPermission = granted ? .granted : .denied
            return granted
        } else {
            automationPermission = .denied
            return false
        }
    }
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            DispatchQueue.main.async {
                self.notificationPermission = granted ? .granted : .denied
            }
            return granted
        } catch {
            DispatchQueue.main.async {
                self.notificationPermission = .denied
            }
            return false
        }
    }
    
    // MARK: - Permission Status
    var allPermissionsGranted: Bool {
        return microphonePermission == .granted &&
               accessibilityPermission == .granted &&
               automationPermission == .granted &&
               notificationPermission == .granted
    }
    
    var criticalPermissionsGranted: Bool {
        return microphonePermission == .granted &&
               accessibilityPermission == .granted
    }
    
    var missingPermissions: [PermissionType] {
        var missing: [PermissionType] = []
        
        if microphonePermission != .granted {
            missing.append(.microphone)
        }
        if accessibilityPermission != .granted {
            missing.append(.accessibility)
        }
        if automationPermission != .granted {
            missing.append(.automation)
        }
        if notificationPermission != .granted {
            missing.append(.notification)
        }
        
        return missing
    }
    
    var criticalMissingPermissions: [PermissionType] {
        var missing: [PermissionType] = []
        
        if microphonePermission != .granted {
            missing.append(.microphone)
        }
        if accessibilityPermission != .granted {
            missing.append(.accessibility)
        }
        
        return missing
    }
    
    // MARK: - Permission Descriptions
    func getPermissionDescription(for type: PermissionType) -> String {
        switch type {
        case .microphone:
            return "Microphone access is required for voice commands and speech recognition."
        case .accessibility:
            return "Accessibility access is required for system automation and control."
        case .automation:
            return "Automation access is required for running AppleScript commands."
        case .notification:
            return "Notification access is required for system notifications and alerts."
        }
    }
    
    func getPermissionInstructions(for type: PermissionType) -> String {
        switch type {
        case .microphone:
            return "1. Click 'Allow' when prompted\n2. Or go to System Preferences > Security & Privacy > Privacy > Microphone\n3. Enable Jarvis in the list"
        case .accessibility:
            return "1. Go to System Preferences > Security & Privacy > Privacy > Accessibility\n2. Click the lock icon and enter your password\n3. Enable Jarvis in the list"
        case .automation:
            return "1. Go to System Preferences > Security & Privacy > Privacy > Automation\n2. Click the lock icon and enter your password\n3. Enable Jarvis for System Events"
        case .notification:
            return "1. Go to System Preferences > Notifications & Focus > Jarvis\n2. Enable notifications for Jarvis\n3. Choose your preferred notification style"
        }
    }
    
    // MARK: - Permission Actions
    func openSystemPreferences(for type: PermissionType) {
        switch type {
        case .microphone:
            openSystemPreferences(path: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        case .accessibility:
            openSystemPreferences(path: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .automation:
            openSystemPreferences(path: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        case .notification:
            openSystemPreferences(path: "x-apple.systempreferences:com.apple.preference.notifications")
        }
    }
    
    private func openSystemPreferences(path: String) {
        if let url = URL(string: path) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Permission Monitoring
    private func setupObservers() {
        // Monitor for permission changes
        NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                // Recheck permissions when system wakes
                self?.checkAllPermissions()
            }
            .store(in: &cancellables)
        
        // Monitor for app activation
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                // Recheck permissions when app becomes active
                self?.checkAllPermissions()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Permission Validation
    func validatePermissionsForVoiceMode() -> PermissionValidationResult {
        var missingPermissions: [PermissionType] = []
        var warnings: [String] = []
        
        if microphonePermission != .granted {
            missingPermissions.append(.microphone)
        }
        
        if accessibilityPermission != .granted {
            warnings.append("Accessibility permission is recommended for full voice control features")
        }
        
        if notificationPermission != .granted {
            warnings.append("Notification permission is recommended for voice feedback")
        }
        
        return PermissionValidationResult(
            isValid: missingPermissions.isEmpty,
            missingPermissions: missingPermissions,
            warnings: warnings
        )
    }
    
    func validatePermissionsForChatMode() -> PermissionValidationResult {
        var missingPermissions: [PermissionType] = []
        var warnings: [String] = []
        
        if accessibilityPermission != .granted {
            warnings.append("Accessibility permission is recommended for system automation features")
        }
        
        if automationPermission != .granted {
            warnings.append("Automation permission is recommended for AppleScript integration")
        }
        
        return PermissionValidationResult(
            isValid: true, // Chat mode doesn't require any permissions
            missingPermissions: missingPermissions,
            warnings: warnings
        )
    }
}

// MARK: - Data Models
enum PermissionStatus {
    case unknown
    case notDetermined
    case granted
    case denied
    
    var displayName: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .notDetermined:
            return "Not Determined"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        }
    }
    
    var iconName: String {
        switch self {
        case .unknown:
            return "questionmark.circle"
        case .notDetermined:
            return "exclamationmark.circle"
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .unknown:
            return .secondary
        case .notDetermined:
            return .orange
        case .granted:
            return .green
        case .denied:
            return .red
        }
    }
}

enum PermissionType: String, CaseIterable {
    case microphone = "Microphone"
    case accessibility = "Accessibility"
    case automation = "Automation"
    case notification = "Notification"
    
    var displayName: String {
        return rawValue
    }
    
    var iconName: String {
        switch self {
        case .microphone:
            return "mic"
        case .accessibility:
            return "accessibility"
        case .automation:
            return "gearshape"
        case .notification:
            return "bell"
        }
    }
    
    var isCritical: Bool {
        switch self {
        case .microphone, .accessibility:
            return true
        case .automation, .notification:
            return false
        }
    }
}

struct PermissionValidationResult {
    let isValid: Bool
    let missingPermissions: [PermissionType]
    let warnings: [String]
    
    var hasWarnings: Bool {
        return !warnings.isEmpty
    }
    
    var hasMissingPermissions: Bool {
        return !missingPermissions.isEmpty
    }
    
    var criticalMissingPermissions: [PermissionType] {
        return missingPermissions.filter { $0.isCritical }
    }
    
    var nonCriticalMissingPermissions: [PermissionType] {
        return missingPermissions.filter { !$0.isCritical }
    }
}

// MARK: - Preview Helper
extension PermissionsManager {
    static var preview: PermissionsManager {
        let manager = PermissionsManager()
        manager.microphonePermission = .granted
        manager.accessibilityPermission = .granted
        manager.automationPermission = .granted
        manager.notificationPermission = .granted
        return manager
    }
} 