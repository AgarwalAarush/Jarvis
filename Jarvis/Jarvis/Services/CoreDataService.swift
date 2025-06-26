import Foundation
import CoreData
import Combine

class CoreDataService: ObservableObject {
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let dataController: DataController
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(dataController: DataController) {
        self.dataController = dataController
        setupObservers()
    }
    
    // MARK: - Chat Operations
    func createChat(title: String? = nil) -> Chat? {
        let context = dataController.container.viewContext
        let newChat = Chat(context: context)
        newChat.id = UUID()
        newChat.title = title ?? "New Chat"
        newChat.createdAt = Date()
        newChat.updatedAt = Date()
        newChat.isActive = true
        
        do {
            try context.save()
            return newChat
        } catch {
            errorMessage = "Failed to create chat: \(error.localizedDescription)"
            return nil
        }
    }
    
    func fetchChats(predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) -> [Chat] {
        let context = dataController.container.viewContext
        let request: NSFetchRequest<Chat> = Chat.fetchRequest()
        
        request.predicate = predicate ?? NSPredicate(format: "isActive == true")
        request.sortDescriptors = sortDescriptors ?? [NSSortDescriptor(keyPath: \Chat.updatedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            errorMessage = "Failed to fetch chats: \(error.localizedDescription)"
            return []
        }
    }
    
    func fetchChat(by id: UUID) -> Chat? {
        let context = dataController.container.viewContext
        let request: NSFetchRequest<Chat> = Chat.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let chats = try context.fetch(request)
            return chats.first
        } catch {
            errorMessage = "Failed to fetch chat: \(error.localizedDescription)"
            return nil
        }
    }
    
