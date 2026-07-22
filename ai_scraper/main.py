import os
import time
import random
from config import logger, DOWNLOADS_DIR, VALID_COURSES, VALID_SUBJECTS
from scraper import find_pdf_links, download_pdf
from classifier import classify_pdf
from firebase_uploader import upload_to_firebase

MAX_PER_QUERY = 5

def cleanup_temp_files():
    for f in os.listdir(DOWNLOADS_DIR):
        file_path = os.path.join(DOWNLOADS_DIR, f)
        try:
            if os.path.isfile(file_path):
                os.remove(file_path)
        except Exception as e:
            logger.error(f"Failed to delete {file_path}: {e}")
def run_scraper():
    logger.info("Starting AI Scraper Engine (Production Mode)...")
    
    # Generate search queries for BCA (broad and specific)
    queries = []
    for subject in VALID_SUBJECTS:
        queries.append(f"BCA {subject} class notes SSMM College KBCNMU Jalgaon pdf")
        queries.append(f"BCA {subject} previous year question papers KBCNMU Jalgaon University pdf")
        queries.append(f"BCA {subject} semester notes pdf")
        queries.append(f"BCA {subject} study material pdf")
        
    random.shuffle(queries)
    daily_queries = queries
    
    processed_count = 0
    
    for query in daily_queries:
        urls = find_pdf_links(query, max_results=MAX_PER_QUERY)
        
        if not urls:
            continue

        for item in urls:
            url = item['url']
            filename = item['filename']
                
            logger.info(f"Processing URL: {url} as {filename}")
            
            filepath = download_pdf(url, override_filename=filename)
            if not filepath:
                continue
                
            metadata = classify_pdf(filepath)
            logger.info(f"Classification result: {metadata}")
            
            if metadata.get('confidence', 0) < 90:
                logger.warning("Confidence is low. Marking as pending_review.")
                
            if 'error' in metadata:
                logger.error(f"Classification failed: {metadata['error']}. Skipping upload.")
                try:
                    os.remove(filepath)
                except:
                    pass
                continue
                
            success = upload_to_firebase(filepath, metadata, url)
            if success:
                processed_count += 1
                if processed_count >= 50:
                    break
                
            try:
                os.remove(filepath)
            except:
                pass
                
            time.sleep(2)
        
        if processed_count >= 50:
            break
            
    logger.info(f"AI Scraper finished a cycle. Processed {processed_count} files successfully.")
    cleanup_temp_files()

def main():
    import time
    logger.info("Starting 24/7 Scraper Daemon...")
    while True:
        try:
            run_scraper()
        except Exception as e:
            logger.error(f"Error in scraper run: {e}")
        
        # Sleep for 6 hours before next run to avoid API limits
        logger.info("Sleeping for 6 hours before next scrape cycle...")
        time.sleep(60 * 60 * 6)

if __name__ == "__main__":
    main()
