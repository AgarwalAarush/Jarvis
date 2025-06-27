import Foundation
import AVFoundation
import SwiftUI
import Combine

class VoiceViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var voiceState: VoiceState = .idle
    @Published var audioLevel: Double = 0.0
    @Published var isRecording: Bool = false
    @Published var isWakeWordEnabled: Bool = true
    @Published var wakeWordDetected: Bool = false
    @Published var lastTranscription: String = ""
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Audio Services
    private let audioManager: AudioManager
    private let audioStreamer: AudioStreamer
    let audioVisualizer: AudioVisualizer
    private let apiClient: APIClientProtocol
    
    // MARK: - State Management
    private var cancellables = Set<AnyCancellable>()
    private var isAudioSessionConfigured = false
    
    // MARK: - Initialization
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
        self.audioManager = AudioManager()
        self.audioStreamer = AudioStreamer(audioManager: audioManager, apiClient: apiClient)
        self.audioVisualizer = AudioVisualizer(barCount: 30)
        
        setupAudioSession()
        setupStateObservers()
        setupAudioMonitoring()
    }
    
    deinit {
        cleanupAudio()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try audioManager.startRecording()
            isAudioSessionConfigured = true
        } catch {
            print("Error setting up audio session: \(error)")
            errorMessage = "Failed to configure audio: \(error.localizedDescription)"
        }
    }
    
    // MARK: - State Observers
    private func setupStateObservers() {
        // Monitor wake word detection
        $wakeWordDetected
            .sink { [weak self] detected in
                if detected {
                    self?.handleWakeWordDetection()
                }
            }
            .store(in: &cancellables)
        
        // Monitor recording state
        $isRecording
            .sink { [weak self] recording in
                if recording {
                    self?.startAudioLevelMonitoring()
                } else {
                    self?.stopAudioLevelMonitoring()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Audio Monitoring
    private func setupAudioMonitoring() {
        // Monitor audio manager state
        audioManager.$isRecording
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)
        
        audioManager.$audioLevel
            .map { Double($0) }
            .assign(to: \.audioLevel, on: self)
            .store(in: &cancellables)
        
        audioManager.$error
            .compactMap { $0 }
            .map { $0.localizedDescription }
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        // Monitor audio streamer state
        audioStreamer.$isStreaming
            .sink { [weak self] streaming in
                if streaming {
                    self?.voiceState = .recording
                }
            }
            .store(in: &cancellables)
        
        audioStreamer.$streamError
            .compactMap { $0 }
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Voice Recording
    func startVoiceRecording() {
        guard !isRecording else { return }
        guard isAudioSessionConfigured else {
            errorMessage = "Audio session not configured"
            return
        }
        
        do {
            try audioStreamer.startStreaming()
            isRecording = true
            voiceState = .recording
            errorMessage = nil
            
            // Start audio visualization
            audioVisualizer.startVisualization()
            
        } catch {
            print("Error starting voice recording: \(error)")
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            voiceState = .error(error.localizedDescription)
        }
    }
    
    func stopVoiceRecording() {
        guard isRecording else { return }
        
        audioStreamer.stopStreaming()
        isRecording = false
        voiceState = .processing
        
        // Stop audio visualization
        audioVisualizer.stopVisualization()
        
        // Process the recorded audio
        processRecordedAudio()
    }
    
    // MARK: - Audio Processing
    private func processRecordedAudio() {
        isProcessing = true
        
        // Send audio to backend for processing
        // This will be implemented when we connect to the Python backend
        
        // For now, simulate processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.handleProcessingComplete()
        }
    }
    
    private func handleProcessingComplete() {
        isProcessing = false
        voiceState = .idle
        lastTranscription = "Voice processing complete (placeholder)"
    }
    
    // MARK: - Audio Level Monitoring
    private func startAudioLevelMonitoring() {
        // Audio level monitoring is now handled by AudioManager
        audioVisualizer.startVisualization()
    }
    
    private func stopAudioLevelMonitoring() {
        audioVisualizer.stopVisualization()
        audioLevel = 0.0
    }
    
    // MARK: - Wake Word Detection
    func handleWakeWordDetection() {
        guard isWakeWordEnabled else { return }
        
        // Reset wake word detection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.wakeWordDetected = false
        }
        
        // Start recording automatically
        startVoiceRecording()
    }
    
    func toggleWakeWordDetection() {
        isWakeWordEnabled.toggle()
        if !isWakeWordEnabled {
            wakeWordDetected = false
        }
    }
    
    // MARK: - Audio Playback
    func playAudioResponse(_ audioData: Data) {
        do {
            try audioManager.startPlayback(audioData: audioData)
            voiceState = .speaking
        } catch {
            errorMessage = "Failed to play audio response: \(error.localizedDescription)"
        }
    }
    
    func stopAudioPlayback() {
        audioManager.stopPlayback()
        if case .speaking = voiceState {
            voiceState = .idle
        }
    }
    
    // MARK: - Audio Visualization
    func startAudioVisualization() {
        audioVisualizer.startVisualization()
    }
    
    func stopAudioVisualization() {
        audioVisualizer.stopVisualization()
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
        if case .error = voiceState {
            voiceState = .idle
        }
    }
    
    // MARK: - Cleanup
    private func cleanupAudio() {
        stopVoiceRecording()
        stopAudioLevelMonitoring()
        audioVisualizer.stopVisualization()
        
        cancellables.removeAll()
    }
    
    // MARK: - Public Interface
    func reset() {
        stopVoiceRecording()
        clearError()
        lastTranscription = ""
        voiceState = .idle
        audioVisualizer.reset()
    }
    
    func requestMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if !granted {
                        self?.errorMessage = "Microphone permission is required for voice mode"
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Microphone permission is required for voice mode"
            }
        @unknown default:
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Unknown microphone permission status"
            }
        }
    }
    
    // MARK: - Audio Streaming
    func startAudioStreaming() throws {
        try audioStreamer.startStreaming()
    }
    
    func stopAudioStreaming() {
        audioStreamer.stopStreaming()
    }
    
    func startAudioReceiving() {
        audioStreamer.startReceiving()
    }
    
    func stopAudioReceiving() {
        audioStreamer.stopReceiving()
    }
}

