import Foundation
import Combine
import Network

// MARK: - WebSocket Client
class WebSocketClient: ObservableObject {
    // MARK: - Properties
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private let baseURL: URL
    
    @Published private(set) var connectionStatus: WebSocketConnectionStatus = .disconnected
    @Published private(set) var lastError: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    
    // MARK: - Configuration
    private let maxReconnectAttempts = 5
    private let reconnectDelay: TimeInterval = 2.0
    private let heartbeatInterval: TimeInterval = 30.0
    private var reconnectAttempts = 0
    
    // MARK: - Event Publishers
    private let eventSubject = PassthroughSubject<WebSocketEvent, Never>()
    var events: AnyPublisher<WebSocketEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init(baseURL: URL = URL(string: "ws://localhost:5000")!) {
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        self.session = URLSession(configuration: config)
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Connection Management
    func connect() {
        guard connectionStatus != .connecting else { return }
        
        connectionStatus = .connecting
        lastError = nil
        
        let wsURL = baseURL.appendingPathComponent("ws")
        webSocketTask = session.webSocketTask(with: wsURL)
        webSocketTask?.resume()
        
        startReceiving()
        startHeartbeat()
    }
    
    func disconnect() {
        webSocketTask?.cancel()
        webSocketTask = nil
        connectionStatus = .disconnected
        stopHeartbeat()
        stopReconnectTimer()
    }
    
    // MARK: - Message Sending
    func send(_ event: WebSocketEvent) {
        guard case .connected = connectionStatus else {
            print("WebSocket not connected, cannot send message")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(event)
            let message = URLSessionWebSocketTask.Message.data(data)
            webSocketTask?.send(message) { [weak self] error in
                if let error = error {
                    print("Failed to send WebSocket message: \(error)")
                    self?.handleError(error)
                }
            }
        } catch {
            print("Failed to encode WebSocket event: \(error)")
        }
    }
    
    // MARK: - Private Methods
    private func startReceiving() {
        webSocketTask?.receive { [weak self] result in
            DispatchQueue.main.async {
                self?.handleReceiveResult(result)
            }
        }
    }
    
    private func handleReceiveResult(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case .success(let message):
            handleMessage(message)
            // Continue receiving
            startReceiving()
            
        case .failure(let error):
            handleError(error)
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            handleDataMessage(data)
        case .string(let string):
            handleStringMessage(string)
        @unknown default:
            print("Unknown WebSocket message type")
        }
    }
    
    private func handleDataMessage(_ data: Data) {
        do {
            let event = try JSONDecoder().decode(WebSocketEvent.self, from: data)
            eventSubject.send(event)
        } catch {
            print("Failed to decode WebSocket event: \(error)")
        }
    }
    
    private func handleStringMessage(_ string: String) {
        // Handle text-based messages (e.g., ping/pong)
        if string == "ping" {
            sendPong()
        } else if string == "pong" {
            // Heartbeat response received
        } else {
            // Try to parse as JSON
            guard let data = string.data(using: .utf8) else { return }
            handleDataMessage(data)
        }
    }
    
    private func handleError(_ error: Error) {
        print("WebSocket error: \(error)")
        lastError = error.localizedDescription
        connectionStatus = .error(error.localizedDescription)
        
        // Attempt reconnection
        scheduleReconnection()
    }
    
    private func scheduleReconnection() {
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionStatus = .failed
            return
        }
        
        reconnectAttempts += 1
        stopReconnectTimer()
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectDelay * Double(reconnectAttempts), repeats: false) { [weak self] _ in
            self?.connect()
        }
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func sendPing() {
        let message = URLSessionWebSocketTask.Message.string("ping")
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                self?.handleError(error)
            }
        }
    }
    
    private func sendPong() {
        let message = URLSessionWebSocketTask.Message.string("pong")
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                self?.handleError(error)
            }
        }
    }
    
    // MARK: - Connection Status Updates
    private func updateConnectionStatus(_ status: WebSocketConnectionStatus) {
        DispatchQueue.main.async {
            self.connectionStatus = status
            if case .connected = status {
                self.reconnectAttempts = 0
                self.lastError = nil
            }
        }
    }
}

// MARK: - WebSocket Connection Status
enum WebSocketConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(String)
    case failed
}

// MARK: - WebSocket Events
enum WebSocketEvent: Codable {
    case voiceActivity(VoiceActivityEvent)
    case wakeWordDetected(WakeWordEvent)
    case systemStatus(SystemStatusEvent)
    case conversationUpdate(ConversationUpdateEvent)
    case error(ErrorEvent)
    case custom(String, [String: Any])
    
    // MARK: - Coding Keys
    private enum CodingKeys: String, CodingKey {
        case type
        case data
    }
    
    // MARK: - Codable Implementation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "voice_activity":
            let data = try container.decode(VoiceActivityEvent.self, forKey: .data)
            self = .voiceActivity(data)
        case "wake_word_detected":
            let data = try container.decode(WakeWordEvent.self, forKey: .data)
            self = .wakeWordDetected(data)
        case "system_status":
            let data = try container.decode(SystemStatusEvent.self, forKey: .data)
            self = .systemStatus(data)
        case "conversation_update":
            let data = try container.decode(ConversationUpdateEvent.self, forKey: .data)
            self = .conversationUpdate(data)
        case "error":
            let data = try container.decode(ErrorEvent.self, forKey: .data)
            self = .error(data)
        default:
            // For custom events, we'll need to handle them differently
            self = .custom(type, [:])
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .voiceActivity(let event):
            try container.encode("voice_activity", forKey: .type)
            try container.encode(event, forKey: .data)
        case .wakeWordDetected(let event):
            try container.encode("wake_word_detected", forKey: .type)
            try container.encode(event, forKey: .data)
        case .systemStatus(let event):
            try container.encode("system_status", forKey: .type)
            try container.encode(event, forKey: .data)
        case .conversationUpdate(let event):
            try container.encode("conversation_update", forKey: .type)
            try container.encode(event, forKey: .data)
        case .error(let event):
            try container.encode("error", forKey: .type)
            try container.encode(event, forKey: .data)
        case .custom(let type, _):
            try container.encode(type, forKey: .type)
            // Note: Custom events with arbitrary data are not fully supported in this implementation
        }
    }
}

// MARK: - Event Data Models
struct VoiceActivityEvent: Codable {
    let isActive: Bool
    let audioLevel: Double
    let timestamp: Date
}

struct WakeWordEvent: Codable {
    let detected: Bool
    let confidence: Double
    let timestamp: Date
}

struct SystemStatusEvent: Codable {
    let status: String
    let uptime: TimeInterval
    let memoryUsage: Double
    let cpuUsage: Double
    let timestamp: Date
}

struct ConversationUpdateEvent: Codable {
    let conversationId: UUID
    let type: UpdateType
    let data: [String: String]
    let timestamp: Date
    
    enum UpdateType: String, Codable {
        case created
        case updated
        case deleted
        case messageAdded
    }
}

struct ErrorEvent: Codable {
    let code: String
    let message: String
    let timestamp: Date
} 