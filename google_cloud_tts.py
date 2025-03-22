from google.cloud import texttospeech
import os

# Initialize the Text-to-Speech client
client = texttospeech.TextToSpeechClient()

# Set the text to convert to speech
text = "Hello! This is a high-quality text-to-speech voice from Google Cloud."

# Configure the voice request
text_input = texttospeech.SynthesisInput(text=text)

# Select the voice type and language
voice = texttospeech.VoiceSelectionParams(
    language_code="en-US",
    # Available voice types: Standard (basic), WaveNet (neural), Studio (premium)
    # See: https://cloud.google.com/text-to-speech/docs/voices
    name="en-US-Chirp3-HD-Aoede",  # Neural voice - female
    # Other high-quality options:
    # en-US-Neural2-J (male), en-US-Studio-O (female), en-US-Wavenet-H (female), etc.
    # ssml_gender=texttospeech.SsmlVoiceGender.FEMALE
)

# Configure the audio settings
audio_config = texttospeech.AudioConfig(
    audio_encoding=texttospeech.AudioEncoding.MP3,
    speaking_rate=1.0,  # 0.25 to 4.0
    pitch=0.0,          # -20.0 to 20.0
    volume_gain_db=0.0  # -96.0 to 16.0
)

# Generate the speech
response = client.synthesize_speech(input=text_input, voice=voice, audio_config=audio_config)

# Save the audio to a file
output_file = "google_cloud_tts_output.mp3"
with open(output_file, "wb") as out:
    out.write(response.audio_content)

print(f"Audio content written to '{output_file}'")

# Play the audio (Mac)
os.system(f"afplay {output_file}")

# print("\nAvailable voices:")
# voices = client.list_voices()
# for voice in voices.voices:
#     if "en-US" in voice.language_codes:
#         print(f"Name: {voice.name}, Gender: {voice.ssml_gender}, Natural: {voice.natural_sample_rate_hertz > 0}")
