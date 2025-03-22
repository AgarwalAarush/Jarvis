import os
import time
import nltk
import numpy as np
import torch
import warnings
import hashlib
from pathlib import Path
import json
import io
import soundfile as sf
from scipy.io import wavfile

# Custom XTTS service implementation
class XTTSService:
    """
    Enhanced TTS service using XTTS model with caching and performance improvements.
    This implementation provides a drop-in replacement for the OptimizedTTSService.
    """
    
    def __init__(self, device: str = "cuda" if torch.cuda.is_available() else "cpu",
                 cache_dir: str = "./tts_cache"):
        """
        Initializes the XTTS service.
        
        Args:
            device: "cuda" or "cpu"
            cache_dir: Directory to store cached audio samples
        """
        self.device = device
        print(f"Initializing XTTS on {device}...")
        
        try:
            # Try to load TTS - this is a placeholder that should be replaced with
            # proper TTS library imports based on installation
            import torch
            from TTS.api import TTS
            self.tts_lib_available = True
            # Initialize the TTS model - replace with appropriate model
            self.tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(self.device)
            
            print("Successfully loaded XTTS model")
        except ImportError:
            self.tts_lib_available = False
            print("WARNING: TTS library not available. Using fallback synthesizer.")
            # If TTS is not available, we'll use a very basic synthesizer that
            # just generates a beep sound as a placeholder
        
        # Set up cache
        self.cache_dir = cache_dir
        if self.cache_dir:
            os.makedirs(self.cache_dir, exist_ok=True)
            self.cache_index_path = Path(self.cache_dir) / "xtts_cache_index.json"
            self.load_cache_index()
        
        # Voice presets (these are just identifiers for the cache since XTTS handles voices differently)
        self.voice_presets = {
            "male": "male_speaker",
            "female": "female_speaker",
            "female2": "female_speaker2",
            "male2": "male_speaker2"
        }
        
        # Sample rate for our audio
        self.sample_rate = 24000  # XTTS typically uses 24kHz
        
        print(f"Initialized XTTSService with cache at: {cache_dir}")
    
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
            cache_path = Path(self.cache_dir) / f"{cache_key}.npy"
            if os.path.exists(cache_path):
                try:
                    return np.load(cache_path), self.sample_rate
                except Exception as e:
                    print(f"Error loading cached audio: {e}")
        
        return None
    
    def cache_audio(self, text, voice_preset, audio_array):
        """Cache the generated audio."""
        if not self.cache_dir:
            return
        
        cache_key = self.get_cache_key(text, voice_preset)
        self.cache_index[cache_key] = True
        cache_path = Path(self.cache_dir) / f"{cache_key}.npy"
        np.save(cache_path, audio_array)
        self.save_cache_index()
        print(f"Cached audio for '{text[:20]}...' as {cache_key}")
    
    def fallback_synthesize(self, text):
        """A basic fallback synthesizer that just generates a simple beep sound."""
        print(f"Using fallback synthesizer for: '{text}'")
        # Generate a simple tone as a placeholder
        duration = 0.5 + len(text) * 0.03  # Scale duration with text length
        t = np.linspace(0, duration, int(self.sample_rate * duration), False)
        note = 0.5 * np.sin(2 * np.pi * 440 * t) * np.exp(-t)
        return self.sample_rate, note
    
    def synthesize(self, text: str, voice_preset: str = None):
        """
        Synthesize speech from text, leveraging caching for speed.
        
        Args:
            text: Text to synthesize
            voice_preset: Voice to use, or None for default
        
        Returns:
            tuple: (sample_rate, audio_array)
        """
        # Use default voice if none specified
        if voice_preset is None:
            voice_preset = self.voice_presets["female"]
        elif voice_preset in self.voice_presets:
            voice_preset = self.voice_presets[voice_preset]
        
        start_time = time.time()
        
        # Check cache first
        cached_result = self.get_cached_audio(text, voice_preset)
        if cached_result is not None:
            print(f"Cache hit! Retrieved cached audio for: '{text[:30]}...'")
            print(f"Retrieved in {time.time() - start_time:.3f}s")
            return cached_result[1], cached_result[0]
        
        print(f"Synthesizing new audio for: '{text}'")
        gen_start_time = time.time()
        
        # Generate speech using XTTS or fallback
        if self.tts_lib_available:
            try:
                # Use appropriate voice for the preset
                if "female" in voice_preset:
                    speaker = "female"  # Use a female reference speaker
                else:
                    speaker = "male"    # Use a male reference speaker
                
                # Get audio from XTTS
                with torch.no_grad():
                    # Convert to waveform with appropriate options
                    wav = self.tts.tts(text=text, speaker=speaker, language="en")
                
                # XTTS returns the waveform directly
                audio_array = np.array(wav)
                
                # Normalize audio to float32 between -1 and 1 if needed
                if audio_array.dtype != np.float32:
                    audio_array = audio_array.astype(np.float32)
                if audio_array.max() > 1.0:
                    audio_array = audio_array / max(abs(audio_array.max()), abs(audio_array.min()))
                
            except Exception as e:
                print(f"Error in XTTS synthesis: {e}")
                return self.fallback_synthesize(text)
        else:
            return self.fallback_synthesize(text)
        
        # Cache the result
        self.cache_audio(text, voice_preset, audio_array)
        
        gen_time = time.time() - gen_start_time
        print(f"Synthesis completed in {gen_time:.3f}s - {len(text)/gen_time:.1f} chars/sec")
        
        return self.sample_rate, audio_array
    
    def long_form_synthesize(self, text: str, voice_preset: str = None):
        """
        Synthesize speech from long-form text, breaking it into sentences.
        
        Args:
            text: Long-form text to synthesize
            voice_preset: Voice to use, or None for default
        
        Returns:
            tuple: (sample_rate, audio_array)
        """
        start_time = time.time()
        
        # Break text into sentences
        sentences = nltk.sent_tokenize(text)
        print(f"Breaking text into {len(sentences)} sentences for synthesis")
        
        # Add silence between sentences
        pieces = []
        silence = np.zeros(int(0.25 * self.sample_rate))
        
        total_chars = sum(len(s) for s in sentences)
        processed_chars = 0
        
        for i, sent in enumerate(sentences):
            # Update progress
            processed_chars += len(sent)
            progress = processed_chars / total_chars * 100
            
            print(f"Synthesizing sentence {i+1}/{len(sentences)} ({progress:.1f}% complete)")
            sample_rate, audio_array = self.synthesize(sent, voice_preset)
            pieces += [audio_array, silence.copy()]
        
        total_time = time.time() - start_time
        print(f"Total synthesis time: {total_time:.2f}s")
        print(f"Characters per second: {total_chars/total_time:.1f}")
        
        return self.sample_rate, np.concatenate(pieces)

# Test the XTTSService
if __name__ == "__main__":
    try:
        print("Testing XTTSService...")
        tts = XTTSService()
        
        print("\nTesting sentence synthesis...")
        sample_rate, audio = tts.synthesize("This is a test of the new XTTS service.")
        
        # Print stats
        audio_length = len(audio) / sample_rate
        print(f"Audio length: {audio_length:.2f} seconds")
        
        print("\nTesting multi-sentence synthesis...")
        sample_rate, audio = tts.long_form_synthesize(
            "This is the first sentence. This is the second sentence. And here's a third one."
        )
        
        # Print stats
        audio_length = len(audio) / sample_rate
        print(f"Audio length: {audio_length:.2f} seconds")
        
        print("Test completed successfully!")
        
    except Exception as e:
        print(f"Error in test: {e}")
