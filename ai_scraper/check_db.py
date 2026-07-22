import firebase_admin
from firebase_admin import credentials, firestore
from config import FIREBASE_SERVICE_ACCOUNT

cred = credentials.Certificate(FIREBASE_SERVICE_ACCOUNT)
firebase_admin.initialize_app(cred)
db = firestore.client()

docs = db.collection('notes').where('uploadedBy', '==', 'AI_SCRAPER').limit(1).get()
for doc in docs:
    print(f"ID: {doc.id}")
    data = doc.to_dict()
    for k, v in data.items():
        print(f"{k}: {v} (Type: {type(v)})")
