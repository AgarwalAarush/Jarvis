from automation import SystemAutomationClient
from cartesia_tts import CartesiaTTS
from llm_interface import LLMInterface
from wake_word.model import Model
import time
import threading
import numpy as np
import whisper
import sounddevice as sd
import os
import sys
from queue import Queue, Empty
from rich.console import Console
from rich.status import Status
from dotenv import load_dotenv

# Add wake_word directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), 'wake_word'))

# Import wake word model

# Import existing components

# Load environment variables
load_dotenv()

# Initialize console for rich display
console = Console()

# Audio configuration
SAMPLE_RATE = 16000
CHUNK_SIZE = 1280  # 80ms chunks for wake word detection
CHANNELS = 1
DTYPE = np.int16

# Wake word detection configuration
WAKE_WORD_CONFIDENCE_THRESHOLD = 0.99
SILENCE_THRESHOLD = 0.005  # Lowered RMS threshold for better sensitivity
SILENCE_DURATION_BLOCKS = 25  # Reduced to ~2 seconds for faster response
KEYWORD_BUFFER_DURATION = 2.0  # seconds

# Improved silence detection configuration
ADAPTIVE_THRESHOLD_MULTIPLIER = 1.5  # Multiplier for adaptive threshold
MIN_SILENCE_THRESHOLD = 0.002  # Minimum threshold
MAX_SILENCE_THRESHOLD = 0.02   # Maximum threshold
SILENCE_BUFFER_SIZE = 10       # Number of chunks to average for adaptive threshold


