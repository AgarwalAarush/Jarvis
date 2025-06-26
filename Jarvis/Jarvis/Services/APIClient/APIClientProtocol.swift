import Foundation
import Combine

// MARK: - API Client Protocol
protocol APIClientProtocol {
    // MARK: - Connection Management
    func connect() -> AnyPublisher<ConnectionStatus, Never>
    func disconnect()
    var connectionStatus: ConnectionStatus { get }
    
    // MARK: - Chat Operations
    func sendMessage(_ message: String, conversationId: UUID?) -> AnyPublisher<ChatResponse, APIError>
    func sendMessageStream(_ message: String, conversationId: UUID?) -> AnyPublisher<ChatStreamResponse, APIError>
    
    // MARK: - Conversation Management
    func getConversations() -> AnyPublisher<[ConversationDTO], APIError>
    func createConversation(title: String?) -> AnyPublisher<ConversationDTO, APIError>
    func getConversation(id: UUID) -> AnyPublisher<ConversationDTO, APIError>
    func deleteConversation(id: UUID) -> AnyPublisher<Void, APIError>
    func updateConversation(id: UUID, title: String) -> AnyPublisher<ConversationDTO, APIError>
    
    // MARK: - Search
    func searchConversations(query: String) -> AnyPublisher<[SearchResult], APIError>
    func searchMessages(query: String, conversationId: UUID?) -> AnyPublisher<[SearchResult], APIError>
    
    // MARK: - Export
    func exportConversation(id: UUID, format: ExportFormat) -> AnyPublisher<Data, APIError>
    func exportAllConversations(format: ExportFormat) -> AnyPublisher<Data, APIError>
    
    // MARK: - System
    func getStatus() -> AnyPublisher<SystemStatus, APIError>
    func getModels() -> AnyPublisher<[ModelInfo], APIError>
    func getConfig() -> AnyPublisher<SystemConfig, APIError>
    func healthCheck() -> AnyPublisher<HealthStatus, APIError>
}

// MARK: - Response Models
struct ChatStreamResponse: Codable {
    let type: StreamType
    let data: String?
    let conversationId: UUID?
    let isComplete: Bool
    let error: String?
    
    enum StreamType: String, Codable {
        case message
        case status
        case error
        case complete
    }
}

struct ModelInfo: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let parameters: Int?
    let isAvailable: Bool
}

struct SystemConfig: Codable {
    let apiVersion: String
    let maxTokens: Int
    let supportedFormats: [String]
    let features: [String]
}

struct HealthStatus: Codable {
    let status: String
    let timestamp: Date
    let checks: [HealthCheck]
    
    struct HealthCheck: Codable {
        let name: String
        let status: String
        let message: String?
    }
} 