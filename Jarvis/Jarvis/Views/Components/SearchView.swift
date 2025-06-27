import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search header
            searchHeader
            
            Divider()
            
            // Search results
            searchResultsView
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    @ViewBuilder
    private var searchHeader: some View {
        VStack(spacing: 20) {
            Text("Search Conversations")
                .font(.title2)
                .fontWeight(.semibold)
            
            ModernSearchField(
                text: $searchText,
                placeholder: "Search messages and conversations...",
                onSubmit: {
                    performSearch()
                },
                onClear: {
                    searchText = ""
                    searchResults = []
                }
            )
            .frame(maxWidth: 400)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    @ViewBuilder
    private var searchResultsView: some View {
        if isSearching {
            VStack {
                Spacer()
                LoadingIndicator()
                Text("Searching...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else if searchResults.isEmpty && !searchText.isEmpty {
            VStack {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No results found")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Try different keywords or check your spelling")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        } else if searchText.isEmpty {
            VStack {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Search your conversations")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Enter keywords to find messages and conversations")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        } else {
            List(searchResults) { result in
                SearchResultRow(result: result)
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isSearching = true
        
        // Simulate search (this will be replaced with actual API call)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.searchResults = self.generateMockResults()
            self.isSearching = false
        }
    }
    
    private func generateMockResults() -> [SearchResult] {
        // Generate mock search results for demonstration
        return [
            SearchResult(
                id: UUID(),
                type: "message",
                title: "Sample Chat",
                content: "Found '\(searchText)' in a previous conversation",
                conversationId: UUID(),
                timestamp: Date().addingTimeInterval(-3600),
                relevance: 0.95
            ),
            SearchResult(
                id: UUID(),
                type: "conversation",
                title: "Project Discussion",
                content: "Another mention of '\(searchText)' in project notes",
                conversationId: UUID(),
                timestamp: Date().addingTimeInterval(-7200),
                relevance: 0.87
            )
        ]
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let result: SearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.accentColor)
                
                Text(result.title)
                    .font(.headline)
                
                Spacer()
                
                Text(result.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(result.content)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(3)
            
            HStack {
                Text(typeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(result.relevance * 100))% match")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch result.type {
        case "message":
            return "message"
        case "conversation":
            return "bubble.left.and.bubble.right"
        case "chat":
            return "text.bubble"
        default:
            return "questionmark.circle"
        }
    }
    
    private var typeText: String {
        switch result.type {
        case "message":
            return "Message"
        case "conversation":
            return "Conversation" 
        case "chat":
            return "Chat"
        default:
            return "Unknown"
        }
    }
}

// MARK: - Preview
struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
} 