import os
import time
import nltk
import numpy as np
import torch
import warnings
from pathlib import Path
import json
from transformers import AutoProcessor, BarkModel

warnings.filterwarnings(
    "ignore",
    message="torch.nn.utils.weight_norm is deprecated in favor of torch.nn.utils.parametrizations.weight_norm.",
)

class OptimizedTTSService:
    """
    An optimized version of the Bark TTS service with caching and performance improvements.
    """
    
    def __init__(self, device: str = "cuda" if torch.cuda.is_available() else "cpu",
                 model_size: str = "small", cache_dir: str = "./tts_cache"):
        """
        Initializes an optimized version of the Bark TTS service.
        
        Args:
            device: "cuda" or "cpu"
            model_size: "small" for faster synthesis or "base" for higher quality
            cache_dir: Directory to store cached audio samples
        """
        self.device = device
        
        # Use smaller model for faster processing
        model_name = f"suno/bark-{model_size}"
        print(f"Loading {model_name} on {device}...")
        
        # Load with optimizations for inference
        self.processor = AutoProcessor.from_pretrained(model_name)
        self.model = BarkModel.from_pretrained(model_name)
        self.model.to(self.device)
        
        # Set up cache
        self.cache_dir = cache_dir
        if self.cache_dir:
            os.makedirs(self.cache_dir, exist_ok=True)
            self.cache_index_path = Path(self.cache_dir) / "cache_index.json"
            self.load_cache_index()
        
        # Voice presets
        self.voice_presets = {
            "male": "v2/en_speaker_1",
            "female": "v2/en_speaker_6",
            "female2": "v2/en_speaker_9",
            "male2": "v2/en_speaker_2"
        }
        
        # Optimization settings
        self.optimize_for_speed()
        
        print(f"Initialized OptimizedTTSService with model: {model_name}")
    
    def load_cache_index(self):
        """Load the cache index from disk or create a new one."""
        if self.cache_dir and os.path.exists(self.cache_index_path):
            with open(self.cache_index_path, 'r') as f:
                self.cache_index = json.load(f)
        else:
            self.cache_index = {}
    
    def save_cache_index(self):
        """Save the cache index to disk."""
        if self.cache_dir:
            with open(self.cache_index_path, 'w') as f:
                json.dump(self.cache_index, f)
    
    def get_cached_audio(self, text, voice_preset):
        """Get cached audio if available."""
        if not self.cache_dir:
            return None
        
        key = f"{text}_{voice_preset}"
        if key in self.cache_index:
            cache_path = Path(self.cache_dir) / f"{self.cache_index[key]}.npy"
            if os.path.exists(cache_path):
                try:
                    return np.load(cache_path), self.model.generation_config.sample_rate
                except Exception as e:
                    print(f"Error loading cached audio: {e}")
        
        return None
    
    def cache_audio(self, text, voice_preset, audio_array):
        """Cache the generated audio."""
        if not self.cache_dir:
            return
        
        key = f"{text}_{voice_preset}"
        filename = str(abs(hash(key)))
        self.cache_index[key] = filename
        cache_path = Path(self.cache_dir) / f"{filename}.npy"
        np.save(cache_path, audio_array)
        self.save_cache_index()
    
    def optimize_for_speed(self):
        """Apply optimizations to make synthesis faster."""
        if self.device == "cuda":
            # Use mixed precision for faster GPU processing
            self.model = self.model.half()
        
        # Optimize inference-only parameters
        self.model.eval()
        
        # Adjust generation parameters for speed
        self.model.generation_config.num_continuation_samples = 1
        self.model.generation_config.temperature = 0.7  # Lower temperature = faster generation
        
        # Disable extra features
        torch.backends.cudnn.benchmark = True
    
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
            print(f"Cache hit! Retrieved cached audio for: '{text}'")
            print(f"Retrieved in {time.time() - start_time:.3f}s")
            return cached_result[1], cached_result[0]
        
        print(f"Synthesizing new audio for: '{text}'")
        gen_start_time = time.time()
        
        # Generate speech
        inputs = self.processor(text, voice_preset=voice_preset, return_tensors="pt")
        inputs = {k: v.to(self.device) for k, v in inputs.items()}
        
        with torch.no_grad():
            audio_array = self.model.generate(**inputs, pad_token_id=10000)
        
        audio_array = audio_array.cpu().numpy().squeeze()
        sample_rate = self.model.generation_config.sample_rate
        
        # Cache the result
        self.cache_audio(text, voice_preset, audio_array)
        
        gen_time = time.time() - gen_start_time
        print(f"Synthesis completed in {gen_time:.3f}s - {len(text)/gen_time:.1f} chars/sec")
        
        return sample_rate, audio_array
    
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
        silence = np.zeros(int(0.25 * self.model.generation_config.sample_rate))
        
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
        
        return self.model.generation_config.sample_rate, np.concatenate(pieces)

# Test the OptimizedTTSService
if __name__ == "__main__":
    try:
        print("Testing OptimizedTTSService...")
        tts = OptimizedTTSService()
        
        print("\nTesting sentence synthesis...")
        sample_rate, audio = tts.synthesize("This is a test of the optimized TTS service.")
        
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
