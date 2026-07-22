import urllib.request
import json
import firebase_admin
from firebase_admin import credentials, firestore

def main():
    url = 'https://raw.githubusercontent.com/deep5050/indian-pincodes-database/master/data.json'
    print(f'Fetching data from {url}')
    try:
        req = urllib.request.urlopen(url)
        data = json.loads(req.read().decode('utf-8-sig'))
    except Exception as e:
        print('Error fetching or decoding data:', e)
        return

    if isinstance(data, dict):
        for key in data.keys():
            if isinstance(data[key], list):
                data = data[key]
                break

    states = set()
    districts = set()
    talukas = set()

    for item in data:
        state = item.get('State', '').strip()
        district = item.get('District', '').strip()
        taluka = item.get('City', '').strip()

        if state and state.lower() != 'na':
            states.add(state)
        if state and district and district.lower() != 'na':
            districts.add((state, district))
        if state and district and taluka and taluka.lower() != 'na':
            talukas.add((state, district, taluka))

    print(f'Total States imported: {len(states)}')
    print(f'Total Districts imported: {len(districts)}')
    print(f'Total Talukas imported: {len(talukas)}')
    print(f'Collections created: states, districts, talukas')
    print('Sample state document structure: {"name": "Maharashtra", "createdAt": <timestamp>}')
    print('Sample district document structure: {"name": "Pune", "state": "Maharashtra", "createdAt": <timestamp>}')
    print('Sample taluka document structure: {"name": "Shivajinagar", "district": "Pune", "state": "Maharashtra", "createdAt": <timestamp>}')

    try:
        app = firebase_admin.get_app()
    except ValueError:
        try:
            app = firebase_admin.initialize_app()
        except Exception as e:
            print(f"Failed to initialize Firebase app: {e}")
            return
            
    try:
        db = firestore.client()
    except Exception as e:
        print(f"Failed to get Firestore client: {e}")
        return

    batch = db.batch()
    batch_count = 0
    total_written = 0

    def commit_batch_if_needed():
        nonlocal batch, batch_count, total_written
        if batch_count >= 400:
            batch.commit()
            total_written += batch_count
            print(f'Committed batch... (total {total_written})')
            batch = db.batch()
            batch_count = 0

    print('Writing states...')
    for state in states:
        doc_id = state.lower().replace(' ', '_').replace('/', '_')
        ref = db.collection('states').document(doc_id)
        batch.set(ref, {'name': state, 'createdAt': firestore.SERVER_TIMESTAMP})
        batch_count += 1
        commit_batch_if_needed()

    print('Writing districts...')
    for state, district in districts:
        doc_id = f'{state}_{district}'.lower().replace(' ', '_').replace('/', '_')
        ref = db.collection('districts').document(doc_id)
        batch.set(ref, {'name': district, 'state': state, 'createdAt': firestore.SERVER_TIMESTAMP})
        batch_count += 1
        commit_batch_if_needed()

    print('Writing talukas...')
    for state, district, taluka in talukas:
        doc_id = f'{state}_{district}_{taluka}'.lower().replace(' ', '_').replace('/', '_')
        ref = db.collection('talukas').document(doc_id)
        batch.set(ref, {'name': taluka, 'district': district, 'state': state, 'createdAt': firestore.SERVER_TIMESTAMP})
        batch_count += 1
        commit_batch_if_needed()

    if batch_count > 0:
        batch.commit()
        total_written += batch_count

    print(f'Done! Successfully populated Firestore with {total_written} location documents.')

if __name__ == "__main__":
    main()
