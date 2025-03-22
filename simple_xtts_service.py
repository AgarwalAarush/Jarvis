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
    import TTS as TTSModule
    from TTS.api import TTS as TTSClass
    COQUI_TTS_AVAILABLE = True
    print(f"Coqui TTS version {TTSModule.__version__} available")
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
        self.sample_rate = 24000  # Default sample rate
        
        if COQUI_TTS_AVAILABLE:
            try:
                # Get available models for Coqui TTS 0.22.0
                available_models = []
                try:
                    # This is the proper way to list models in 0.22.0
                    print("Listing available TTS models...")
                    tts_api = TTSClass()
                    available_models = tts_api.list_models()
                    print(f"Found {len(available_models)} available TTS models")
                except Exception as e:
                    print(f"Error listing models: {e}")
                    
                    # Try hardcoded list of common models as fallback
                    available_models = [
                        "tts_models/en/ljspeech/tacotron2-DDC",
                        "tts_models/en/ljspeech/glow-tts",
                        "tts_models/en/ljspeech/fast_pitch",
                        "tts_models/multilingual/multi-dataset/xtts_v2",
                        "tts_models/multilingual/multi-dataset/xtts_v1"
                    ]
                    print(f"Using fallback list of {len(available_models)} models")
                
                # Select model based on availability
                selected_model = None
                
                # Use specified model if provided
                if model_name:
                    if model_name in available_models:
                        selected_model = model_name
                    else:
                        print(f"Specified model '{model_name}' not available")
                
                # Otherwise select best available model
                if not selected_model:
                    # Try models in preference order
                    preferred_models = [
                        "tts_models/multilingual/multi-dataset/xtts_v2",  # Best quality
                        "tts_models/multilingual/multi-dataset/xtts_v1",  # Good quality
                        "tts_models/en/ljspeech/fast_pitch",              # Fast CPU-friendly
                        "tts_models/en/ljspeech/tacotron2-DDC",           # Reliable fallback
                        "tts_models/en/ljspeech/glow-tts"                 # Another option
                    ]
                    
                    for model in preferred_models:
                        if model in available_models:
                            selected_model = model
                            break
                
                    # If still no model selected, use first available
                    if not selected_model and available_models:
                        selected_model = available_models[0]
                
                # Load the selected model
                if selected_model:
                    print(f"Loading TTS model: {selected_model}")
                    try:
                        # Simple loading - should work with TORCH_LOAD_WEIGHTS_ONLY=0
                        self.tts_model = TTSClass(selected_model).to(device)
                        print(f"Successfully loaded {selected_model}")
                        
                        # Try to determine sample rate from model
                        if hasattr(self.tts_model, "synthesizer"):
                            if hasattr(self.tts_model.synthesizer, "output_sample_rate"):
                                self.sample_rate = self.tts_model.synthesizer.output_sample_rate
                    except Exception as e:
                        print(f"Failed to load model {selected_model}: {e}")
                        print("Trying simplified loader...")
                        try:
                            # Try with simpler model as fallback
                            simple_model = "tts_models/en/ljspeech/tacotron2-DDC"
                            if simple_model in available_models:
                                self.tts_model = TTSClass(simple_model).to(device)
                                print(f"Loaded fallback model {simple_model}")
                        except Exception as e2:
                            print(f"Could not load any TTS model: {e2}")
                else:
                    print("No suitable TTS models available")
            except Exception as e:
                print(f"Error initializing TTS: {e}")
        else:
            print("Coqui TTS not available - will use fallback synthesizer")
        
        # Set up cache
        self.cache_dir = cache_dir
        if self.cache_dir:
            os.makedirs(self.cache_dir, exist_ok=True)
            self.cache_index_path = Path(self.cache_dir) / "simple_xtts_cache_index.json"
            self.load_cache_index()
        
        # Voice presets - map friendly names to speaker IDs
        # These depend on the model being used
        self.voice_presets = {
            "male": "male",
            "female": "female", 
            "female2": "female",
            "male2": "male"
        }
        
        print(f"SimpleXTTSService initialization complete. TTS model ready: {self.tts_model is not None}")
    
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
        key_string = f"{text}_{voice_preset}"
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
    
    def generate_fallback_audio(self, text, voice_preset="female"):
        """Generate a simple fallback audio when TTS is not available."""
        print(f"Using fallback audio synthesis for: '{text}'")
        
        # Generate audio duration based on text length
        duration = 0.1 + len(text) * 0.05  # Scale duration with text length
        
        # Generate different tones based on voice preset
        if "female" in voice_preset:
            freq = 440  # A4 note
        else:
            freq = 220  # A3 note
            
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
    
    def synthesize(self, text, voice_preset=None):
        """
        Synthesize speech from text using Coqui TTS or fallback.
        
        Args:
            text: Text to synthesize
            voice_preset: Voice to use, or None for default
        
        Returns:
            tuple: (sample_rate, audio_array)
        """
        if not text or text.strip() == "":
            return self.generate_fallback_audio("Empty text")
        
        # Use default voice if none specified
        if voice_preset is None:
            voice_preset = "female"
        elif voice_preset in self.voice_presets:
            voice_preset = self.voice_presets[voice_preset]
        
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
                # Determine the right synthesis parameters based on model type
                kwargs = {}
                
                # Check if we're using XTTS
                model_name = self.tts_model.model_name if hasattr(self.tts_model, "model_name") else ""
                
                if isinstance(model_name, str) and "xtts" in model_name.lower():
                    print(f"Using XTTS model with {voice_preset} voice")
                    kwargs["speaker"] = voice_preset
                    kwargs["language"] = "en"
                
                # Generate speech with Coqui TTS
                try:
                    audio_output = self.tts_model.tts(text=text, **kwargs)
                    
                    # Handle different return types from TTS models
                    if isinstance(audio_output, str):
                        # TTS returned a file path
                        output_path = audio_output
                        if NUMPY_AVAILABLE:
                            try:
                                import soundfile as sf
                                audio_array, _ = sf.read(output_path)
                            except:
                                audio_array = output_path
                        else:
                            audio_array = output_path
                    else:
                        # TTS returned a numpy array
                        audio_array = audio_output
                    
                    gen_time = time.time() - gen_start_time
                    print(f"Synthesis completed in {gen_time:.3f}s - {len(text)/gen_time:.1f} chars/sec")
                    
                    # Cache the result
                    self.cache_audio(text, voice_preset, audio_array)
                    
                    return self.sample_rate, audio_array
                except Exception as e:
                    print(f"Error in TTS synthesis: {str(e)}")
                    
            except Exception as e:
                print(f"Error preparing TTS synthesis: {e}")
                print("Falling back to basic audio generation")
        
        # If TTS failed or isn't available, use fallback
        return self.generate_fallback_audio(text, voice_preset)
    
    def long_form_synthesize(self, text, voice_preset=None):
        """
        Synthesize speech from long-form text by breaking it into sentences.
        
        Args:
            text: Long-form text to synthesize
            voice_preset: Voice to use, or None for default
        
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
        
        # Process each sentence
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
            curr_sample_rate, audio = self.synthesize(sent, voice_preset)
            
            # Save the sample rate from the first synthesis
            if i == 0:
                sample_rate = curr_sample_rate
            
            # Handle different types of audio
            if NUMPY_AVAILABLE and isinstance(audio, np.ndarray):
                audio_pieces.append(audio)
                # Add silence between sentences (0.25 sec)
                silence = np.zeros(int(0.25 * sample_rate))
                audio_pieces.append(silence)
            elif isinstance(audio, str) and os.path.exists(audio):
                # If it's a path to a WAV file, we'll need to concatenate them separately
                audio_pieces.append(audio)
        
        total_time = time.time() - start_time
        print(f"Total synthesis time: {total_time:.2f}s")
        if total_chars > 0:
            print(f"Characters per second: {total_chars/total_time:.1f}")
        
        # Combine all pieces
        if NUMPY_AVAILABLE and all(isinstance(p, np.ndarray) for p in audio_pieces):
            # If all are numpy arrays, concatenate them
            final_audio = np.concatenate(audio_pieces)
            return sample_rate, final_audio
        else:
            # If we have file paths, combine the WAV files
            import tempfile
            import wave
            
            # Create a temporary file for the combined audio
            temp_file = tempfile.NamedTemporaryFile(suffix='.wav', delete=False)
            temp_file.close()
            output_path = temp_file.name
            
            # Concatenate WAV files
            if all(isinstance(p, str) and os.path.exists(p) for p in audio_pieces):
                data = []
                for wav_file in audio_pieces:
                    with wave.open(wav_file, 'rb') as w:
                        data.append([w.getparams(), w.readframes(w.getnframes())])
                
                with wave.open(output_path, 'wb') as output:
                    # Use parameters from the first file
                    output.setparams(data[0][0])
                    for _, frames in data:
                        output.writeframes(frames)
                
                return sample_rate, output_path
            
            # If we have a mix, this is more complex - just return the first one
            if audio_pieces:
                return sample_rate, audio_pieces[0]
            else:
                return self.generate_fallback_audio("Processing failed")


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
            "This is the first sentence. This is the second sentence. And here's a third one."
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