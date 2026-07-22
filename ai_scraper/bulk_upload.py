import os
import sys
from config import logger
from classifier import classify_pdf
from firebase_uploader import upload_to_firebase

DOCS_DIR = r"c:\Users\visha\OneDrive\Desktop\photos\my_documents"

def main():
    logger.info("Starting Bulk Upload from Local Documents...")
    
    if not os.path.exists(DOCS_DIR):
        logger.error(f"Directory not found: {DOCS_DIR}")
        return

    files = os.listdir(DOCS_DIR)
    processed_count = 0
    failed_count = 0
    
    for filename in files:
        filepath = os.path.join(DOCS_DIR, filename)
        
        if not os.path.isfile(filepath):
            continue
            
        logger.info(f"Processing local file: {filename}")
        
        metadata = classify_pdf(filepath)
        
        if 'error' in metadata:
            logger.error(f"Classification failed for {filename}: {metadata['error']}. Skipping.")
            failed_count += 1
            continue
            
        # Since these are user-provided files, we can trust them and force high confidence
        metadata['confidence'] = 100
        
        success = upload_to_firebase(filepath, metadata, source_url="Local Bulk Upload")
        if success:
            processed_count += 1
        else:
            failed_count += 1
            
    logger.info(f"Bulk Upload complete. Successfully uploaded: {processed_count}. Failed/Skipped: {failed_count}.")

if __name__ == "__main__":
    main()
