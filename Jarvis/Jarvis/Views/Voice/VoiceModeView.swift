import SwiftUI

struct VoiceModeView: View {
    @EnvironmentObject var stateManager: JarvisStateManager
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // AI Sphere Animation (placeholder)
            AISphereView()
                .frame(width: 200, height: 200)
            
            // Voice Activity Indicator
            VoiceActivityView()
                .frame(height: 100)
            
            // Status Text
            Text(voiceStatusText)
                .font(.title2)
                .foregroundColor(.primary)
            
            // Microphone Controls
            MicrophoneView()
                .frame(width: 80, height: 80)
            
            Spacer()
            
            // Instructions
            VStack(spacing: 8) {
                Text("Voice Mode")
                    .font(.headline)
                
                Text("Say 'Jarvis' to activate, then speak your message")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var voiceStatusText: String {
        switch stateManager.voiceState {
        case .idle:
            return "Ready to listen"
        case .listening:
            return "Listening..."
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .speaking:
            return "Speaking..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

// MARK: - AI Sphere View (Placeholder)
struct AISphereView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Inner sphere
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.8), Color.accentColor.opacity(0.2)],
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Voice Activity View (Placeholder)
struct VoiceActivityView: View {
    @EnvironmentObject var stateManager: JarvisStateManager
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<20) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 4, height: 20 + CGFloat(stateManager.audioLevel * 40))
                    .scaleEffect(y: 0.5 + Double.random(in: 0.5...1.5), anchor: .bottom)
                    .animation(
                        Animation.easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.05),
                        value: stateManager.audioLevel
                    )
            }
        }
    }
}

// MARK: - Microphone View (Placeholder)
struct MicrophoneView: View {
    @EnvironmentObject var stateManager: JarvisStateManager
    
    var body: some View {
        Button(action: {
            if stateManager.isRecording {
                stateManager.stopVoiceRecording()
            } else {
                stateManager.startVoiceRecording()
            }
        }) {
            Image(systemName: stateManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(stateManager.isRecording ? .red : .accentColor)
        }
        .buttonStyle(PlainButtonStyle())
        .help(stateManager.isRecording ? "Stop Recording" : "Start Recording")
    }
}

// MARK: - Preview
struct VoiceModeView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceModeView()
            .environmentObject(JarvisStateManager.preview)
    }
} 