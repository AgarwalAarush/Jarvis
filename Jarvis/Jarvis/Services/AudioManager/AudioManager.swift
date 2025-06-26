import Foundation
import AVFoundation
import Combine

// MARK: - Audio Manager
class AudioManager: NSObject, ObservableObject {
    // MARK: - Properties
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode
    private var outputNode: AVAudioOutputNode
    
    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var isSessionActive = false
    @Published private(set) var error: AudioError?
    
    private var audioLevelTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Audio Configuration
    private let sampleRate: Double = 16000
    private let bufferSize: AVAudioFrameCount = 1024
    private let audioLevelUpdateInterval: TimeInterval = 0.1
    
    // MARK: - Initialization
    override init() {
        self.audioEngine = AVAudioEngine()
        self.inputNode = audioEngine.inputNode
        self.outputNode = audioEngine.outputNode
        
        super.init()
        
        setupAudioSession()
        setupAudioEngine()
        setupAudioLevelMonitoring()
    }
    
    deinit {
        stopRecording()
        stopPlayback()
        cleanup()
    }
    
    // MARK: - Public Methods
    func startRecording() throws {
        guard !isRecording else { return }
        
        do {
            try setupAudioSession()
            try setupRecordingFormat()
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            error = nil
            
            startAudioLevelMonitoring()
            
        } catch {
            self.error = .recordingFailed(error.localizedDescription)
            throw error
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        isRecording = false
        stopAudioLevelMonitoring()
    }
    
    func startPlayback(audioData: Data) throws {
        guard !isPlaying else { return }
        
        do {
            try setupAudioSession()
            
            let audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            
            isPlaying = true
            error = nil
            
            audioPlayer.play()
            
        } catch {
            self.error = .playbackFailed(error.localizedDescription)
            throw error
        }
    }
    
    func stopPlayback() {
        isPlaying = false
    }
    
    func pausePlayback() {
        // Implementation for pausing playback
    }
    
    func resumePlayback() {
        // Implementation for resuming playback
    }
    
    // MARK: - Audio Level Monitoring
    func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: audioLevelUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0.0
    }
    
    // MARK: - Private Methods
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            isSessionActive = true
        } catch {
            self.error = .sessionSetupFailed(error.localizedDescription)
            throw error
        }
    }
    
    private func setupAudioEngine() {
        audioEngine.prepare()
    }
    
    private func setupRecordingFormat() throws {
        let recordingFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        )
        
        guard let format = recordingFormat else {
            throw AudioError.invalidFormat
        }
        
        // Configure input node format
        inputNode.setPreferredInputFormat(format, forBus: 0)
    }
    
    private func setupAudioLevelMonitoring() {
        // Set up audio level monitoring
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            self?.calculateAudioLevel(buffer)
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Process audio buffer for recording
        // This is where you would send audio data to the backend
        calculateAudioLevel(buffer)
    }
    
    private func calculateAudioLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0
        
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        let db = 20 * log10(rms)
        
        // Normalize to 0-1 range
        let normalizedLevel = max(0.0, min(1.0, (db + 60) / 60))
        
        DispatchQueue.main.async {
            self.audioLevel = normalizedLevel
        }
    }
    
    private func updateAudioLevel() {
        // Update audio level from the current buffer
        // This is called periodically to provide smooth audio level updates
    }
    
    private func cleanup() {
        stopRecording()
        stopPlayback()
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            isSessionActive = false
        } catch {
            print("Error deactivating audio session: \(error)")
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isPlaying = false
            if let error = error {
                self.error = .playbackFailed(error.localizedDescription)
            }
        }
    }
}

// MARK: - Audio Error
enum AudioError: Error, LocalizedError {
    case sessionSetupFailed(String)
    case recordingFailed(String)
    case playbackFailed(String)
    case invalidFormat
    case permissionDenied
    case deviceNotFound
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .sessionSetupFailed(let message):
            return "Audio session setup failed: \(message)"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .playbackFailed(let message):
            return "Playback failed: \(message)"
        case .invalidFormat:
            return "Invalid audio format"
        case .permissionDenied:
            return "Microphone permission denied"
        case .deviceNotFound:
            return "Audio device not found"
        case .unknown:
            return "Unknown audio error"
        }
    }
}

// MARK: - Audio Configuration
struct AudioConfiguration {
    let sampleRate: Double
    let channels: Int
    let bitDepth: Int
    let bufferSize: AVAudioFrameCount
    
    static let standard = AudioConfiguration(
        sampleRate: 16000,
        channels: 1,
        bitDepth: 16,
        bufferSize: 1024
    )
    
    static let highQuality = AudioConfiguration(
        sampleRate: 44100,
        channels: 2,
        bitDepth: 24,
        bufferSize: 2048
    )
}

// MARK: - Audio Level Observer
class AudioLevelObserver: ObservableObject {
    @Published var currentLevel: Float = 0.0
    @Published var peakLevel: Float = 0.0
    @Published var averageLevel: Float = 0.0
    
    private var levels: [Float] = []
    private let maxLevels = 100
    
    func updateLevel(_ level: Float) {
        currentLevel = level
        
        // Update peak level
        if level > peakLevel {
            peakLevel = level
        }
        
        // Update average level
        levels.append(level)
        if levels.count > maxLevels {
            levels.removeFirst()
        }
        
        averageLevel = levels.reduce(0, +) / Float(levels.count)
    }
    
    func reset() {
        currentLevel = 0.0
        peakLevel = 0.0
        averageLevel = 0.0
        levels.removeAll()
    }
} 