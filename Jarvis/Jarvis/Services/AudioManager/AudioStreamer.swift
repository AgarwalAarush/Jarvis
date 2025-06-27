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
    
    private var streamingTask: URLSessionDataTask?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
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
            request.setValue("audio/pcm", forHTTPHeaderField: "Content-Type")
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
    }
    
    func startReceiving() {
        guard !isReceiving else { return }
        
        var request = URLRequest(url: streamingURL.appendingPathComponent("receive"))
        request.httpMethod = "GET"
        request.setValue("audio/pcm", forHTTPHeaderField: "Accept")
        
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
        audioManager.audioBufferPublisher
            .sink { [weak self] buffer in
                self?.sendAudioBuffer(buffer)
            }
            .store(in: &cancellables)
    }
    
    private func sendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isStreaming, let data = buffer.toData() else { return }
        
        // Send audio data to server
        streamingTask?.resume()
        
        bytesSent += Int64(data.count)
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

// MARK: - AVAudioPCMBuffer Extension
extension AVAudioPCMBuffer {
    func toData() -> Data? {
        let channelCount = Int(format.channelCount)
        let frameLength = Int(frameLength)
        let stride = format.streamDescription.pointee.mBytesPerFrame
        
        let byteCount = frameLength * Int(stride)
        var data = Data(capacity: byteCount)
        
        guard let floatChannelData = floatChannelData else { return nil }
        
        for channel in 0..<channelCount {
            data.append(UnsafeBufferPointer(start: floatChannelData[channel], count: frameLength))
        }
        
        return data
    }
}