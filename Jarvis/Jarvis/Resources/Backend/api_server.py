from context import ContextManager
from llm_interface import LLMInterface
from llm_client import LLMClient
from jarvis import VoiceAssistant
from flask import Flask, request, jsonify, Response
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import json
import logging
import threading
import time
import uuid
from datetime import datetime
import os
import sys
import base64
import tempfile
import io
from werkzeug.utils import secure_filename

# Add the current directory to Python path to import local modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes
socketio = SocketIO(app, cors_allowed_origins="*")

# Global state
voice_assistant = None
llm_interface = None
context_manager = None
conversations = {}  # Store conversation history
is_voice_active = False


def initialize_backend():
    """Initialize the backend components"""
    global voice_assistant, llm_interface, context_manager

    try:
        logger.info("Initializing backend components...")

        # Initialize LLM interface
        llm_interface = LLMInterface()

        # Initialize context manager
        context_manager = ContextManager()

        # Initialize voice assistant (but don't start it yet)
        voice_assistant = VoiceAssistant()

        logger.info("Backend components initialized successfully")
        return True

    except Exception as e:
        logger.error(f"Failed to initialize backend: {e}")
        return False


@app.route('/api/v1/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    })


@app.route('/api/v1/status', methods=['GET'])
def get_status():
    """Get system status and capabilities"""
    return jsonify({
        'status': 'ready',
        'voice_assistant_available': voice_assistant is not None,
        'llm_available': llm_interface is not None,
        'voice_active': is_voice_active,
        'conversations_count': len(conversations),
        'timestamp': datetime.now().isoformat()
    })


@app.route('/api/v1/chat', methods=['POST'])
def chat():
    """Handle text chat messages"""
    try:
        data = request.get_json()

        if not data or 'message' not in data:
            return jsonify({'error': 'Message is required'}), 400

        message = data['message'].strip()
        conversation_id = data.get('conversation_id')

        if not message:
            return jsonify({'error': 'Message cannot be empty'}), 400

        # Create new conversation if not provided
        if not conversation_id:
            conversation_id = str(uuid.uuid4())
            conversations[conversation_id] = {
                'id': conversation_id,
                'created_at': datetime.now().isoformat(),
                'messages': []
            }

        # Add user message to conversation
        user_message = {
            'id': str(uuid.uuid4()),
            'content': message,
            'is_user': True,
            'timestamp': datetime.now().isoformat()
        }

        if conversation_id not in conversations:
            conversations[conversation_id] = {
                'id': conversation_id,
                'created_at': datetime.now().isoformat(),
                'messages': []
            }

        conversations[conversation_id]['messages'].append(user_message)

        # Get LLM response
        logger.info(f"Processing message: {message[:50]}...")

        try:
            # Use the LLM client to get response
            response_text = LLMClient.get_response(message)

            # Add bot response to conversation
            bot_message = {
                'id': str(uuid.uuid4()),
                'content': response_text,
                'is_user': False,
                'timestamp': datetime.now().isoformat()
            }

            conversations[conversation_id]['messages'].append(bot_message)

            return jsonify({
                'id': bot_message['id'],
                'message': response_text,
                'conversationId': conversation_id,
                'timestamp': bot_message['timestamp'],
                'model': 'jarvis-llm',
                'metadata': {}
            })

        except Exception as e:
            logger.error(f"Error getting LLM response: {e}")
            return jsonify({
                'error': 'Failed to get response from AI',
                'details': str(e)
            }), 500

    except Exception as e:
        logger.error(f"Error in chat endpoint: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/chat/<conversation_id>', methods=['GET'])
def get_conversation(conversation_id):
    """Get conversation history"""
    try:
        if conversation_id not in conversations:
            return jsonify({'error': 'Conversation not found'}), 404

        return jsonify(conversations[conversation_id])

    except Exception as e:
        logger.error(f"Error getting conversation: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/conversations', methods=['GET'])
def list_conversations():
    """List all conversations"""
    try:
        conversation_list = []
        for conv_id, conv_data in conversations.items():
            last_message = conv_data['messages'][-1] if conv_data['messages'] else None
            conversation_list.append({
                'id': conv_id,
                'title': f"Conversation {conv_id[:8]}",
                'createdAt': conv_data['created_at'],
                'updatedAt': conv_data.get('updated_at', conv_data['created_at']),
                'messageCount': len(conv_data['messages']),
                'lastMessage': {
                    'content': last_message['content'][:100] + '...' if last_message and len(last_message['content']) > 100 else last_message['content'] if last_message else '',
                    'timestamp': last_message['timestamp'] if last_message else conv_data['created_at']
                } if last_message else None,
                'metadata': {}
            })

        # Sort by creation date (newest first)
        conversation_list.sort(key=lambda x: x['createdAt'], reverse=True)

        return jsonify({
            'conversations': conversation_list,
            'totalCount': len(conversation_list),
            'hasMore': False
        })

    except Exception as e:
        logger.error(f"Error listing conversations: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/conversations', methods=['POST'])
def create_conversation():
    """Create a new conversation"""
    try:
        data = request.get_json() or {}
        title = data.get('title', f"New Conversation")
        
        conversation_id = str(uuid.uuid4())
        timestamp = datetime.now().isoformat()
        
        conversation = {
            'id': conversation_id,
            'title': title,
            'createdAt': timestamp,
            'updatedAt': timestamp,
            'messages': [],
            'metadata': data.get('metadata', {})
        }
        
        conversations[conversation_id] = {
            'id': conversation_id,
            'created_at': timestamp,
            'updated_at': timestamp,
            'messages': []
        }
        
        return jsonify(conversation), 201
        
    except Exception as e:
        logger.error(f"Error creating conversation: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/conversations/<conversation_id>', methods=['PUT'])
def update_conversation(conversation_id):
    """Update conversation title/metadata"""
    try:
        if conversation_id not in conversations:
            return jsonify({'error': 'Conversation not found'}), 404
            
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400
            
        # Update timestamp
        conversations[conversation_id]['updated_at'] = datetime.now().isoformat()
        
        # Return updated conversation info
        conv_data = conversations[conversation_id]
        last_message = conv_data['messages'][-1] if conv_data['messages'] else None
        
        updated_conversation = {
            'id': conversation_id,
            'title': data.get('title', f"Conversation {conversation_id[:8]}"),
            'createdAt': conv_data['created_at'],
            'updatedAt': conv_data['updated_at'],
            'messageCount': len(conv_data['messages']),
            'lastMessage': {
                'content': last_message['content'] if last_message else '',
                'timestamp': last_message['timestamp'] if last_message else conv_data['created_at']
            } if last_message else None,
            'metadata': data.get('metadata', {})
        }
        
        return jsonify(updated_conversation)
        
    except Exception as e:
        logger.error(f"Error updating conversation: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/conversations/<conversation_id>', methods=['DELETE'])
def delete_conversation(conversation_id):
    """Delete a conversation"""
    try:
        if conversation_id not in conversations:
            return jsonify({'error': 'Conversation not found'}), 404
            
        del conversations[conversation_id]
        return '', 204
        
    except Exception as e:
        logger.error(f"Error deleting conversation: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/voice/start', methods=['POST'])
def start_voice():
    """Start voice recording session"""
    global is_voice_active

    try:
        if is_voice_active:
            return jsonify({'error': 'Voice session already active'}), 400

        if not voice_assistant:
            return jsonify({'error': 'Voice assistant not available'}), 503

        # Start voice assistant in a separate thread
        def start_voice_thread():
            global is_voice_active
            try:
                is_voice_active = True
                voice_assistant.start()
            except Exception as e:
                logger.error(f"Error in voice assistant: {e}")
                is_voice_active = False

        voice_thread = threading.Thread(target=start_voice_thread, daemon=True)
        voice_thread.start()

        return jsonify({
            'status': 'voice_started',
            'message': 'Voice assistant is now listening'
        })

    except Exception as e:
        logger.error(f"Error starting voice: {e}")
        return jsonify({'error': 'Failed to start voice assistant'}), 500


@app.route('/api/v1/voice/stop', methods=['POST'])
def stop_voice():
    """Stop voice recording session"""
    global is_voice_active

    try:
        if not is_voice_active:
            return jsonify({'error': 'No voice session active'}), 400

        if voice_assistant:
            voice_assistant.stop()

        is_voice_active = False

        return jsonify({
            'status': 'voice_stopped',
            'message': 'Voice assistant stopped'
        })

    except Exception as e:
        logger.error(f"Error stopping voice: {e}")
        return jsonify({'error': 'Failed to stop voice assistant'}), 500


@app.route('/api/v1/voice/status', methods=['GET'])
def voice_status():
    """Get voice assistant status"""
    return jsonify({
        'is_active': is_voice_active,
        'is_listening': voice_assistant.is_listening if voice_assistant else False,
        'is_recording': voice_assistant.is_recording if voice_assistant else False,
        'is_processing': voice_assistant.is_processing if voice_assistant else False
    })


@app.route('/api/v1/voice/upload', methods=['POST'])
def upload_audio():
    """Process uploaded audio file and return transcription"""
    try:
        # Check if voice assistant is available
        if not voice_assistant or not voice_assistant.whisper_model:
            return jsonify({'error': 'Voice processing not available'}), 503
        
        # Handle different audio input formats
        audio_data = None
        audio_format = None
        
        # Check for JSON with base64 audio data
        if request.is_json:
            data = request.get_json()
            if 'audioData' in data:
                try:
                    audio_data = base64.b64decode(data['audioData'])
                    audio_format = data.get('format', 'wav')
                except Exception as e:
                    return jsonify({'error': f'Invalid base64 audio data: {e}'}), 400
        
        # Check for file upload
        elif 'audio' in request.files:
            file = request.files['audio']
            if file.filename == '':
                return jsonify({'error': 'No file selected'}), 400
            
            audio_data = file.read()
            audio_format = file.filename.split('.')[-1].lower() if '.' in file.filename else 'wav'
        
        else:
            return jsonify({'error': 'No audio data provided'}), 400
        
        if not audio_data:
            return jsonify({'error': 'Empty audio data'}), 400
        
        # Save audio to temporary file for processing
        with tempfile.NamedTemporaryFile(suffix=f'.{audio_format}', delete=False) as temp_file:
            temp_file.write(audio_data)
            temp_path = temp_file.name
        
        try:
            # Use Whisper to transcribe the audio
            import whisper
            import numpy as np
            
            # Load audio with whisper
            audio = whisper.load_audio(temp_path)
            
            # Transcribe using the voice assistant's whisper model
            result = voice_assistant.whisper_model.transcribe(audio, fp16=False)
            transcribed_text = result['text'].strip()
            
            # Get additional metadata
            confidence = result.get('confidence', 0.0)
            language = result.get('language', 'en')
            duration = len(audio) / 16000  # Assuming 16kHz sample rate
            
            # Clean up temp file
            os.unlink(temp_path)
            
            # Optionally process the text through the LLM if requested
            conversation_id = request.args.get('conversation_id')
            process_with_llm = request.args.get('process', 'false').lower() == 'true'
            
            response_data = {
                'transcription': transcribed_text,
                'confidence': confidence,
                'language': language,
                'duration': duration,
                'timestamp': datetime.now().isoformat(),
                'metadata': {
                    'audio_format': audio_format,
                    'audio_size': len(audio_data)
                }
            }
            
            if process_with_llm and transcribed_text:
                # Process through LLM like regular chat
                try:
                    # Create or use existing conversation
                    if not conversation_id:
                        conversation_id = str(uuid.uuid4())
                        conversations[conversation_id] = {
                            'id': conversation_id,
                            'created_at': datetime.now().isoformat(),
                            'messages': []
                        }
                    
                    # Add user message
                    user_message = {
                        'id': str(uuid.uuid4()),
                        'content': transcribed_text,
                        'is_user': True,
                        'timestamp': datetime.now().isoformat(),
                        'type': 'voice'
                    }
                    
                    if conversation_id not in conversations:
                        conversations[conversation_id] = {
                            'id': conversation_id,
                            'created_at': datetime.now().isoformat(),
                            'messages': []
                        }

                    conversations[conversation_id]['messages'].append(user_message)
                    
                    # Get LLM response
                    llm_response = LLMClient.get_response(transcribed_text)
                    
                    # Add bot response
                    bot_message = {
                        'id': str(uuid.uuid4()),
                        'content': llm_response,
                        'is_user': False,
                        'timestamp': datetime.now().isoformat()
                    }
                    
                    conversations[conversation_id]['messages'].append(bot_message)
                    
                    response_data.update({
                        'conversation_id': conversation_id,
                        'llm_response': llm_response,
                        'message_id': bot_message['id']
                    })
                    
                except Exception as e:
                    logger.error(f"Error processing with LLM: {e}")
                    response_data['llm_error'] = str(e)
            
            return jsonify(response_data)
            
        except Exception as e:
            # Clean up temp file on error
            if os.path.exists(temp_path):
                os.unlink(temp_path)
            raise e
            
    except Exception as e:
        logger.error(f"Error processing audio: {e}")
        return jsonify({
            'error': 'Failed to process audio',
            'details': str(e)
        }), 500


@app.route('/api/v1/voice/transcribe', methods=['POST'])
def transcribe_audio():
    """Transcribe audio without LLM processing"""
    # Set process parameter to false and call upload_audio
    request.args = request.args.copy()
    request.args['process'] = 'false'
    return upload_audio()


@app.route('/api/v1/chat/stream', methods=['POST'])
def chat_stream():
    """Handle streaming chat messages"""
    try:
        data = request.get_json()

        if not data or 'message' not in data:
            return jsonify({'error': 'Message is required'}), 400

        message = data['message'].strip()
        conversation_id = data.get('conversationId')

        if not message:
            return jsonify({'error': 'Message cannot be empty'}), 400

        # Create new conversation if not provided
        if not conversation_id:
            conversation_id = str(uuid.uuid4())
            conversations[conversation_id] = {
                'id': conversation_id,
                'created_at': datetime.now().isoformat(),
                'messages': []
            }

        # Add user message to conversation
        user_message = {
            'id': str(uuid.uuid4()),
            'content': message,
            'is_user': True,
            'timestamp': datetime.now().isoformat()
        }

        if conversation_id not in conversations:
            conversations[conversation_id] = {
                'id': conversation_id,
                'created_at': datetime.now().isoformat(),
                'messages': []
            }

        conversations[conversation_id]['messages'].append(user_message)

        # Create streaming response
        def generate_response():
            try:
                # Get LLM response
                response_text = LLMClient.get_response(message)
                
                # Create bot message
                bot_message = {
                    'id': str(uuid.uuid4()),
                    'content': response_text,
                    'is_user': False,
                    'timestamp': datetime.now().isoformat()
                }
                
                conversations[conversation_id]['messages'].append(bot_message)
                
                # For now, send the complete response (could be chunked in future)
                stream_response = {
                    'id': bot_message['id'],
                    'content': response_text,
                    'conversationId': conversation_id,
                    'isComplete': True,
                    'timestamp': bot_message['timestamp']
                }
                
                yield f"data: {json.dumps(stream_response)}\n\n"
                
            except Exception as e:
                error_response = {
                    'error': str(e),
                    'conversationId': conversation_id,
                    'isComplete': True,
                    'timestamp': datetime.now().isoformat()
                }
                yield f"data: {json.dumps(error_response)}\n\n"

        return Response(
            generate_response(),
            mimetype='text/event-stream',
            headers={
                'Cache-Control': 'no-cache',
                'Connection': 'keep-alive'
            }
        )

    except Exception as e:
        logger.error(f"Error in streaming chat endpoint: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/search/conversations', methods=['GET'])
def search_conversations():
    """Search conversations"""
    try:
        query = request.args.get('q', '').strip()
        if not query:
            return jsonify({'error': 'Query parameter q is required'}), 400
            
        results = []
        for conv_id, conv_data in conversations.items():
            # Simple text search in messages
            for message in conv_data['messages']:
                if query.lower() in message['content'].lower():
                    results.append({
                        'id': str(uuid.uuid4()),
                        'type': 'conversation',
                        'title': f"Conversation {conv_id[:8]}",
                        'content': message['content'][:200] + '...' if len(message['content']) > 200 else message['content'],
                        'conversationId': conv_id,
                        'timestamp': message['timestamp'],
                        'relevance': 1.0  # Simple relevance score
                    })
                    break  # Only include one result per conversation
        
        return jsonify(results)
        
    except Exception as e:
        logger.error(f"Error searching conversations: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/search/messages', methods=['GET'])
def search_messages():
    """Search messages"""
    try:
        query = request.args.get('q', '').strip()
        conversation_id = request.args.get('conversationId')
        
        if not query:
            return jsonify({'error': 'Query parameter q is required'}), 400
            
        results = []
        search_conversations = [conversation_id] if conversation_id else conversations.keys()
        
        for conv_id in search_conversations:
            if conv_id not in conversations:
                continue
                
            conv_data = conversations[conv_id]
            for message in conv_data['messages']:
                if query.lower() in message['content'].lower():
                    results.append({
                        'id': message['id'],
                        'type': 'message',
                        'title': f"Message from {conv_id[:8]}",
                        'content': message['content'],
                        'conversationId': conv_id,
                        'timestamp': message['timestamp'],
                        'relevance': 1.0
                    })
        
        return jsonify(results)
        
    except Exception as e:
        logger.error(f"Error searching messages: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/export/conversations/<conversation_id>', methods=['GET'])
def export_conversation(conversation_id):
    """Export a specific conversation"""
    try:
        if conversation_id not in conversations:
            return jsonify({'error': 'Conversation not found'}), 404
            
        format_type = request.args.get('format', 'json').lower()
        conv_data = conversations[conversation_id]
        
        if format_type == 'json':
            response_data = json.dumps(conv_data, indent=2)
            mimetype = 'application/json'
            filename = f'conversation_{conversation_id[:8]}.json'
        elif format_type == 'markdown':
            response_data = f"# Conversation {conversation_id[:8]}\n\n"
            response_data += f"Created: {conv_data['created_at']}\n\n"
            for message in conv_data['messages']:
                user_type = "**You**" if message['is_user'] else "**Assistant**"
                response_data += f"{user_type}: {message['content']}\n\n"
            mimetype = 'text/markdown'
            filename = f'conversation_{conversation_id[:8]}.md'
        elif format_type == 'text':
            response_data = f"Conversation {conversation_id[:8]}\n"
            response_data += f"Created: {conv_data['created_at']}\n\n"
            for message in conv_data['messages']:
                user_type = "You" if message['is_user'] else "Assistant"
                response_data += f"{user_type}: {message['content']}\n\n"
            mimetype = 'text/plain'
            filename = f'conversation_{conversation_id[:8]}.txt'
        else:
            return jsonify({'error': 'Unsupported format'}), 400
            
        return Response(
            response_data,
            mimetype=mimetype,
            headers={
                'Content-Disposition': f'attachment; filename="{filename}"'
            }
        )
        
    except Exception as e:
        logger.error(f"Error exporting conversation: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/export/conversations', methods=['GET'])
def export_all_conversations():
    """Export all conversations"""
    try:
        format_type = request.args.get('format', 'json').lower()
        
        if format_type == 'json':
            response_data = json.dumps(conversations, indent=2)
            mimetype = 'application/json'
            filename = 'all_conversations.json'
        elif format_type == 'markdown':
            response_data = "# All Conversations\n\n"
            for conv_id, conv_data in conversations.items():
                response_data += f"## Conversation {conv_id[:8]}\n"
                response_data += f"Created: {conv_data['created_at']}\n\n"
                for message in conv_data['messages']:
                    user_type = "**You**" if message['is_user'] else "**Assistant**"
                    response_data += f"{user_type}: {message['content']}\n\n"
                response_data += "---\n\n"
            mimetype = 'text/markdown'
            filename = 'all_conversations.md'
        elif format_type == 'text':
            response_data = "All Conversations\n\n"
            for conv_id, conv_data in conversations.items():
                response_data += f"Conversation {conv_id[:8]}\n"
                response_data += f"Created: {conv_data['created_at']}\n\n"
                for message in conv_data['messages']:
                    user_type = "You" if message['is_user'] else "Assistant"
                    response_data += f"{user_type}: {message['content']}\n\n"
                response_data += "---\n\n"
            mimetype = 'text/plain'
            filename = 'all_conversations.txt'
        else:
            return jsonify({'error': 'Unsupported format'}), 400
            
        return Response(
            response_data,
            mimetype=mimetype,
            headers={
                'Content-Disposition': f'attachment; filename="{filename}"'
            }
        )
        
    except Exception as e:
        logger.error(f"Error exporting all conversations: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/v1/models', methods=['GET'])
def get_models():
    """Get available models"""
    return jsonify({
        'models': [
            {
                'id': 'jarvis-llm',
                'name': 'Jarvis LLM',
                'description': 'Primary language model for Jarvis',
                'parameters': None,
                'isAvailable': llm_interface is not None,
                'downloadProgress': None
            },
            {
                'id': 'whisper-base',
                'name': 'Whisper Base',
                'description': 'Speech recognition model',
                'parameters': None,
                'isAvailable': voice_assistant and voice_assistant.whisper_model is not None,
                'downloadProgress': None
            }
        ]
    })


@app.route('/api/v1/config', methods=['GET'])
def get_config():
    """Get system configuration"""
    return jsonify({
        'version': '1.0.0',
        'features': {
            'voice_processing': voice_assistant is not None,
            'llm_processing': llm_interface is not None,
            'websocket_support': True,
            'streaming_chat': True,
            'conversation_export': True,
            'search': True
        },
        'audio_config': {
            'supported_formats': ['wav', 'mp3', 'flac', 'pcm'],
            'max_file_size': 50 * 1024 * 1024,  # 50MB
            'sample_rates': [16000, 44100, 48000]
        }
    })

# WebSocket events for real-time communication


@socketio.on('connect')
def handle_connect():
    logger.info('Client connected to WebSocket')
    emit('status', {'message': 'Connected to Jarvis API'})


@socketio.on('disconnect')
def handle_disconnect():
    logger.info('Client disconnected from WebSocket')


@socketio.on('voice_activity')
def handle_voice_activity(data):
    """Handle voice activity updates from client"""
    emit('voice_activity_update', data, broadcast=True)


@socketio.on('wake_word_detected')
def handle_wake_word():
    """Handle wake word detection"""
    emit('wake_word_triggered', {
         'timestamp': datetime.now().isoformat()}, broadcast=True)

# Error handlers


@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500


@app.errorhandler(Exception)
def handle_exception(e):
    logger.error(f"Unhandled exception: {e}")
    return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    # Initialize backend components
    if not initialize_backend():
        logger.error("Failed to initialize backend. Exiting.")
        sys.exit(1)

    # Run the Flask app
    logger.info("Starting Jarvis API server...")
    logger.info("API will be available at: http://localhost:5000")
    logger.info("WebSocket will be available at: ws://localhost:5000")

    # Run with socketio for WebSocket support
    socketio.run(
        app,
        host='0.0.0.0',
        port=5000,
        debug=True,
        allow_unsafe_werkzeug=True
    )
