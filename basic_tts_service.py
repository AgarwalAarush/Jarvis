import os
import time
import array
import math
import hashlib
from pathlib import Path
import json
import wave
import struct

class BasicTTSService:
    """
    A basic TTS service that works with Python's standard library only.
    This provides the same interface as OptimizedTTSService but can work
    without any external dependencies.
    """
    
    def __init__(self, device: str = "cpu", cache_dir: str = "./tts_cache"):
        """
        Initializes a basic TTS service.
        
        Args:
            device: "cuda" or "cpu" (ignored in basic version)
            cache_dir: Directory to store cached audio samples
        """
        print(f"Initializing BasicTTSService...")
        
        # Set up cache
        self.cache_dir = cache_dir
        if self.cache_dir:
            os.makedirs(self.cache_dir, exist_ok=True)
            self.cache_index_path = Path(self.cache_dir) / "basic_tts_cache_index.json"
            self.load_cache_index()
        
        # Voice presets (identifiers for the cache)
        self.voice_presets = {
            "male": "male_speaker",
            "female": "female_speaker",
            "female2": "female_speaker2",
            "male2": "male_speaker2"
        }
        
        # Sample rate for our audio
        self.sample_rate = 24000  # Standard sample rate
        
        print(f"Initialized BasicTTSService with cache at: {cache_dir}")
    
    def load_cache_index(self):
        """Load the cache index from disk or create a new one."""
        if self.cache_dir and os.path.exists(self.cache_index_path):
            try:
                with open(self.cache_index_path, 'r') as f:
                    self.cache_index = json.load(f)
            except:
                print(f"Error loading cache index, creating new one")
                self.cache_index = {}
        else:
            self.cache_index = {}
    
    def save_cache_index(self):
        """Save the cache index to disk."""
        if self.cache_dir:
            with open(self.cache_index_path, 'w') as f:
                json.dump(self.cache_index, f)
    
    def get_cache_key(self, text, voice_preset):
        """Generate a unique cache key for the text and voice preset."""
        # Create a hash-based key for the cache
        key_string = f"{text}_{voice_preset}"
        return hashlib.md5(key_string.encode()).hexdigest()
    
    def get_cached_audio(self, text, voice_preset):
        """Get cached audio if available."""
        if not self.cache_dir:
            return None
        
        cache_key = self.get_cache_key(text, voice_preset)
        if cache_key in self.cache_index:
            cache_path = Path(self.cache_dir) / f"{cache_key}.wav"
            if os.path.exists(cache_path):
                try:
                    # Load WAV file
                    with wave.open(str(cache_path), 'rb') as wf:
                        sample_rate = wf.getframerate()
                        n_frames = wf.getnframes()
                        # Read frames and convert to array
                        frames =