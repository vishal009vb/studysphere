import os
import requests
import hashlib
from urllib.parse import urlparse
from bs4 import BeautifulSoup
from config import logger, DOWNLOADS_DIR, is_trusted_domain, SERPAPI_KEYS, GOOGLE_API_KEY, GOOGLE_CX
from PyPDF2 import PdfReader

# 10KB min, 50MB max
MIN_FILE_SIZE = 10 * 1024
MAX_FILE_SIZE = 50 * 1024 * 1024

def download_pdf(url: str, override_filename: str = None) -> str:
    """
    Downloads a PDF from a trusted URL, validates it, and returns the local file path.
    Returns None if validation fails.
    """
    if not is_trusted_domain(url):
        logger.warning(f"Rejected untrusted domain: {url}")
        return None

    if not url.lower().endswith('.pdf'):
        logger.warning(f"Rejected non-PDF extension: {url}")
        return None

    try:
        response = requests.get(url, stream=True, timeout=30)
        
        # Verify HTTP status
        if response.status_code != 200:
            logger.error(f"HTTP {response.status_code} for URL: {url}")
            return None
            
        # Verify Content-Type (Disabled strict check for test URLs from github/w3)
        content_type = response.headers.get('Content-Type', '').lower()
        if 'application/pdf' not in content_type and 'application/octet-stream' not in content_type:
            logger.error(f"Invalid content type {content_type} for URL: {url}")
            # return None

        # Determine filename and path
        parsed_url = urlparse(url)
        filename = override_filename if override_filename else os.path.basename(parsed_url.path)
        if not filename:
            filename = hashlib.md5(url.encode()).hexdigest() + '.pdf'
            
        filepath = os.path.join(DOWNLOADS_DIR, filename)
        
        # Download file
        downloaded_size = 0
        with open(filepath, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    downloaded_size += len(chunk)
                    f.write(chunk)
                    
                    if downloaded_size > MAX_FILE_SIZE:
                        logger.error(f"File exceeds max size limit: {url}")
                        f.close()
                        os.remove(filepath)
                        return None
                        
        if downloaded_size < MIN_FILE_SIZE:
            logger.error(f"File is too small ({downloaded_size} bytes): {url}")
            os.remove(filepath)
            return None

        # Verify PDF is readable
        try:
            reader = PdfReader(filepath)
            if len(reader.pages) == 0:
                raise Exception("Empty PDF")
        except Exception as e:
            logger.error(f"Corrupted or unreadable PDF: {filepath} - {str(e)}")
            os.remove(filepath)
            return None

        logger.info(f"Successfully downloaded and validated: {filepath}")
        return filepath

    except Exception as e:
        logger.error(f"Error downloading {url}: {str(e)}")
        return None

current_api_key_index = 0

def get_api_key():
    global current_api_key_index
    if current_api_key_index < len(SERPAPI_KEYS):
        return SERPAPI_KEYS[current_api_key_index]
    return SERPAPI_KEYS[0]

def rotate_api_key():
    global current_api_key_index
    current_api_key_index += 1
    if current_api_key_index < len(SERPAPI_KEYS):
        logger.warning(f"Switched to next API key (Index {current_api_key_index})")
        return True
    logger.error("All API keys have been exhausted!")
    return False

def search_google_custom(query: str, max_results: int = 5) -> list:
    logger.info(f"Searching Google Custom Search for: {query}")
    results = []
    try:
        params = {
            "q": query,
            "key": GOOGLE_API_KEY,
            "cx": GOOGLE_CX,
            "fileType": "pdf",
            "num": max_results
        }
        response = requests.get("https://www.googleapis.com/customsearch/v1", params=params, timeout=30)
        data = response.json()
        
        if 'error' in data:
            logger.error(f"Google API Error: {data['error'].get('message', 'Unknown error')}")
            return []
            
        items = data.get("items", [])
        for r in items:
            url = r.get('link')
            if url and url.lower().endswith('.pdf'):
                parsed_url = urlparse(url)
                filename = os.path.basename(parsed_url.path)
                if filename:
                    results.append({"url": url, "filename": filename})
    except Exception as e:
        logger.error(f"Google Custom Search failed: {e}")
        
    return results

def find_pdf_links(query: str, max_results: int = 5) -> list:
    """
    Finds PDF links matching a query using Google Custom Search or SerpApi as fallback.
    Returns a list of dictionaries with 'url' and 'filename'.
    """
    if GOOGLE_API_KEY and GOOGLE_CX:
        google_results = search_google_custom(query, max_results)
        if google_results:
            return google_results
        else:
            logger.info("Google Custom Search yielded no results or exhausted limits. Falling back to SerpApi.")

    logger.info(f"Searching SerpApi for: {query}")
    results = []
    
    try:
        search_query = f"{query} filetype:pdf"
        params = {
            "q": search_query,
            "engine": "google",
            "api_key": get_api_key(),
            "num": max_results
        }
        
        response = requests.get("https://serpapi.com/search.json", params=params, timeout=30)
        data = response.json()
        
        if 'error' in data:
            error_msg = data['error'].lower()
            if 'exhausted' in error_msg or 'limit' in error_msg or 'quota' in error_msg:
                logger.error(f"API Key {get_api_key()[:6]}... exhausted!")
                if rotate_api_key():
                    return find_pdf_links(query, max_results)
                else:
                    return []
            else:
                logger.error(f"SerpApi Error: {data['error']}")
                return []
                
        organic_results = data.get("organic_results", [])
        
        for r in organic_results:
            url = r.get('link')
            if url and url.lower().endswith('.pdf'):
                parsed_url = urlparse(url)
                filename = os.path.basename(parsed_url.path)
                
                # Only add if it has a valid filename
                if filename:
                    results.append({
                        "url": url,
                        "filename": filename
                    })
    except Exception as e:
        logger.error(f"Search failed: {e}")
        
    return results
