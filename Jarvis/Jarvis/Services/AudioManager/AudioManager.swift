import Foundation
import AVFoundation
import Combine
import Accelerate

// MARK: - Audio Manager
class AudioManager: NSObject, ObservableObject {
    // MARK: - Properties
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode
    private var playerNode: AVAudioPlayerNode

    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var isSessionActive = false
    @Published private(set) var error: AudioError?

    private let audioBufferSubject = PassthroughSubject<AVAudioPCMBuffer, Never>()
    public lazy var audioBufferPublisher = audioBufferSubject.eraseToAnyPublisher()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Audio Configuration
    private let sampleRate: Double = 16000
    private let bufferSize: AVAudioFrameCount = 1024

    // MARK: - Initialization
    override init() {
        self.audioEngine = AVAudioEngine()
        self.inputNode = audioEngine.inputNode
        self.playerNode = AVAudioPlayerNode()

        super.init()

        do {
            try setupAudioSession()
        } catch {
            print("Warning: Audio session setup failed: \(error)")
        }
        setupAudioEngine()
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
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            isRecording = true
            error = nil

        } catch {
            self.error = .recordingFailed(error.localizedDescription)
            throw error
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        inputNode.removeTap(onBus: 0)
        if !playerNode.isPlaying {
             audioEngine.stop()
        }

        isRecording = false
        audioLevel = 0.0
    }

    func startPlayback(audioData: Data) throws {
        guard !isPlaying else { return }

        do {
            try setupAudioSession()

            let playbackFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)
            guard let format = playbackFormat else {
                throw AudioError.invalidFormat
            }

            let frameCount = AVAudioFrameCount(audioData.count / MemoryLayout<Float>.size)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                throw AudioError.playbackFailed("Failed to create buffer")
            }
            buffer.frameLength = frameCount
            
            audioData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                if let floatPtr = bytes.baseAddress?.assumingMemoryBound(to: Float.self) {
                    buffer.floatChannelData?.pointee.update(from: floatPtr, count: Int(frameCount))
                }
            }

            if !audioEngine.isRunning {
                audioEngine.prepare()
                try audioEngine.start()
            }
            
            playerNode.scheduleBuffer(buffer) { [weak self] in
                DispatchQueue.main.async {
                    self?.isPlaying = false
                    if self?.isRecording == false {
                        self?.playerNode.stop()
                        self?.audioEngine.stop()
                    }
                }
            }

            playerNode.play()
            isPlaying = true
            error = nil

        } catch {
            self.error = .playbackFailed(error.localizedDescription)
            throw error
        }
    }

    func stopPlayback() {
        if playerNode.isPlaying {
            playerNode.stop()
        }
        isPlaying = false
    }

    func pausePlayback() {
        if playerNode.isPlaying {
            playerNode.pause()
        }
    }

    func resumePlayback() {
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    // MARK: - Private Methods
    private func setupAudioSession() throws {
        isSessionActive = true
    }

    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.outputNode, format: nil)
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        calculateAudioLevel(buffer)
        audioBufferSubject.send(buffer)
    }

    private func calculateAudioLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let frameLength = vDSP_Length(buffer.frameLength)
        var rms: Float = 0.0
        vDSP_rmsqv(channelData, 1, &rms, frameLength)

        let db = 20 * log10(rms)
        
        let normalizedLevel = rms > 0 ? max(0.0, min(1.0, (db + 60) / 60)) : 0.0

        DispatchQueue.main.async {
            self.audioLevel = normalizedLevel
        }
    }

    private func cleanup() {
        stopRecording()
        stopPlayback()
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        isSessionActive = false
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
        
        if level > peakLevel {
            peakLevel = level
        }
        
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
