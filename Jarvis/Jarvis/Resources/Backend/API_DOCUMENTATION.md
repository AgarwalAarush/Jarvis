# Jarvis API Documentation

## Overview

The Jarvis API provides a RESTful interface and WebSocket support for the Jarvis voice assistant. It bridges the Python backend with the SwiftUI frontend, enabling both text-based chat and voice interactions.

## Base URL

- **Development**: `http://localhost:5000`
- **API Version**: `v1`
- **Base Path**: `/api/v1`

## Authentication

Currently, the API does not require authentication for local development. In production, consider implementing API keys or JWT tokens.

## Endpoints

### Health Check

#### GET `/api/v1/health`

Check if the API server is running.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "version": "1.0.0"
}
```

### System Status

#### GET `/api/v1/status`

Get the current system status and capabilities.

**Response:**
```json
{
  "status": "ready",
  "voice_assistant_available": true,
  "llm_available": true,
  "voice_active": false,
  "conversations_count": 5,
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### Chat Endpoints

#### POST `/api/v1/chat`

Send a text message and get an AI response.

**Request Body:**
```json
{
  "message": "Hello Jarvis, what's the weather like?",
  "conversation_id": "optional-uuid-for-continuing-conversation"
}
```

**Response:**
```json
{
  "conversation_id": "uuid-of-conversation",
  "response": "The weather is currently sunny with a temperature of 72°F.",
  "message_id": "uuid-of-response-message",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

**Error Response:**
```json
{
  "error": "Message is required"
}
```

#### GET `/api/v1/chat/{conversation_id}`

Get the full conversation history.

**Response:**
```json
{
  "id": "conversation-uuid",
  "created_at": "2024-01-15T10:00:00.000Z",
  "messages": [
    {
      "id": "message-uuid-1",
      "content": "Hello Jarvis",
      "is_user": true,
      "timestamp": "2024-01-15T10:00:00.000Z"
    },
    {
      "id": "message-uuid-2",
      "content": "Hello! How can I help you today?",
      "is_user": false,
      "timestamp": "2024-01-15T10:00:01.000Z"
    }
  ]
}
```

#### GET `/api/v1/conversations`

List all conversations.

**Response:**
```json
[
  {
    "id": "conversation-uuid",
    "created_at": "2024-01-15T10:00:00.000Z",
    "message_count": 4,
    "last_message": "Thank you for your help!"
  }
]
```

### Voice Endpoints

#### POST `/api/v1/voice/start`

Start the voice assistant listening session.

**Response:**
```json
{
  "status": "voice_started",
  "message": "Voice assistant is now listening"
}
```

#### POST `/api/v1/voice/stop`

Stop the voice assistant listening session.

**Response:**
```json
{
  "status": "voice_stopped",
  "message": "Voice assistant stopped"
}
```

#### GET `/api/v1/voice/status`

Get the current voice assistant status.

**Response:**
```json
{
  "is_active": false,
  "is_listening": false,
  "is_recording": false,
  "is_processing": false
}
```

## WebSocket Events

The API also supports WebSocket connections for real-time communication.

### Connection

Connect to: `ws://localhost:5000`

### Events

#### Client → Server

- `voice_activity`: Send voice activity data
- `wake_word_detected`: Notify when wake word is detected

#### Server → Client

- `status`: Connection status updates
- `voice_activity_update`: Real-time voice activity updates
- `wake_word_triggered`: Wake word detection notifications

## Error Handling

All endpoints return appropriate HTTP status codes:

- `200`: Success
- `400`: Bad Request (invalid input)
- `404`: Not Found (resource doesn't exist)
- `500`: Internal Server Error

Error responses include an `error` field with a description:

```json
{
  "error": "Message is required"
}
```

## Rate Limiting

Currently, no rate limiting is implemented. Consider adding rate limiting for production use.

## Testing

### Using curl

```bash
# Health check
curl http://localhost:5000/api/v1/health

# Send a chat message
curl -X POST http://localhost:5000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello Jarvis"}'

# Get system status
curl http://localhost:5000/api/v1/status

# Start voice assistant
curl -X POST http://localhost:5000/api/v1/voice/start

# Stop voice assistant
curl -X POST http://localhost:5000/api/v1/voice/stop
```

### Using Python requests

```python
import requests

# Base URL
base_url = "http://localhost:5000/api/v1"

# Send a message
response = requests.post(f"{base_url}/chat", json={
    "message": "Hello Jarvis, what can you do?"
})

if response.status_code == 200:
    data = response.json()
    print(f"Response: {data['response']}")
else:
    print(f"Error: {response.json()['error']}")
```

## Development

### Running the Server

```bash
# Install dependencies
pip install -r requirements.txt

# Run the server
python run_api.py
```

### Environment Variables

Create a `.env` file in the Backend directory:

```env
# LLM Configuration
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama2

# TTS Configuration
CARTESIA_VOICE=Joan

# Audio Configuration
SAMPLE_RATE=16000
CHUNK_SIZE=1280

# Wake Word Configuration
WAKE_WORD_CONFIDENCE_THRESHOLD=0.95

# API Configuration
FLASK_ENV=development
FLASK_DEBUG=True
```

## Troubleshooting

### Common Issues

1. **Port 5000 already in use**
   - Change the port in `api_server.py` or kill the process using port 5000

2. **Import errors**
   - Make sure all dependencies are installed: `pip install -r requirements.txt`

3. **Voice assistant not starting**
   - Check if Ollama is running: `ollama serve`
   - Verify microphone permissions
   - Check the logs for specific error messages

4. **CORS errors**
   - The API includes CORS support, but if you're still getting errors, check the frontend URL configuration

### Logs

The API server logs all requests and errors. Check the console output for debugging information.

## Future Enhancements

- [ ] Authentication and authorization
- [ ] Rate limiting
- [ ] Request/response logging
- [ ] API versioning
- [ ] Swagger/OpenAPI documentation
- [ ] Metrics and monitoring
- [ ] Load balancing support 