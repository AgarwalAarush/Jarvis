import os
import subprocess
import webbrowser
from search import SearchInterface
from file_interaction import FileSystem

class AutomationClient:

    def __init__(self, config: dict):
        """
        Initialize the AutomationClient with a configuration dictionary.

        Args:
            config: A dictionary containing configuration settings
        """
        self.VOLUME_STEP = config.get('VOLUME_STEP', 20)
        self.BRIGHTNESS_UP_KEYCODE = 144
        self.BRIGHTNESS_DOWN_KEYCODE = 145

    def open_url(url: str):
        webbrowser.open(url)

    def run_command(command: str):
        subprocess.run(command, shell=True)

    def increase_volume():
        script = f"set volume output volume (output volume of (get volume settings) + {self.VOLUME_STEP})"
        subprocess.run(['osascript', '-e', script], capture_output=True)

    def decrease_volume():
        script = f"set volume output volume (output volume of (get volume settings) - {self.VOLUME_STEP})"
        subprocess.run(['osascript', '-e', script], capture_output=True)

    def increase_brightness():
        """
        Increases screen brightness by simulating the brightness up key press.
        May require Accessibility permissions and might only affect the primary display.
        """
        print("Increasing brightness (simulating key press)...")
        script = f'tell application "System Events" to key code {self.BRIGHTNESS_UP_KEYCODE}'
        subprocess.run(['osascript', '-e', script], capture_output=True)

    def decrease_brightness():
        """
        Decreases screen brightness by simulating the brightness down key press.
        May require Accessibility permissions and might only affect the primary display.
        """
        print("Decreasing brightness (simulating key press)...")
        script = f'tell application "System Events" to key code {self.BRIGHTNESS_DOWN_KEYCODE}'
        subprocess.run(['osascript', '-e', script], capture_output=True)

    def open_app(app_name):
        """
        Opens a macOS application.
        Provide the application name (e.g., "TextEdit", "Google Chrome")
        or the full path to the .app bundle.
        """
        print(f"Attempting to open '{app_name}'...")
        try:
            # Using '-a' is generally preferred for finding apps by name
            subprocess.run(['open', '-a', app_name], check=True)
            print(f"Successfully launched or switched to '{app_name}'.")
        except subprocess.CalledProcessError as e:
            print(f"Error opening '{app_name}': {e}. Is it installed and named correctly?")
        except FileNotFoundError:
            print("Error: 'open' command not found. Is this a macOS system?")
        except Exception as e:
            print(f"An unexpected error occurred opening {app_name}: {e}")

    def close_app(app_name):
        """
        Closes (quits) a running macOS application.
        Provide the exact application name (case-sensitive usually matters for AppleScript).
        """
        print(f"Attempting to close '{app_name}'...")
        # AppleScript usually doesn't want the .app extension
        if app_name.lower().endswith(".app"):
            app_name = app_name[:-4]

        script = f'quit app "{app_name}"'
        result = subprocess.run(['osascript', '-e', script], capture_output=True)
        if result.returncode == 0:
            print(f"Sent quit command to '{app_name}'.")
        else:
            print(f"Failed to quit '{app_name}' with error: {result.stderr}")

    def run_terminal_command(command: str):
        """
        Runs a command in the macOS Terminal.
        """
        print(f"Terminal Commands TBI")
        # print(f"Running command in terminal: {command}")
        # subprocess.run(['osascript', '-e', f'tell application "Terminal" to do script "{command}"'])
        # print("Command executed.")

    def play_spotify(song: str):
        """
        Play Spotify using AppleScript.
        """

        track_id = None

        # send song to lowercase
        song_retrieval = song.lower()

        # check if song is in songs.json
        songs = FileSystem.retrieve_json("storage/songs.json")
        if song_retrieval in songs:
            track_id = songs[song_retrieval]

        if track_id:
            script = f'''
            tell application "Spotify"
                play track "spotify:track:{track_id}"
            end tell
            '''
            subprocess.run(['osascript', '-e', script])
            return
        else:
            print(f"Song '{song}' not found in memory.")
            # search song, retrieve url
            search_results = SearchInterface.google_search(song + " spotify")
            if search_results:
                first_result = search_results[0]
                # first_result is in the format, "URL: <url> Title: <title> Description: <description>\n\n" retrieve the url
                url = first_result.split("URL: ")[1].split("\n")[0]
                # Extract track ID from the Spotify URL
                if "spotify.com/track/" in url:
                    track_id = url.split("spotify.com/track/")[1].split("?")[0].split()[0].strip()
                    print(f"Playing Spotify track ID: {track_id}")
                    
                # Use AppleScript to control Spotify
                script = f'''
                tell application "Spotify"
                    play track "spotify:track:{track_id}"
                end tell
                '''
                subprocess.run(['osascript', '-e', script])

                # save song to songs.json
                songs = FileSystem.retrieve_json("storage/songs.json")
                songs[song_retrieval] = track_id
                FileSystem.write_json("storage/songs.json", songs)
            else:
                print(f"Could not extract track ID from URL: {url}")
            
if __name__ == "__main__":
    AutomationClient.play_spotify("")
    