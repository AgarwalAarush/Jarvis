import Foundation
import Combine

// MARK: - Streaming Parser
class StreamingParser: ObservableObject {
    // MARK: - Properties
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    // MARK: - Initialization
    init() {
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    // MARK: - Public Methods
    func parseStreamData(_ data: Data) -> AnyPublisher<StreamChunk, StreamingError> {
        guard let string = String(data: data, encoding: .utf8) else {
            return Fail(error: StreamingError.invalidData).eraseToAnyPublisher()
        }
        
        let lines = string.components(separatedBy: .newlines)
        var chunks: [StreamChunk] = []
        
        for line in lines {
            guard !line.isEmpty else { continue }
            
            if let chunk = parseLine(line) {
                chunks.append(chunk)
            }
        }
        
        return Publishers.Sequence(sequence: chunks)
            .setFailureType(to: StreamingError.self)
            .eraseToAnyPublisher()
    }
    
    func parseStreamResponse(_ response: URLResponse, data: Data) -> AnyPublisher<StreamChunk, StreamingError> {
        guard let httpResponse = response as? HTTPURLResponse else {
            return Fail(error: StreamingError.invalidResponse).eraseToAnyPublisher()
        }
        
        // Check if this is a streaming response
        guard isStreamingResponse(httpResponse) else {
            return Fail(error: StreamingError.notStreamingResponse).eraseToAnyPublisher()
        }
        
        return parseStreamData(data)
    }
    
    // MARK: - Private Methods
    private func parseLine(_ line: String) -> StreamChunk? {
        // Handle different SSE formats
        if line.hasPrefix("data: ") {
            return parseDataLine(line)
        } else if line.hasPrefix("event: ") {
            return parseEventLine(line)
        } else if line.hasPrefix("id: ") {
            return parseIdLine(line)
        } else if line.hasPrefix("retry: ") {
            return parseRetryLine(line)
        } else if line.isEmpty {
            // Empty line indicates end of message
            return nil
        } else {
            // Unknown line format
            return nil
        }
    }
    
    private func parseDataLine(_ line: String) -> StreamChunk? {
        let dataString = String(line.dropFirst(6))
        
        // Handle special SSE tokens
        if dataString == "[DONE]" {
            return StreamChunk.complete
        }
        
        // Try to parse as JSON
        guard let data = dataString.data(using: .utf8) else {
            return StreamChunk.text(dataString)
        }
        
        do {
            let streamResponse = try decoder.decode(ChatStreamResponse.self, from: data)
            return StreamChunk.chatResponse(streamResponse)
        } catch {
            // If JSON parsing fails, treat as plain text
            return StreamChunk.text(dataString)
        }
    }
    
    private func parseEventLine(_ line: String) -> StreamChunk? {
        let eventString = String(line.dropFirst(7))
        return StreamChunk.event(eventString)
    }
    
    private func parseIdLine(_ line: String) -> StreamChunk? {
        let idString = String(line.dropFirst(4))
        return StreamChunk.id(idString)
    }
    
    private func parseRetryLine(_ line: String) -> StreamChunk? {
        let retryString = String(line.dropFirst(7))
        if let retryInterval = TimeInterval(retryString) {
            return StreamChunk.retry(retryInterval)
        }
        return nil
    }
    
    private func isStreamingResponse(_ response: HTTPURLResponse) -> Bool {
        // Check content type for SSE
        let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? ""
        return contentType.contains("text/event-stream") || contentType.contains("application/stream+json")
    }
}

// MARK: - Stream Chunk
enum StreamChunk {
    case text(String)
    case chatResponse(ChatStreamResponse)
    case event(String)
    case id(String)
    case retry(TimeInterval)
    case complete
    case error(String)
}

// MARK: - Streaming Error
enum StreamingError: Error, LocalizedError {
    case invalidData
    case invalidResponse
    case notStreamingResponse
    case parsingError(String)
    case connectionError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid streaming data received"
        case .invalidResponse:
            return "Invalid HTTP response"
        case .notStreamingResponse:
            return "Response is not a streaming response"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        case .connectionError(let message):
            return "Connection error: \(message)"
        }
    }
}

// MARK: - Streaming Manager
class StreamingManager: ObservableObject {
    // MARK: - Properties
    private let parser = StreamingParser()
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var isStreaming = false
    @Published private(set) var streamError: String?
    
    // MARK: - Event Publishers
    private let streamSubject = PassthroughSubject<StreamChunk, Never>()
    var streamEvents: AnyPublisher<StreamChunk, Never> {
        streamSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Public Methods
   func startStreaming(from publisher: AnyPublisher<Data, Error>) {
        isStreaming = true
        streamError = nil
        
        publisher
            .flatMap { [weak self] data in
                self?.parser.parseStreamData(data) 
                .mapError { $0 as Error }
                .eraseToAnyPublisher()
                ?? Empty<StreamChunk, Error>().eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.handleStreamCompletion(completion)
                },
                receiveValue: { [weak self] chunk in
                    self?.handleStreamChunk(chunk)
                }
            )
            .store(in: &cancellables)
    }
    
    func stopStreaming() {
        isStreaming = false
        cancellables.removeAll()
    }
    
    // MARK: - Private Methods
    private func handleStreamChunk(_ chunk: StreamChunk) {
        streamSubject.send(chunk)
        
        // Handle completion
        if case .complete = chunk {
            isStreaming = false
        }
        
        // Handle errors
        if case .error(let message) = chunk {
            streamError = message
            isStreaming = false
        }
    }
    
    private func handleStreamCompletion(_ completion: Subscribers.Completion<Error>) {
        isStreaming = false
        
        if case .failure(let error) = completion {
            streamError = error.localizedDescription
        }
    }
}

// MARK: - Stream Response Builder
class StreamResponseBuilder {
    private var chunks: [StreamChunk] = []
    private var currentText = ""
    private var currentEvent: String?
    private var currentId: String?
    private var currentRetry: TimeInterval?
    
    func addChunk(_ chunk: StreamChunk) {
        chunks.append(chunk)
        
        switch chunk {
        case .text(let text):
            currentText += text
        case .event(let event):
            currentEvent = event
        case .id(let id):
            currentId = id
        case .retry(let retry):
            currentRetry = retry
        case .complete, .error, .chatResponse:
            // These are terminal chunks
            break
        }
    }
    
    func buildResponse() -> StreamResponse {
        return StreamResponse(
            text: currentText,
            event: currentEvent,
            id: currentId,
            retry: currentRetry,
            chunks: chunks
        )
    }
    
    func reset() {
        chunks.removeAll()
        currentText = ""
        currentEvent = nil
        currentId = nil
        currentRetry = nil
    }
}

// MARK: - Stream Response
struct StreamResponse {
    let text: String
    let event: String?
    let id: String?
    let retry: TimeInterval?
    let chunks: [StreamChunk]
    
    var isComplete: Bool {
        return chunks.contains { chunk in
            if case .complete = chunk { return true }
            if case .error = chunk { return true }
            return false
        }
    }
    
    var hasError: Bool {
        return chunks.contains { chunk in
            if case .error = chunk { return true }
            return false
        }
    }
    
    var errorMessage: String? {
        for chunk in chunks {
            if case .error(let message) = chunk {
                return message
            }
        }
        return nil
    }
    
    var chatResponses: [ChatStreamResponse] {
        return chunks.compactMap { chunk in
            if case .chatResponse(let response) = chunk {
                return response
            }
            return nil
        }
    }
} 