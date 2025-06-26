import Foundation
import CoreData

extension Conversation {
    convenience init(dto: ConversationDTO, context: NSManagedObjectContext) {
        self.init(context: context)
        self.id = dto.id
        self.title = dto.title
        self.createdAt = dto.createdAt
        self.lastMessage = dto.lastMessage
        self.messageCount = Int32(dto.messageCount)
    }

    func update(from dto: ConversationDTO) {
        self.id = dto.id
        self.title = dto.title
        self.createdAt = dto.createdAt
        self.lastMessage = dto.lastMessage
        self.messageCount = Int32(dto.messageCount)
    }
} 