// MARK: - Voice Error
enum VoiceError: LocalizedError {
    case audioEngineNotInitialized
    case permissionDenied
    case recordingFailed
    case streamingFailed(String)
    case playbackFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .audioEngineNotInitialized:
            return "Audio engine not initialized"
        case .permissionDenied:
            return "Microphone permission denied"
        case .recordingFailed:
            return "Failed to start recording"
        case .streamingFailed(let message):
            return "Audio streaming failed: \(message)"
        case .playbackFailed(let message):
            return "Audio playback failed: \(message)"
        }
    }
}

// MARK: - Voice State Extension
extension VoiceState {
    var displayName: String {
        switch self {
        case .idle:
            return "Ready"
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
    
    var iconName: String {
        switch self {
        case .idle:
            return "mic"
        case .listening:
            return "mic.fill"
        case .recording:
            return "mic.fill"
        case .processing:
            return "clock"
        case .speaking:
            return "speaker.wave.2.fill"
        case .error:
            return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .listening, .recording:
            return .red
        case .processing:
            return .orange
        case .speaking:
            return .green
        case .error:
            return .red
        }
    }
}

// MARK: - Preview Helper
extension VoiceViewModel {
    static var preview: VoiceViewModel {
        let viewModel = VoiceViewModel(apiClient: JarvisAPIClient.shared)
        viewModel.voiceState = .idle
        viewModel.audioLevel = 0.3
        viewModel.isWakeWordEnabled = true
        return viewModel
    }
}
