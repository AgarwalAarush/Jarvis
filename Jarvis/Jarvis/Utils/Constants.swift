import Foundation
import SwiftUI

// MARK: - App Constants
struct AppConstants {
    static let appName = "Jarvis"
    static let appVersion = "1.0.0"
    static let buildNumber = "1"
    
    // API Configuration
    static let defaultAPIURL = "http://localhost:5000"
    static let defaultAPITimeout: TimeInterval = 30.0
    
    // UI Configuration
    static let minWindowWidth: CGFloat = 500
    static let minWindowHeight: CGFloat = 700
    static let sidebarMinWidth: CGFloat = 200
    static let sidebarMaxWidth: CGFloat = 300
    
    // Animation Durations
    static let shortAnimationDuration: Double = 0.2
    static let mediumAnimationDuration: Double = 0.3
    static let longAnimationDuration: Double = 0.5
    
    // CoreData Configuration
    static let maxMessagesPerChat = 1000
    static let maxChatsToKeep = 100
    
    // Audio Configuration
    static let defaultSampleRate = 16000
    static let defaultChannels = 1
    static let defaultBitDepth = 16
    
    // UserDefaults Keys
    struct UserDefaultsKeys {
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let chatSettings = "chatSettings"
        static let isWakeWordEnabled = "isWakeWordEnabled"
        static let currentModel = "currentModel"
        static let apiURL = "apiURL"
        static let apiKey = "apiKey"
    }
    
    // Notification Names
    struct NotificationNames {
        static let chatUpdated = "chatUpdated"
        static let voiceStateChanged = "voiceStateChanged"
        static let connectionStatusChanged = "connectionStatusChanged"
    }
}

// MARK: - Color Extensions
extension Color {
    static let jarvisAccent = Color.accentColor
    static let jarvisBackground = Color(NSColor.controlBackgroundColor)
    static let jarvisSecondary = Color.secondary
    static let jarvisError = Color.red
    static let jarvisSuccess = Color.green
    static let jarvisWarning = Color.orange
}

// MARK: - Font Extensions
extension Font {
    static let jarvisTitle = Font.largeTitle
    static let jarvisHeadline = Font.headline
    static let jarvisBody = Font.body
    static let jarvisCaption = Font.caption
    static let jarvisCaption2 = Font.caption2
}

// MARK: - Spacing Constants
struct Spacing {
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 32
}

// MARK: - Corner Radius Constants
struct CornerRadius {
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 24
} 