"""
MIT License

Copyright (c) 2021 Nv7-GitHub

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"""

import random
from time import sleep
from bs4 import BeautifulSoup
from requests import get
from urllib.parse import unquote

def get_useragent():
    """
    Generates a random user agent string mimicking the format of various software versions.

    The user agent string is composed of:
    - Lynx version: Lynx/x.y.z where x is 2-3, y is 8-9, and z is 0-2
    - libwww version: libwww-FM/x.y where x is 2-3 and y is 13-15
    - SSL-MM version: SSL-MM/x.y where x is 1-2 and y is 3-5
    - OpenSSL version: OpenSSL/x.y.z where x is 1-3, y is 0-4, and z is 0-9

    Returns:
        str: A randomly generated user agent string.
    """
    lynx_version = f"Lynx/{random.randint(2, 3)}.{random.randint(8, 9)}.{random.randint(0, 2)}"
    libwww_version = f"libwww-FM/{random.randint(2, 3)}.{random.randint(13, 15)}"
    ssl_mm_version = f"SSL-MM/{random.randint(1, 2)}.{random.randint(3, 5)}"
    openssl_version = f"OpenSSL/{random.randint(1, 3)}.{random.randint(0, 4)}.{random.randint(0, 9)}"
    return f"{lynx_version} {libwww_version} {ssl_mm_version} {openssl_version}"

def _req(term, results, lang, start, proxies, timeout, safe, ssl_verify, region):
    resp = get(
        url="https://www.google.com/search",
        headers={
            "User-Agent": get_useragent(),
            "Accept": "*/*"
        },
        params={
            "q": term,
            "num": results + 2,  # Prevents multiple requests
            "hl": lang,
            "start": start,
            "safe": safe,
            "gl": region,
        },
        proxies=proxies,
        timeout=timeout,
        verify=ssl_verify,
        cookies = {
            'CONSENT': 'PENDING+987', # Bypasses the consent page
            'SOCS': 'CAESHAgBEhIaAB',
        }
    )
    resp.raise_for_status()
    return resp


class SearchResult:
    def __init__(self, url, title, description):
        self.url = url
        self.title = title
        self.description = description

    def __repr__(self):
        return f"SearchResult(url={self.url}, title={self.title}, description={self.description})"


def search(term, num_results=10, lang="en", proxy=None, advanced=False, sleep_interval=0, timeout=5, safe="active", ssl_verify=None, region=None, start_num=0, unique=False):
    """
    Searches the Google search engine for a given term.
    Args:
        term: The term to search for.
        num_results: The number of results to return.
        lang: The language to search in.
        proxy: The proxy to use.
        advanced: Whether to return advanced results.
        sleep_interval: The time to sleep between requests.
        timeout: The timeout for the request.
        safe: The safe search setting.
        ssl_verify: Whether to verify the SSL certificate.
        region: The region to search in.
        start_num: The starting number of results to return.
        unique: Whether to return unique results.
    Returns:
        A generator of SearchResult objects.
    """

    # Proxy setup
    proxies = {"https": proxy, "http": proxy} if proxy and (proxy.startswith("https") or proxy.startswith("http") or proxy.startswith("socks5")) else None

    start = start_num
    fetched_results = 0  # Keep track of the total fetched results
    fetched_links = set() # to keep track of links that are already seen previously

    while fetched_results < num_results:
        # Send request
        resp = _req(term, num_results - start,
                    lang, start, proxies, timeout, safe, ssl_verify, region)
        
        # put in file - comment for debugging purpose
        # with open('google.html', 'w') as f:
        #     f.write(resp.text)
        
        # Parse
        soup = BeautifulSoup(resp.text, "html.parser")
        result_block = soup.find_all("div", class_="ezO2md")
        new_results = 0  # Keep track of new results in this iteration

        for result in result_block:
            # Find the link tag within the result block
            link_tag = result.find("a", href=True)
            # Find the title tag within the link tag
            title_tag = link_tag.find("span", class_="CVA68e") if link_tag else None
            # Find the description tag within the result block
            description_tag = result.find("span", class_="FrIlee")

            # Check if all necessary tags are found
            if link_tag and title_tag and description_tag:
                # Extract and decode the link URL
                link = unquote(link_tag["href"].split("&")[0].replace("/url?q=", "")) if link_tag else ""
                # Check if the link has already been fetched and if unique results are required
                if link in fetched_links and unique:
                    continue  # Skip this result if the link is not unique
                # Add the link to the set of fetched links
                fetched_links.add(link)
                # Extract the title text
                title = title_tag.text if title_tag else ""
                # Extract the description text
                description = description_tag.text if description_tag else ""
                # Increment the count of fetched results
                fetched_results += 1
                # Increment the count of new results in this iteration
                new_results += 1
                # Yield the result based on the advanced flag
                if advanced:
                    yield SearchResult(link, title, description)  # Yield a SearchResult object
                else:
                    yield link  # Yield only the link

                if fetched_results >= num_results:
                    break  # Stop if we have fetched the desired number of results

        if new_results == 0:
            break  # Break the loop if no new results were found in this iteration

        start += 10  # Prepare for the next set of results
        sleep(sleep_interval)

def search_website(
    url: str,
    *,
    raw_html: bool = False,
    timeout: int = 10,
    max_chars: int = None,
) -> str:
    """
    Fetch the contents of a web-page.

    By default this function removes HTML tags, scripts, styles, and returns
    only the visible text a user would normally read in the browser.
    Pass ``raw_html=True`` to obtain the unmodified HTML instead.

    Args:
        url (str): The page to download.
        raw_html (bool, optional): Return raw HTML (default: False).
        timeout (int, optional): Seconds before the request times out (default: 10).
        max_chars (int, optional): Maximum number of characters to return (default: None for no limit).

    Returns:
        str: Visible text or the raw HTML of the page, depending on ``raw_html``.
    """
    try:
        # A realistic User-Agent helps avoid simple bot-blocking measures.
        headers = {
            "User-Agent": get_useragent(),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        }

        resp = get(url, headers=headers, timeout=timeout)
        
        # Handle specific HTTP status codes
        if resp.status_code == 403:
            return f"Access denied (403) for URL: {url}. The website may be blocking automated requests."
        elif resp.status_code == 404:
            return f"Page not found (404) for URL: {url}."
        elif resp.status_code == 429:
            return f"Rate limited (429) for URL: {url}. Too many requests."
        elif resp.status_code == 503:
            return f"Service unavailable (503) for URL: {url}. The server may be temporarily down."
        
        resp.raise_for_status()

        # Return early if the caller explicitly wants the raw markup.
        if raw_html:
            result = resp.text
            return result[:max_chars] if max_chars else result

        # Parse and extract visible text.
        soup = BeautifulSoup(resp.text, "html.parser")

        # Remove non-visible elements.
        for elem in soup(["script", "style", "noscript", "header",
                          "footer", "svg", "iframe"]):
            elem.decompose()

        text = soup.get_text(separator="\n")

        # Collapse excessive whitespace/newlines.
        cleaned_lines = [line.strip() for line in text.splitlines() if line.strip()]
        result = "\n".join(cleaned_lines)
        
        # Apply character limit if specified
        return result[:max_chars] if max_chars else result
        
    except Exception as e:
        return f"Error fetching URL {url}: {str(e)}"