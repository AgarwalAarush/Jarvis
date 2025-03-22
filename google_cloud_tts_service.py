import os
import time
import hashlib
from pathlib import Path
import json
import numpy as np
import ffmpeg
import nltk

try:
    nltk.data.find('tokenizers/punkt')
except LookupError:
    nltk.download('punkt', quiet=True)

from google.cloud import texttospeech

class GoogleCloudTTSService:
    """
    A TTS service that uses Google Cloud Text-to-Speech API.
    """
    
    def __init__(self, cache_dir="./tts_cache"):
        """
        Initializes the TTS service with Google Cloud TTS.
        
        Args:
            cache_dir: Directory to store cached audio samples
        """
        print("Initializing GoogleCloudTTSService...")
        
        # Initialize the Text-to-Speech client
        self.tts_client = texttospeech.TextToSpeechClient()
        print("Successfully initialized Google Cloud TTS client")
        
        # Set default sample rate
        self.sample_rate = 24000  # Default sample rate for Google Cloud TTS
        
        # Set up cache
        self.cache_dir = cache_dir
        if self.cache_dir:
            os.makedirs(self.cache_dir, exist_ok=True)
            self.cache_index_path = Path(self.cache_dir) / "google_tts_cache_index.json"
            self.load_cache_index()
        
        # Voice presets mapping to Google Cloud voices
        self.voice_presets = {
            "male": "en-US-Neural2-J",       # Male voice
            "female": "en-US-Chirp3-HD-Aoede", # Neural voice - female (premium)
            "female2": "en-US-Studio-O",     # Studio voice - female
            "male2": "en-US-Wavenet-H"       # Wavenet voice - male
        }
        
        # Default voice parameters
        self.speaking_rate = 1.0
        self.pitch_shift = 0.0
        self.energy = 0.0
        
        print(f"GoogleCloudTTSService initialization complete.")
    
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
    
    def get_cache_key(self, text, voice_preset):
        """Generate a unique cache key for the text and voice preset."""
        voice_name = self.voice_presets.get(voice_preset, self.voice_presets["female"])
        key_string = f"{text}_{voice_name}_{self.speaking_rate}_{self.pitch_shift}_{self.energy}"
        return hashlib.md5(key_string.encode()).hexdigest()
    
    def get_cached_audio(self, text, voice_preset):
        """Get cached audio if available."""
        if not self.cache_dir:
            return None
        
        cache_key = self.get_cache_key(text, voice_preset)
        if cache_key in self.cache_index:
            cache_path = Path(self.cache_dir) / f"{cache_key}.mp3"
            if os.path.exists(cache_path):
                return self.sample_rate, str(cache_path)
        
        return None
    
    def cache_audio(self, text, voice_preset, audio_path):
        """Cache the generated audio."""
        if not self.cache_dir:
            return
        
        cache_key = self.get_cache_key(text, voice_preset)
        self.cache_index[cache_key] = True
        
        # We already have the audio file at audio_path, just update the index
        self.save_cache_index()
        
        return cache_key
    
    def synthesize(self, text, voice_preset=None, language=None, 
                   speed=None, pitch=None, energy=None):
        """
        Synthesize speech from text using Google Cloud TTS.
        
        Args:
            text: Text to synthesize
            voice_preset: Voice to use, or None for default
            language: Language code (default is "en-US")
            speed: Override the speaking rate
            pitch: Override the pitch shift
            energy: Override the energy/volume
        
        Returns:
            tuple: (sample_rate, audio_file_path)
        """
        if not text or text.strip() == "":
            # Return a simple empty audio file
            empty_file = Path(self.cache_dir) / f"empty_{int(time.time())}.mp3"
            with open(empty_file, "wb") as f:
                f.write(b"")
            return self.sample_rate, str(empty_file)
                
        start_time = time.time()
        
        # Check cache first
        cached_result = self.get_cached_audio(text, voice_preset)
        if cached_result is not None:
            print(f"Cache hit! Retrieved cached audio for: '{text[:30]}...'")
            print(f"Retrieved in {time.time() - start_time:.3f}s")
            return cached_result
        
        print(f"Synthesizing new audio for: '{text}'")
        gen_start_time = time.time()
        
        # Use provided parameters or fall back to instance defaults
        speaking_rate = speed if speed is not None else self.speaking_rate
        pitch_shift = pitch if pitch is not None else self.pitch_shift
        energy_level = energy if energy is not None else self.energy
        
        # Select the language and voice
        lang_code = language or "en-US"
        voice_name = self.voice_presets.get(voice_preset, self.voice_presets["female"])
        
        # Set the text input
        text_input = texttospeech.SynthesisInput(text=text)
        
        # Select the voice
        voice = texttospeech.VoiceSelectionParams(
            language_code=lang_code,
            name=voice_name
        )
        
        # Configure audio settings exactly as in the example
        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.MP3,
            speaking_rate=speaking_rate,  # 0.25 to 4.0
            pitch=pitch_shift,           # -20.0 to 20.0
            volume_gain_db=energy_level  # -96.0 to 16.0
        )
        
        # Generate the speech
        response = self.tts_client.synthesize_speech(
            input=text_input,
            voice=voice,
            audio_config=audio_config
        )
        
        # Save the audio to a file
        cache_key = self.get_cache_key(text, voice_preset)
        output_file = Path(self.cache_dir) / f"{cache_key}.mp3"
        with open(output_file, "wb") as out:
            out.write(response.audio_content)
            
        gen_time = time.time() - gen_start_time
        print(f"Synthesis completed in {gen_time:.3f}s - {len(text)/gen_time:.1f} chars/sec")
        
        # Cache the result
        self.cache_audio(text, voice_preset, output_file)
        
        return self.sample_rate, str(output_file)

    def long_form_synthesize(self, text, voice_preset=None, language=None, speed=None, pitch=None, energy=None):
        """
        Synthesize speech from long-form text by breaking it into sentences.
        
        Args:
            text: Long-form text to synthesize
            voice_preset: Voice to use, or None for default
            language: Language code (default is "en-US")
            speed: Override the speaking rate
            pitch: Override the pitch shift
            energy: Override the energy/volume
        
        Returns:
            tuple: (sample_rate, audio_file_path)
        """
        if not text or text.strip() == "":
            # Return a simple empty audio file
            empty_file = Path(self.cache_dir) / f"empty_{int(time.time())}.mp3"
            with open(empty_file, "wb") as f:
                f.write(b"")
            return self.sample_rate, str(empty_file)
                
        start_time = time.time()
        
        # Break text into sentences
        sentences = nltk.sent_tokenize(text)
        if not sentences and text.strip():
            # If tokenization failed but we have text, treat the whole text as one sentence
            sentences = [text]
                
        print(f"Breaking text into {len(sentences)} sentences for synthesis")
        
        # Process each sentence
        audio_files = []
        total_chars = sum(len(s) for s in sentences)
        processed_chars = 0
        
        for i, sent in enumerate(sentences):
            if not sent.strip():
                continue
                    
            # Update progress
            processed_chars += len(sent)
            progress = processed_chars / total_chars * 100 if total_chars > 0 else 100
                
            print(f"Synthesizing sentence {i+1}/{len(sentences)} ({progress:.1f}% complete)")
            try:
                _, audio_file = self.synthesize(
                    sent, voice_preset, language, speed, pitch, energy
                )
                
                # Add the file to our list
                if os.path.exists(audio_file) and os.path.getsize(audio_file) > 0:
                    audio_files.append(audio_file)
            except Exception as e:
                print(f"Error synthesizing sentence {i+1}: {e}")
                # Continue with other sentences
        
        # Combine all audio files using ffmpeg
        if len(audio_files) > 0:
            # Create a concatenation file
            concat_file = Path(self.cache_dir) / f"concat_{int(time.time())}.txt"
            with open(concat_file, "w") as f:
                for audio_file in audio_files:
                    f.write(f"file '{os.path.abspath(audio_file)}'\n")
            
            # Output file
            output_file = Path(self.cache_dir) / f"combined_{int(time.time())}.mp3"
            
            # Use ffmpeg to concatenate
            try:
                (
                    ffmpeg
                    .input(str(concat_file), format='concat', safe=0)
                    .output(str(output_file), c='copy')
                    .run(quiet=True, overwrite_output=True)
                )
                print(f"Successfully concatenated {len(audio_files)} audio files")
                
                total_time = time.time() - start_time
                print(f"Total synthesis time: {total_time:.2f}s")
                if total_chars > 0:
                    print(f"Characters per second: {total_chars/total_time:.1f}")
                
                return self.sample_rate, str(output_file)
            except Exception as e:
                print(f"Error concatenating audio files: {e}")
                print("Returning the list of individual files for sequential playback")
                return self.sample_rate, audio_files
        else:
            print("No audio files generated")
            # Return a simple empty audio file
            empty_file = Path(self.cache_dir) / f"empty_{int(time.time())}.mp3"
            with open(empty_file, "wb") as f:
                f.write(b"")
            return self.sample_rate, str(empty_file)

# For backward compatibility with the app.py interface
XTTSService = GoogleCloudTTSService