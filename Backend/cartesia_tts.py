import os
import numpy as np
import sounddevice as sd
import base64
from cartesia import Cartesia
from cartesia.tts import Controls, OutputFormat_RawParams, TtsRequestIdSpecifierParams

from dotenv import load_dotenv
load_dotenv()

voices = {
    "Joan": "5abd2130-146a-41b1-bcdb-974ea8e19f56",
    "DEFAULT": "f9836c6e-a0bd-460e-9d3c-f7299fa60f94"
}


def stream_tts(text: str, voice: str = "DEFAULT", sample_rate: int = 44100, channels: int = 1):
    """
    Streams audio directly from the Cartesia TTS API as the data is received.

    Args:
        text: The transcript to convert to speech.
        voice: The voice key to use from the voices dict.
        sample_rate: Audio sample rate (must match API settings).
        channels: Number of audio channels (default is 1 for mono).
    """
    client = Cartesia(
        api_key=os.getenv("CARTESIA_API_KEY"),
    )
    
    response = client.tts.sse(
        model_id="sonic-2",
        transcript=text,
        voice={
            "id": voices[voice],
            "experimental_controls": {
                "speed": -0.1,
                "emotion": [],
            },
        },
        language="en",
        output_format={
            "container": "raw",
            "encoding": "pcm_f32le",
            "sample_rate": sample_rate,
        },
    )
    
    # Open an output stream for real-time playback
    with sd.OutputStream(samplerate=sample_rate, channels=channels, dtype='float32') as stream:
        for idx, chunk in enumerate(response):
            try:
                # If chunk.data is a string, assume it's base64 encoded
                if isinstance(chunk.data, str):
                    raw_bytes = base64.b64decode(chunk.data)
                else:
                    raw_bytes = chunk.data
                
                # Convert raw bytes to float32 numpy array
                audio_data = np.frombuffer(raw_bytes, dtype=np.float32)
                
                # Write audio data directly to the stream
                stream.write(audio_data)
                print(f"Streamed chunk {idx + 1}: {len(audio_data)} samples")
            except Exception as e:
                print(f"Error streaming chunk {idx + 1}: {e}")


if __name__ == "__main__":
    print("Streaming Cartesia TTS...")
    stream_tts(text="What is a CNN?", voice="Joan")
    print("Streaming complete")