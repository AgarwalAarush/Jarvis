import sounddevice as sd
import numpy as np
import whisper
import queue
import threading
import argparse
import sys
import time

# --- Configuration ---
DEFAULT_KEYWORD = "jarvis"
DEFAULT_MODEL = "tiny"  # Options: tiny, base, small, medium, large
DEFAULT_SAMPLE_RATE = 16000  # Whisper works best with 16kHz
DEFAULT_BLOCK_SIZE = 1024  # Process audio in chunks (adjust based on performance)
DEFAULT_SILENCE_THRESHOLD = 0.01 # RMS amplitude threshold for silence (adjust based on mic/environment)
DEFAULT_SILENCE_BLOCKS = 30    # How many consecutive blocks of silence trigger stop (e.g., ~1.8 seconds with defaults)
KEYWORD_DETECTION_DURATION_S = 1.5 # How many seconds of audio to analyze for the keyword

# --- State Enum ---
class State:
    LISTENING_FOR_ENERGY = 1
    DETECTING_KEYWORD = 2
    RECORDING = 3
    PROCESSING = 4

# --- Global Variables ---
audio_queue = queue.Queue()
recording_buffer = []
current_state = State.LISTENING_FOR_ENERGY
keyword_buffer = np.array([], dtype=np.float32)
silence_counter = 0
args = None # Will hold command line arguments
model = None # Whisper model

# --- Helper Functions ---
def calculate_rms(audio_chunk):
    """Calculates the Root Mean Square (RMS) of an audio chunk."""
    return np.sqrt(np.mean(audio_chunk**2))

def keyword_normalize_text(text):
    """Normalizes text for keyword matching."""
    return text.lower().strip().replace("!", "").replace("?", "").replace(".", "").replace(",", "")

# --- Audio Callback ---
def audio_callback(indata, frames, time, status):
    """This is called (from a separate thread) for each audio block."""
    if status:
        print(status, file=sys.stderr)
    # Add the audio block to the queue for processing in the main thread
    audio_queue.put(indata.copy())

