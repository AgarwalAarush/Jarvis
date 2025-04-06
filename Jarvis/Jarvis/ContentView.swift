import SwiftUI

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
}

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Add user message
        let userMessage = Message(content: inputText, isUser: true)
        messages.append(userMessage)
        
        // Clear input field
        let userInput = inputText
        inputText = ""
        
        // Simulate bot response with markdown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let markdownResponse = """
            **Response to**: \(userInput)

            - This is a bullet point
            - This is *italicized* text
            - This is **bold** text

            ```
            func greet(name: String) {
                print("Hello, \\(name)!")
            }

            greet(name: "User")
            ```
            """
            
            let botResponse = Message(content: markdownResponse, isUser: false)
            self.messages.append(botResponse)
        }
    }
}

struct MarkdownView: View {
    let content: String
    
    var body: some View {
        Text(.init(content))
//            .markdownCodeBackground() // Use AttributedString initializer for markdown
            .textSelection(.enabled)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.colorScheme, .dark) // Ensure dark mode for markdown
            // Apply custom styling to code blocks
            .environment(\.font, .system(.body, design: .monospaced))
    }
}

// Custom view modifier for code blocks in markdown
extension View {
    func markdownCodeBackground() -> some View {
        self.modifier(MarkdownCodeBackgroundModifier())
    }
}

struct MarkdownCodeBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
            )
    }
}

struct MessageView: View {
    let message: Message
    
    var body: some View {
        if message.isUser {
            HStack {
                Spacer()
                Text(message.content)
                    .padding()
                    .background(Color(red: 0.25, green: 0.25, blue: 0.25)) // Dark gray for user messages
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
            }
        } else {
            MarkdownView(content: message.content)
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        ZStack {
            // Background tap gesture to dismiss keyboard when tapping outside
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = false
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack(spacing: 0) {
                // Chat messages area
                ScrollViewReader { scrollView in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()
                
                // Input area
                TextField("Type a message", text: $viewModel.inputText)
                    .focused($isInputFocused)
                    // Remove default text field styling
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(12)
                    // Make background transparent
                    .background(Color.clear)
                    // Optional subtle border
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .onSubmit {
                        viewModel.sendMessage()
                        isInputFocused = true
                    }
                    .padding()
            }
        }
        .frame(minWidth: 400, minHeight: 600)
        .preferredColorScheme(.dark) // Force dark mode
        .background(Color(red: 0.1, green: 0.1, blue: 0.12).ignoresSafeArea())
    }
}
