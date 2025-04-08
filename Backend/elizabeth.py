import time
import threading
import numpy as np
import whisper
import sounddevice as sd
import os
from queue import Queue
from rich.console import Console
from langchain_ollama import OllamaLLM
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.messages import HumanMessage, AIMessage
from langchain_community.chat_message_histories import ChatMessageHistory
from langchain_core.runnables.history import RunnableWithMessageHistory

from dotenv import load_dotenv
load_dotenv()

# Import TTS Service
from cartesia_tts import CartesiaTTS

# initialize tts
tts = CartesiaTTS(
	voice = os.environ.get("CARTESIA_VOICE", "Joan"),
)

tts_service = "cartesia"

# initialize Console
console = Console()

# initialize whisper
stt = whisper.load_model("base.en")

console.print(f"[cyan] Using {tts_service.capitalize()} TTS Service")
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

if __name__ == "__main__":
    console.print("[cyan]Assistant started! Press Ctrl+C to exit.")

    try:
        while True:
            console.input(
                "Please press Enter to start recording, then press Enter again to stop"
            )

            data_queue = Queue() # type: ignore[var-annotated]
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

                # Text to Speech
                start_time = time.time()
                with console.status("Converting to speech and playing in real-time...", spinner="dots"):
                    tts.stream_tts(response, speed=-0.2)

                tts_time = time.time() - start_time
                console.print(f"[green]✓ Speech synthesis and playback completed in {tts_time:.2f} seconds")

                # Total processing time
                console.print(f"[blue]Total processing time: {transcription_time + llm_time + tts_time:.2f} seconds")
            else:
                console.print("[red]No audio data captured. Please ensure your microphone is working.")
    except KeyboardInterrupt:
        console.print("\n[red]Exiting...")
            
    console.print("[blue]Session ended...")
