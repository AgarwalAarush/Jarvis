import Foundation
import CoreData
import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [MessageModel] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var currentChatId: UUID?
    @Published var currentChatTitle: String = "New Chat"
    @Published var lastActivity: Date?
    @Published var errorMessage: String?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var isRetrying: Bool = false
    
    @Environment(\.managedObjectContext) private var viewContext
    private var dataController: DataController?
    private let apiClient: JarvisAPIClient
    private var cancellables = Set<AnyCancellable>()
    private var retryCount = 0
    private let maxRetries = 3
    
    init(apiClient: JarvisAPIClient = JarvisAPIClient.shared) {
        self.apiClient = apiClient
        setupConnectionMonitoring()
    }
    
    private func setupConnectionMonitoring() {
        connectionStatus = apiClient.connectionStatus
        
        // Monitor connection status changes
        apiClient.connect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.connectionStatus = status
            }
            .store(in: &cancellables)
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
        
        // Send message to API
        isLoading = true
        errorMessage = nil
        
        sendMessageToAPI(userInput, in: chatId)
    }
    
    private func handleAPIResponse(_ response: ChatResponse, in chatId: UUID) {
        let botResponse = MessageModel(
            content: response.message,
            isUser: false
        )
        
        messages.append(botResponse)
        saveMessage(botResponse, to: chatId)
    }
    
    private func handleAPIError(_ error: APIError) {
        errorMessage = error.localizedDescription
        
        // Implement retry logic for network errors
        if case .networkError = error.code, retryCount < maxRetries {
            retryLastMessage()
            return
        }
        
        retryCount = 0 // Reset retry count on non-network errors
        
        // Add error message to chat for user visibility
        let errorResponse = MessageModel(
            content: "Sorry, I encountered an error: \(error.message). Please try again.",
            isUser: false
        )
        
        messages.append(errorResponse)
        if let chatId = currentChatId {
            saveMessage(errorResponse, to: chatId)
        }
    }
    
    private func retryLastMessage() {
        guard retryCount < maxRetries else {
            retryCount = 0
            return
        }
        
        retryCount += 1
        isRetrying = true
        
        // Find the last user message to retry
        guard let lastUserMessage = messages.last(where: { $0.isUser }),
              let chatId = currentChatId else {
            isRetrying = false
            return
        }
        
        // Retry after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount)) {
            self.sendMessageToAPI(lastUserMessage.content, in: chatId)
        }
    }
    
    private func sendMessageToAPI(_ message: String, in chatId: UUID) {
        apiClient.sendMessage(message, conversationId: chatId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    self?.isRetrying = false
                    if case .failure(let error) = completion {
                        self?.handleAPIError(error)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.retryCount = 0 // Reset on success
                    self?.handleAPIResponse(response, in: chatId)
                }
            )
            .store(in: &cancellables)
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
    
    func clearError() {
        errorMessage = nil
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