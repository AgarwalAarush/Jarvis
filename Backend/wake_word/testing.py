# Imports
import numpy as np
import sounddevice as sd
import argparse
import os
import sys
import threading
import queue
import time
from model import Model

# Add the current directory to the path so we can import the local modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Parse input arguments
parser = argparse.ArgumentParser()
parser.add_argument(
    "--chunk_size",
    help="How much audio (in number of samples) to predict on at once",
    type=int,
    default=1280,
    required=False
)
parser.add_argument(
    "--inference_framework",
    help="The inference framework to use (either 'onnx' or 'tflite'",
    type=str,
    default='onnx',
    required=False
)
parser.add_argument(
    "--device",
    help="Audio input device ID (use -1 for default)",
    type=int,
    default=-1,
    required=False
)

args = parser.parse_args()

# Audio configuration
CHANNELS = 1
RATE = 16000
CHUNK = args.chunk_size
DTYPE = np.int16

# Global variables for audio streaming
audio_queue = queue.Queue()
stream = None
stop_stream = False


def audio_callback(indata, frames, time, status):
    """Callback function for continuous audio streaming"""
    if status:
        print(f"Audio callback status: {status}")
    if not stop_stream:
        audio_queue.put(indata.copy())


def start_audio_stream():
    """Start the continuous audio stream"""
    global stream
    try:
        stream = sd.InputStream(
            samplerate=RATE,
            channels=CHANNELS,
            dtype=DTYPE,
            device=args.device,
            blocksize=CHUNK,
            callback=audio_callback
        )
        stream.start()
        return True
    except Exception as e:
        print(f"Error starting audio stream: {e}")
        return False


def stop_audio_stream():
    """Stop the continuous audio stream"""
    global stream, stop_stream
    stop_stream = True
    if stream:
        stream.stop()
        stream.close()


def get_audio_chunk():
    """Get the next audio chunk from the queue"""
    try:
        # Wait for audio data with a timeout
        audio_data = audio_queue.get(timeout=1.0)
        return audio_data.flatten()
    except queue.Empty:
        # Return silence if no audio data available
        return np.zeros(CHUNK, dtype=DTYPE)


# Run capture loop continuosly, checking for wakewords
if __name__ == "__main__":
    # Print available audio devices
    print("Available audio input devices:")
    devices = sd.query_devices()
    input_devices = []
    for i, device in enumerate(devices):
        if device['max_input_channels'] > 0:
            print(f"  {i}: {device['name']}")
            input_devices.append(i)

    if not input_devices:
        print("No input devices found!")
        sys.exit(1)

    # Use the first available input device if default device fails
    if args.device == -1:
        args.device = input_devices[0]
        print(f"Using first available input device: {args.device}")
    elif args.device not in input_devices:
        print(
            f"Device {args.device} not found. Using first available device: {input_devices[0]}")
        args.device = input_devices[0]

    print(f"\nUsing device: {args.device} ({devices[args.device]['name']})")

    # Get the path to the jarvis model
    current_dir = os.path.dirname(os.path.abspath(__file__))
    model_path = os.path.join(current_dir, "models", "jarvis.onnx")

    if not os.path.exists(model_path):
        print(f"Model not found at: {model_path}")
        sys.exit(1)

    print(f"Loading model from: {model_path}")

    # Load pre-trained openwakeword models
    try:
        owwModel = Model(wakeword_models=[model_path],
                         inference_framework=args.inference_framework)
        n_models = len(owwModel.models.keys())
        print(f"Loaded {n_models} model(s)")
    except Exception as e:
        print(f"Error loading model: {e}")
        sys.exit(1)

    # Start the audio stream
    if not start_audio_stream():
        print("Failed to start audio stream")
        sys.exit(1)

    print("Audio stream started successfully")

    # Generate output string header
    print("\n\n")
    print("#"*100)
    print("Listening for wakewords...")
    print("#"*100)
    print("\n"*(n_models*3))

    try:
        while True:
            # Get audio chunk from the continuous stream
            audio = get_audio_chunk()

            # Feed to openWakeWord model
            prediction = owwModel.predict(audio)

            # Column titles
            n_spaces = 16
            output_string_header = """
                Model Name         | Score | Wakeword Status
                --------------------------------------
                """

            for mdl in owwModel.prediction_buffer.keys():
                # Add scores in formatted table
                scores = list(owwModel.prediction_buffer[mdl])
                curr_score = format(scores[-1], '.20f').replace("-", "")

                output_string_header += f"""{mdl}{" "*(n_spaces - len(mdl))}   | {curr_score[0:5]} | {"--"+" "*20 if scores[-1] <= 0.5 else "Wakeword Detected!"}
                """

            # Print results table
            print("\033[F"*(4*n_models+1))
            print(output_string_header, "                             ", end='\r')
    except KeyboardInterrupt:
        print("\n\nStopping wake word detection...")
    finally:
        stop_audio_stream()
        print("Audio stream stopped")
        sys.exit(0)
