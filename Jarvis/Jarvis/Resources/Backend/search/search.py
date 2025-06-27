import json
from llm_client import LLMClient
from .search_utils import search, search_website


class SearchInterface:
    @staticmethod
    def google_search(query: str) -> str:
        websites = {}
        try:
            for result in search(query, advanced=True):
                # Extract all available information from the SearchResult object
                info = {
                    "url": result.url,
                    "title": result.title.lower(),
                    "description": result.description
                }
                websites[info["title"]] = info
        except Exception as e:
            print(f"Error performing Google search: {e}")

        # ----------------------------------------
        # Have the LLM select the three most relevant results
        # ----------------------------------------

        websites_string = "\n".join(
            [f"{title}: {info['description']}" for title, info in websites.items()])
        prompt = """
        You are a helpful assistant that can answer questions and help with tasks.
        You are given a list of websites from a Google search.
        You need to return the three most relevant websites in the following JSON format:
        {{"titles": ["title1", "title2", "title3"]}}
        Importantly, do not include any other text in your response.
        The websites are:
        {websites}
        """

        prompt = prompt.format(websites=websites_string)

        response = LLMClient.get_response(prompt)
        try:
            # Parse the JSON response
            response_data = json.loads(response.strip())
            titles = response_data.get("titles", [])
        except json.JSONDecodeError:
            # Fallback: try to extract titles from malformed response
            print(f"Warning: Could not parse JSON response: {response}")
            # Remove any markdown formatting or extra text
            response_clean = response.strip()
            if response_clean.startswith("```json"):
                response_clean = response_clean.replace(
                    "```json", "").replace("```", "").strip()
            try:
                response_data = json.loads(response_clean)
                titles = response_data.get("titles", [])
            except json.JSONDecodeError:
                # Last resort: use the old parsing method
                response_clean = response_clean.lstrip("[").rstrip("]")
                titles = [t.strip().strip('"')
                          for t in response_clean.split(",") if t.strip()]

        # ----------------------------------------
        # For each chosen title -> fetch page -> summarize
        # ----------------------------------------

        # Begin with Lookup
        title_lookup = {k.lower(): k for k in websites.keys()}

        summaries = {}
        for requested_title in titles:
            original_title = title_lookup.get(
                requested_title.lower(), requested_title)
            if not original_title:
                # attempt partial match
                for k in websites.keys():
                    if requested_title.lower() in k.lower():
                        original_title = k
                        break
            if not original_title:
                continue

            url = websites[original_title]["url"]

            page = search_website(url)
            summary = LLMClient.get_response(
                prompt="""
                You are a helpful assistant that is excellent at cleaning up text and distilling a large corpus into a concise format with all the information.
                You are given a website. You need to remove the extraneous text and just return the cleaned up text — remove unnecessary information as well.
                The query being answered is: {query}
                The website is:
                {page}
                """.format(query=query, page=page)
            )

            formatted_result = {
                "title": original_title,
                "description": websites[original_title]['description'],
                "summary": summary
            }

            summaries[original_title] = formatted_result

        # ----------------------------------------
        # Return the answer
        # ----------------------------------------

        final_prompt = """
        You are a helpful assistant that can answer questions and help with tasks. You are given a query and a list of summaries.
        You need to return the summarized and concise answer to the query based on the summaries and your own knowledge. Note, the output should be in a speech format, as it will be read out loud, not written.
        The query is: {query}
        The summaries are:
        {summaries}
        """.format(query=query, summaries=summaries)
        answer = LLMClient.get_response(final_prompt)

        return answer
