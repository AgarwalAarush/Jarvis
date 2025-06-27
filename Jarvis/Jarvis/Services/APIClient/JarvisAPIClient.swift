import Foundation
import Combine

// MARK: - Jarvis API Client
class JarvisAPIClient: APIClientProtocol {
    static let shared = JarvisAPIClient()
    
    private let baseURL: URL
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Try multiple ports for backend (5000 might be used by AirPlay)
        self.baseURL = URL(string: "http://localhost:5001/api/v1")!
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        self.session = URLSession(configuration: config)
        
        print("APIClient initialized with base URL: \(baseURL)")
    }
    
    func connect() -> AnyPublisher<ConnectionStatus, Never> {
        // For now, we assume connection is always successful
        return Just(.connected).eraseToAnyPublisher()
    }
    
    func disconnect() {
        // No-op
    }
    
    var connectionStatus: ConnectionStatus = .connected
    
    func sendMessage(_ message: String, conversationId: UUID?) -> AnyPublisher<ChatResponse, APIError> {
        let request = ChatRequest(message: message, conversationId: conversationId)
        let url = baseURL.appendingPathComponent("chat")
        return post(url, body: request)
    }
    
    func sendMessageStream(_ message: String, conversationId: UUID?) -> AnyPublisher<ChatStreamResponse, APIError> {
        let request = ChatRequest(message: message, conversationId: conversationId, stream: true)
        let url = baseURL.appendingPathComponent("chat/stream")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = try? JSONEncoder().encode(request)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        return session.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw APIError.invalidResponse
                }
                
                // Parse Server-Sent Events format
                let dataString = String(data: data, encoding: .utf8) ?? ""
                let lines = dataString.components(separatedBy: "\n")
                
                for line in lines {
                    if line.hasPrefix("data: ") {
                        let jsonString = String(line.dropFirst(6))
                        if let jsonData = jsonString.data(using: .utf8) {
                            do {
                                let streamData = try JSONDecoder().decode(StreamingChatResponse.self, from: jsonData)
                                return ChatStreamResponse(
                                    type: streamData.isComplete ? .complete : .message,
                                    data: streamData.content,
                                    conversationId: streamData.conversationId,
                                    isComplete: streamData.isComplete,
                                    error: nil
                                )
                            } catch {
                                continue
                            }
                        }
                    }
                }
                
                throw APIError.invalidData
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func getConversations() -> AnyPublisher<[ConversationDTO], APIError> {
        let url = baseURL.appendingPathComponent("conversations")
        return get(url)
            .map { (response: ConversationsResponse) in
                return response.conversations
            }
            .eraseToAnyPublisher()
    }
    
    func createConversation(title: String?) -> AnyPublisher<ConversationDTO, APIError> {
        let request = ConversationRequest(title: title, metadata: nil)
        let url = baseURL.appendingPathComponent("conversations")
        return post(url, body: request)
    }
    
    func getConversation(id: UUID) -> AnyPublisher<ConversationDTO, APIError> {
        let url = baseURL.appendingPathComponent("conversations/\(id)")
        return get(url)
    }
    
    func deleteConversation(id: UUID) -> AnyPublisher<Void, APIError> {
        let url = baseURL.appendingPathComponent("conversations/\(id)")
        return delete(url)
    }
    
    func updateConversation(id: UUID, title: String) -> AnyPublisher<ConversationDTO, APIError> {
        let request = ConversationRequest(title: title, metadata: nil)
        let url = baseURL.appendingPathComponent("conversations/\(id)")
        return put(url, body: request)
    }
    
    func searchConversations(query: String) -> AnyPublisher<[SearchResult], APIError> {
        let url = baseURL.appendingPathComponent("search/conversations?q=\(query)")
        return get(url)
    }
    
    func searchMessages(query: String, conversationId: UUID?) -> AnyPublisher<[SearchResult], APIError> {
        var url = baseURL.appendingPathComponent("search/messages?q=\(query)")
        if let conversationId = conversationId {
            url.append(queryItems: [URLQueryItem(name: "conversationId", value: conversationId.uuidString)])
        }
        return get(url)
    }
    
    func exportConversation(id: UUID, format: ExportFormat) -> AnyPublisher<Data, APIError> {
        let url = baseURL.appendingPathComponent("export/conversations/\(id)?format=\(format.rawValue)")
        return get(url)
    }
    
    func exportAllConversations(format: ExportFormat) -> AnyPublisher<Data, APIError> {
        let url = baseURL.appendingPathComponent("export/conversations?format=\(format.rawValue)")
        return get(url)
    }
    
    func getStatus() -> AnyPublisher<SystemStatus, APIError> {
        let url = baseURL.appendingPathComponent("status")
        return get(url)
    }
    
    func getModels() -> AnyPublisher<[ModelsResponse.ModelInfo], APIError> {
        let url = baseURL.appendingPathComponent("models")
        return get(url)
            .map { (response: ModelsResponse) in
                return response.models
            }
            .eraseToAnyPublisher()
    }
    
    func getConfig() -> AnyPublisher<SystemConfig, APIError> {
        let url = baseURL.appendingPathComponent("config")
        return get(url)
    }
    
    func healthCheck() -> AnyPublisher<HealthStatus, APIError> {
        let url = baseURL.appendingPathComponent("health")
        return get(url)
    }
    
    // MARK: - Voice Processing Methods
    func uploadAudio(_ audioData: Data, format: String, processWithLLM: Bool = false, conversationId: UUID? = nil) -> AnyPublisher<VoiceProcessingResponse, APIError> {
        let url = baseURL.appendingPathComponent("voice/upload")
        
        // Create multipart form data request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.\(format)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/\(format)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add process parameter if needed
        if processWithLLM {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"process\"\r\n\r\n".data(using: .utf8)!)
            body.append("true".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add conversation ID if provided
        if let conversationId = conversationId {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"conversation_id\"\r\n\r\n".data(using: .utf8)!)
            body.append(conversationId.uuidString.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        urlRequest.httpBody = body
        
        return session.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw APIError.invalidResponse
                }
                return data
            }
            .decode(type: VoiceProcessingResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func transcribeAudio(_ audioData: Data, format: String) -> AnyPublisher<TranscriptionResponse, APIError> {
        return uploadAudio(audioData, format: format, processWithLLM: false)
            .map { response in
                return TranscriptionResponse(
                    transcription: response.transcription,
                    confidence: response.confidence,
                    language: response.language,
                    duration: response.duration,
                    timestamp: response.timestamp,
                    metadata: response.metadata
                )
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Helper Methods
    private func get<T: Decodable>(_ url: URL) -> AnyPublisher<T, APIError> {
        print("GET request to: \(url)")
        
        return session.dataTaskPublisher(for: url)
            .tryMap { data, response in
                print("Response received for GET \(url)")
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 200 {
                        return data
                    } else {
                        let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                        print("HTTP Error \(httpResponse.statusCode): \(errorMsg)")
                        throw APIError.serverError(httpResponse.statusCode, errorMsg)
                    }
                } else {
                    print("Invalid response type")
                    throw APIError.invalidResponse
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                print("Error in GET request to \(url): \(error)")
                if let apiError = error as? APIError {
                    return apiError
                } else if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet:
                        return APIError(code: "NETWORK_ERROR", message: "No internet connection", details: nil, timestamp: Date())
                    case .cannotFindHost, .cannotConnectToHost:
                        return APIError(code: "NETWORK_ERROR", message: "Cannot connect to server. Make sure the backend is running.", details: urlError.localizedDescription, timestamp: Date())
                    case .timedOut:
                        return APIError.timeout
                    default:
                        return APIError.networkError(urlError)
                    }
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func post<T: Decodable, B: Encodable>(_ url: URL, body: B) -> AnyPublisher<T, APIError> {
        print("POST request to: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(body)
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                print("Response received for POST \(url)")
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                        return data
                    } else {
                        let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                        print("HTTP Error \(httpResponse.statusCode): \(errorMsg)")
                        throw APIError.serverError(httpResponse.statusCode, errorMsg)
                    }
                } else {
                    print("Invalid response type")
                    throw APIError.invalidResponse
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                print("Error in POST request to \(url): \(error)")
                if let apiError = error as? APIError {
                    return apiError
                } else if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet:
                        return APIError(code: "NETWORK_ERROR", message: "No internet connection", details: nil, timestamp: Date())
                    case .cannotFindHost, .cannotConnectToHost:
                        return APIError(code: "NETWORK_ERROR", message: "Cannot connect to server. Make sure the backend is running.", details: urlError.localizedDescription, timestamp: Date())
                    case .timedOut:
                        return APIError.timeout
                    default:
                        return APIError.networkError(urlError)
                    }
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func put<T: Decodable, B: Encodable>(_ url: URL, body: B) -> AnyPublisher<T, APIError> {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = try? JSONEncoder().encode(body)
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw APIError.invalidResponse
                }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func delete(_ url: URL) -> AnyPublisher<Void, APIError> {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
                    throw APIError.invalidResponse
                }
                return ()
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
}