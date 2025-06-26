import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var stateManager: JarvisStateManager
    @EnvironmentObject var dataController: DataController
    
    var body: some View {
        List {
            Section("Navigation") {
                NavigationLink(
                    destination: ChatView(),
                    tag: TabSelection.chat,
                    selection: $stateManager.selectedTab
                ) {
                    Label("Chat", systemImage: "message")
                }
                
                NavigationLink(
                    destination: VoiceModeView(),
                    tag: TabSelection.voice,
                    selection: $stateManager.selectedTab
                ) {
                    Label("Voice", systemImage: "mic")
                }
                
                NavigationLink(
                    destination: SearchView(),
                    tag: TabSelection.search,
                    selection: $stateManager.selectedTab
                ) {
                    Label("Search", systemImage: "magnifyingglass")
                }
            }
            
            Section("Recent Conversations") {
                ChatListView()
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
}

// MARK: - Enhanced Chat List View
struct ChatListView: View {
    @EnvironmentObject var dataController: DataController
    @EnvironmentObject var stateManager: JarvisStateManager
    @State private var searchText = ""
    @State private var showingCreateChat = false
    @State private var selectedFilter: ChatFilter = .all
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Chat.updatedAt, ascending: false)],
        predicate: NSPredicate(format: "isActive == true"),
        animation: .default
    ) private var allChats: FetchedResults<Chat>
    
    var filteredChats: [Chat] {
        let chats = allChats.filter { chat in
            if searchText.isEmpty { return true }
            return (chat.title ?? "").localizedCaseInsensitiveContains(searchText) ||
                   (chat.messages as? Set<Message>)?.contains { message in
                       (message.content ?? "").localizedCaseInsensitiveContains(searchText)
                   } == true
        }
        
        switch selectedFilter {
        case .all:
            return Array(chats)
        case .recent:
            return Array(chats.prefix(10))
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            return chats.filter { chat in
                chat.updatedAt ?? .distantPast >= today
            }
        case .thisWeek:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return chats.filter { chat in
                chat.updatedAt ?? .distantPast >= weekAgo
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and filter controls
            VStack(spacing: 8) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search conversations...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Filter picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(ChatFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Chat list
            if filteredChats.isEmpty {
                EmptyChatListView(searchText: searchText, filter: selectedFilter)
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
            
            // Create new chat button
            Button(action: { showingCreateChat = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("New Chat")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
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
    let filter: ChatFilter
    
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
        }
        
        switch filter {
        case .all:
            return "No conversations yet"
        case .recent:
            return "No recent conversations"
        case .today:
            return "No conversations today"
        case .thisWeek:
            return "No conversations this week"
        }
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "Try adjusting your search terms or filters"
        }
        
        switch filter {
        case .all:
            return "Start a new conversation to begin chatting with Jarvis"
        case .recent:
            return "Your recent conversations will appear here"
        case .today:
            return "No conversations have been updated today"
        case .thisWeek:
            return "No conversations have been updated this week"
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
                    .foregroundColor(.accentColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(chat.title ?? "Untitled Chat")
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    if let lastMessage = getLastMessage() {
                        Text(lastMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    if let updatedAt = chat.updatedAt {
                        Text(updatedAt, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Message count badge
                if let messageCount = (chat.messages as? Set<Message>)?.count, messageCount > 0 {
                    Text("\(messageCount)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getLastMessage() -> String? {
        guard let messages = chat.messages as? Set<Message> else { return nil }
        return messages.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
            .last?.content
    }
}

// MARK: - Chat Filter Enum
enum ChatFilter: CaseIterable {
    case all
    case recent
    case today
    case thisWeek
    
    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .recent:
            return "Recent"
        case .today:
            return "Today"
        case .thisWeek:
            return "This Week"
        }
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