import SwiftUI

struct MessageInputView: View {
    @ObservedObject var viewModel: ChatViewModel
    @EnvironmentObject var stateManager: JarvisStateManager
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Input field with send button
            HStack(spacing: 12) {
                // Modern text input
                ModernMessageField(
                    text: $viewModel.inputText,
                    placeholder: "Type a message...",
                    onSubmit: {
                        sendMessage()
                    },
                    lineLimit: 1...5
                )
                .focused($isInputFocused)
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(canSendMessage ? .accentColor : .gray)
                        .scaleEffect(canSendMessage ? 1.0 : 0.9)
                        .animation(.easeInOut(duration: 0.2), value: canSendMessage)
                }
                .disabled(!canSendMessage)
                .help("Send message (⌘+Return)")
                .buttonStyle(PlainButtonStyle())
            }
            
            // Character count and status
            HStack {
                Text("\(viewModel.inputText.count) characters")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.isLoading {
                    HStack(spacing: 4) {
                        LoadingDots()
                        Text("Processing...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            isInputFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isInputFocused = true
        }
    }
    
    private var canSendMessage: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading && !viewModel.isRetrying
    }
    
    private func sendMessage() {
        guard canSendMessage else { return }
        
        viewModel.sendMessage()
        isInputFocused = true
    }
}

// MARK: - Loading Dots
struct LoadingDots: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 4, height: 4)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
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
struct MessageInputView_Previews: PreviewProvider {
    static var previews: some View {
        MessageInputView(viewModel: ChatViewModel())
            .environmentObject(JarvisStateManager.preview)
    }
} 