import SwiftUI

struct MessageInputView: View {
    @ObservedObject var viewModel: ChatViewModel
    @EnvironmentObject var stateManager: JarvisStateManager
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Input field
            HStack(spacing: 8) {
                // Text input
                TextField("Type a message...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .onSubmit {
                        sendMessage()
                    }
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSendMessage ? .accentColor : .gray)
                }
                .disabled(!canSendMessage)
                .help("Send message (⌘+Return)")
            }
            
            // Character count and status
            HStack {
                Text("\(viewModel.inputText.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.isLoading {
                    Text("Processing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            isInputFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isInputFocused = true
        }
    }
    
    private var canSendMessage: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }
    
    private func sendMessage() {
        guard canSendMessage else { return }
        
        viewModel.sendMessage()
        isInputFocused = true
    }
}

// MARK: - Preview
struct MessageInputView_Previews: PreviewProvider {
    static var previews: some View {
        MessageInputView(viewModel: ChatViewModel())
            .environmentObject(JarvisStateManager.preview)
    }
} 