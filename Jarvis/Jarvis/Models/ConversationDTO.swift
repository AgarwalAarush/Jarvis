import Foundation

struct ConversationDTO: Codable, Identifiable {
    let id: UUID
    let title: String
    let createdAt: Date
    let lastMessage: String
    let messageCount: Int
} 