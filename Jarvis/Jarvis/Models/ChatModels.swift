import Foundation
import CoreData

// MARK: - Chat Models
struct ChatModel: Identifiable, Codable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool
    var messages: [MessageModel]
    
    init(from chat: Chat) {
        self.id = chat.id ?? UUID()
        self.title = chat.title ?? "Untitled Chat"
        self.createdAt = chat.createdAt ?? Date()
        self.updatedAt = chat.updatedAt ?? Date()
        self.isActive = chat.isActive
        self.messages = chat.messages?.allObjects.compactMap { message in
            guard let message = message as? Message else { return nil }
            return MessageModel(from: message)
        }.sorted { $0.timestamp < $1.timestamp } ?? []
    }
}

struct MessageModel: Identifiable, Codable {
    let id: UUID
    var content: String
    var isUser: Bool
    var timestamp: Date
    var metadata: [String: CodableValue]?
    
    init(from message: Message) {
        self.id = message.id ?? UUID()
        self.content = message.content ?? ""
        self.isUser = message.isUser
        self.timestamp = message.timestamp ?? Date()
        if let metadataData = message.metadata {
            if let dict = try? JSONDecoder().decode([String: CodableValue].self, from: metadataData) {
                self.metadata = dict
            } else {
                self.metadata = nil
            }
        }
    }
    
    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date(), metadata: [String: CodableValue]? = nil) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

struct ConversationModel: Identifiable, Codable {
    let id: UUID
    var title: String
    var createdAt: Date
    var lastMessage: String
    var messageCount: Int
    
    init(from conversation: Conversation) {
        self.id = conversation.id ?? UUID()
        self.title = conversation.title ?? "Untitled Conversation"
        self.createdAt = conversation.createdAt ?? Date()
        self.lastMessage = conversation.lastMessage ?? ""
        self.messageCount = Int(conversation.messageCount)
    }
}

// MARK: - Chat State Models
enum ChatMode {
    case text
    case voice
}

enum ChatState {
    case idle
    case loading
    case error(String)
    case recording
    case processing
}

struct ChatSettings: Codable {
    var enableMarkdown: Bool = true
    var enableCodeHighlighting: Bool = true
    var autoScroll: Bool = true
    var showTimestamps: Bool = true
    var maxMessages: Int = 100
}

// MARK: - Search Models
struct SearchResult: Identifiable, Codable {
    let id: UUID
    let title: String
    let content: String
    let timestamp: Date
    let type: SearchResultType
    let relevance: Double
}

enum SearchResultType: String, Codable {
    case message
    case conversation
    case chat
}

// MARK: - Export Models
struct ExportOptions {
    var includeMetadata: Bool = true
    var format: ExportFormat = .json
    var dateRange: DateInterval?
    var includeAttachments: Bool = false
}

enum ExportFormat: String, Codable {
    case json
    case markdown
    case plainText
    case csv
} 