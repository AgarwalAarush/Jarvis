import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var stateManager: JarvisStateManager
    @EnvironmentObject var dataController: DataController
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Section
            List {
                Section("Navigation") {
                    NavigationLink(value: TabSelection.chat) {
                        Label("Chat", systemImage: "message")
                    }
                    
                    NavigationLink(value: TabSelection.voice) {
                        Label("Voice", systemImage: "mic")
                    }
                    
                    NavigationLink(value: TabSelection.search) {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(height: 120)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Recent Conversations Section
            ChatListView()
        }
        .frame(minWidth: 220, idealWidth: 280, maxWidth: 350)
        .background(Color(NSColor.controlBackgroundColor))
        .clipped()
    }
}

// MARK: - Enhanced Chat List View
struct ChatListView: View {
    @EnvironmentObject var dataController: DataController
    @EnvironmentObject var stateManager: JarvisStateManager
    @State private var searchText = ""
    @State private var showingCreateChat = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Chat.updatedAt, ascending: false)],
        predicate: NSPredicate(format: "isActive == true"),
        animation: .default
    ) private var allChats: FetchedResults<Chat>
    
    var filteredChats: [Chat] {
        if searchText.isEmpty {
            return Array(allChats)
        }
        
        return allChats.filter { chat in
            (chat.title ?? "").localizedCaseInsensitiveContains(searchText) ||
            (chat.messages as? Set<Message>)?.contains { message in
                (message.content ?? "").localizedCaseInsensitiveContains(searchText)
            } == true
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Text("Recent Conversations")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                // Modern search bar
                ModernSearchField(
                    text: $searchText,
                    placeholder: "Search conversations...",
                    onClear: {
                        searchText = ""
                    }
                )
                .frame(maxWidth: .infinity)
                
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Chat list
            ScrollView {
                LazyVStack(spacing: 4) {
                    if filteredChats.isEmpty {
                        EmptyChatListView(searchText: searchText)
                    } else {
                        ForEach(filteredChats) { chat in
                            ChatRowView(chat: chat)
                                .contextMenu {
                                    Button("Rename") {
                                        // TODO: Implement rename functionality
                                    }
                                    
                                    Button("Export") {
                                        // TODO: Implement export functionality
                                    }
                                    
                                    Divider()
                                    
                                    Button("Delete", role: .destructive) {
                                        deleteChat(chat)
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Create new chat button - floating in bottom right
            ZStack {
                Color.clear
                    .frame(height: 60)
                
                HStack {
                    Spacer()
                    
                    Button(action: { showingCreateChat = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("New Chat")
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showingCreateChat) {
            CreateChatView()
        }
    }
    
    private func deleteChat(_ chat: Chat) {
        let context = dataController.container.viewContext
        context.delete(chat)
        
        do {
            try context.save()
        } catch {
            print("Error deleting chat: \(error)")
        }
    }
}

// MARK: - Empty Chat List View
struct EmptyChatListView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "message.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(emptyStateTitle)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(emptyStateMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No conversations found"
        } else {
            return "No conversations yet"
        }
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "Try adjusting your search terms"
        } else {
            return "Start a new conversation to begin chatting with Jarvis"
        }
    }
}

// MARK: - Create Chat View
struct CreateChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataController: DataController
    @EnvironmentObject var stateManager: JarvisStateManager
    @State private var chatTitle = ""
    @State private var isCreating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Chat")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Chat Title (Optional)")
                    .font(.headline)
                
                TextField("Enter chat title...", text: $chatTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Leave empty to use the first message as the title")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Create Chat") {
                    createChat()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreating)
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func createChat() {
        isCreating = true
        
        let context = dataController.container.viewContext
        let newChat = Chat(context: context)
        newChat.id = UUID()
        newChat.title = chatTitle.isEmpty ? "New Chat" : chatTitle
        newChat.createdAt = Date()
        newChat.updatedAt = Date()
        newChat.isActive = true
        
        do {
            try context.save()
            stateManager.currentChatId = newChat.id
            stateManager.selectedTab = .chat
            dismiss()
        } catch {
            print("Error creating chat: \(error)")
        }
        
        isCreating = false
    }
}

// MARK: - Enhanced Chat Row View
struct ChatRowView: View {
    let chat: Chat
    @EnvironmentObject var stateManager: JarvisStateManager
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            stateManager.currentChatId = chat.id
            stateManager.selectedTab = .chat
        }) {
            HStack(spacing: 12) {
                // Chat icon
                Image(systemName: "message.circle.fill")
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .font(.system(size: 16, weight: .medium))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(chat.title ?? "Untitled Chat")
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    if let lastMessage = getLastMessage() {
                        Text(lastMessage)
                            .font(.system(size: 12))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            .lineLimit(2)
                    }
                    
                    if let updatedAt = chat.updatedAt {
                        Text(updatedAt, style: .relative)
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    }
                }
                
                Spacer()
                
                // Message count badge
                if let messageCount = (chat.messages as? Set<Message>)?.count, messageCount > 0 {
                    Text("\(messageCount)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? .accentColor : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? .white : .accentColor)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var isSelected: Bool {
        stateManager.currentChatId == chat.id
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .accentColor
        } else if isHovered {
            return Color.accentColor.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private func getLastMessage() -> String? {
        guard let messages = chat.messages as? Set<Message> else { return nil }
        return messages.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
            .last?.content
    }
}


// MARK: - Preview
struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
            .environmentObject(DataController.preview)
            .environmentObject(JarvisStateManager.preview)
    }
} 