import firebase_admin
from firebase_admin import credentials, firestore
from config import FIREBASE_SERVICE_ACCOUNT

cred = credentials.Certificate(FIREBASE_SERVICE_ACCOUNT)
firebase_admin.initialize_app(cred)
db = firestore.client()

docs = db.collection('notes').where('uploadedBy', '==', 'AI_SCRAPER').get()
for doc in docs:
    data = doc.to_dict()
    if 'createdAt' not in data and 'uploadedAt' in data:
        db.collection('notes').document(doc.id).update({
            'createdAt': data['uploadedAt']
        })
        print(f"Updated createdAt for {doc.id}")
print("Done")
