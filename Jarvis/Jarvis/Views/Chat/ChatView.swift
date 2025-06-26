import SwiftUI

struct ChatView: View {
    @EnvironmentObject var stateManager: JarvisStateManager
    @EnvironmentObject var dataController: DataController
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeader
            
            Divider()
            
            // Messages area
            messagesArea
            
            Divider()
            
            // Input area
            MessageInputView(viewModel: viewModel)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            viewModel.loadChat(id: stateManager.currentChatId)
        }
        .onChange(of: stateManager.currentChatId) { oldValue, newValue in
            viewModel.loadChat(id: newValue)
        }
    }
    
    @ViewBuilder
    private var chatHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentChatTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let lastActivity = viewModel.lastActivity {
                    Text("Last active \(lastActivity, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Connection status indicator
            ConnectionStatusView()
        }
        .padding()
    }
    
    @ViewBuilder
    private var messagesArea: some View {
        ScrollViewReader { scrollView in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                    
                    if viewModel.isLoading {
                        LoadingIndicator()
                            .padding()
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: viewModel.messages.count) { oldValue, newValue in
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Connection Status View
struct ConnectionStatusView: View {
    @EnvironmentObject var stateManager: JarvisStateManager
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
            
            Text(connectionText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var connectionColor: Color {
        switch stateManager.connectionStatus {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .yellow
        case .disconnected, .error:
            return .red
        }
    }
    
    private var connectionText: String {
        switch stateManager.connectionStatus {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .reconnecting:
            return "Reconnecting..."
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

// MARK: - Loading Indicator
struct LoadingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .environmentObject(DataController.preview)
            .environmentObject(JarvisStateManager.preview)
    }
} 