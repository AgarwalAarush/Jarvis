import time
import threading
import numpy as np
import whisper
import sounddevice as sd
from queue import Queue
from rich.console import Console
from langchain_ollama import OllamaLLM
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.messages import HumanMessage, AIMessage
from langchain_community.chat_message_histories import ChatMessageHistory
from langchain_core.runnables.history import RunnableWithMessageHistory
# Import the Google Cloud TTS service
from google_cloud_tts_service import GoogleCloudTTSService

console = Console()
stt = whisper.load_model("base.en")
# Initialize the Google Cloud TTS service
tts = GoogleCloudTTSService(cache_dir="./tts_cache")
# Set parameters using Google Cloud's range: speaking_rate (0.25-4.0), pitch (-20.0-20.0), volume_gain_db (-96.0-16.0)
tts.set_speech_parameters(speaking_rate=1.5, pitch_shift=0.0, energy=0.0)

# Update template to use chat format
prompt = ChatPromptTemplate.from_messages([
    ("system", """You are a helpful and friendly AI assistant. You are polite, respectful, and aim to provide concise responses of up to 3 sentences unless prompted otherwise. You are an expert in all things related to programming, machine learning, and software development. Unless instructed to do so otherwise, output everything in plain english, not in markdown."""),
    MessagesPlaceholder(variable_name="history"),
    ("human", "{input}")
])

# Setup chat history store
def get_message_history():
    return ChatMessageHistory()

# Create the chain with message history
chain_model = OllamaLLM(model="llama3.2")
chain = prompt | chain_model
chain_with_history = RunnableWithMessageHistory(
    chain,
    get_message_history,
    input_messages_key="input",
    history_messages_key="history"
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
    Generates a response to the given text using the Llama language model.

    Args:
        text (str): The input text to be processed.

    Returns:
        str: The generated response.
    """
    response = chain_with_history.invoke(
        {"input": text},
        config={"configurable": {"session_id": "default"}}
    )
    return response


def play_audio(sample_rate, audio_data):
    """
    Plays the given audio data using the appropriate method.

    Args:
        sample_rate (int): The sample rate of the audio data.
        audio_data (numpy.ndarray or str or list): The audio data or file path(s).

    Returns:
        None
    """
    # Handle numpy arrays
    if isinstance(audio_data, np.ndarray):
        sd.play(audio_data, sample_rate)
        sd.wait()
        return
    
    # Handle lists of files
    if isinstance(audio_data, list):
        console.print(f"[cyan]Playing {len(audio_data)} audio segments sequentially")
        for i, audio_file in enumerate(audio_data):
            if os.path.exists(audio_file):
                console.print(f"[cyan]Playing segment {i+1}/{len(audio_data)}")
                play_audio_file(audio_file)
        return
    
    # Handle single file paths
    if isinstance(audio_data, str) and os.path.exists(audio_data):
        play_audio_file(audio_data)
        return
    
    console.print(f"[red]Unable to play audio: {audio_data}")


def play_audio_file(file_path):
    """
    Plays an audio file using the appropriate method for the current platform.

    Args:
        file_path (str): Path to the audio file.

    Returns:
        None
    """
    import platform
    system = platform.system().lower()
    
    if system == 'darwin':  # macOS
        console.print(f"[green]Playing audio with afplay: {file_path}")
        os.system(f"afplay {file_path}")
    elif system == 'linux':
        console.print(f"[green]Playing audio with xdg-open: {file_path}")
        os.system(f"xdg-open {file_path}")
    elif system == 'windows':
        console.print(f"[green]Playing audio with start: {file_path}")
        os.system(f"start {file_path}")
    else:
        console.print(f"[red]Unsupported platform: {system}")


def on_segment_played(segment, total, is_complete):
    """
    Callback function for playback progress updates.
    
    Args:
        segment (int): The current segment number
        total (int): Total number of segments
        is_complete (bool): Whether playback is complete
    """
    if total > 0:
        if is_complete:
            console.print(f"[green]✓ All {total} segments played")
        else:
            console.print(f"[cyan]Playing segment {segment}/{total}")


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
                
                # Text-to-speech step with Google Cloud TTS using threaded playback
                start_time = time.time()
                with console.status("Converting to speech and playing in real-time...", spinner="dots"):
                    # Using the same voice as in the example (en-US-Chirp3-HD-Aoede)
                    playback_thread = tts.long_form_synthesize_threaded(
                        response, 
                        voice_preset="female",  # Maps to en-US-Chirp3-HD-Aoede
                        language="en-US",
                        speed=1.0,      # Default speaking rate
                        pitch=0.0,      # Default pitch
                        energy=0.0,     # Default volume gain
                        progress_callback=on_segment_played
                    )
                    
                    # Wait for playback to complete
                    playback_thread.join()
                    
                tts_time = time.time() - start_time
                console.print(f"[green]✓ Speech synthesis and playback completed in {tts_time:.2f} seconds")
                
                # Total processing time
                console.print(f"[blue]Total processing time: {transcription_time + llm_time + tts_time:.2f} seconds")
            else:
                console.print(
                    "[red]No audio recorded. Please ensure your microphone is working."
                )

    except KeyboardInterrupt:
        # Stop any ongoing playback
        tts.stop_threaded_playback()
        console.print("\n[red]Exiting...")

    console.print("[blue]Session ended.")