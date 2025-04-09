from googlesearch import search

class SearchInterface:
    @staticmethod
    def google_search(query: str) -> list[str]:
        try:
            results = []
            for result in search(query, advanced=True):
                # Extract all available information from the SearchResult object
                info = f"URL: {result.url}\nTitle: {result.title}\nDescription: {result.description}\n\n"
                results.append(info)
            return results
        except Exception as e:
            print(f"Error performing Google search: {e}")
            return []