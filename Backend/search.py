from googlesearch import search
from llm_client import LLMClient

class SearchInterface:

    @staticmethod
    def google_search(query: str) -> list[str]:

        prompt = """
        

        """

        try:
            results = []
            for result in search(query, advanced=True):
                # Extract all available information from the SearchResult object
                info = f"URL: {result.url}\nTitle: {result.title}\nDescription: {result.description}\n\n"
                results.append(info)

            
        except Exception as e:
            print(f"Error performing Google search: {e}")
            return []