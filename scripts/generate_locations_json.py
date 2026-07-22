import urllib.request
import json
import os

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

    # We want a hierarchical dictionary: { state: { district: [talukas] } }
    locations = {}

    for item in data:
        state = item.get('State', '').strip()
        district = item.get('District', '').strip()
        taluka = item.get('City', '').strip() # City/Taluka

        if not state or state.lower() == 'na': continue
        if state not in locations:
            locations[state] = {}
        
        if not district or district.lower() == 'na': continue
        if district not in locations[state]:
            locations[state][district] = set()
            
        if taluka and taluka.lower() != 'na':
            locations[state][district].add(taluka)

    # Convert sets to sorted lists
    final_locations = {}
    for state, dists in locations.items():
        final_locations[state] = {}
        for dist, tals in dists.items():
            final_locations[state][dist] = sorted(list(tals))

    # ensure assets folder exists
    os.makedirs('../assets', exist_ok=True)
    
    with open('../assets/locations.json', 'w', encoding='utf-8') as f:
        json.dump(final_locations, f, ensure_ascii=False)
        
    print("Done! Saved to assets/locations.json")

if __name__ == "__main__":
    main()
