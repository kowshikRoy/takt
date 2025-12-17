import json
import random
import datetime
import os

# Define some templates to simulate generation
TEMPLATES = [
    {
        "title": "Der Marktbesuch",
        "englishTitle": "The Market Visit",
        "content": "Heute geht Lisa auf den Markt. Sie kauft Äpfel und Birnen. Das Wetter ist schön.",
        "difficulty": "Beginner",
        "vocabulary": {"Markt": "Market", "Äpfel": "Apples", "Birnen": "Pears"}
    },
    {
        "title": "Im Café",
        "englishTitle": "At the Café",
        "content": "Peter trinkt gerne Kaffee. Er sitzt im Café und liest ein Buch.",
        "difficulty": "Beginner",
        "vocabulary": {"Kaffee": "Coffee", "Buch": "Book"}
    },
    {
        "title": "Die Reise",
        "englishTitle": "The Journey",
        "content": "Der Zug fährt schnell. Maria schaut aus dem Fenster. Sie sieht viele Bäume.",
        "difficulty": "Intermediate",
        "vocabulary": {"Zug": "Train", "Fenster": "Window", "Bäume": "Trees"}
    }
]

def generate_story():
    # In a real scenario, this would call an LLM API
    story = random.choice(TEMPLATES)
    story['id'] = datetime.datetime.now().strftime("%Y%m%d")
    return story

def main():
    # Ensure directory exists
    output_dir = "assets/data"
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    file_path = os.path.join(output_dir, "stories.json")

    stories = []
    if os.path.exists(file_path):
        with open(file_path, "r") as f:
            try:
                stories = json.load(f)
            except json.JSONDecodeError:
                stories = []

    new_story = generate_story()

    # Check if story with same ID exists (prevent duplicate runs on same day adding same ID)
    existing_ids = [s['id'] for s in stories]
    if new_story['id'] not in existing_ids:
        stories.insert(0, new_story) # Add new story to the top
        print(f"Generated new story: {new_story['title']}")
    else:
        print("Story for today already exists.")

    with open(file_path, "w") as f:
        json.dump(stories, f, indent=2, ensure_ascii=False)

if __name__ == "__main__":
    main()
