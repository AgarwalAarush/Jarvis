import Foundation
import CoreData
import SwiftUI

class ChatViewModel: ObservableObject {
    @Published var messages: [MessageModel] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var currentChatId: UUID?
    @Published var currentChatTitle: String = "New Chat"
    @Published var lastActivity: Date?
    
    @Environment(\.managedObjectContext) private var viewContext
    private var dataController: DataController?
    
    init() {
        // This will be set by the view
    }
    
    func setDataController(_ dataController: DataController) {
        self.dataController = dataController
    }
    
    // MARK: - Chat Management
    func loadChat(id: UUID?) {
        guard let id = id else {
            createNewChat()
            return
        }
        
        currentChatId = id
        loadMessages(for: id)
        updateChatTitle(for: id)
    }
    
    private func createNewChat() {
        guard let dataController = dataController else { return }
        
        let context = dataController.container.viewContext
        let newChat = Chat(context: context)
        newChat.id = UUID()
        newChat.title = "New Chat"
        newChat.createdAt = Date()
        newChat.updatedAt = Date()
        newChat.isActive = true
        
        do {
            try context.save()
            currentChatId = newChat.id
            currentChatTitle = newChat.title ?? "New Chat"
            messages = []
            lastActivity = newChat.createdAt
        } catch {
            print("Error creating new chat: \(error)")
        }
    }
    
    private func loadMessages(for chatId: UUID) {
        guard let dataController = dataController else { return }
        
        let context = dataController.container.viewContext
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "chat.id == %@", chatId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.timestamp, ascending: true)]
        
        do {
            let fetchedMessages = try context.fetch(request)
            messages = fetchedMessages.map { MessageModel(from: $0) }
        } catch {
            print("Error loading messages: \(error)")
        }
    }
    
    private func updateChatTitle(for chatId: UUID) {
        guard let dataController = dataController else { return }
        
        let context = dataController.container.viewContext
        let request: NSFetchRequest<Chat> = Chat.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Chat.id, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let chats = try context.fetch(request)
            if let chat = chats.first {
                currentChatTitle = chat.title ?? "Untitled Chat"
                lastActivity = chat.updatedAt
            }
        } catch {
            print("Error updating chat title: \(error)")
        }
    }
    
    // MARK: - Message Management
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        guard let chatId = currentChatId else {
            createNewChat()
            return
        }
        
        let userMessage = MessageModel(
            content: inputText.trimmingCharacters(in: .whitespacesAndNewlines),
            isUser: true
        )
        
        // Add user message to UI immediately
        messages.append(userMessage)
        
        // Save user message to CoreData
        saveMessage(userMessage, to: chatId)
        
        // Clear input
        let userInput = inputText
        inputText = ""
        
        // Update chat title if it's still "New Chat"
        if currentChatTitle == "New Chat" {
            updateChatTitle(to: userInput)
        }
        
        // Simulate bot response (this will be replaced with actual API call)
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.generateBotResponse(to: userInput, in: chatId)
        }
    }
    
    private func generateBotResponse(to userInput: String, in chatId: UUID) {
        // This is a placeholder - will be replaced with actual API integration
        let botResponse = MessageModel(
            content: """
            **Response to**: \(userInput)
            
            This is a placeholder response. The actual API integration will be implemented in Phase 2.
            
            - This is a bullet point
            - This is *italicized* text
            - This is **bold** text
            
            ```
            func greet(name: String) {
                print("Hello, \\(name)!")
            }
            
            greet(name: "User")
            ```
            """,
            isUser: false
        )
        
        messages.append(botResponse)
        saveMessage(botResponse, to: chatId)
        isLoading = false
    }
    
    private func saveMessage(_ message: MessageModel, to chatId: UUID) {
        guard let dataController = dataController else { return }
        
        let context = dataController.container.viewContext
        
        // Find the chat
        let chatRequest: NSFetchRequest<Chat> = Chat.fetchRequest()
        chatRequest.predicate = NSPredicate(format: "id == %@", chatId as CVarArg)
        
        do {
            let chats = try context.fetch(chatRequest)
            guard let chat = chats.first else { return }
            
            // Create new message
            let newMessage = Message(context: context)
            newMessage.id = message.id
            newMessage.content = message.content
            newMessage.isUser = message.isUser
            newMessage.timestamp = message.timestamp
            newMessage.chat = chat
            
            // Update chat metadata
            chat.updatedAt = Date()
            if let metadata = message.metadata,
               let metadataData = try? JSONSerialization.data(withJSONObject: metadata) {
                newMessage.metadata = metadataData
            }
            
            try context.save()
            
            // Update last activity
            lastActivity = chat.updatedAt
            
        } catch {
            print("Error saving message: \(error)")
        }
    }
    
    private func updateChatTitle(to newTitle: String) {
        guard let chatId = currentChatId,
              let dataController = dataController else { return }
        
        let context = dataController.container.viewContext
        let chatRequest: NSFetchRequest<Chat> = Chat.fetchRequest()
        chatRequest.predicate = NSPredicate(format: "id == %@", chatId as CVarArg)
        
        do {
            let chats = try context.fetch(chatRequest)
            if let chat = chats.first {
                chat.title = newTitle.prefix(50).trimmingCharacters(in: .whitespacesAndNewlines)
                chat.updatedAt = Date()
                try context.save()
                currentChatTitle = chat.title ?? "Untitled Chat"
            }
        } catch {
            print("Error updating chat title: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    func clearMessages() {
        messages.removeAll()
    }
    
    func deleteCurrentChat() {
        guard let chatId = currentChatId,
              let dataController = dataController else { return }
        
        let context = dataController.container.viewContext
        let chatRequest: NSFetchRequest<Chat> = Chat.fetchRequest()
        chatRequest.predicate = NSPredicate(format: "id == %@", chatId as CVarArg)
        
        do {
            let chats = try context.fetch(chatRequest)
            if let chat = chats.first {
                context.delete(chat)
                try context.save()
                
                // Reset to new chat
                createNewChat()
            }
        } catch {
            print("Error deleting chat: \(error)")
        }
    }
}

// MARK: - Preview Helper
extension ChatViewModel {
    static var preview: ChatViewModel {
        let viewModel = ChatViewModel()
        viewModel.messages = [
            MessageModel(content: "Hello, how can I help you today?", isUser: false),
            MessageModel(content: "I need help with my project", isUser: true),
            MessageModel(content: "I'd be happy to help! What kind of project are you working on?", isUser: false)
        ]
        viewModel.currentChatTitle = "Sample Chat"
        viewModel.lastActivity = Date()
        return viewModel
    }
} 