class VoiceAssistant:
    def __init__(self):
        self.console = Console()

        # Audio processing
        self.audio_queue = Queue()
        self.recording_buffer = []
        self.keyword_buffer = np.array([], dtype=np.float32)
        self.silence_counter = 0

        # Improved silence detection
        self.silence_threshold = SILENCE_THRESHOLD
        self.audio_levels_buffer = []
        self.adaptive_threshold = SILENCE_THRESHOLD
        self.silence_debug_enabled = False

        # State management
        self.is_listening = True
        self.is_recording = False
        self.is_processing = False

        # Models
        self.wake_word_model = None
        self.whisper_model = None
        self.tts = None

        # Threading
        self.audio_stream = None
        self.stop_event = threading.Event()

        self._initialize_models()

    def _initialize_models(self):
        """Initialize all AI models and services"""
        try:
            # Initialize TTS
            self.console.print("[cyan]Initializing TTS service...")
            self.tts = CartesiaTTS(
                voice=os.environ.get("CARTESIA_VOICE", "Joan")
            )

            # Initialize Whisper
            self.console.print("[cyan]Loading Whisper model...")
            self.whisper_model = whisper.load_model("base.en")

            # Initialize Wake Word model
            self.console.print("[cyan]Loading wake word model...")
            current_dir = os.path.dirname(os.path.abspath(__file__))
            model_path = os.path.join(
                current_dir, "wake_word", "models", "jarvis.onnx")

            # Initialize System
            self.system_automation = SystemAutomationClient({})

            if not os.path.exists(model_path):
                raise FileNotFoundError(
                    f"Wake word model not found at: {model_path}")

            self.wake_word_model = Model(
                wakeword_models=[model_path],
                inference_framework="onnx"
            )

            self.console.print("[green] All models loaded successfully")

        except Exception as e:
            self.console.print(f"[red]Error initializing models: {e}")
            sys.exit(1)

    def audio_callback(self, indata, frames, time_info, status):
        """Callback for continuous audio stream"""
        if status:
            self.console.print(f"[yellow]Audio status: {status}")

        if not self.stop_event.is_set():
            self.audio_queue.put(indata.copy())

    def calculate_rms(self, audio_data):
        """Calculate RMS (Root Mean Square) of audio data"""
        # Convert to float32 for better precision
        audio_float = audio_data.astype(np.float32) / 32768.0
        return np.sqrt(np.mean(audio_float ** 2))

    def update_adaptive_threshold(self, current_rms):
        """Update adaptive threshold based on recent audio levels"""
        self.audio_levels_buffer.append(current_rms)

        # Keep only recent audio levels
        if len(self.audio_levels_buffer) > SILENCE_BUFFER_SIZE:
            self.audio_levels_buffer.pop(0)

        # Calculate adaptive threshold from recent audio levels
        if len(self.audio_levels_buffer) >= 5:  # Need at least 5 samples
            avg_level = np.mean(self.audio_levels_buffer)
            self.adaptive_threshold = max(
                MIN_SILENCE_THRESHOLD,
                min(MAX_SILENCE_THRESHOLD, avg_level *
                    ADAPTIVE_THRESHOLD_MULTIPLIER)
            )

    def detect_silence(self, audio_chunk):
        """Detect if audio chunk contains silence using adaptive threshold"""
        rms = self.calculate_rms(audio_chunk)

        # Update adaptive threshold during recording
        if self.is_recording:
            self.update_adaptive_threshold(rms)

        # Use adaptive threshold if available, otherwise fall back to fixed threshold
        threshold = self.adaptive_threshold if self.is_recording else self.silence_threshold

        # Debug output (uncomment for troubleshooting)
        if self.silence_debug_enabled and self.is_recording and self.silence_counter % 10 == 0:  # Log every 10th chunk
            self.console.print(
                f"[dim]RMS: {rms:.4f}, Threshold: {threshold:.4f}, Counter: {self.silence_counter}")

        return rms < threshold

    def process_wake_word_detection(self):
        """Process audio for wake word detection"""
        keyword_buffer_max_len = int(KEYWORD_BUFFER_DURATION * SAMPLE_RATE)

        while not self.stop_event.is_set():
            try:
                # Get audio chunk from queue (with timeout to check stop_event)
                audio_chunk = self.audio_queue.get(timeout=0.1)
                audio_chunk_flat = audio_chunk.flatten().astype(np.int16)

                if self.is_listening and not self.is_recording and not self.is_processing:
                    # Update keyword buffer (rolling window)
                    self.keyword_buffer = np.append(
                        self.keyword_buffer, audio_chunk_flat)
                    if len(self.keyword_buffer) > keyword_buffer_max_len:
                        self.keyword_buffer = self.keyword_buffer[-keyword_buffer_max_len:]

                    # Check for wake word
                    prediction = self.wake_word_model.predict(audio_chunk_flat)

                    # Get the confidence score for jarvis model
                    jarvis_score = 0.0
                    for model_name, score in prediction.items():
                        if 'jarvis' in model_name.lower():
                            jarvis_score = score
                            break

                    if jarvis_score >= WAKE_WORD_CONFIDENCE_THRESHOLD:
                        self.console.print(
                            f"[green]< Wake word detected! (confidence: {jarvis_score:.3f})")
                        # Clear audio buffer and start recording
                        self._clear_audio_buffer()
                        self._start_recording()

                elif self.is_recording and not self.is_processing:
                    # Add to recording buffer
                    self.recording_buffer.append(audio_chunk_flat)

                    # Check for silence to stop recording
                    if self.detect_silence(audio_chunk_flat):
                        self.silence_counter += 1
                        if self.silence_counter >= SILENCE_DURATION_BLOCKS:
                            self.console.print(
                                "[yellow]Silence detected, stopping recording")
                            self._stop_recording()
                    else:
                        self.silence_counter = 0  # Reset silence counter

            except Empty:
                # Timeout occurred, continue loop to check stop_event
                continue
            except Exception as e:
                self.console.print(f"[red]Error in wake word processing: {e}")
                self._reset_state()

    def _start_recording(self):
        """Start recording user speech"""
        self.is_recording = True
        self.is_listening = False
        self.recording_buffer = []
        self.silence_counter = 0

        # Reset adaptive threshold for new recording
        self.audio_levels_buffer = []
        self.adaptive_threshold = SILENCE_THRESHOLD

        # Reset wake word model buffers to avoid leftover frames affecting subsequent detections
        if self.wake_word_model:
            try:
                self.wake_word_model.reset()
            except Exception as e:
                self.console.print(
                    f"[red]Warning: Failed to reset wake word model: {e}")

        self.console.print("[yellow]< Recording... (speak now)")

    def _stop_recording(self):
        """Stop recording and process the speech"""
        self.is_recording = False
        self.is_processing = True

        # Process recording in separate thread to avoid blocking audio
        processing_thread = threading.Thread(target=self._process_recording)
        processing_thread.start()

    def _process_recording(self):
        """Process the recorded audio"""
        try:
            if not self.recording_buffer:
                self.console.print("[red]No audio recorded")
                self._reset_state()
                return

            # Combine all recorded chunks
            full_recording = np.concatenate(self.recording_buffer)
            audio_float = full_recording.astype(np.float32) / 32768.0

            self.console.print("[cyan]Transcribing audio...")

            # Transcribe with Whisper
            with Status("Transcribing...", spinner="earth", console=self.console):
                result = self.whisper_model.transcribe(audio_float, fp16=False)
                transcribed_text = result["text"].strip()

            if not transcribed_text:
                self.console.print("[yellow]No speech detected")
                self._reset_state()
                return

            self.console.print(f"[yellow]You: {transcribed_text}")

            # Process with LLM
            self._process_command(transcribed_text)

        except Exception as e:
            self.console.print(f"[red]Error processing recording: {e}")
            self._reset_state()
        finally:
            if self.is_processing:
                self._reset_state()

    def _process_command(self, text):
        """Process user command with LLM and generate response"""
        try:
            # Get abstraction response to categorize the command
            with Status("Analyzing command...", spinner="earth", console=self.console):
                abstraction_result = LLMInterface.get_abstraction_response(
                    text)

            if not abstraction_result:
                # Fall back to general chatbot response
                with Status("Generating response...", spinner="earth", console=self.console):
                    response = LLMInterface.get_live_chatbot_response(text)
                self._speak_response(response)
                return

            # Process based on abstraction result
            response = None
            for command in abstraction_result:
                command = command.lower().strip()

                SYSTEM_COMMANDS = ["system", "play", "open", "close"]

                # MacOS System Commands
                for cmd in SYSTEM_COMMANDS:
                    if command.startswith(cmd):
                        response = self.system_automation._process_command(
                            command, text)
                        break

                # Generalized Commands
                if any(cmd in command for cmd in ["google search", "youtube search", "spotify search"]):
                    # Handle search commands
                    response = LLMInterface.get_live_chatbot_response(text)
                    break
                elif command.startswith("general"):
                    # Handle general conversation
                    response = LLMInterface.get_live_chatbot_response(text)
                    break

            if not response:
                response = LLMInterface.get_live_chatbot_response(text)

            self._speak_response(response)

        except Exception as e:
            self.console.print(f"[red]Error processing command: {e}")
            self._speak_response(
                "Sorry, I encountered an error processing your request.")
        finally:
            self._reset_state()

    def _speak_response(self, response):
        """Convert response to speech and play it"""
        try:
            self.console.print(f"[cyan]Assistant: {response}")
            with Status("Speaking...", spinner="dots", console=self.console):
                self.tts.stream_tts(response, speed=-0.2)
        except Exception as e:
            self.console.print(f"[red]Error with TTS: {e}")

    def _clear_audio_buffer(self):
        """Clear the audio queue to remove any residual audio"""
        try:
            while not self.audio_queue.empty():
                self.audio_queue.get_nowait()
        except Empty:
            pass

    def _reset_state(self):
        """Reset assistant state to listening mode"""
        self.is_listening = True
        self.is_recording = False
        self.is_processing = False
        self.recording_buffer = []
        self.silence_counter = 0
        self.keyword_buffer = np.array([], dtype=np.float32)

        # Reset adaptive threshold
        self.audio_levels_buffer = []
        self.adaptive_threshold = SILENCE_THRESHOLD

        # Clear audio queue to prevent residual audio from affecting next detection
        self._clear_audio_buffer()

        # Reset wake word model buffers to avoid residual frames influencing future detections
        if self.wake_word_model:
            try:
                self.wake_word_model.reset()
            except Exception as e:
                self.console.print(
                    f"[red]Warning: Failed to reset wake word model: {e}")

        self.console.print("[green]= Listening for wake word...")

    def enable_silence_debug(self, enabled=True):
        """Enable or disable debug output for silence detection"""
        self.silence_debug_enabled = enabled
        if enabled:
            self.console.print("[cyan]Silence detection debug mode enabled")
        else:
            self.console.print("[cyan]Silence detection debug mode disabled")

    def start(self):
        """Start the voice assistant"""
        try:
            self.console.print(
                "[bold green]> Jarvis Voice Assistant Starting...")
            self.console.print("[cyan]Initializing audio stream...")

            # Start audio stream
            self.audio_stream = sd.InputStream(
                samplerate=SAMPLE_RATE,
                blocksize=CHUNK_SIZE,
                device=None,  # Use default device
                channels=CHANNELS,
                dtype='int16',
                callback=self.audio_callback
            )

            self.audio_stream.start()
            self.console.print("[green] Audio stream started")

            # Start wake word detection in separate thread
            wake_word_thread = threading.Thread(
                target=self.process_wake_word_detection)
            wake_word_thread.daemon = True
            wake_word_thread.start()

            self.console.print(
                "[bold green]< Ready! Say 'Jarvis' to activate...")
            self._reset_state()

            # Keep main thread alive
            try:
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                self.console.print("\n[yellow]Shutting down...")
                self.stop()

        except Exception as e:
            self.console.print(f"[red]Error starting voice assistant: {e}")
            self.stop()

    def stop(self):
        """Stop the voice assistant"""
        self.stop_event.set()

        if self.audio_stream:
            self.audio_stream.stop()
            self.audio_stream.close()

        self.console.print("[green]Voice assistant stopped")


if __name__ == "__main__":
    assistant = VoiceAssistant()
    assistant.start()
