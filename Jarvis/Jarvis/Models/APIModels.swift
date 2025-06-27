import Foundation

// MARK: - API Connection Status

enum ConnectionStatus: Equatable, Codable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(String)
}

// MARK: - API Request Models
struct ChatRequest: Codable {
    let message: String
    let conversationId: UUID?
    let stream: Bool
    let model: String?
    let temperature: Double?
    
    init(message: String, conversationId: UUID? = nil, stream: Bool = false, model: String? = nil, temperature: Double? = nil) {
        self.message = message
        self.conversationId = conversationId
        self.stream = stream
        self.model = model
        self.temperature = temperature
    }
}

struct VoiceRequest: Codable {
    let audioData: Data
    let format: AudioFormat
    let sampleRate: Int
    let channels: Int
    
    enum AudioFormat: String, Codable {
        case wav
        case mp3
        case flac
        case pcm
    }
}

struct ConversationRequest: Codable {
    let title: String?
    let metadata: [String: String]?
}

struct SearchRequest: Codable {
    let query: String
    let limit: Int?
    let offset: Int?
    let filters: SearchFilters?
    
    struct SearchFilters: Codable {
        let dateRange: DateInterval?
        let conversationIds: [UUID]?
        let messageTypes: [String]?
    }
}

// MARK: - API Response Models
struct ChatResponse: Codable {
    let id: String
    let message: String
    let conversationId: String
    let timestamp: String
    let model: String?
    let metadata: [String: CodableValue]?
    
    enum CodingKeys: String, CodingKey {
        case id, message, conversationId, timestamp, model, metadata
    }
}

struct StreamingChatResponse: Codable {
    let id: UUID
    let content: String
    let conversationId: UUID
    let isComplete: Bool
    let timestamp: Date
    
    init(id: UUID, content: String, conversationId: UUID, isComplete: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.conversationId = conversationId
        self.isComplete = isComplete
        self.timestamp = timestamp
    }
}

struct ConversationsResponse: Codable {
    let conversations: [ConversationDTO]
    let totalCount: Int
    let hasMore: Bool
}

struct SearchResult: Codable, Identifiable {
    let id: UUID
    let type: String
    let title: String
    let content: String
    let conversationId: UUID?
    let timestamp: Date
    let relevance: Double
}

struct SearchResponse: Codable {
    let results: [SearchResult]
    let totalCount: Int
    let query: String
    let processingTime: TimeInterval
}

struct StatusResponse: Codable {
    let status: String
    let version: String
    let uptime: TimeInterval
    let activeConnections: Int
    let systemInfo: SystemInfo
    
    struct SystemInfo: Codable {
        let cpuUsage: Double
        let memoryUsage: Double
        let diskUsage: Double
        let networkStatus: String
    }
}

struct ModelsResponse: Codable {
    let models: [ModelInfo]
    
    struct ModelInfo: Codable, Identifiable {
        let id: String
        let name: String
        let description: String?
        let parameters: Int?
        let isAvailable: Bool
        let downloadProgress: Double?
    }
}

// MARK: - Error Models
struct APIError: Codable, LocalizedError {
    let code: String
    let message: String
    let details: String?
    let timestamp: Date
    
    var errorDescription: String? {
        return message
    }
}

extension APIError {
    static let unknown = APIError(
        code: "UNKNOWN_ERROR",
        message: "An unknown error occurred",
        details: nil,
        timestamp: Date()
    )
    
    static let invalidData = APIError(
        code: "INVALID_DATA",
        message: "Invalid data received",
        details: nil,
        timestamp: Date()
    )
    
    static let authenticationError = APIError(
        code: "AUTHENTICATION_ERROR",
        message: "Authentication failed",
        details: nil,
        timestamp: Date()
    )
    
    static let rateLimitExceeded = APIError(
        code: "RATE_LIMIT_EXCEEDED",
        message: "Rate limit exceeded",
        details: nil,
        timestamp: Date()
    )
    
    static func serverError(_ statusCode: Int, _ message: String) -> APIError {
        return APIError(
            code: "SERVER_ERROR",
            message: message,
            details: "HTTP Status: \(statusCode)",
            timestamp: Date()
        )
    }
    
    static let timeout = APIError(
        code: "TIMEOUT",
        message: "Request timed out",
        details: nil,
        timestamp: Date()
    )
    
    static func networkError(_ error: Error) -> APIError {
        return APIError(
            code: "NETWORK_ERROR",
            message: "Network error occurred",
            details: error.localizedDescription,
            timestamp: Date()
        )
    }
    
    static let invalidResponse = APIError(
        code: "INVALID_RESPONSE",
        message: "Invalid response received",
        details: nil,
        timestamp: Date()
    )
}

enum APIErrorType: String, CaseIterable {
    case invalidRequest = "INVALID_REQUEST"
    case authenticationFailed = "AUTHENTICATION_FAILED"
    case rateLimitExceeded = "RATE_LIMIT_EXCEEDED"
    case serverError = "SERVER_ERROR"
    case modelNotFound = "MODEL_NOT_FOUND"
    case conversationNotFound = "CONVERSATION_NOT_FOUND"
    case audioProcessingError = "AUDIO_PROCESSING_ERROR"
    case networkError = "NETWORK_ERROR"
}

// MARK: - WebSocket Models
struct WebSocketMessage: Codable {
    let type: WebSocketMessageType
    let data: [String: CodableValue]
    let timestamp: Date
    
    enum WebSocketMessageType: String, Codable {
        case chatUpdate = "chat_update"
        case voiceActivity = "voice_activity"
        case systemStatus = "system_status"
        case wakeWordDetected = "wake_word_detected"
        case error = "error"
        case ping = "ping"
        case pong = "pong"
    }
}

struct VoiceActivityData: Codable {
    let isRecording: Bool
    let audioLevel: Double
    let duration: TimeInterval
    let timestamp: Date
}

struct SystemStatusData: Codable {
    let cpuUsage: Double
    let memoryUsage: Double
    let activeConnections: Int
    let uptime: TimeInterval
    let timestamp: Date
}

// MARK: - Audio Models
struct AudioConfig: Codable {
    let sampleRate: Int
    let channels: Int
    let format: AudioFormat
    let bitDepth: Int?
    
    enum AudioFormat: String, Codable {
        case pcm
        case wav
        case mp3
        case flac
    }
}

struct AudioChunk: Codable {
    let data: Data
    let timestamp: Date
    let sequenceNumber: Int
    let isLast: Bool
}

// MARK: - CodableValue for Codable Dictionaries
/// CodableValue allows encoding/decoding heterogenous dictionaries for Codable conformance
enum CodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([CodableValue])
    case dictionary([String: CodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: CodableValue].self) {
            self = .dictionary(value)
        } else if let value = try? container.decode([CodableValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

enum ExportFormat: String, Codable, CaseIterable {
    case json
    case markdown
    case text
    case csv
}

struct SystemStatus: Codable {
    let status: String
    let uptime: TimeInterval
    let version: String
    let models: [String]
    let activeConnections: Int
    let memoryUsage: Double
    let cpuUsage: Double
} 