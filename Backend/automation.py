import json
import subprocess
import webbrowser
from llm_client import LLMClient
from search.search import SearchInterface
from file_interaction import FileSystem


class SystemAutomationClient:

    def __init__(self, config: dict):
        """
        Description: initialize the AutomationClient with a configuration dictionary.
        Args: config: A dictionary containing configuration settings
        """
        self.VOLUME_STEP = config.get('VOLUME_STEP', 20)
        self.BRIGHTNESS_UP_KEYCODE = 144
        self.BRIGHTNESS_DOWN_KEYCODE = 145

        self.FUNCS = {
            "open_url": self.open_url,
            "run_command": self.run_command,
            "increase_volume": self.increase_volume,
            "decrease_volume": self.decrease_volume,
            "mute_volume": self.mute_volume,
            "unmute_volume": self.unmute_volume,
            "increase_brightness": self.increase_brightness,
            "decrease_brightness": self.decrease_brightness,
            "zero_brightness": self.zero_brightness,
            "full_brightness": self.full_brightness,
            "open_app": self.open_app,
            "close_app": self.close_app,
            "get_spotify_track_info": self.get_spotify_track_info,
            "play_spotify": self.play_spotify,
            "google_search": self.google_search
        }

        self.tools_description = "\n".join(
            [f"{name}: {func.__doc__}" for name, func in self.FUNCS.items()])

        self.command_processing_prompt = """
        You are an intelligent assistant that can call tools to help users. Below is a list of available tools:

        {tools_description}\n
        """.format(tools_description=self.tools_description)

        self.command_processing_prompt += """
        When a user asks something, decide which tool (if any) should be called, and return the tool name and arguments in the following format:

        {
          "tool_name": "<name>",
          "arguments": {
            ... key-value pairs ...
          }
        }

        If no tool applies, return:
        {
          "tool_name": null,
          "arguments": {}
        }        
        """

    def _process_command(self, command: str):
        """
        Tool: "_process_command"
        Description: Processes a command to determine if it is a system command (like volume or brightness control) and executes it if applicable.
        Args:
            command: The command to process.
        """
        try:
            llm_prompt = self.command_processing_prompt + \
                "\n The following is the user command and prompt: " + command
            tool_call = LLMClient.get_response(llm_prompt)
            try:
                json_str = tool_call[tool_call.find(
                    "{"): tool_call.rfind("}") + 1]
                tool_data = json.loads(json_str)
            except (ValueError, json.JSONDecodeError):
                print(f"Error parsing JSON: {tool_call}")
                return "Unable to understand system tool call"

            print(tool_data)
            tool_name = tool_data.get("tool_name")
            if tool_name:
                tool_func = self.FUNCS.get(tool_name)
                if tool_func:
                    result = tool_func(**tool_data.get("arguments", {}))
                    return result
                else:
                    return "Tool not found"
            else:
                return "Tool name not found"
        except Exception as e:
            return f"Error executing system command: {e}"

    def open_url(self, url: str):
        """
        Tool: "open_url"
        Description: Opens a URL in the default web browser.
        Args:
            url: The URL to open.
        """
        webbrowser.open(url)
        return "Opened URL"

    def run_command(self, command: str):
        """
        Tool: "run_command"
        Description: Runs a shell command.
        Args:
            command: The shell command to run.
        """
        subprocess.run(command, shell=True)
        return "Command executed"

    def increase_volume(self):
        """
        Tool: "increase_volume"
        Description: Increases the system volume by a predefined step.
        Args:
            None
        """
        script = f"set volume output volume (output volume of (get volume settings) + {self.VOLUME_STEP})"
        subprocess.run(['osascript', '-e', script], capture_output=True)
        return "Volume increased"

    def decrease_volume(self):
        """
        Tool: "decrease_volume"
        Description: Decreases the system volume by a predefined step.
        Args:
            None
        """
        script = f"set volume output volume (output volume of (get volume settings) - {self.VOLUME_STEP})"
        subprocess.run(['osascript', '-e', script], capture_output=True)
        return "Volume decreased"

    def mute_volume(self):
        """
        Tool: "mute_volume"
        Description: Mutes the system volume.
        Args:
            None
        """
        script = "set volume output muted true"
        subprocess.run(['osascript', '-e', script], capture_output=True)
        return "Volume muted"

    def unmute_volume(self):
        """
        Tool: "unmute_volume"
        Description: Unmutes the system volume.
        Args:
            None
        """
        script = "set volume output muted false"
        subprocess.run(['osascript', '-e', script], capture_output=True)
        return "Volume unmuted"

    def increase_brightness(self):
        """
        Tool: "increase_brightness"
        Description: Increases the screen brightness by simulating a key press.
        Args:
            None
        """
        script = f'tell application "System Events" to key code {self.BRIGHTNESS_UP_KEYCODE}'
        subprocess.run(['osascript', '-e', script], capture_output=True)
        return "Brightness increased"

    def decrease_brightness(self):
        """
        Tool: "decrease_brightness"
        Description: Decreases the screen brightness by simulating a key press.
        Args:
            None
        """
        script = f'tell application "System Events" to key code {self.BRIGHTNESS_DOWN_KEYCODE}'
        subprocess.run(['osascript', '-e', script], capture_output=True)
        return "Brightness decreased"

    def zero_brightness(self):
        """
        Tool: "zero_brightness"
        Description: Sets the screen brightness to zero.
        Args:
            None
        """
        script = f'tell application "System Events" to key code {self.BRIGHTNESS_DOWN_KEYCODE}'
        for _ in range(10):
            subprocess.run(['osascript', '-e', script], capture_output=True)
        return "Brightness set to 0"

    def full_brightness(self):
        """
        Tool: "full_brightness"
        Description: Sets the screen brightness to 100%.
        Args:
            None
        """
        script = "set brightness 100"
        subprocess.run(['osascript', '-e', script], capture_output=True)
        return "Brightness set to 100"

    def open_app(self, app_name):
        """
        Tool: "open_app"
        Description: Opens a macOS application.        
        Args:
            app_name: The name of the application to open (e.g., "Safari", "Terminal").
        """
        print(f"Attempting to open '{app_name}'...")
        try:
            # Using '-a' is generally preferred for finding apps by name
            subprocess.run(['open', '-a', app_name], check=True)
            print(f"Successfully launched or switched to '{app_name}'.")
            return f"Opened {app_name}"
        except subprocess.CalledProcessError as e:
            print(
                f"Error opening '{app_name}': {e}. Is it installed and named correctly?")
        except FileNotFoundError:
            print("Error: 'open' command not found. Is this a macOS system?")
        except Exception as e:
            print(f"An unexpected error occurred opening {app_name}: {e}")
        return f"Failed to open {app_name}"

    def close_app(self, app_name):
        """
        Tool: "close_app"
        Description: Closes (quits) a running macOS application.
        Args:
            app_name: The name of the application to close (e.g., "Safari", "Terminal").
        """
        print(f"Attempting to close '{app_name}'...")
        # AppleScript usually doesn't want the .app extension
        if app_name.lower().endswith(".app"):
            app_name = app_name[:-4]

        script = f'quit app "{app_name}"'
        result = subprocess.run(
            ['osascript', '-e', script], capture_output=True)
        if result.returncode == 0:
            print(f"Sent quit command to '{app_name}'.")
            return f"Closed {app_name}"
        else:
            print(f"Failed to quit '{app_name}' with error: {result.stderr}")
            return f"Failed to close {app_name}"

    def get_spotify_track_info(self):
        """
        Tool: "get_spotify_track_info"
        Description: retrieves the currently playing track's name and artist from Spotify.
        Args:
            None
        """
        script = '''
        tell application "Spotify"
            if it is running then
                set trackName to name of current track
                set trackArtist to artist of current track
                return trackName & " by " & trackArtist
            else
                return "Spotify is not running."
            end if
        end tell
        '''
        result = subprocess.run(
            ['osascript', '-e', script], capture_output=True, text=True)
        if result.returncode == 0:
            info = result.stdout.strip()
            print("Current track info:", info)
            return info
        else:
            print("Error retrieving track info:", result.stderr)
            return None

    def play_spotify(self, song: str, trial: int = 1):
        """
        Tool: "play_spotify"
        Description: play Spotify using AppleScript.
        Args:
            song: The name of the song to play.
            trial [Optional]: The number of trials to attempt if the song is not found.
        """

        # Sanity check
        trial = min(max(trial, 1), 3)  # Limit trials to between 1 and 3

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
            track_id_found = False
            for i in range(3):
                # search song, retrieve url
                search_results = SearchInterface.google_search(
                    "spotify song & lyrics track for " + song)
                if search_results:
                    search_result = search_results[i]
                    # first_result is in the format, "URL: <url> Title: <title> Description: <description>\n\n" retrieve the url
                    url = search_result.split("URL: ")[1].split("\n")[0]
                    # Extract track ID from the Spotify URL
                    if "spotify.com/track/" in url:
                        track_id = url.split(
                            "spotify.com/track/")[1].split("?")[0].split()[0].strip()
                        print(f"Playing Spotify track ID: {track_id}")

                    if track_id:
                        track_id_found = True
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
                        break
                if not track_id_found:
                    print(f"Could not extract track ID from URL: {url}")
                    if trial == 1:
                        print("Trying again...")
                        self.play_spotify(song, 2)
            else:
                print(f"Could not extract track ID from URL: {url}")
                if trial == 1:
                    print("Trying again...")
                    self.play_spotify(song, 2)
                return "Failed to play song"

    def google_search(self, query: str):
        """
        Tool: "google_search"
        Description: searches Google for a query.
        Args:
            query: The query to search for.
        """
        result = SearchInterface.google_search(query)
        print(result)
        return result


if __name__ == "__main__":
    auto = SystemAutomationClient({})
    print("Running...")
    auto._process_command("play", "play Viva la Vida by Coldplay")
    # auto.zero_brightness()
