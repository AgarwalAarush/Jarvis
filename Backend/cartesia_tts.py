import os
import numpy as np
import sounddevice as sd
import base64
from cartesia import Cartesia

class CartesiaTTS:
    def __init__(self, voice: str = "DEFAULT", model: str = "sonic-2", api_key: str = None):
        # load .env file
        from dotenv import load_dotenv
        load_dotenv()

        # initialize api
        self.api_key = api_key or os.getenv("CARTESIA_API_KEY")
        if not self.api_key:
            raise ValueError("Cartesia API key not found. Please set CARTESIA_API_KEY environment variable or pass api_key parameter.")

        self.voices = {
            "Joan": "5abd2130-146a-41b1-bcdb-974ea8e19f56",
            "DEFAULT": "f9836c6e-a0bd-460e-9d3c-f7299fa60f94"
        }

        self.model = model
        self.voice = voice

        self.client = Cartesia(
            api_key=self.api_key
        )

    def stream_tts(self, text: str, speed: int = 0, sample_rate: int = 44100, channels: int = 1):
        """
        Streams audio directly from the Cartesia TTS API as the data is received.

        Args:
            text: The transcript to convert to speech.
            voice: The voice key to use from the voices dict.
            sample_rate: Audio sample rate (must match API settings).
            channels: Number of audio channels (default is 1 for mono).
        """

        response = self.client.tts.sse(
            model_id=self.model,
            transcript=text,
            voice={
                "id": self.voices[self.voice],
                "experimental_controls": {
                    "speed": speed,
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
                    # print(f"Streamed chunk {idx + 1}: {len(audio_data)} samples")
                except Exception as e:
                    print(f"Error streaming chunk {idx + 1}: {e}")

# if __name__ == "__main__":
#     print("Streaming Cartesia TTS...")
#     tts_service = CartesiaTTS(voice="Joan")
#     tts_service.stream_tts("A CNN, or Convolutional Neural Network, is a type of deep learning model that’s especially good at processing data with a grid-like topology—most commonly used for image and video recognition, but also applied in speech, NLP, and more.")
#     # stream_tts(text="What is a CNN?", voice="Joan")
#     print("Streaming complete")