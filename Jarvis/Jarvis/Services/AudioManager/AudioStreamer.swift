import Foundation
import AVFoundation
import Combine

// MARK: - Audio Streamer
class AudioStreamer: NSObject, ObservableObject {
    // MARK: - Properties
    private let audioManager: AudioManager
    private let apiClient: APIClientProtocol
    
    @Published private(set) var isStreaming = false
    @Published private(set) var isReceiving = false
    @Published private(set) var streamError: String?
    @Published private(set) var bytesSent: Int64 = 0
    @Published private(set) var bytesReceived: Int64 = 0
    
    private var audioBuffer: Data = Data()
    private var streamingTask: URLSessionDataTask?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let bufferThreshold: Int = 4096 // 4KB buffer threshold
    private let streamingURL: URL
    private let session: URLSession
    
    // MARK: - Initialization
    init(audioManager: AudioManager, apiClient: APIClientProtocol, baseURL: URL = URL(string: "http://localhost:5000")!) {
        self.audioManager = audioManager
        self.apiClient = apiClient
        self.streamingURL = baseURL.appendingPathComponent("api/v1/audio/stream")
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 300.0 // 5 minutes for streaming
        self.session = URLSession(configuration: config)
        
        super.init()
        
        setupAudioMonitoring()
    }
    
    deinit {
        stopStreaming()
        stopReceiving()
    }
    
    // MARK: - Public Methods
    func startStreaming() throws {
        guard !isStreaming else { return }
        
        do {
            try audioManager.startRecording()
            
            var request = URLRequest(url: streamingURL)
            request.httpMethod = "POST"
            request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
            request.setValue("chunked", forHTTPHeaderField: "Transfer-Encoding")
            
            streamingTask = session.dataTask(with: request) { [weak self] data, response, error in
                self?.handleStreamingResponse(data: data, response: response, error: error)
            }
            
            streamingTask?.resume()
            isStreaming = true
            streamError = nil
            
        } catch {
            self.streamError = error.localizedDescription
            throw error
        }
    }
    
    func stopStreaming() {
        guard isStreaming else { return }
        
        streamingTask?.cancel()
        streamingTask = nil
        audioManager.stopRecording()
        
        isStreaming = false
        audioBuffer.removeAll()
    }
    
    func startReceiving() {
        guard !isReceiving else { return }
        
        var request = URLRequest(url: streamingURL.appendingPathComponent("receive"))
        request.httpMethod = "GET"
        request.setValue("audio/wav", forHTTPHeaderField: "Accept")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            self?.handleReceivingResponse(data: data, response: response, error: error)
        }
        
        task.resume()
        isReceiving = true
    }
    
    func stopReceiving() {
        isReceiving = false
    }
    
    // MARK: - Private Methods
    private func setupAudioMonitoring() {
        // Monitor audio manager for audio data
        audioManager.$audioLevel
            .sink { [weak self] level in
                self?.processAudioLevel(level)
            }
            .store(in: &cancellables)
    }
    
    private func processAudioLevel(_ level: Float) {
        // Convert audio level to audio data and add to buffer
        // This is a simplified implementation - in practice, you'd get actual audio data
        let audioData = createAudioData(from: level)
        audioBuffer.append(audioData)
        
        // Send buffer if it exceeds threshold
        if audioBuffer.count >= bufferThreshold {
            sendAudioBuffer()
        }
    }
    
    private func createAudioData(from level: Float) -> Data {
        // Create mock audio data from level
        // In practice, this would be actual audio samples
        let sampleCount = 1024
        var samples: [Float] = []
        
        for _ in 0..<sampleCount {
            let sample = Float.random(in: -level...level)
            samples.append(sample)
        }
        
        return Data(bytes: samples, count: samples.count * MemoryLayout<Float>.size)
    }
    
    private func sendAudioBuffer() {
        guard isStreaming, !audioBuffer.isEmpty else { return }
        
        let dataToSend = audioBuffer
        audioBuffer.removeAll()
        
        // Send audio data to server
        streamingTask?.resume()
        
        bytesSent += Int64(dataToSend.count)
    }
    
    private func handleStreamingResponse(data: Data?, response: URLResponse?, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.streamError = error.localizedDescription
                self.isStreaming = false
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.streamError = "Invalid response"
                self.isStreaming = false
                return
            }
            
            if httpResponse.statusCode != 200 {
                self.streamError = "Server error: \(httpResponse.statusCode)"
                self.isStreaming = false
                return
            }
            
            // Handle successful streaming response
            if let data = data {
                self.bytesReceived += Int64(data.count)
                self.processReceivedAudio(data)
            }
        }
    }
    
    private func handleReceivingResponse(data: Data?, response: URLResponse?, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.streamError = error.localizedDescription
                self.isReceiving = false
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.streamError = "Invalid response"
                self.isReceiving = false
                return
            }
            
            if httpResponse.statusCode != 200 {
                self.streamError = "Server error: \(httpResponse.statusCode)"
                self.isReceiving = false
                return
            }
            
            // Handle received audio data
            if let data = data {
                self.bytesReceived += Int64(data.count)
                self.processReceivedAudio(data)
            }
        }
    }
    
    private func processReceivedAudio(_ data: Data) {
        // Process received audio data and play it back
        do {
            try audioManager.startPlayback(audioData: data)
        } catch {
            streamError = "Failed to play received audio: \(error.localizedDescription)"
        }
    }
}

