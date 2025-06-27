import SwiftUI

struct MessageBubbleView: View {
    let message: MessageModel
    @EnvironmentObject var stateManager: JarvisStateManager
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer()
                userMessageBubble
            } else {
                assistantMessageBubble
                Spacer()
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var userMessageBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .textSelection(.enabled)
            
            if stateManager.chatSettings.showTimestamps {
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var assistantMessageBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            if stateManager.chatSettings.enableMarkdown {
                MarkdownView(content: message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            } else {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .textSelection(.enabled)
            }
            
            if stateManager.chatSettings.showTimestamps {
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview
struct MessageBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            MessageBubbleView(message: MessageModel(
                content: "Hello, how can I help you today?",
                isUser: false
            ))
            
            MessageBubbleView(message: MessageModel(
                content: "I need help with my project",
                isUser: true
            ))
        }
        .environmentObject(JarvisStateManager.preview)
        .padding()
    }
}