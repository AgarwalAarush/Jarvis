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

# Import TTS Service
from cartesia_tts import stream_tts

# initialize Console
console = Console()

# initialize whisper
stt = whisper.load_model("base.en")