// MARK: - Audio Streaming Configuration
struct AudioStreamingConfig {
    let sampleRate: Double
    let channels: Int
    let bitDepth: Int
    let bufferSize: Int
    let compressionEnabled: Bool
    let encryptionEnabled: Bool
    
    static let standard = AudioStreamingConfig(
        sampleRate: 16000,
        channels: 1,
        bitDepth: 16,
        bufferSize: 4096,
        compressionEnabled: true,
        encryptionEnabled: false
    )
    
    static let highQuality = AudioStreamingConfig(
        sampleRate: 44100,
        channels: 2,
        bitDepth: 24,
        bufferSize: 8192,
        compressionEnabled: true,
        encryptionEnabled: true
    )
}

// MARK: - Audio Streaming Stats
struct AudioStreamingStats {
    let bytesSent: Int64
    let bytesReceived: Int64
    let packetsSent: Int
    let packetsReceived: Int
    let averageLatency: TimeInterval
    let packetLoss: Double
    let timestamp: Date
    
    var throughput: Double {
        let totalBytes = bytesSent + bytesReceived
        return Double(totalBytes) / 1024.0 // KB/s
    }
}

// MARK: - Audio Streaming Error
enum AudioStreamingError: Error, LocalizedError {
    case connectionFailed(String)
    case authenticationFailed
    case serverError(Int, String)
    case audioProcessingFailed(String)
    case networkTimeout
    case invalidAudioFormat
    case bufferOverflow
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .authenticationFailed:
            return "Authentication failed"
        case .serverError(let code, let message):
            return "Server error \(code): \(message)"
        case .audioProcessingFailed(let message):
            return "Audio processing failed: \(message)"
        case .networkTimeout:
            return "Network timeout"
        case .invalidAudioFormat:
            return "Invalid audio format"
        case .bufferOverflow:
            return "Audio buffer overflow"
        case .unknown:
            return "Unknown streaming error"
        }
    }
}

// MARK: - Audio Streaming Protocol
protocol AudioStreamingProtocol {
    func startStreaming() throws
    func stopStreaming()
    func startReceiving()
    func stopReceiving()
    func sendAudioData(_ data: Data)
    func receiveAudioData() -> AnyPublisher<Data, AudioStreamingError>
}

// MARK: - Audio Streaming Manager
class AudioStreamingManager: ObservableObject {
    // MARK: - Properties
    private let streamer: AudioStreamer
    private let config: AudioStreamingConfig
    
    @Published private(set) var stats = AudioStreamingStats(
        bytesSent: 0,
        bytesReceived: 0,
        packetsSent: 0,
        packetsReceived: 0,
        averageLatency: 0,
        packetLoss: 0,
        timestamp: Date()
    )
    
    @Published private(set) var isActive = false
    @Published private(set) var error: AudioStreamingError?
    
    private var statsTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(streamer: AudioStreamer, config: AudioStreamingConfig = .standard) {
        self.streamer = streamer
        self.config = config
        
        setupMonitoring()
    }
    
    // MARK: - Public Methods
    func startStreaming() throws {
        try streamer.startStreaming()
        isActive = true
        error = nil
        startStatsMonitoring()
    }
    
    func stopStreaming() {
        streamer.stopStreaming()
        isActive = false
        stopStatsMonitoring()
    }
    
    // MARK: - Private Methods
    private func setupMonitoring() {
        // Monitor streamer state
        streamer.$isStreaming
            .combineLatest(streamer.$isReceiving)
            .map { $0 || $1 }
            .assign(to: \.isActive, on: self)
            .store(in: &cancellables)
        
        // Monitor streamer errors
        streamer.$streamError
            .compactMap { $0 }
            .map { AudioStreamingError.connectionFailed($0) }
            .assign(to: \.error, on: self)
            .store(in: &cancellables)
        
        // Monitor bytes sent/received
        streamer.$bytesSent
            .combineLatest(streamer.$bytesReceived)
            .sink { [weak self] sent, received in
                self?.updateStats(bytesSent: sent, bytesReceived: received)
            }
            .store(in: &cancellables)
    }
    
    private func startStatsMonitoring() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    private func stopStatsMonitoring() {
        statsTimer?.invalidate()
        statsTimer = nil
    }
    
    private func updateStats(bytesSent: Int64 = 0, bytesReceived: Int64 = 0) {
        stats = AudioStreamingStats(
            bytesSent: bytesSent,
            bytesReceived: bytesReceived,
            packetsSent: Int(bytesSent / Int64(config.bufferSize)),
            packetsReceived: Int(bytesReceived / Int64(config.bufferSize)),
            averageLatency: 0.1, // Mock latency
            packetLoss: 0.0, // Mock packet loss
            timestamp: Date()
        )
    }
} 