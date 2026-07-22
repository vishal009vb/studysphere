import firebase_admin
from firebase_admin import credentials, firestore
from config import FIREBASE_SERVICE_ACCOUNT

cred = credentials.Certificate(FIREBASE_SERVICE_ACCOUNT)
firebase_admin.initialize_app(cred)
db = firestore.client()

notes_ref = db.collection('notes').where('status', '==', 'pending_review').get()
for doc in notes_ref:
    db.collection('notes').document(doc.id).update({'status': 'pending'})
    print(f"Updated {doc.id} to pending")
print("Done")
