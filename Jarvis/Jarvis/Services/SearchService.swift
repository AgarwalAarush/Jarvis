import Foundation
import CoreData
import Combine

class SearchService: ObservableObject {
    // MARK: - Published Properties
    @Published var searchResults: [SearchResultViewModel] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let coreDataService: CoreDataService
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(coreDataService: CoreDataService) {
        self.coreDataService = coreDataService
        setupObservers()
    }
    
    // MARK: - Search Operations
    func search(query: String, scope: SearchScope = .all, limit: Int = 50) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        // Cancel previous search
        searchTask?.cancel()
        
        isSearching = true
        errorMessage = nil
        
        searchTask = Task {
            await performSearch(query: query, scope: scope, limit: limit)
        }
    }
    
    @MainActor
    private func performSearch(query: String, scope: SearchScope, limit: Int) async {
        defer { isSearching = false }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var results: [SearchResultViewModel] = []
        
        switch scope {
        case .all:
            results = await searchAll(query: trimmedQuery, limit: limit)
        case .chats:
            results = await searchChats(query: trimmedQuery, limit: limit)
        case .messages:
            results = await searchMessages(query: trimmedQuery, limit: limit)
        case .recent:
            results = await searchRecent(query: trimmedQuery, limit: limit)
        }
        
        // Sort results by relevance
        results.sort { $0.relevanceScore > $1.relevanceScore }
        
        searchResults = results
    }
    
    private func searchAll(query: String, limit: Int) async -> [SearchResultViewModel] {
        var results: [SearchResultViewModel] = []
        
        // Search chats
        let chatResults = await searchChats(query: query, limit: limit / 2)
        results.append(contentsOf: chatResults)
        
        // Search messages
        let messageResults = await searchMessages(query: query, limit: limit / 2)
        results.append(contentsOf: messageResults)
        
        return results
    }
    
    private func searchChats(query: String, limit: Int) async -> [SearchResultViewModel] {
        let chats = coreDataService.searchChats(query: query)
        
        return chats.prefix(limit).map { chat in
            let relevanceScore = calculateRelevanceScore(
                query: query,
                title: chat.title ?? "",
                content: getLastMessageContent(from: chat),
                date: chat.updatedAt ?? Date()
            )
            
            return SearchResultViewModel(
                id: chat.id ?? UUID(),
                type: .chat,
                title: chat.title ?? "Untitled Chat",
                content: getLastMessageContent(from: chat),
                date: chat.updatedAt ?? Date(),
                relevanceScore: relevanceScore,
                metadata: [
                    "messageCount": (chat.messages as? Set<Message>)?.count ?? 0,
                    "isActive": chat.isActive
                ]
            )
        }
    }
    
    private func searchMessages(query: String, limit: Int) async -> [SearchResultViewModel] {
        let messages = coreDataService.searchMessages(query: query)
        
        return messages.prefix(limit).map { message in
            let relevanceScore = calculateRelevanceScore(
                query: query,
                title: "",
                content: message.content ?? "",
                date: message.timestamp ?? Date()
            )
            
            return SearchResultViewModel(
                id: message.id ?? UUID(),
                type: .message,
                title: message.chat?.title ?? "Untitled Chat",
                content: message.content ?? "",
                date: message.timestamp ?? Date(),
                relevanceScore: relevanceScore,
                metadata: [
                    "isUser": message.isUser,
                    "chatId": message.chat?.id?.uuidString ?? ""
                ]
            )
        }
    }
    
    private func searchRecent(query: String, limit: Int) async -> [SearchResultViewModel] {
        let recentDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let predicate = NSPredicate(format: "updatedAt >= %@", recentDate as CVarArg)
        let recentChats = coreDataService.fetchChats(predicate: predicate)
        
        var results: [SearchResultViewModel] = []
        
        for chat in recentChats.prefix(limit) {
            let messages = coreDataService.fetchMessages(for: chat)
            let matchingMessages = messages.filter { message in
                (message.content ?? "").localizedCaseInsensitiveContains(query)
            }
            
            for message in matchingMessages {
                let relevanceScore = calculateRelevanceScore(
                    query: query,
                    title: chat.title ?? "",
                    content: message.content ?? "",
                    date: message.timestamp ?? Date()
                )
                
                results.append(SearchResultViewModel(
                    id: message.id ?? UUID(),
                    type: .message,
                    title: chat.title ?? "Untitled Chat",
                    content: message.content ?? "",
                    date: message.timestamp ?? Date(),
                    relevanceScore: relevanceScore,
                    metadata: [
                        "isUser": message.isUser,
                        "chatId": chat.id?.uuidString ?? ""
                    ]
                ))
            }
        }
        
        return results
    }
    
    // MARK: - Relevance Scoring
    private func calculateRelevanceScore(query: String, title: String, content: String, date: Date) -> Double {
        var score: Double = 0.0
        
        let queryLower = query.lowercased()
        let titleLower = title.lowercased()
        let contentLower = content.lowercased()
        
        // Title matches (higher weight)
        if titleLower.contains(queryLower) {
            score += 10.0
            if titleLower == queryLower {
                score += 5.0 // Exact match
            }
        }
        
        // Content matches
        if contentLower.contains(queryLower) {
            score += 5.0
            if contentLower == queryLower {
                score += 3.0 // Exact match
            }
        }
        
        // Word boundary matches (higher relevance)
        let words = queryLower.components(separatedBy: .whitespacesAndNewlines)
        for word in words where !word.isEmpty {
            if titleLower.contains(word) {
                score += 2.0
            }
            if contentLower.contains(word) {
                score += 1.0
            }
        }
        
        // Recency bonus (newer items get higher scores)
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        let recencyBonus = max(0.0, 10.0 - Double(daysSince))
        score += recencyBonus * 0.1
        
        return score
    }
    
    // MARK: - Helper Methods
    private func getLastMessageContent(from chat: Chat) -> String {
        guard let messages = chat.messages as? Set<Message> else { return "" }
        let sortedMessages = messages.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
        return sortedMessages.last?.content ?? ""
    }
    
    // MARK: - Advanced Search
    func advancedSearch(criteria: SearchCriteria) async -> [SearchResultViewModel] {
        isSearching = true
        errorMessage = nil
        
        defer { isSearching = false }
        
        var results: [SearchResultViewModel] = []
        
        // Build predicate based on criteria
        var predicates: [NSPredicate] = []
        
        if let dateFrom = criteria.dateFrom {
            predicates.append(NSPredicate(format: "timestamp >= %@", dateFrom as CVarArg))
        }
        
        if let dateTo = criteria.dateTo {
            predicates.append(NSPredicate(format: "timestamp <= %@", dateTo as CVarArg))
        }
        
        if criteria.isUserOnly {
            predicates.append(NSPredicate(format: "isUser == true"))
        }
        
        if criteria.isAssistantOnly {
            predicates.append(NSPredicate(format: "isUser == false"))
        }
        
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let messages = coreDataService.fetchMessages(with: compoundPredicate)
        
        for message in messages {
            if criteria.query.isEmpty || (message.content ?? "").localizedCaseInsensitiveContains(criteria.query) {
                let relevanceScore = calculateRelevanceScore(
                    query: criteria.query,
                    title: message.chat?.title ?? "",
                    content: message.content ?? "",
                    date: message.timestamp ?? Date()
                )
                
                results.append(SearchResultViewModel(
                    id: message.id ?? UUID(),
                    type: .message,
                    title: message.chat?.title ?? "Untitled Chat",
                    content: message.content ?? "",
                    date: message.timestamp ?? Date(),
                    relevanceScore: relevanceScore,
                    metadata: [
                        "isUser": message.isUser,
                        "chatId": message.chat?.id?.uuidString ?? ""
                    ]
                ))
            }
        }
        
        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    // MARK: - Search Suggestions
    func getSearchSuggestions(query: String) -> [String] {
        guard !query.isEmpty else { return [] }
        
        let suggestions = [
            "from:user",
            "from:assistant",
            "date:today",
            "date:yesterday",
            "date:this week",
            "date:this month",
            "has:code",
            "has:link",
            "has:image"
        ]
        
        return suggestions.filter { $0.localizedCaseInsensitiveContains(query) }
    }
    
    // MARK: - Search History
    func saveSearchQuery(_ query: String) {
        var history = getSearchHistory()
        
        // Remove if already exists
        history.removeAll { $0 == query }
        
        // Add to beginning
        history.insert(query, at: 0)
        
        // Keep only last 20 searches
        if history.count > 20 {
            history = Array(history.prefix(20))
        }
        
        UserDefaults.standard.set(history, forKey: "searchHistory")
    }
    
    func getSearchHistory() -> [String] {
        return UserDefaults.standard.stringArray(forKey: "searchHistory") ?? []
    }
    
    func clearSearchHistory() {
        UserDefaults.standard.removeObject(forKey: "searchHistory")
    }
    
    // MARK: - Observers
    private func setupObservers() {
        // Monitor Core Data changes for search updates
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                // Optionally refresh search results when data changes
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Data Models
struct SearchResultViewModel: Identifiable {
    let id: UUID
    let type: SearchResultType
    let title: String
    let content: String
    let date: Date
    let relevanceScore: Double
    let metadata: [String: Any]
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var previewContent: String {
        let maxLength = 150
        if content.count <= maxLength {
            return content
        }
        
        let truncated = String(content.prefix(maxLength))
        return truncated + "..."
    }
}

enum SearchResultType {
    case chat
    case message
    
    var displayName: String {
        switch self {
        case .chat:
            return "Chat"
        case .message:
            return "Message"
        }
    }
    
    var iconName: String {
        switch self {
        case .chat:
            return "message.circle"
        case .message:
            return "text.bubble"
        }
    }
}

enum SearchScope: String, CaseIterable {
    case all = "All"
    case chats = "Chats"
    case messages = "Messages"
    case recent = "Recent"
    
    var displayName: String {
        return rawValue
    }
}

struct SearchCriteria {
    var query: String = ""
    var dateFrom: Date?
    var dateTo: Date?
    var isUserOnly: Bool = false
    var isAssistantOnly: Bool = false
    var scope: SearchScope = .all
    var limit: Int = 50
    
    var isValid: Bool {
        if isUserOnly && isAssistantOnly {
            return false // Can't be both user and assistant only
        }
        
        if let dateFrom = dateFrom, let dateTo = dateTo {
            return dateFrom <= dateTo
        }
        
        return true
    }
}

// MARK: - Preview Helper
extension SearchService {
    static var preview: SearchService {
        let coreDataService = CoreDataService.preview
        return SearchService(coreDataService: coreDataService)
    }
} 