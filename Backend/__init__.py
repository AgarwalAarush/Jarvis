"""
Jarvis Backend Module

A comprehensive voice assistant backend system with AI-powered capabilities including:
- Voice recognition and wake word detection
- Text-to-speech synthesis
- System automation (volume, brightness, apps)
- Web search and information retrieval
- Context and memory management
- LLM integration

Main Components:
- VoiceAssistant: Core voice assistant with wake word detection and speech processing
- SystemAutomationClient: System control and automation
- LLMInterface: LLM interaction utilities
- SearchInterface: Web search and information retrieval
- ContextClient: Real-time context and memory management
- CartesiaTTS: Text-to-speech service
"""

__version__ = "1.0.0"
__author__ = "Jarvis Team"
__description__ = "AI-powered voice assistant backend system"

# Main exports for easy access
__all__ = [
    # Core classes
    "VoiceAssistant",
    "SystemAutomationClient",
    "LLMInterface",
    "LLMClient",

    # Context and memory
    "ContextClient",
    "MemoryClient",
    "DateTimeClient",

    # Search and TTS
    "SearchInterface",
    "CartesiaTTS",
    "GoogleCloudTTSService",

    # Utilities
    "FileSystem",
    "Model",
    "VoiceActivityDetector",

    # Version info
    "__version__",
    "__author__",
    "__description__"
]

# Lazy imports to avoid dependency issues


def _import_voice_assistant():
    """Lazy import for VoiceAssistant"""
    from .jarvis import VoiceAssistant
    return VoiceAssistant


def _import_system_automation():
    """Lazy import for SystemAutomationClient"""
    from .automation import SystemAutomationClient
    return SystemAutomationClient


def _import_llm_interface():
    """Lazy import for LLMInterface"""
    from .llm_interface import LLMInterface
    return LLMInterface


def _import_llm_client():
    """Lazy import for LLMClient"""
    from .llm_client import LLMClient
    return LLMClient


def _import_context():
    """Lazy import for context classes"""
    from .context import ContextClient, MemoryClient, DateTimeClient
    return ContextClient, MemoryClient, DateTimeClient


def _import_search():
    """Lazy import for SearchInterface"""
    from .search.search import SearchInterface
    return SearchInterface


def _import_tts():
    """Lazy import for TTS classes"""
    from .cartesia_tts import CartesiaTTS
    from .google_cloud_tts_service import GoogleCloudTTSService
    return CartesiaTTS, GoogleCloudTTSService


def _import_file_system():
    """Lazy import for FileSystem"""
    from .file_interaction import FileSystem
    return FileSystem


def _import_wake_word():
    """Lazy import for wake word classes"""
    from .wake_word.model import Model
    from .wake_word.vad import VoiceActivityDetector
    return Model, VoiceActivityDetector

# Convenience function to create a fully configured voice assistant


def create_voice_assistant(config=None):
    """
    Create and configure a VoiceAssistant instance with default settings.

    Args:
        config (dict, optional): Configuration dictionary for system automation

    Returns:
        VoiceAssistant: Configured voice assistant instance
    """
    if config is None:
        config = {}

    VoiceAssistant = _import_voice_assistant()
    return VoiceAssistant()

# Quick start function


def quick_start():
    """
    Quick start function to create and start a voice assistant.

    Returns:
        VoiceAssistant: Started voice assistant instance
    """
    assistant = create_voice_assistant()
    try:
        assistant.start()
        return assistant
    except KeyboardInterrupt:
        print("\nShutting down voice assistant...")
        assistant.stop()
        return assistant

# Lazy property accessors


class _LazyLoader:
    """Lazy loader for module components"""

    @property
    def VoiceAssistant(self):
        return _import_voice_assistant()

    @property
    def SystemAutomationClient(self):
        return _import_system_automation()

    @property
    def LLMInterface(self):
        return _import_llm_interface()

    @property
    def LLMClient(self):
        return _import_llm_client()

    @property
    def ContextClient(self):
        return _import_context()[0]

    @property
    def MemoryClient(self):
        return _import_context()[1]

    @property
    def DateTimeClient(self):
        return _import_context()[2]

    @property
    def SearchInterface(self):
        return _import_search()

    @property
    def CartesiaTTS(self):
        return _import_tts()[0]

    @property
    def GoogleCloudTTSService(self):
        return _import_tts()[1]

    @property
    def FileSystem(self):
        return _import_file_system()

    @property
    def Model(self):
        return _import_wake_word()[0]

    @property
    def VoiceActivityDetector(self):
        return _import_wake_word()[1]


# Create lazy loader instance
_lazy_loader = _LazyLoader()

# Expose lazy properties


def __getattr__(name):
    """Handle lazy attribute access"""
    if name in __all__:
        return getattr(_lazy_loader, name)
    raise AttributeError(f"module '{__name__}' has no attribute '{name}'")
