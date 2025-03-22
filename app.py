import time
import threading
import numpy as np
import whisper
import sounddevice as sd
from queue import Queue
from rich.console import Console
from langchain.prompts import PromptTemplate
from langchain_ollama import OllamaLLM
from langchain_core.messages import AIMessage, HumanMessage
from langchain.memory import ConversationBufferMemory
from langchain.chains import ConversationChain
# Import the simplified XTTS service that works with minimal dependencies
from simple_xtts_service import SimpleXTTSService

console = Console()
stt = whisper.load_model("base.en")
# Use the simplified XTTS service as a drop-in replacement
tts = SimpleXTTSService(cache_dir="./tts_cache")

template = """
You are a helpful and friendly AI assistant. You are polite, respectful, and aim to provide concise responses.

The conversation transcript is as follows:
{history}

And here is the user's follow-up: {input}

Your response:
"""
PROMPT = PromptTemplate(input_variables=["history", "input"], template=template)
chain = ConversationChain(
    prompt=PROMPT,
    verbose=False,
    memory=ConversationBufferMemory(ai_prefix="Assistant:"),
    llm=OllamaLLM(model="llama3.2"),
)


def record_audio(stop_event, data_queue):
    """
    Captures audio data from the user's microphone and adds it to a queue for further processing.

    Args:
        stop_event (threading.Event): An event that, when set, signals the function to stop recording.
        data_queue (queue.Queue): A queue to which the recorded audio data will be added.

    Returns:
        None
    """
    def callback(indata, frames, time, status):
        if status:
            console.print(status)
        data_queue.put(bytes(indata))

    with sd.RawInputStream(
        samplerate=16000, dtype="int16", channels=1, callback=callback
    ):
        while not stop_event.is_set():
            time.sleep(0.1)


def transcribe(audio_np: np.ndarray) -> str:
    """
    Transcribes the given audio data using the Whisper speech recognition model.

    Args:
        audio_np (numpy.ndarray): The audio data to be transcribed.

    Returns:
        str: The transcribed text.
    """
    result = stt.transcribe(audio_np, fp16=False)  # Set fp16=True if using a GPU
    text = result["text"].strip()
    return text


def get_llm_response(text: str) -> str:
    """
    Generates a response to the given text using the Llama-2 language model.

    Args:
        text (str): The input text to be processed.

    Returns:
        str: The generated response.
    """
    response = chain.predict(input=text)
    if response.startswith("Assistant:"):
        response = response[len("Assistant:") :].strip()
    return response


def play_audio(sample_rate, audio_array):
    """
    Plays the given audio data using the sounddevice library.

    Args:
        sample_rate (int): The sample rate of the audio data.
        audio_array (numpy.ndarray): The audio data to be played.

    Returns:
        None
    """
    sd.play(audio_array, sample_rate)
    sd.wait()


if __name__ == "__main__":
    console.print("[cyan]Assistant started! Press Ctrl+C to exit.")

    try:
        while True:
            console.input(
                "Press Enter to start recording, then press Enter again to stop."
            )

            data_queue = Queue()  # type: ignore[var-annotated]
            stop_event = threading.Event()
            recording_thread = threading.Thread(
                target=record_audio,
                args=(stop_event, data_queue),
            )
            recording_thread.start()

            input()
            stop_event.set()
            recording_thread.join()

            audio_data = b"".join(list(data_queue.queue))
            audio_np = (
                np.frombuffer(audio_data, dtype=np.int16).astype(np.float32) / 32768.0
            )

            if audio_np.size > 0:
                # Transcription step
                start_time = time.time()
                with console.status("Transcribing...", spinner="earth"):
                    text = transcribe(audio_np)
                transcription_time = time.time() - start_time
                console.print(f"[yellow]You: {text}")
                console.print(f"[green]✓ Transcription completed in {transcription_time:.2f} seconds")
                
                # LLM response step
                start_time = time.time()
                with console.status("Generating response...", spinner="earth"):
                    response = get_llm_response(text)
                llm_time = time.time() - start_time
                console.print(f"[cyan]Assistant: {response}")
                console.print(f"[green]✓ LLM response generated in {llm_time:.2f} seconds")
                
                # Text-to-speech step with improved performance
                start_time = time.time()
                with console.status("Converting to speech (with caching)...", spinner="earth"):
                    # Using female voice preset with English language
                    sample_rate, audio_array = tts.long_form_synthesize(response, voice_preset="female", language="en")
                tts_time = time.time() - start_time
                console.print(f"[green]✓ Speech synthesis completed in {tts_time:.2f} seconds")
                
                # Stats about the audio
                audio_length = len(audio_array) / sample_rate
                real_time_factor = tts_time / audio_length if audio_length > 0 else 0
                console.print(f"[blue]Audio length: {audio_length:.2f} seconds")
                console.print(f"[blue]Real-time factor: {real_time_factor:.2f}x (lower is better)")
                
                # Play the audio
                play_audio(sample_rate, audio_array)
                
                # Total processing time
                console.print(f"[blue]Total processing time: {transcription_time + llm_time + tts_time:.2f} seconds")
            else:
                console.print(
                    "[red]No audio recorded. Please ensure your microphone is working."
                )

    except KeyboardInterrupt:
        console.print("\n[red]Exiting...")

    console.print("[blue]Session ended.")