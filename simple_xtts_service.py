import os
import time
import hashlib
from pathlib import Path
import json
import warnings

# Try to import optional dependencies, but don't fail if they're not available
try:
    import numpy as np
    NUMPY_AVAILABLE = True
except ImportError:
    NUMPY_AVAILABLE = False
    print("WARNING: NumPy not available. Using fallback audio processing.")

try:
    import torch
    TORCH_AVAILABLE = True
    # Handle PyTorch version-specific code for safe loading
    TORCH_VERSION = torch.__version__
    print(f"PyTorch {TORCH_VERSION} available")
    
    # For PyTorch 2.6+, set environment variable to use weights_only=False
    if TORCH_VERSION.startswith('2.') and int(TORCH_VERSION.split('.')[1]) >= 6:
        print("Setting TORCH_LOAD_WEIGHTS_ONLY=0 for compatibility with PyTorch 2.6+")
        os.environ["TORCH_LOAD_WEIGHTS_ONLY"] = "0"
        
except ImportError:
    TORCH_AVAILABLE = False
    TORCH_VERSION = None
    print("WARNING: PyTorch not available. Using CPU-only mode.")

try:
    import nltk
    try:
        nltk.data.find('tokenizers/punkt')
    except LookupError:
        nltk.download('punkt', quiet=True)
    NLTK_AVAILABLE = True
    sent_tokenize = nltk.sent_tokenize
except ImportError:
    NLTK_AVAILABLE = False
    print("WARNING: NLTK not available. Using basic sentence tokenization.")
    # Simple sentence tokenizer if nltk is not available
    def sent_tokenize(text):
        return [s.strip() for s in text.replace('!', '.').replace('?', '.').split('.') if s.strip()]

# Try to import Coqui TTS, but don't fail if it's not available
COQUI_TTS_AVAILABLE = False
try:
    import TTS
    from TTS.api import TTS as TTSApi
    COQUI_TTS_AVAILABLE = True
    print(f"Coqui TTS version {TTS.__version__} available")
except ImportError:
    print("WARNING: Coqui TTS not available. Using fallback synthesizer.")


