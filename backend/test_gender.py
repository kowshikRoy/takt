import requests
import json

URL = "http://localhost:5001/process_full"
TEXT = "Der Hund ist groß. Die Katze schläft. Das Haus ist neu."

def test():
    try:
        response = requests.post(URL, json={"text": TEXT, "lang": "de"})
        if response.status_code == 200:
            data = response.json()
            for i, p in enumerate(data.get('paragraphs', [])):
                print(f"--- Paragraph {i} ---")
                for token in p.get('german_analysis', []):
                    print(f"Token: {token['word']}, POS: {token['pos']}, Gender: {token.get('gender')}")
        else:
            print(f"Error: {response.status_code}")
            print(response.text)
    except Exception as e:
        print(f"Connection error: {e}")

if __name__ == "__main__":
    test()
