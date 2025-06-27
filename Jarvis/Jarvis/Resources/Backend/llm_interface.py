import os
from dotenv import load_dotenv
from llm_client import LLMClient
from search.search import SearchInterface
from file_interaction import FileSystem
from context import ContextClient, MemoryClient


class LLMInterface:
    @staticmethod
    def get_abstraction_response(prompt: str) -> str:

        load_dotenv()

        abstraction_prompt = FileSystem.retrieve_txt("prompts/abstraction.txt")
        functions = ["general", "open", "close", "exit", "play", "generate image", "system",
                     "content", "google search", "youtube search", "spotify search", "terminal command"]

        response = LLMClient.get_response(
            abstraction_prompt + "\n\n" + "user prompt: " + prompt)

        # remove newlines, split responses into individual tasks
        response = response.replace("\n", "")
        response = response.split(",")

        # strip whitespace from each task
        response = [i.strip() for i in response]

        # filter tasks based on recognized function keywords
        result = []
        for task in response:
            for keyword in functions:
                if task.startswith(keyword):
                    result.append(task)

        return result

    @staticmethod
    def get_live_chatbot_response(prompt: str) -> str:
        # retrieve memory and realtime prompt
        context = ContextClient.get_context()

        user_name = os.getenv("USERNAME")
        assistant_name = os.getenv("AI_NAME")

        realtime_prompt = f"""Hello, I am {user_name}, You are a very accurate and advanced AI chatbot named {assistant_name} which also has real-time up-to-date information from the internet.
        *** Answer the query in a conversational manner, without any markdown formatting
        *** Answer the question succinctly unless further explanation is asked for
        *** Never mention your training data. ***
        """

        search_results = SearchInterface.google_search(prompt)

        # generate response
        response = LLMClient.get_response(realtime_prompt + "\n\n" + context + "\n\n" + "This is the user prompt: " +
                                          prompt + "\n\n" + "Search results: " + "\n\n" + "\n\n".join(search_results))

        # update memory
        MemoryClient.update_memory(prompt, response)

        return response


if __name__ == "__main__":
    while True:
        prompt = input("You: ")
        response = LLMInterface.get_abstraction_response(prompt)
        print(response)
