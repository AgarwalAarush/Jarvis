#!/usr/bin/env python3
"""
Simple API Server for testing Jarvis connectivity
This is a minimal Flask server that provides the basic API endpoints
without requiring heavy dependencies like Ollama or LangChain.
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import uuid
from datetime import datetime
import socket

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Simple in-memory storage
conversations = {}

@app.route('/api/v1/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0-simple',
        'message': 'Simple API server is running'
    })

@app.route('/api/v1/status', methods=['GET'])
def get_status():
    """Get system status"""
    return jsonify({
        'status': 'ready',
        'server_type': 'simple',
        'conversations_count': len(conversations),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/v1/chat', methods=['POST'])
def chat():
    """Handle text chat messages with simple echo response"""
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

        # Simple echo response with some variations
        if 'hello' in message.lower():
            response_text = "Hello! I'm a simple test backend. The API connectivity is working!"
        elif 'test' in message.lower():
            response_text = "Test successful! The Swift app can communicate with the Python backend."
        elif 'how are you' in message.lower():
            response_text = "I'm a simple backend running Flask. All systems are operational!"
        else:
            response_text = f"I received your message: '{message}'. This is a simple echo response from the test backend."

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
            'model': 'simple-echo',
            'metadata': {'server_type': 'simple'}
        })

    except Exception as e:
        print(f"Error in chat endpoint: {e}")
        return jsonify({'error': 'Internal server error', 'details': str(e)}), 500

@app.route('/api/v1/conversations', methods=['GET'])
def list_conversations():
    """List all conversations"""
    try:
        conversation_list = []
        for conv_id, conv_data in conversations.items():
            last_message = conv_data['messages'][-1] if conv_data['messages'] else None
            conversation_list.append({
                'id': conv_id,
                'title': f"Test Chat {conv_id[:8]}",
                'createdAt': conv_data['created_at'],
                'updatedAt': conv_data.get('updated_at', conv_data['created_at']),
                'messageCount': len(conv_data['messages']),
                'lastMessage': {
                    'content': last_message['content'][:100] + '...' if last_message and len(last_message['content']) > 100 else last_message['content'] if last_message else '',
                    'timestamp': last_message['timestamp'] if last_message else conv_data['created_at']
                } if last_message else None
            })
        
        return jsonify({
            'conversations': conversation_list,
            'totalCount': len(conversation_list),
            'hasMore': False
        })

    except Exception as e:
        print(f"Error listing conversations: {e}")
        return jsonify({'error': 'Internal server error'}), 500

def find_available_port(start_port=5001):
    """Find an available port starting from start_port"""
    for port in range(start_port, start_port + 10):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('localhost', port))
                return port
        except OSError:
            continue
    return None

if __name__ == '__main__':
    # Find an available port (avoiding 5000 which is used by AirPlay)
    port = find_available_port(5001)
    if port is None:
        print("❌ Could not find an available port")
        exit(1)
    
    print("🚀 Starting Simple Jarvis API Server...")
    print("=" * 50)
    print(f"🌐 API available at: http://localhost:{port}")
    print(f"🔍 Health check: http://localhost:{port}/api/v1/health")
    print(f"💬 Chat endpoint: http://localhost:{port}/api/v1/chat")
    print("=" * 50)
    
    app.run(
        host='0.0.0.0',
        port=port,
        debug=True
    )