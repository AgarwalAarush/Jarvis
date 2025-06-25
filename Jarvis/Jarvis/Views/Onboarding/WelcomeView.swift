import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var stateManager: JarvisStateManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    
    private let steps = [
        WelcomeStep(
            title: "Welcome to Jarvis",
            subtitle: "Your AI Assistant",
            description: "Jarvis is an intelligent voice assistant that combines text chat with hands-free voice control. Get ready to experience the future of AI interaction.",
            icon: "brain.head.profile",
            color: .blue
        ),
        WelcomeStep(
            title: "Text Chat",
            subtitle: "Powerful Conversations",
            description: "Engage in rich text conversations with support for markdown, code highlighting, and conversation history. Your chats are automatically saved and organized.",
            icon: "message",
            color: .green
        ),
        WelcomeStep(
            title: "Voice Control",
            subtitle: "Hands-Free Interaction",
            description: "Say 'Jarvis' to activate voice mode. Speak naturally and get instant responses. Perfect for when your hands are busy or you prefer voice interaction.",
            icon: "mic",
            color: .orange
        ),
        WelcomeStep(
            title: "Ready to Start",
            subtitle: "Let's Begin",
            description: "You're all set! Start with text chat or switch to voice mode anytime. Your conversations will be saved automatically.",
            icon: "checkmark.circle",
            color: .purple
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressIndicator
            
            // Content area
            contentArea
            
            // Navigation buttons
            navigationButtons
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    @ViewBuilder
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var contentArea: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: steps[currentStep].icon)
                .font(.system(size: 80))
                .foregroundColor(steps[currentStep].color)
                .animation(.easeInOut(duration: 0.5), value: currentStep)
            
            // Text content
            VStack(spacing: 16) {
                Text(steps[currentStep].title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(steps[currentStep].subtitle)
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(steps[currentStep].description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .animation(.easeInOut(duration: 0.5), value: currentStep)
            
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            if currentStep < steps.count - 1 {
                Button("Next") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Get Started") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// MARK: - Welcome Step Model
struct WelcomeStep {
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let color: Color
}

// MARK: - Preview
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
            .environmentObject(JarvisStateManager.preview)
    }
} 