import Foundation
import Combine

// MARK: - Jarvis API Client
class JarvisAPIClient: APIClientProtocol, ObservableObject {
    // MARK: - Properties
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let timeoutInterval: TimeInterval = 30.0
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    
    // MARK: - Initialization
    init(baseURL: URL = URL(string: "http://localhost:5000")!) {
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval * 2
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        
        // Start connection monitoring
        startConnectionMonitoring()
    }
    
    // MARK: - Connection Management
    func connect() -> AnyPublisher<ConnectionStatus, Never> {
        connectionStatus = .connecting
        
        return healthCheck()
            .map { _ in ConnectionStatus.connected }
            .catch { _ in Just(ConnectionStatus.error("Failed to connect")) }
            .handleEvents(receiveOutput: { [weak self] status in
                self?.connectionStatus = status
            })
            .eraseToAnyPublisher()
    }
    
    func disconnect() {
        connectionStatus = .disconnected
    }
    
    private func startConnectionMonitoring() {
        // Monitor connection status and attempt reconnection
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkConnection()
            }
            .store(in: &cancellables)
    }
    
    private func checkConnection() {
        guard case .connected = connectionStatus else { return }
        
        healthCheck()
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.connectionStatus = .error("Connection lost")
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Chat Operations
    func sendMessage(_ message: String, conversationId: UUID?) -> AnyPublisher<ChatResponse, APIError> {
        let request = ChatRequest(message: message, conversationId: conversationId)
        
        return performRequest(
            endpoint: "/api/v1/chat",
            method: "POST",
            body: request
        )
    }
    
    func sendMessageStream(_ message: String, conversationId: UUID?) -> AnyPublisher<ChatStreamResponse, APIError> {
        let request = ChatRequest(message: message, conversationId: conversationId, stream: true)
        
        return performStreamRequest(
            endpoint: "/api/v1/chat",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - Conversation Management
    func getConversations() -> AnyPublisher<[ConversationDTO], APIError> {
        return performRequest (
            endpoint: "/api/v1/conversations",
            method: "GET",
            body: EmptyBody(),
            queryItems: nil
        )
    }
    
    func createConversation(title: String?) -> AnyPublisher<ConversationDTO, APIError> {
        let request = CreateConversationRequest(title: title)
        
        return performRequest(
            endpoint: "/api/v1/conversations",
            method: "POST",
            body: request
        )
    }
    
    func getConversation(id: UUID) -> AnyPublisher<ConversationDTO, APIError> {
        return performRequest (
            endpoint: "/api/v1/conversations/\(id)",
            method: "GET",
            body: EmptyBody(),
            queryItems: nil
        )
    }
    
    func deleteConversation(id: UUID) -> AnyPublisher<Void, APIError> {
        return performRequest (
            endpoint: "/api/v1/conversations/\(id)",
            method: "DELETE",
            body: EmptyBody(),
            queryItems: nil
        )
        .map { (_ : EmptyBody) in () }
        .eraseToAnyPublisher()
    }
    
    func updateConversation(id: UUID, title: String) -> AnyPublisher<ConversationDTO, APIError> {
        let request = UpdateConversationRequest(title: title)
        
        return performRequest(
            endpoint: "/api/v1/conversations/\(id)",
            method: "PUT",
            body: request
        )
    }
    
    // MARK: - Search
    func searchConversations(query: String) -> AnyPublisher<[SearchResult], APIError> {
        let queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "type", value: "conversation")]
        return performRequest (
            endpoint: "/api/v1/search",
            method: "GET",
            body: EmptyBody(),
            queryItems: queryItems
        )
    }
    
    func searchMessages(query: String, conversationId: UUID?) -> AnyPublisher<[SearchResult], APIError> {
        var queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "type", value: "message")]
        if let conversationId = conversationId {
            queryItems.append(URLQueryItem(name: "conversation_id", value: conversationId.uuidString))
        }
        return performRequest (
            endpoint: "/api/v1/search",
            method: "GET",
            body: EmptyBody(),
            queryItems: queryItems
        )
    }
    
    // MARK: - Export
    func exportConversation(id: UUID, format: ExportFormat) -> AnyPublisher<Data, APIError> {
        let queryItems = [URLQueryItem(name: "format", value: format.rawValue)]
        return performDataRequest(
            endpoint: "/api/v1/export/conversation/\(id)",
            method: "GET",
            queryItems: queryItems
        )
    }
    
    func exportAllConversations(format: ExportFormat) -> AnyPublisher<Data, APIError> {
        let queryItems = [URLQueryItem(name: "format", value: format.rawValue)]
        return performDataRequest(
            endpoint: "/api/v1/export/all",
            method: "GET",
            queryItems: queryItems
        )
    }
    
    // MARK: - System
    func getStatus() -> AnyPublisher<SystemStatus, APIError> {
        return performRequest(
            endpoint: "/api/v1/status",
            method: "GET",
            body: EmptyBody(),
            queryItems: nil
        )
    }
    
    func getModels() -> AnyPublisher<[ModelInfo], APIError> {
        return performRequest(
            endpoint: "/api/v1/models",
            method: "GET",
            body: EmptyBody(),
            queryItems: nil
        )
    }
    
    func getConfig() -> AnyPublisher<SystemConfig, APIError> {
        return performRequest (
            endpoint: "/api/v1/config",
            method: "GET",
            body: EmptyBody(),
            queryItems: nil
        )
    }
    
    func healthCheck() -> AnyPublisher<HealthStatus, APIError> {
        return performRequest (
            endpoint: "/api/v1/health",
            method: "GET",
            body: EmptyBody(),
            queryItems: nil
        )
    }
    
    // MARK: - Private Helper Methods
    private func performRequest<T: Codable, U: Codable>(
        endpoint: String,
        method: String,
        body: T? = nil,
        queryItems: [URLQueryItem]? = nil
    ) -> AnyPublisher<U, APIError> {
        guard let url = buildURL(endpoint: endpoint, queryItems: queryItems) else {
            return Fail(error: APIError.invalidData).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                return Fail(error: APIError.invalidData).eraseToAnyPublisher()
            }
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                try self.validateResponse(data: data, response: response)
            }
            .decode(type: U.self, decoder: decoder)
            .mapError { error in
                self.handleError(error)
            }
            .retry(maxRetries)
            .eraseToAnyPublisher()
    }
    
    private func performDataRequest(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil
    ) -> AnyPublisher<Data, APIError> {
        guard let url = buildURL(endpoint: endpoint, queryItems: queryItems) else {
            return Fail(error: APIError.invalidData).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                try self.validateResponse(data: data, response: response)
            }
            .mapError { error in
                self.handleError(error)
            }
            .retry(maxRetries)
            .eraseToAnyPublisher()
    }
    
    private func performStreamRequest<T: Codable>(
        endpoint: String,
        method: String,
        body: T
    ) -> AnyPublisher<ChatStreamResponse, APIError> {
        guard let url = buildURL(endpoint: endpoint) else {
            return Fail(error: APIError.invalidData).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            return Fail(error: APIError.invalidData).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                try self.validateResponse(data: data, response: response)
            }
            .mapError { error in
                self.handleError(error)
            }
            .flatMap { data in
                self.parseStreamData(data)
            }
            .mapError { error in
                self.handleError(error)
            }
            .eraseToAnyPublisher()
    }
    
    private func buildURL(endpoint: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        return components?.url
    }
    
    private func validateResponse(data: Data, response: URLResponse) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw APIError.authenticationError
        case 429:
            throw APIError.rateLimitExceeded
        case 500...599:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Server error"
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        default:
            throw APIError.serverError(httpResponse.statusCode, "Unexpected status code")
        }
    }
    
    private func handleError(_ error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }
        
        switch error {
        case let urlError as URLError:
            switch urlError.code {
            case .timedOut:
                return .timeout
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError(error)
            default:
                return .networkError(error)
            }
        case let decodingError as DecodingError:
            return .invalidData
        default:
            return .unknown
        }
    }
    
    private func parseStreamData(_ data: Data) -> AnyPublisher<ChatStreamResponse, APIError> {
        guard let string = String(data: data, encoding: .utf8) else {
            return Fail(error: APIError.invalidData).eraseToAnyPublisher()
        }
        
        let lines = string.components(separatedBy: .newlines)
        var responses: [ChatStreamResponse] = []
        
        for line in lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            
            if jsonString == "[DONE]" {
                let response = ChatStreamResponse(
                    type: .complete,
                    data: nil,
                    conversationId: nil,
                    isComplete: true,
                    error: nil
                )
                responses.append(response)
                continue
            }
            
            guard let jsonData = jsonString.data(using: .utf8),
                  let response = try? decoder.decode(ChatStreamResponse.self, from: jsonData) else {
                continue
            }
            
            responses.append(response)
        }
        
        return Publishers.Sequence(sequence: responses)
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
}

private struct CreateConversationRequest: Codable {
    let title: String?
}

private struct UpdateConversationRequest: Codable {
    let title: String
}

private struct EmptyBody: Codable {} 