# --- Main Processing Function ---
def process_audio():
    global current_state, recording_buffer, keyword_buffer, silence_counter, model

    print(f"Loading whisper model '{args.model_name}'...")
    try:
        model = whisper.load_model(args.model_name)
        print(f"Model '{args.model_name}' loaded.")
    except Exception as e:
        print(f"Error loading whisper model: {e}", file=sys.stderr)
        print("Ensure you have torch installed and the model name is correct.", file=sys.stderr)
        print("Available models usually include: tiny, base, small, medium, large", file=sys.stderr)
        return # Exit if model can't load

    print(f"\n--- Listening for audio energy (using device: {args.device}) ---")

    keyword_buffer_max_len = int(KEYWORD_DETECTION_DURATION_S * args.sample_rate)
    keyword_activation_threshold = args.silence_threshold * 2 # Need slightly higher energy to trigger keyword check

    while True:
        try:
            # Get audio data from the queue
            audio_chunk = audio_queue.get()
            chunk_rms = calculate_rms(audio_chunk)

            # --- State Machine Logic ---
            if current_state == State.LISTENING_FOR_ENERGY:
                # Keep adding to keyword buffer (rolling)
                keyword_buffer = np.append(keyword_buffer, audio_chunk.flatten())
                if len(keyword_buffer) > keyword_buffer_max_len:
                     keyword_buffer = keyword_buffer[-keyword_buffer_max_len:]

                # Check if the *latest* chunk has enough energy
                if chunk_rms > keyword_activation_threshold:
                    print(f"Energy detected (RMS: {chunk_rms:.4f}). Checking for keyword '{args.keyword}'...")
                    current_state = State.DETECTING_KEYWORD
                    # Keep the current keyword buffer for analysis
                    analysis_buffer = keyword_buffer.copy()
                    # Process the detection in a separate thread to avoid blocking audio queue
                    threading.Thread(target=detect_keyword_in_buffer, args=(analysis_buffer,)).start()

            elif current_state == State.DETECTING_KEYWORD:
                # Still add to keyword buffer while detection runs in background
                # This ensures we don't lose audio if keyword is at the end
                keyword_buffer = np.append(keyword_buffer, audio_chunk.flatten())
                if len(keyword_buffer) > keyword_buffer_max_len:
                     keyword_buffer = keyword_buffer[-keyword_buffer_max_len:]
                # State change happens in detect_keyword_in_buffer if successful

            elif current_state == State.RECORDING:
                recording_buffer.append(audio_chunk)

                # Silence detection
                if chunk_rms < args.silence_threshold:
                    silence_counter += 1
                    if silence_counter >= args.silence_blocks:
                        print(f"\nSilence detected (RMS: {chunk_rms:.4f}). Stopping recording.")
                        current_state = State.PROCESSING
                        # Process the recording in a separate thread
                        threading.Thread(target=transcribe_recording).start()
                        # Reset for next round
                        recording_buffer = []
                        silence_counter = 0
                        keyword_buffer = np.array([], dtype=np.float32) # Clear keyword buffer too
                else:
                    # Reset silence counter if sound is detected
                    silence_counter = 0

            elif current_state == State.PROCESSING:
                # Main loop waits while transcription happens in another thread
                # Keep consuming queue to prevent it from filling up indefinitely
                # while processing, although ideally processing is fast.
                # A small sleep helps prevent busy-waiting if queue is empty
                # but processing thread hasn't finished yet.
                time.sleep(0.05)


        except queue.Empty:
            # This shouldn't happen with a blocking get, but handle defensively
            time.sleep(0.01)
            continue
        except Exception as e:
            print(f"Error during processing: {e}", file=sys.stderr)
            # Reset state on error? Or just log? Let's just log for now.
            # current_state = State.LISTENING_FOR_ENERGY # Optional: Reset state on error
            # recording_buffer = []
            # keyword_buffer = np.array([], dtype=np.float32)


def detect_keyword_in_buffer(buffer_to_check):
    """Transcribes a buffer and checks for the keyword."""
    global current_state, recording_buffer, keyword_buffer

    if model is None:
        print("Whisper model not loaded, cannot detect keyword.", file=sys.stderr)
        current_state = State.LISTENING_FOR_ENERGY # Go back to listening
        return

    if len(buffer_to_check) == 0:
        print("Keyword detection buffer is empty.", file=sys.stderr)
        current_state = State.LISTENING_FOR_ENERGY
        return

    try:
        # Ensure data is float32
        audio_data = buffer_to_check.astype(np.float32)

        # Suppress whisper's normal output during keyword check for cleaner logs
        result = model.transcribe(audio_data, fp16=False, language="en") # fp16=False often more stable on CPU
        detected_text = result['text']
        normalized_text = keyword_normalize_text(detected_text)
        normalized_keyword = keyword_normalize_text(args.keyword)

        print(f"Keyword check transcription: '{detected_text}'")

        if normalized_keyword in normalized_text:
            print(f"Keyword '{args.keyword}' DETECTED!")
            print("--- Starting recording ---")
            current_state = State.RECORDING
            recording_buffer = [buffer_to_check] # Start recording with the keyword buffer
            keyword_buffer = np.array([], dtype=np.float32) # Clear keyword buffer
            # No need to clear silence counter here, will be reset on first non-silent block in RECORDING state
        else:
            print("Keyword not detected.")
            current_state = State.LISTENING_FOR_ENERGY # Go back to listening for energy

    except Exception as e:
        print(f"Error during keyword detection transcription: {e}", file=sys.stderr)
        current_state = State.LISTENING_FOR_ENERGY # Go back to listening on error


