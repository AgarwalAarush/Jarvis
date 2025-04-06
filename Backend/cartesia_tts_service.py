import os
import time
import hashlib
from pathlib import Path
import json
import requests
import threading
import queue
import nltk
from typing import List, Tuple, Optional, Dict, Any, Callable

try:
    nltk.data.find('tokenizers/punkt')
except LookupError:
    nltk.download('punkt', quiet=True)

voices = {
    "Joan": "5abd2130-146a-41b1-bcdb-974ea8e19f56",
    "DEFAULT": "f9836c6e-a0bd-460e-9d3c-f7299fa60f94"
}

class CartesiaTTSService:
    """
    A TTS service that uses Cartesia API with the sonic-2 model and "Joan" voice.
    """
    
    def __init__(self, cache_dir="./tts_cache", api_key=None):
        """
        Initializes the TTS service with Cartesia API.
        
        Args:
            cache_dir: Directory to store cached audio samples
            api_key: Cartesia API key (if None, will look for CARTESIA_API_KEY environment variable)
        """
        print("Initializing CartesiaTTSService...")
        
        from dotenv import load_dotenv
        load_dotenv()

        # Get API key
        self.api_key = api_key or os.environ.get("CARTESIA_API_KEY")
        if not self.api_key:
            print("Warning: No Cartesia API key provided. Please set the CARTESIA_API_KEY environment variable or pass api_key parameter.")
        
        # Set Cartesia API parameters
        self.model = "sonic-2"
        self.voice = "Joan"
        self.api_base_url = "https://api.cartesia.ai/v1"
        
        # Set default sample rate
        self.sample_rate = 24000  # Default sample rate
        
        # Set up cache
        self.cache_dir = cache_dir
        if self.cache_dir:
            os.makedirs(self.cache_dir, exist_ok=True)
            self.cache_index_path = Path(self.cache_dir) / "cartesia_tts_cache_index.json"
            self.load_cache_index()
        
        # Default voice parameters
        self.speaking_rate = 1.0
        self.pitch_shift = 0.0
        self.energy = 0.0
        
        # Threading resources
        self.audio_queue = None
        self.playback_thread = None
        self.stop_playback = None
        self.successful_segments = 0  # Track successful segments
        self.total_expected_segments = 0  # Total expected segments
        self.on_progress_callback = None
        
        print(f"CartesiaTTSService initialization complete.")
    
    def set_speech_parameters(self, speaking_rate=1.0, pitch_shift=0.0, energy=0.0):
        """
        Adjust speech parameters for more natural sound.

        Args:
            speaking_rate: Value between 0.25-4.0, where 1.0 is normal speed
            pitch_shift: Value between -20.0 and 20.0 to shift pitch
            energy: Value between -96.0 and 16.0 dB for volume gain
        """
        self.speaking_rate = speaking_rate
        self.pitch_shift = pitch_shift
        self.energy = energy
        
        print("---------- SETTING SPEECH PARAMETERS -----------")
        print(f"Speaking rate: {speaking_rate}, Pitch shift: {pitch_shift}, Volume gain: {energy} dB")
        print("---------- SPEECH PARAMETERS SET -----------")
    
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
    
    def get_cache_key(self, text):
        """Generate a unique cache key for the text and voice parameters."""
        key_string = f"{text}_{self.model}_{self.voice}_{self.speaking_rate}_{self.pitch_shift}_{self.energy}"
        return hashlib.md5(key_string.encode()).hexdigest()
    
    def get_cached_audio(self, text):
        """Get cached audio if available."""
        if not self.cache_dir:
            return None
        
        cache_key = self.get_cache_key(text)
        if cache_key in self.cache_index:
            cache_path = Path(self.cache_dir) / f"{cache_key}.mp3"
            if os.path.exists(cache_path):
                return self.sample_rate, str(cache_path)
        
        return None
    
    def cache_audio(self, text, audio_path):
        """Cache the generated audio."""
        if not self.cache_dir:
            return
        
        cache_key = self.get_cache_key(text)
        self.cache_index[cache_key] = True
        
        # We already have the audio file at audio_path, just update the index
        self.save_cache_index()
        
        return cache_key
    
    def create_fallback_audio(self, message="Text-to-speech failed. Using fallback audio."):
        """Create a fallback audio file with a simple message.
        
        Args:
            message: Message to include in the filename
            
        Returns:
            tuple: (sample_rate, audio_file_path)
        """
        # Create a simple audio file - this will be a silent audio file
        safe_message = "".join(c for c in message if c.isalnum() or c in " ._-")
        output_file = Path(self.cache_dir) / f"fallback_{int(time.time())}_{safe_message}.mp3"
        
        try:
            import ffmpeg
            # Generate a simple tone
            (
                ffmpeg
                .input('anullsrc', f='lavfi', t=0.5)  # 0.5 seconds of silence
                .output(str(output_file), ar=self.sample_rate, ac=1)
                .run(quiet=True, overwrite_output=True)
            )
            print(f"Created fallback audio: {output_file}")
            return self.sample_rate, str(output_file)
        except Exception as e:
            print(f"Error creating fallback audio: {e}")
            # Create an empty file as last resort
            with open(output_file, 'wb') as f:
                f.write(b'')
            return self.sample_rate, str(output_file)
    
    def synthesize(self, text, retry_count=2):
        """
        Synthesize speech from text using Cartesia API.
        
        Args:
            text: Text to synthesize
            retry_count: Number of times to retry if synthesis fails
        
        Returns:
            tuple: (sample_rate, audio_file_path)
        """
        if not text or text.strip() == "":
            # Return a simple empty audio file
            empty_file = Path(self.cache_dir) / f"empty_{int(time.time())}.mp3"
            with open(empty_file, "wb") as f:
                f.write(b"")
            return self.sample_rate, str(empty_file)
        
        if not self.api_key:
            print("Error: Cartesia API key not set. Please set CARTESIA_API_KEY environment variable or pass api_key parameter.")
            return self.create_fallback_audio("Cartesia API key not set")
                
        start_time = time.time()
        
        # Check cache first
        cached_result = self.get_cached_audio(text)
        if cached_result is not None:
            print(f"Cache hit! Retrieved cached audio for: '{text[:30]}...'")
            print(f"Retrieved in {time.time() - start_time:.3f}s")
            return cached_result
        
        print(f"Synthesizing new audio for: '{text}'")
        
        # Generate a unique filename
        timestamp = int(time.time())
        output_filename = f"cartesia_{timestamp}_{self.get_cache_key(text)[:10]}.mp3"
        output_path = Path(self.cache_dir) / output_filename
        
        # Define the API request data
        payload = {
            "model": self.model,
            "voice": self.voice,
            "input": text,
            "speed": self.speaking_rate,
            "pitch": self.pitch_shift / 10.0,  # Scale pitch to Cartesia's range
            "energy": self.energy / 16.0 + 1.0  # Scale energy to Cartesia's range (assuming 0-1 with 1 being normal)
        }
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        # Make the API request
        for attempt in range(retry_count):
            try:
                response = requests.post(
                    f"{self.api_base_url}/tts", 
                    json=payload,
                    headers=headers
                )
                
                # Check for successful response
                if response.status_code == 200:
                    with open(output_path, "wb") as f:
                        f.write(response.content)
                    
                    # Cache the result
                    self.cache_audio(text, str(output_path))
                    
                    print(f"Synthesis completed in {time.time() - start_time:.3f}s")
                    print(f"Audio saved to {output_path}")
                    
                    return self.sample_rate, str(output_path)
                else:
                    print(f"API Error (attempt {attempt+1}/{retry_count}): {response.status_code} - {response.text}")
                    if attempt == retry_count - 1:  # Last attempt
                        error_message = f"Failed to synthesize speech. Status code: {response.status_code}"
                        print(error_message)
                        return self.create_fallback_audio(error_message)
            
            except Exception as e:
                print(f"Exception (attempt {attempt+1}/{retry_count}): {e}")
                if attempt == retry_count - 1:  # Last attempt
                    error_message = f"Exception during speech synthesis: {str(e)}"
                    print(error_message)
                    return self.create_fallback_audio(error_message)
                time.sleep(1)  # Wait a bit before retrying
        
        # This should not be reached due to the returns in the loops above
        return self.create_fallback_audio("Failed to synthesize speech after retries")
    
    def synthesize_long_text(self, text, on_progress_callback=None):
        """
        Synthesize longer text by breaking it into sentences and synthesizing each one.
        
        Args:
            text: The long text to synthesize
            on_progress_callback: Optional callback to report progress
            
        Returns:
            tuple: (sample_rate, list of audio file paths)
        """
        if not text or text.strip() == "":
            return self.sample_rate, []
        
        # Set callback
        self.on_progress_callback = on_progress_callback
        
        # Split text into sentences
        sentences = nltk.sent_tokenize(text)
        audio_files = []
        
        print(f"Breaking text into {len(sentences)} sentences")
        self.total_expected_segments = len(sentences)
        self.successful_segments = 0
        
        # Synthesize each sentence
        for i, sentence in enumerate(sentences):
            if not sentence.strip():
                continue
                
            print(f"Synthesizing sentence {i+1}/{len(sentences)}: '{sentence[:30]}...'")
            
            sample_rate, audio_path = self.synthesize(sentence)
            if audio_path:
                audio_files.append(audio_path)
                self.successful_segments += 1
                
                # Report progress
                if self.on_progress_callback:
                    is_complete = (i == len(sentences) - 1)
                    self.on_progress_callback(i+1, len(sentences), is_complete)
        
        if not audio_files:
            empty_file = Path(self.cache_dir) / f"empty_{int(time.time())}.mp3"
            with open(empty_file, "wb") as f:
                f.write(b"")
            return self.sample_rate, [str(empty_file)]
            
        return self.sample_rate, audio_files

    def text_to_speech(self, text):
        """
        Main TTS interface function - converts text to speech.
        If text is short, uses direct synthesis, otherwise splits into sentences.
        
        Args:
            text: Text to convert to speech
            
        Returns:
            tuple: (sample_rate, audio_path_or_paths)
        """
        # For longer text, use the sentence-by-sentence approach
        if len(text) > 100:
            return self.synthesize_long_text(text, on_progress_callback=None)
        else:
            sample_rate, audio_path = self.synthesize(text)
            return sample_rate, [audio_path] if audio_path else []
