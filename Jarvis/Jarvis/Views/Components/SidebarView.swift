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

// MARK: - Chat List View
struct ChatListView: View {
    @EnvironmentObject var dataController: DataController
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Chat.updatedAt, ascending: false)],
        predicate: NSPredicate(format: "isActive == true"),
        animation: .default
    ) private var chats: FetchedResults<Chat>
    
    var body: some View {
        ForEach(chats) { chat in
            ChatRowView(chat: chat)
        }
    }
}

// MARK: - Chat Row View
struct ChatRowView: View {
    let chat: Chat
    @EnvironmentObject var stateManager: JarvisStateManager
    
    var body: some View {
        Button(action: {
            stateManager.currentChatId = chat.id
            stateManager.selectedTab = .chat
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.title ?? "Untitled Chat")
                    .font(.headline)
                    .lineLimit(1)
                
                if let lastMessage = (chat.messages as? Set<Message>)?.sorted(by: { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }).last {
                    Text(lastMessage.content ?? "")
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
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