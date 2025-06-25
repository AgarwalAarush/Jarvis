from context import ContextManager
from llm_interface import LLMInterface
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
            # Use the LLM interface to get response
            response_text = llm_interface.get_response(message)

            # Add bot response to conversation
            bot_message = {
                'id': str(uuid.uuid4()),
                'content': response_text,
                'is_user': False,
                'timestamp': datetime.now().isoformat()
            }

            conversations[conversation_id]['messages'].append(bot_message)

            return jsonify({
                'conversation_id': conversation_id,
                'response': response_text,
                'message_id': bot_message['id'],
                'timestamp': bot_message['timestamp']
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
            conversation_list.append({
                'id': conv_id,
                'created_at': conv_data['created_at'],
                'message_count': len(conv_data['messages']),
                'last_message': conv_data['messages'][-1]['content'][:100] + '...' if conv_data['messages'] else ''
            })

        # Sort by creation date (newest first)
        conversation_list.sort(key=lambda x: x['created_at'], reverse=True)

        return jsonify(conversation_list)

    except Exception as e:
        logger.error(f"Error listing conversations: {e}")
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