class SimpleXTTSService:
    """
    A simplified TTS service that works with Coqui TTS when available,
    but can also operate with fallbacks when dependencies are missing.
    """
    
    def __init__(self, device: str = "cuda" if TORCH_AVAILABLE and torch.cuda.is_available() else "cpu",
                 cache_dir: str = "./tts_cache", model_name: str = None):
        """
        Initializes the TTS service with Coqui TTS when available.
        
        Args:
            device: "cuda" or "cpu" for model processing
            cache_dir: Directory to store cached audio samples
            model_name: Specific TTS model to use, or None for default
        """
        self.device = device
        print(f"Initializing SimpleXTTSService on {device}...")
        
        # Set up TTS model if available
        self.tts_model = None
        self.sample_rate = 22050  # Default sample rate for Tacotron2
        self.model_type = None
        
        if COQUI_TTS_AVAILABLE:
            try:
                # Try loading models in preferred order
                preferred_models = [model_name] if model_name else [
                    "tts_models/multilingual/multi-dataset/xtts_v2",
                    "tts_models/en/ljspeech/vits",
                    "tts_models/en/ljspeech/tacotron2-DDC",  # Reliable and works well with PyTorch 2.6+
                    "tts_models/en/ljspeech/glow-tts",       # Alternative model
                    "tts_models/en/ljspeech/fast_pitch"      # Another alternative
                ]
                
                # Try each model until one works
                for model in preferred_models:
                    try:
                        print(f"Attempting to load model: {model}")
                        self.tts_model = TTSApi(model_name=model)
                        self.tts_model.to(device)
                        
                        # Detect model type
                        self.model_type = model.split('/')[-1] if '/' in model else model
                        print(f"Successfully loaded model: {model}")
                        break
                    except Exception as e:
                        print(f"Failed to load model {model}: {e}")
                
                # Get sample rate from the loaded model
                if self.tts_model:
                    try:
                        # First try the synthesizer's audio processor
                        if hasattr(self.tts_model, "synthesizer") and hasattr(self.tts_model.synthesizer, "ap"):
                            if hasattr(self.tts_model.synthesizer.ap, "sample_rate"):
                                self.sample_rate = self.tts_model.synthesizer.ap.sample_rate
                                print(f"Detected sample rate from model: {self.sample_rate} Hz")
                    except Exception as e:
                        print(f"Error detecting sample rate: {e}")
                        print(f"Using default sample rate: {self.sample_rate} Hz")
            except Exception as e:
                print(f"Error initializing TTS: {e}")
                self.tts_model = None
        else:
            print("Coqui TTS not available - will use fallback synthesizer")
        
        # Set up cache
        self.cache_dir = cache_dir
        if self.cache_dir:
            os.makedirs(self.cache_dir, exist_ok=True)
            self.cache_index_path = Path(self.cache_dir) / "simple_tts_cache_index.json"
            self.load_cache_index()
        
        # Voice presets don't apply to Tacotron2, but keep for compatibility
        self.voice_presets = {
            "male": None,     # Tacotron2 doesn't support speaker selection
            "female": None,   # It uses a fixed voice
            "female2": None,
            "male2": None
        }
        
        print(f"SimpleXTTSService initialization complete. TTS model ready: {self.tts_model is not None}")
        if self.tts_model is not None:
            print(f"Model type: {self.model_type}, Sample rate: {self.sample_rate} Hz")
    
    def set_speech_parameters(self, speaking_rate=1.0, pitch_shift=0.0, energy=1.0):
        """
        Adjust speech parameters for more natural sound.

        Args:
            speaking_rate: Value between 0.5-1.5, where 1.0 is normal speed
            pitch_shift: Value between -1.0 and 1.0 to shift pitch
            energy: Value between 0.5-1.5 to adjust volume/energy
        """
        self.speaking_rate = speaking_rate
        self.pitch_shift = pitch_shift
        self.energy = energy
        
        print("---------- SETTING SPEECH PARAMETERS -----------")
        # Store these for synthesis
        if hasattr(self.tts_model, "synthesizer"):
            # Different models use different parameter names
            if self.model_type and "vits" in self.model_type.lower():
                # VITS model parameters
                if hasattr(self.tts_model.synthesizer, "inference_settings"):
                    self.tts_model.synthesizer.inference_settings.update({
                        "length_scale": 1.0 / speaking_rate,  # Inverse relationship
                        "noise_scale": max(0.3, 0.667 - (speaking_rate - 1.0) * 0.1),  # Reduce noise for faster speech
                        "noise_scale_w": 0.8,
                    })
                    print(f"Set VITS parameters - speed:{speaking_rate}, noise:{max(0.3, 0.667 - (speaking_rate - 1.0) * 0.1)}")
            elif self.model_type and "xtts" in self.model_type.lower():
                # XTTS specific parameters
                if hasattr(self.tts_model, "config") and hasattr(self.tts_model.config, "inference"):
                    self.tts_model.config.inference.update({
                        "speed": speaking_rate,
                        "temperature": max(0.3, 0.65 - (speaking_rate - 1.0) * 0.1),  # Adjust temperature based on speed
                    })
                    print(f"Set XTTS parameters - speed:{speaking_rate}")
            else:
                # Generic parameters for other models
                if hasattr(self.tts_model.synthesizer, "inference_settings"):
                    self.tts_model.synthesizer.inference_settings.update({
                        "length_scale": 1.0 / speaking_rate,  # Inverse relationship
                    })
                    print(f"Set speaking rate to {speaking_rate}")
        
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
        # For Tacotron2, voice_preset doesn't matter, but keep for compatibility
        key_string = f"{text}_{self.model_type or 'fallback'}"
        return hashlib.md5(key_string.encode()).hexdigest()
    
    def get_cached_audio(self, text, voice_preset):
        """Get cached audio if available."""
        if not self.cache_dir:
            return None
        
        cache_key = self.get_cache_key(text, voice_preset)
        if cache_key in self.cache_index:
            # Try different formats based on available libraries
            if NUMPY_AVAILABLE:
                cache_path = Path(self.cache_dir) / f"{cache_key}.npy"
                if os.path.exists(cache_path):
                    try:
                        return self.sample_rate, np.load(cache_path)
                    except Exception as e:
                        print(f"Error loading cached numpy audio: {e}")
            
            # Try WAV format as backup
            cache_path = Path(self.cache_dir) / f"{cache_key}.wav"
            if os.path.exists(cache_path):
                try:
                    if NUMPY_AVAILABLE:
                        try:
                            import soundfile as sf
                            audio_array, sample_rate = sf.read(str(cache_path))
                            return sample_rate, audio_array
                        except:
                            pass
                    
                    # Return file path if we can't load the array
                    return self.sample_rate, str(cache_path)
                except Exception as e:
                    print(f"Error loading cached wav audio: {e}")
        
        return None
    
    def cache_audio(self, text, voice_preset, audio_array):
        """Cache the generated audio."""
        if not self.cache_dir:
            return
        
        cache_key = self.get_cache_key(text, voice_preset)
        self.cache_index[cache_key] = True
        
        if NUMPY_AVAILABLE and isinstance(audio_array, np.ndarray):
            # Save as numpy array if possible
            cache_path = Path(self.cache_dir) / f"{cache_key}.npy"
            np.save(cache_path, audio_array)
            
            # Also save as WAV for compatibility
            try:
                import soundfile as sf
                wav_path = Path(self.cache_dir) / f"{cache_key}.wav"
                sf.write(str(wav_path), audio_array, self.sample_rate)
            except Exception as e:
                print(f"Error saving WAV: {e}")
        elif isinstance(audio_array, str) and os.path.exists(audio_array):
            # If it's a path to a WAV file, just copy it
            import shutil
            dst_path = Path(self.cache_dir) / f"{cache_key}.wav"
            shutil.copy(audio_array, dst_path)
        
        self.save_cache_index()
    
    def generate_fallback_audio(self, text, voice_preset=None):
        """Generate a simple fallback audio when TTS is not available."""
        print(f"Using fallback audio synthesis for: '{text}'")
        
        # Generate audio duration based on text length
        duration = 0.1 + len(text) * 0.05  # Scale duration with text length
        
        # Generate different tones based on voice preset
        freq = 440  # A4 note (doesn't vary for Tacotron2 as it has a fixed voice)
            
        if NUMPY_AVAILABLE:
            # Generate a simple sine wave with numpy
            t = np.linspace(0, duration, int(self.sample_rate * duration), False)
            audio_array = 0.5 * np.sin(2 * np.pi * freq * t) * np.exp(-0.5 * t)
            return self.sample_rate, audio_array
        else:
            # Generate a simple WAV file with standard library
            import wave
            import struct
            import math
            import tempfile
            
            temp_file = tempfile.NamedTemporaryFile(suffix='.wav', delete=False)
            temp_file.close()
            
            with wave.open(temp_file.name, 'w') as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2)
                wf.setframerate(self.sample_rate)
                
                for i in range(int(self.sample_rate * duration)):
                    t = i / self.sample_rate
                    value = int(32767 * 0.5 * math.sin(2 * math.pi * freq * t) * math.exp(-0.5 * t))
                    wf.writeframes(struct.pack('h', value))
            
            return self.sample_rate, temp_file.name
    
    def synthesize(self, text, voice_preset=None, language=None, 
               speed=None, pitch=None, energy=None):
        """
        Synthesize speech from text using Coqui TTS or fallback.
        
        Args:
            text: Text to synthesize
            voice_preset: Voice to use, or None for default
            language: Language code (ignored for Tacotron2 as it's English only)
            speed: Speaking speed override (1.0 is normal)
            pitch: Pitch shift override (-1.0 to 1.0)
            energy: Energy/volume override (1.0 is normal)
        
        Returns:
            tuple: (sample_rate, audio_array)
        """
        if not text or text.strip() == "":
            return self.generate_fallback_audio("Empty text")
        
        # Use parameter overrides if provided, otherwise use instance values
        speaking_rate = speed if speed is not None else getattr(self, 'speaking_rate', 1.0)
        pitch_shift = pitch if pitch is not None else getattr(self, 'pitch_shift', 0.0)
        energy_value = energy if energy is not None else getattr(self, 'energy', 1.0)
                
        start_time = time.time()
        
        # Check cache first
        cached_result = self.get_cached_audio(text, voice_preset)
        if cached_result is not None:
            print(f"Cache hit! Retrieved cached audio for: '{text[:30]}...'")
            print(f"Retrieved in {time.time() - start_time:.3f}s")
            return cached_result
        
        print(f"Synthesizing new audio for: '{text}'")
        gen_start_time = time.time()
        
        # Try to use Coqui TTS if available
        if COQUI_TTS_AVAILABLE and self.tts_model is not None:
            try:
                # Prepare keyword arguments based on model type
                kwargs = {}

                if hasattr(self, "model_type") and self.model_type:
                    if "vctk" in self.model_type.lower():
                        kwargs["speaker_id"] = "p226"  # Example: male speaker
                    
                    # Apply appropriate parameters based on model type
                    if "vits" in self.model_type.lower():
                        # VITS model parameters
                        kwargs.update({
                            "length_scale": 1.0 / speaking_rate,  # Inverse relationship
                            "noise_scale": max(0.3, 0.667 - (speaking_rate - 1.0) * 0.1),  # Reduce noise for faster speech
                            "noise_scale_w": 0.8,
                        })
                    elif "xtts" in self.model_type.lower():
                        # XTTS specific parameters
                        kwargs.update({
                            "speed": speaking_rate,
                            "temperature": max(0.3, 0.65 - (speaking_rate - 1.0) * 0.1),  # Adjust temperature based on speed
                        })
                    else:
                        # Generic parameters for other models
                        kwargs.update({
                            "length_scale": 1.0 / speaking_rate,  # Inverse relationship
                        })
                
                # Generate speech with Coqui TTS
                audio_output = self.tts_model.tts(text=text, **kwargs)
                
                # Debug info about the returned audio
                print(f"TTS output type: {type(audio_output)}")
                if NUMPY_AVAILABLE and isinstance(audio_output, np.ndarray):
                    print(f"TTS output shape: {audio_output.shape}, dtype: {audio_output.dtype}")
                
                # Always treat the result as a numpy array - this is what Tacotron2 returns
                audio_array = audio_output
                
                gen_time = time.time() - gen_start_time
                print(f"Synthesis completed in {gen_time:.3f}s - {len(text)/gen_time:.1f} chars/sec")
                
                # Cache the result
                self.cache_audio(text, voice_preset, audio_array)
                
                return self.sample_rate, audio_array
                
            except Exception as e:
                print(f"Error in TTS synthesis: {e}")
                print("Falling back to basic audio generation")
        
        # If TTS failed or isn't available, use fallback
        return self.generate_fallback_audio(text, voice_preset)

    def long_form_synthesize(self, text, voice_preset=None, language=None, 
                            speed=None, pitch=None, energy=None):
        """
        Synthesize speech from long-form text by breaking it into sentences.
        
        Args:
            text: Long-form text to synthesize
            voice_preset: Voice to use, or None for default
            language: Language code
            speed: Speaking speed override (1.0 is normal)
            pitch: Pitch shift override (-1.0 to 1.0)
            energy: Energy/volume override (1.0 is normal)
        
        Returns:
            tuple: (sample_rate, audio_array)
        """
        if not text or text.strip() == "":
            return self.generate_fallback_audio("Empty text")
                
        start_time = time.time()
        
        # Break text into sentences
        sentences = sent_tokenize(text)
        if not sentences and text.strip():
            # If tokenization failed but we have text, treat the whole text as one sentence
            sentences = [text]
                
        print(f"Breaking text into {len(sentences)} sentences for synthesis")
        
        # Process each sentence - use a single list for audio pieces
        audio_pieces = []
        sample_rate = self.sample_rate
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
                # Pass the speed, pitch, and energy parameters to the synthesize method
                curr_sample_rate, audio = self.synthesize(
                    sent, 
                    voice_preset=voice_preset,
                    language=language,
                    speed=speed,
                    pitch=pitch,
                    energy=energy
                )
                
                # Save the sample rate from the first synthesis
                if i == 0:
                    sample_rate = curr_sample_rate
                
                # For Tacotron2 with Coqui TTS 0.22.0, the audio should always be a numpy array
                if NUMPY_AVAILABLE and isinstance(audio, np.ndarray):
                    audio_pieces.append(audio)
                    # Add silence between sentences (0.25 sec)
                    silence = np.zeros(int(0.25 * sample_rate))
                    audio_pieces.append(silence)
                    print(f"Added audio for sentence {i+1}: shape={audio.shape}")
                else:
                    print(f"Unexpected audio type for sentence {i+1}: {type(audio)}")
                    # For unexpected types, we'll try to convert if possible
                    if isinstance(audio, list) and len(audio) > 0:
                        # Try to convert list to numpy array
                        try:
                            audio_array = np.array(audio)
                            audio_pieces.append(audio_array)
                            silence = np.zeros(int(0.25 * sample_rate))
                            audio_pieces.append(silence)
                            print(f"Converted list to numpy array for sentence {i+1}")
                        except Exception as e:
                            print(f"Failed to convert list to array: {e}")
                    elif isinstance(audio, str) and os.path.exists(audio):
                        # It's a path to a file - we'll handle this in the concatenation step
                        print(f"Audio is a file path: {audio}")
                        audio_pieces.append(audio)
                    else:
                        print(f"Skipping invalid audio for sentence {i+1}")
            except Exception as e:
                print(f"Error synthesizing sentence {i+1}: {e}")
                # Continue with other sentences
        
        # Rest of the method remains the same
        # [Existing concatenation and return code]
        total_time = time.time() - start_time
        print(f"Total synthesis time: {total_time:.2f}s")
        if total_chars > 0:
            print(f"Characters per second: {total_chars/total_time:.1f}")
        
        # Combine all pieces with proper error handling
        if NUMPY_AVAILABLE:
            try:
                # Check if we have audio pieces to concatenate
                if audio_pieces:
                    print(f"Concatenating {len(audio_pieces)} audio pieces")
                    # Verify all pieces are numpy arrays before concatenating
                    if all(isinstance(p, np.ndarray) for p in audio_pieces):
                        # Everything is a numpy array, we can concatenate
                        final_audio = np.concatenate(audio_pieces)
                        print(f"Successfully concatenated audio: shape={final_audio.shape}")
                        return sample_rate, final_audio
                    else:
                        # Mixed types, handle differently
                        numpy_pieces = [p for p in audio_pieces if isinstance(p, np.ndarray)]
                        if numpy_pieces:
                            # We have some numpy arrays, concatenate those
                            final_audio = np.concatenate(numpy_pieces)
                            print(f"Concatenated {len(numpy_pieces)} numpy arrays")
                            return sample_rate, final_audio
                        else:
                            # No numpy arrays, return the first audio piece (likely a file path)
                            print(f"No numpy arrays to concatenate, returning first piece")
                            return sample_rate, audio_pieces[0]
                else:
                    print("Warning: No audio pieces to concatenate")
                    return self.generate_fallback_audio("No audio generated")
            except Exception as e:
                print(f"Error concatenating audio pieces: {e}")
                print(f"Audio pieces types: {[type(p) for p in audio_pieces]}")
                
                # If concatenation fails but we have at least one piece, return the first one
                if audio_pieces:
                    print("Returning first audio piece instead")
                    return sample_rate, audio_pieces[0]
                else:
                    return self.generate_fallback_audio("Audio concatenation failed")
        else:
            # No numpy available
            if audio_pieces:
                return sample_rate, audio_pieces[0]  # Return the first audio piece
            else:
                return self.generate_fallback_audio("No audio generated")


