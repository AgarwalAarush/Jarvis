import json
import ollama
from typing import Literal

class LLMClient:
    @staticmethod
    def get_response(prompt: str, model_name = "gemma3:4b") -> str:
        response = ollama.generate(
            model=model_name,
            prompt=prompt,
            stream=False
        )['response']

        return response

    @staticmethod
    def get_response_with_complexity(prompt: str, complexity: Literal["low", "medium", "high"] = "medium") -> str:

        if complexity == "low":
            model_name = LLMClient.lowest_complexity_model()
        elif complexity == "high":
            model_name = LLMClient.highest_complexity_model()
        else:
            model_name = "gemma3:4b"

        response = ollama.generate(
            model=model_name,
            prompt=prompt,
            stream=False
        )['response']

        return response
    
    @staticmethod
    def list_models() -> str:
        """
        Returns a list of all locally-downloaded models.
        Each entry is a dict with fields like 'name', 'size', 'modified', etc.
        """
        return json.loads(ollama.list().model_dump_json())
    
    def highest_complexity_model(self) -> str:
        models = self.list_models()['models']
        models.sort(key=lambda x: x['size'], reverse=True)
        return models[0]['name']
    
    def lowest_complexity_model(self) -> str:
        models = self.list_models()['models']
        models.sort(key=lambda x: x['size'])
        return models[0]['name']