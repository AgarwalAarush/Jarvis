import ollama

class LLMClient:
    @staticmethod
    # try phi4
    def get_response(prompt: str, model_name = "gemma3:4b") -> str:
        response = ollama.generate(
            model=model_name,
            prompt=prompt,
            stream=False
        )['response']

        return response