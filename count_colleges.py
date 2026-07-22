import json

def count_colleges(data):
    count = 0
    if isinstance(data, list):
        return len(data)
    elif isinstance(data, dict):
        for k, v in data.items():
            count += count_colleges(v)
    return count

d = json.load(open('c:/Users/visha/OneDrive/Desktop/photos/assets/locations.json', encoding='utf-8'))
print('Total Colleges:', count_colleges(d))
