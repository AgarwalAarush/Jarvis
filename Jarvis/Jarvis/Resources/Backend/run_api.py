#!/usr/bin/env python3
"""
Jarvis API Server Runner

This script starts the Flask API server for the Jarvis voice assistant.
It handles environment setup and provides a simple way to start the server.
"""

import os
import sys
import subprocess
from pathlib import Path


def check_dependencies():
    """Check if required dependencies are installed"""
    try:
        import flask
        import flask_cors
        import flask_socketio
        print("✅ All Flask dependencies are installed")
        return True
    except ImportError as e:
        print(f"❌ Missing dependency: {e}")
        print("Please install dependencies with: pip install -r requirements.txt")
        return False


def check_environment():
    """Check if environment variables are set up"""
    env_file = Path(__file__).parent / ".env"

    if not env_file.exists():
        print("⚠️  No .env file found. Creating template...")
        create_env_template(env_file)
        print("Please edit .env file with your configuration")
        return False

    print("✅ Environment file found")
    return True


def create_env_template(env_file):
    """Create a template .env file"""
    template = """# Jarvis API Configuration

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
"""

    with open(env_file, 'w') as f:
        f.write(template)


def main():
    """Main function to start the API server"""
    print("🚀 Starting Jarvis API Server...")
    print("=" * 50)

    # Check dependencies
    if not check_dependencies():
        sys.exit(1)

    # Check environment
    check_environment()

    # Change to the backend directory
    backend_dir = Path(__file__).parent
    os.chdir(backend_dir)

    print(f"📁 Working directory: {backend_dir}")
    print("🌐 API will be available at: http://localhost:5000")
    print("🔌 WebSocket will be available at: ws://localhost:5000")
    print("=" * 50)

    try:
        # Import and run the API server
        from api_server import app, socketio, initialize_backend

        # Initialize backend components
        if not initialize_backend():
            print("❌ Failed to initialize backend components")
            sys.exit(1)

        print("✅ Backend components initialized successfully")
        print("🎯 Starting Flask server...")

        # Run the server
        socketio.run(
            app,
            host='0.0.0.0',
            port=5000,
            debug=True,
            allow_unsafe_werkzeug=True
        )

    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
    except Exception as e:
        print(f"❌ Error starting server: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
