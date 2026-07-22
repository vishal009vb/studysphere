import os
import hashlib
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore, storage
from config import FIREBASE_SERVICE_ACCOUNT, logger

# Initialize Firebase
try:
    cred = credentials.Certificate(FIREBASE_SERVICE_ACCOUNT)
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'studysphere-app-3a480.appspot.com'
    })
    db = firestore.client()
    logger.info("Firebase Firestore & Storage initialized successfully.")
except Exception as e:
    logger.error(f"Failed to initialize Firebase: {e}")
    db = None

def get_file_hash(filepath: str) -> str:
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def is_duplicate(file_hash: str) -> bool:
    if not db:
        return True # Fail safe
        
    # Check notes
    notes_ref = db.collection('notes').where('fileHash', '==', file_hash).limit(1).get()
    if len(notes_ref) > 0:
        return True
        
    # Check question papers
    papers_ref = db.collection('question_papers').where('fileHash', '==', file_hash).limit(1).get()
    if len(papers_ref) > 0:
        return True
        
    return False

def upload_to_firebase(filepath: str, metadata: dict, source_url: str) -> bool:
    if not db:
        logger.error("Firebase not initialized. Cannot upload.")
        return False

    try:
        file_hash = get_file_hash(filepath)
        
        if is_duplicate(file_hash):
            logger.info(f"Duplicate detected. Skipping upload for {filepath}")
            return False

        filename = os.path.basename(filepath)
        
        # Upload to Supabase Storage
        import requests
        from config import SUPABASE_URL, SUPABASE_ANON_KEY
        
        if not SUPABASE_URL or not SUPABASE_ANON_KEY:
            logger.error("Supabase URL or Key is missing from .env!")
            return False
            
        supabase_upload_url = f"{SUPABASE_URL}/storage/v1/object/studysphere_pdfs/AI_SCRAPER/{filename}"
        
        headers = {
            "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
            "apikey": SUPABASE_ANON_KEY,
            "Content-Type": "application/pdf"
        }
        
        try:
            with open(filepath, "rb") as f:
                response = requests.post(supabase_upload_url, headers=headers, data=f)
                
            if response.status_code in [200, 201]:
                # Construct public URL
                file_url = f"{SUPABASE_URL}/storage/v1/object/public/studysphere_pdfs/AI_SCRAPER/{filename}"
                logger.info(f"Successfully uploaded to Supabase Storage: {file_url}")
            elif response.status_code == 400 and "Duplicate" in response.text:
                 # If duplicate, just use the url
                 file_url = f"{SUPABASE_URL}/storage/v1/object/public/studysphere_pdfs/AI_SCRAPER/{filename}"
                 logger.info(f"File already exists in Supabase Storage: {file_url}")
            else:
                logger.error(f"Supabase Storage upload failed: {response.text}")
                return False
        except Exception as e:
            logger.error(f"Supabase upload request failed: {e}")
            return False
        
        # Prepare Firestore Data
        doc_data = {
            "title": metadata.get('title', 'Unknown Document'),
            "course": metadata.get('course'),
            "subject": metadata.get('subject'),
            "type": metadata.get('type'),
            "semester": metadata.get('semester', ''),
            "year": metadata.get('year', ''),
            "pdfUrl": file_url,
            "sourceUrl": source_url,
            "fileHash": file_hash,
            "status": "approved" if metadata.get('confidence', 0) >= 90 else "pending",
            "createdAt": firestore.SERVER_TIMESTAMP,
            "uploadedBy": "AI_SCRAPER",
            "collegeId": "SSMM College",
            "state": "Maharashtra",
            "district": "",
            "downloads": 0,
            "likes": 0,
            "qualityScore": metadata.get('confidence', 0) / 10.0
        }
        
        # Save to Firestore
        collection_name = 'question_papers' if metadata.get('type') == 'Paper' else 'notes'
        doc_ref = db.collection(collection_name).document()
        doc_data['noteId' if collection_name == 'notes' else 'paperId'] = doc_ref.id
        
        doc_ref.set(doc_data)
        logger.info(f"Successfully uploaded {filename} to {collection_name}. Status: {doc_data['status']}")
        return True

    except Exception as e:
        logger.error(f"Failed to upload {filepath} to Firebase: {e}")
        return False
