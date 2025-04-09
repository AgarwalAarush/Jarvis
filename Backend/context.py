import time
import datetime
from file_interaction import FileSystem
from langchain_ollama import OllamaLLM

class MemoryClient:
    @staticmethod
    def update_memory(query: str, response: str):
        # retrieve memory system settings
        last_memory_update: int = FileSystem.retrieve_json("systems.json")["last_memory_update"]
        memory_threshold: int = FileSystem.retrieve_json("systems.json")["memory_threshold"]
        
        # append memory to memory.txt
        if response != "":
            FileSystem.append_txt("storage/memory.txt", f"Query: {query}\nResponse: {response}\n")

            # update last memory update
            FileSystem.change_json_value("systems.json", "last_memory_update", time.time())

            last_memory_update += 1;
            FileSystem.change_json_value("systems.json", "last_memory_update", last_memory_update % memory_threshold)
        else:
            FileSystem.append_txt("storage/memory.txt", f"Query: {query}\n")
        
        # summarize memory.txt if threshold is reached
        if last_memory_update % memory_threshold == 0:
            # init model
            model = OllamaLLM(model="llama3.2:3b")

            # retrieve memory content
            memory_content = FileSystem.retrieve_txt("storage/memory.txt")

            # retrieve memory summary prompt & summarize
            summary_prompt = f"{FileSystem.retrieve_txt('prompts/memory_summary.txt')}\n\n{memory_content}"
            summary = model.invoke(summary_prompt)
            
            # save the summary and reset memory.txt
            FileSystem.write_txt("storage/memory.txt", summary)

    @staticmethod
    def retrieve_memory():
        return FileSystem.retrieve_txt("storage/memory.txt")

class DateTimeClient:
    @staticmethod
    def get_realtime_information_string():
        try:
            current_date_time = datetime.datetime.now() # Get the current date and time.

            # Extract components using strftime format codes
            day = current_date_time.strftime("%A")     # Full name of the weekday (e.g., Tuesday)
            date = current_date_time.strftime("%d")     # Day of the month as a zero-padded decimal number (e.g., 08)
            month = current_date_time.strftime("%B")    # Full name of the month (e.g., April)
            year = current_date_time.strftime("%Y")     # Year with century (e.g., 2025)
            hour = current_date_time.strftime("%H")     # Hour (24-hour clock) as a zero-padded decimal number (e.g., 20)
            minute = current_date_time.strftime("%M")   # Minute as a zero-padded decimal number (e.g., 15)
            second = current_date_time.strftime("%S")   # Second as a zero-padded decimal number (e.g., 41)

            # Format time in a more readable 12-hour format
            hour_int = int(hour)
            am_pm = "AM" if hour_int < 12 else "PM"
            hour_12 = hour_int % 12
            if hour_12 == 0:
                hour_12 = 12
            descriptive_time = f"{hour_12}:{minute} {am_pm}"


            # Format the information into a single descriptive string using an f-string.
            # Corrected potential typos from the image (e.g., "needed,n", ":{minute}").
            info_string = (
                f"Real-time information:\n" # Changed introductory phrase slightly
                f"Day: {day}\n"
                f"Date: {date}\n"
                f"Month: {month}\n"
                f"Year: {year}\n"
                f"Time: {descriptive_time}.\n"
            )
            return info_string
        except Exception as e:
            # Basic error handling in case getting datetime fails
            print(f"Error getting real-time information: {e}")
            return "Could not retrieve real-time information."

class ContextClient:
    @staticmethod
    def get_context():
        date_time = DateTimeClient.get_realtime_information_string()
        memory = MemoryClient.retrieve_memory()
        return "Real-time information:\n\n" + date_time + "\n\n" + "The following is your memory:\n\n" + memory
    