    func updateChat(_ chat: Chat, title: String? = nil) -> Bool {
        let context = dataController.container.viewContext
        
        if let title = title {
            chat.title = title
        }
        chat.updatedAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            errorMessage = "Failed to update chat: \(error.localizedDescription)"
            return false
        }
    }
    
    func deleteChat(_ chat: Chat) -> Bool {
        let context = dataController.container.viewContext
        context.delete(chat)
        
        do {
            try context.save()
            return true
        } catch {
            errorMessage = "Failed to delete chat: \(error.localizedDescription)"
            return false
        }
    }
    
    func deleteChats(with predicate: NSPredicate) -> Bool {
        let context = dataController.container.viewContext
        let request: NSFetchRequest<NSFetchRequestResult> = Chat.fetchRequest()
        request.predicate = predicate
        
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            return true
        } catch {
            errorMessage = "Failed to delete chats: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Message Operations
    func createMessage(content: String, isUser: Bool, in chat: Chat, metadata: [String: Any]? = nil) -> Message? {
        let context = dataController.container.viewContext
        let newMessage = Message(context: context)
        newMessage.id = UUID()
        newMessage.content = content
        newMessage.isUser = isUser
        newMessage.timestamp = Date()
        newMessage.chat = chat
        
        if let metadata = metadata,
           let metadataData = try? JSONSerialization.data(withJSONObject: metadata) {
            newMessage.metadata = metadataData
        }
        
        // Update chat metadata
        chat.updatedAt = Date()
        
        do {
            try context.save()
            return newMessage
        } catch {
            errorMessage = "Failed to create message: \(error.localizedDescription)"
            return nil
        }
    }
    
    func fetchMessages(for chat: Chat, limit: Int? = nil) -> [Message] {
        let context = dataController.container.viewContext
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "chat == %@", chat)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.timestamp, ascending: true)]
        
        if let limit = limit {
            request.fetchLimit = limit
        }
        
        do {
            return try context.fetch(request)
        } catch {
            errorMessage = "Failed to fetch messages: \(error.localizedDescription)"
            return []
        }
    }
    
    func fetchMessages(with predicate: NSPredicate, sortDescriptors: [NSSortDescriptor]? = nil) -> [Message] {
        let context = dataController.container.viewContext
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors ?? [NSSortDescriptor(keyPath: \Message.timestamp, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            errorMessage = "Failed to fetch messages: \(error.localizedDescription)"
            return []
        }
    }
    
    func updateMessage(_ message: Message, content: String? = nil, metadata: [String: Any]? = nil) -> Bool {
        let context = dataController.container.viewContext
        
        if let content = content {
            message.content = content
        }
        
        if let metadata = metadata,
           let metadataData = try? JSONSerialization.data(withJSONObject: metadata) {
            message.metadata = metadataData
        }
        
        do {
            try context.save()
            return true
        } catch {
            errorMessage = "Failed to update message: \(error.localizedDescription)"
            return false
        }
    }
    
    func deleteMessage(_ message: Message) -> Bool {
        let context = dataController.container.viewContext
        context.delete(message)
        
        do {
            try context.save()
            return true
        } catch {
            errorMessage = "Failed to delete message: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Search Operations
    func searchChats(query: String) -> [Chat] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@ OR ANY messages.content CONTAINS[cd] %@", query, query)
        return fetchChats(predicate: predicate)
    }
    
    func searchMessages(query: String, in chat: Chat? = nil) -> [Message] {
        var predicate: NSPredicate
        
        if let chat = chat {
            predicate = NSPredicate(format: "chat == %@ AND content CONTAINS[cd] %@", chat, query)
        } else {
            predicate = NSPredicate(format: "content CONTAINS[cd] %@", query)
        }
        
        return fetchMessages(with: predicate)
    }
    
    // MARK: - Statistics
    func getChatStatistics() -> ChatStatistics {
        let context = dataController.container.viewContext
        
        // Total chats
        let chatRequest: NSFetchRequest<Chat> = Chat.fetchRequest()
        let totalChats = (try? context.count(for: chatRequest)) ?? 0
        
        // Active chats
        let activeChatRequest: NSFetchRequest<Chat> = Chat.fetchRequest()
        activeChatRequest.predicate = NSPredicate(format: "isActive == true")
        let activeChats = (try? context.count(for: activeChatRequest)) ?? 0
        
        // Total messages
        let messageRequest: NSFetchRequest<Message> = Message.fetchRequest()
        let totalMessages = (try? context.count(for: messageRequest)) ?? 0
        
        // Messages today
        let today = Calendar.current.startOfDay(for: Date())
        let todayMessageRequest: NSFetchRequest<Message> = Message.fetchRequest()
        todayMessageRequest.predicate = NSPredicate(format: "timestamp >= %@", today as CVarArg)
        let messagesToday = (try? context.count(for: todayMessageRequest)) ?? 0
        
        return ChatStatistics(
            totalChats: totalChats,
            activeChats: activeChats,
            totalMessages: totalMessages,
            messagesToday: messagesToday
        )
    }
    
    // MARK: - Export Operations
    func exportChat(_ chat: Chat) -> ChatExport? {
        let messages = fetchMessages(for: chat)
        
        let export = ChatExport(
            id: chat.id ?? UUID(),
            title: chat.title ?? "Untitled Chat",
            createdAt: chat.createdAt ?? Date(),
            updatedAt: chat.updatedAt ?? Date(),
            messages: messages.map { message in
                MessageExport(
                    id: message.id ?? UUID(),
                    content: message.content ?? "",
                    isUser: message.isUser,
                    timestamp: message.timestamp ?? Date(),
                    metadata: message.metadata != nil ? (try? JSONSerialization.jsonObject(with: message.metadata!, options: []) as? [String: Any]) : nil
                )
            }
        )
        
        return export
    }
    
    func exportAllChats() -> [ChatExport] {
        let chats = fetchChats()
        return chats.compactMap { exportChat($0) }
    }
    
    // MARK: - Cleanup Operations
    func cleanupOldChats(olderThan days: Int) -> Bool {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = NSPredicate(format: "updatedAt < %@", cutoffDate as CVarArg)
        return deleteChats(with: predicate)
    }
    
    func cleanupOldMessages(olderThan days: Int) -> Bool {
        let context = dataController.container.viewContext
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = NSPredicate(format: "timestamp < %@", cutoffDate as CVarArg)
        
        let request: NSFetchRequest<NSFetchRequestResult> = Message.fetchRequest()
        request.predicate = predicate
        
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            return true
        } catch {
            errorMessage = "Failed to cleanup old messages: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Observers
    private func setupObservers() {
        // Monitor Core Data save notifications
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                // Handle save notifications if needed
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Data Models
struct ChatStatistics {
    let totalChats: Int
    let activeChats: Int
    let totalMessages: Int
    let messagesToday: Int
    
    var averageMessagesPerChat: Double {
        return totalChats > 0 ? Double(totalMessages) / Double(totalChats) : 0.0
    }
}

struct ChatExport: Codable {
    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let messages: [MessageExport]
    
    var messageCount: Int {
        return messages.count
    }
    
    var userMessageCount: Int {
        return messages.filter { $0.isUser }.count
    }
    
    var assistantMessageCount: Int {
        return messages.filter { !$0.isUser }.count
    }
}

struct MessageExport: Codable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    let metadata: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case id, content, isUser, timestamp, metadata
    }
    
    init(id: UUID, content: String, isUser: Bool, timestamp: Date, metadata: [String: Any]?) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        isUser = try container.decode(Bool.self, forKey: .isUser)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        metadata = try container.decodeIfPresent([String: Any].self, forKey: .metadata)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(isUser, forKey: .isUser)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

// MARK: - Preview Helper
extension CoreDataService {
    static var preview: CoreDataService {
        return CoreDataService(dataController: DataController.preview)
    }
} 