# For backward compatibility
XTTSService = SimpleXTTSService

# Test the service
if __name__ == "__main__":
    try:
        print("Testing SimpleXTTSService...")
        tts = SimpleXTTSService()
        
        print("\nTesting sentence synthesis...")
        sample_rate, audio = tts.synthesize("This is a test of the TTS service.")
        
        # Print stats
        if NUMPY_AVAILABLE and isinstance(audio, np.ndarray):
            audio_length = len(audio) / sample_rate
            print(f"Audio length: {audio_length:.2f} seconds")
        elif isinstance(audio, str):
            print(f"Audio saved to file: {audio}")
        
        print("\nTesting multi-sentence synthesis...")
        sample_rate, audio = tts.long_form_synthesize(
            "This is the first sentence. This is the second sentence. And here's a third one.",
            voice_preset="female2",
            speed=1.7,
            pitch=0.0,
            energy=1.0
        )
        
        # Print stats
        if NUMPY_AVAILABLE and isinstance(audio, np.ndarray):
            audio_length = len(audio) / sample_rate
            print(f"Audio length: {audio_length:.2f} seconds")
        elif isinstance(audio, str):
            print(f"Audio saved to file: {audio}")
        
        print("Test completed successfully!")
        
    except Exception as e:
        print(f"Error in test: {e}")