import SwiftUI
import Combine

struct VoiceModeView: View {
    @EnvironmentObject var stateManager: JarvisStateManager
    @StateObject private var viewModel: VoiceViewModel
    
    init() {
        // Initialize with a mock API client for now
        let mockAPIClient = MockAPIClient()
        self._viewModel = StateObject(wrappedValue: VoiceViewModel(apiClient: mockAPIClient))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // AI Sphere Animation with enhanced visualization
            ZStack {
                AISphereView()
                    .frame(width: 200, height: 200)
                
                // Audio visualization overlay
                if viewModel.isRecording {
                    AudioVisualizationView(
                        visualizer: viewModel.getAudioVisualizer(),
                        style: .circular
                    )
                    .frame(width: 180, height: 180)
                }
            }
            
            // Voice Activity Indicator with enhanced visualization
            VoiceActivityView()
                .frame(height: 100)
            
            // Status Text
            Text(voiceStatusText)
                .font(.title2)
                .foregroundColor(.primary)
            
            // Audio Level Meter
            AudioLevelMeter(
                level: Float(viewModel.audioLevel),
                peakLevel: Float(viewModel.getAudioVisualizer().peakLevel)
            )
            .frame(height: 20)
            .padding(.horizontal, 40)
            
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
        .onAppear {
            viewModel.startAudioVisualization()
        }
        .onDisappear {
            viewModel.stopAudioVisualization()
        }
    }
    
    private var voiceStatusText: String {
        switch viewModel.voiceState {
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

// MARK: - Enhanced AI Sphere View
struct AISphereView: View {
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 3)
                .scaleEffect(pulseScale)
                .opacity(isAnimating ? 0 : 1)
                .animation(
                    Animation.easeOut(duration: 2.0)
                        .repeatForever(autoreverses: false),
                    value: pulseScale
                )
            
            // Middle ring
            Circle()
                .stroke(Color.accentColor.opacity(0.4), lineWidth: 2)
                .scaleEffect(isAnimating ? 1.3 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Inner sphere with gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.accentColor.opacity(0.9),
                            Color.accentColor.opacity(0.6),
                            Color.accentColor.opacity(0.2)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 60
                    )
                )
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Center highlight
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 20, height: 20)
                .blur(radius: 2)
        }
        .onAppear {
            isAnimating = true
            pulseScale = 2.0
        }
    }
}

// MARK: - Enhanced Voice Activity View
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

// MARK: - Enhanced Microphone View
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
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                // Icon
                Image(systemName: stateManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(stateManager.isRecording ? .red : .accentColor)
                    .scaleEffect(stateManager.isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: stateManager.isRecording)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .help(stateManager.isRecording ? "Stop Recording" : "Start Recording")
        .scaleEffect(stateManager.isRecording ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: stateManager.isRecording)
    }
}

// MARK: - Mock API Client for VoiceModeView
private class MockAPIClient: APIClientProtocol {
    func connect() -> AnyPublisher<ConnectionStatus, Never> {
        return Just(.connected).eraseToAnyPublisher()
    }
    
    func disconnect() {}
    
    var connectionStatus: ConnectionStatus = .connected
    
    func sendMessage(_ message: String, conversationId: UUID?) -> AnyPublisher<ChatResponse, APIError> {
        return Fail(error: APIError.unknown).eraseToAnyPublisher()
    }
    
    func sendMessageStream(_ message: String, conversationId: UUID?) -> AnyPublisher<ChatStreamResponse, APIError> {
        return Fail(error: APIError.unknown).eraseToAnyPublisher()
    }
    
    func getConversations() -> AnyPublisher<[ConversationDTO], APIError> {
        return Just([]).setFailureType(to: APIError.self).eraseToAnyPublisher()
    }
    
    func createConversation(title: String?) -> AnyPublisher<ConversationDTO, APIError> {
        return Fail(error: APIError.unknown).eraseToAnyPublisher()
    }
    
    func getConversation(id: UUID) -> AnyPublisher<ConversationDTO, APIError> {
        return Fail(error: APIError.unknown).eraseToAnyPublisher()
    }
    
    func deleteConversation(id: UUID) -> AnyPublisher<Void, APIError> {
        return Just(()).setFailureType(to: APIError.self).eraseToAnyPublisher()
    }
    
    func updateConversation(id: UUID, title: String) -> AnyPublisher<ConversationDTO, APIError> {
        return Fail(error: APIError.unknown).eraseToAnyPublisher()
    }
    
    func searchConversations(query: String) -> AnyPublisher<[SearchResult], APIError> {
        return Just([]).setFailureType(to: APIError.self).eraseToAnyPublisher()
    }
    
    func searchMessages(query: String, conversationId: UUID?) -> AnyPublisher<[SearchResult], APIError> {
        return Just([]).setFailureType(to: APIError.self).eraseToAnyPublisher()
    }
    
    func exportConversation(id: UUID, format: ExportFormat) -> AnyPublisher<Data, APIError> {
        return Fail(error: APIError.unknown).eraseToAnyPublisher()
    }
    
    func exportAllConversations(format: ExportFormat) -> AnyPublisher<Data, APIError> {
        return Fail(error: APIError.unknown).eraseToAnyPublisher()
    }
    
    func getStatus() -> AnyPublisher<SystemStatus, APIError> {
        return Fail(error: APIError.unknown).eraseToAnyPublisher()
    }
    
    func getModels() -> AnyPublisher<[ModelInfo], APIError> {
        return Just([]).setFailureType(to: APIError.self).eraseToAnyPublisher()
    }
    
    func getConfig() -> AnyPublisher<SystemConfig, APIError> {
        return Fail(error: APIError.unknown).eraseToAnyPublisher()
    }
    
    func healthCheck() -> AnyPublisher<HealthStatus, APIError> {
        return Fail(error: APIError.unknown).eraseToAnyPublisher()
    }
}

// MARK: - Preview
struct VoiceModeView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceModeView()
            .environmentObject(JarvisStateManager.preview)
    }
} 