def transcribe_recording():
    """Processes the completed recording buffer."""
    global current_state

    if not recording_buffer:
        print("Recording buffer is empty, nothing to transcribe.", file=sys.stderr)
        current_state = State.LISTENING_FOR_ENERGY
        print(f"\n--- Listening for audio energy ---")
        return

    if model is None:
        print("Whisper model not loaded, cannot transcribe.", file=sys.stderr)
        current_state = State.LISTENING_FOR_ENERGY
        print(f"\n--- Listening for audio energy ---")
        return

    print("Processing transcription...")
    # Concatenate all recorded chunks
    full_recording = np.concatenate([chunk.flatten() for chunk in recording_buffer])
    # Ensure data is float32
    audio_data = full_recording.astype(np.float32)

    try:
        # Transcribe
        result = model.transcribe(audio_data, fp16=False, language="en") # fp16=False often more stable on CPU
        transcription = result['text']
        print("\n--- Transcription ---")
        print(transcription)
        print("---------------------\n")

    except Exception as e:
        print(f"Error during transcription: {e}", file=sys.stderr)

    # Reset state to listening after processing
    current_state = State.LISTENING_FOR_ENERGY
    print(f"\n--- Listening for audio energy ---")


# --- Main Execution ---
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Listen for a keyword and transcribe subsequent audio.")
    parser.add_argument("-k", "--keyword", type=str, default=DEFAULT_KEYWORD,
                        help=f"Keyword to trigger recording (default: {DEFAULT_KEYWORD})")
    parser.add_argument("-m", "--model_name", type=str, default=DEFAULT_MODEL,
                        help=f"Whisper model name (default: {DEFAULT_MODEL})")
    parser.add_argument("-sr", "--sample_rate", type=int, default=DEFAULT_SAMPLE_RATE,
                        help=f"Audio sample rate (default: {DEFAULT_SAMPLE_RATE})")
    parser.add_argument("-bs", "--block_size", type=int, default=DEFAULT_BLOCK_SIZE,
                        help=f"Audio block size (default: {DEFAULT_BLOCK_SIZE})")
    parser.add_argument("-st", "--silence_threshold", type=float, default=DEFAULT_SILENCE_THRESHOLD,
                        help=f"RMS amplitude threshold for silence (default: {DEFAULT_SILENCE_THRESHOLD})")
    parser.add_argument("-sb", "--silence_blocks", type=int, default=DEFAULT_SILENCE_BLOCKS,
                        help=f"Consecutive silent blocks to stop recording (default: {DEFAULT_SILENCE_BLOCKS})")
    parser.add_argument("-d", "--device", type=int, default=None,
                        help="Input device ID (integer). Leave blank for default.")
    parser.add_argument("--list_devices", action="store_true",
                        help="List available audio devices and exit.")

    args = parser.parse_args()

    if args.list_devices:
        print("Available audio devices:")
        try:
            print(sd.query_devices())
        except Exception as e:
             print(f"Could not query devices: {e}", file=sys.stderr)
             print("Ensure PortAudio library is installed correctly.", file=sys.stderr)
        sys.exit(0)

    # Start the processing thread
    processing_thread = threading.Thread(target=process_audio)
    processing_thread.daemon = True # Allows program to exit even if thread is running
    processing_thread.start()

    # Start the audio stream
    try:
        with sd.InputStream(samplerate=args.sample_rate,
                            blocksize=args.block_size,
                            device=args.device,
                            channels=1, # Mono input
                            dtype='float32', # Data type for audio
                            callback=audio_callback):
            print("Starting audio stream...")
            # Keep the main thread alive while the processing thread runs
            while processing_thread.is_alive():
                 time.sleep(0.1)

    except KeyboardInterrupt:
        print("\nStopping...")
    except Exception as e:
        parser.exit(f"Error starting audio stream: {e}\n"
                    "Try --list_devices to check available devices.\n"
                    "Ensure your microphone is connected and configured.")

    print("Program finished.")