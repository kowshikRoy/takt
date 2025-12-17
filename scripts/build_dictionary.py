import sqlite3
import json
import requests
import os
import sys

# Configuration
# Using a smaller subset/test URL or the full one?
# The user wants "process it and integrate it". Let's use the full URL but maybe limit for testing if it takes too long.
# However, usually we want the full thing. I'll add a limit arg.
URL = "https://kaikki.org/dictionary/German/kaikki.org-dictionary-German.jsonl"
DB_PATH = "../assets/german_dictionary_v3.db" 
TEMP_JSONL = "temp_dictionary.jsonl"

def setup_database(conn):
    c = conn.cursor()
    c.execute("DROP TABLE IF EXISTS words")
    c.execute("DROP TABLE IF EXISTS definitions")
    c.execute("DROP TABLE IF EXISTS forms")

    # Main words table
    c.execute("""
        CREATE TABLE words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL COLLATE NOCASE,
            pos TEXT,
            gender TEXT,
            ipa TEXT
        )
    """)

    # Index for fast prefix search
    c.execute("CREATE INDEX idx_words_word ON words(word COLLATE NOCASE)")

    # Definitions
    c.execute("""
        CREATE TABLE definitions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word_id INTEGER,
            definition TEXT,
            FOREIGN KEY(word_id) REFERENCES words(id)
        )
    """)
    
    # Forms (Declensions/Conjugations)
    c.execute("""
        CREATE TABLE forms (
            word_id INTEGER,
            form TEXT,
            tags TEXT,
            FOREIGN KEY(word_id) REFERENCES words(id)
        )
    """)
    
    conn.commit()

def process_file(file_path, conn):
    c = conn.cursor()
    count = 0
    
    print("Processing JSONL...")
    
    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            if not line.strip(): continue
            
            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue

            word = data.get("word")
            if not word: continue

            pos = data.get("pos")
            # Filter out names/proper nouns as requested
            if pos == "name":
                continue
            
            # Extract IPA
            ipa = ""
            if "sounds" in data:
                for s in data["sounds"]:
                    if "ipa" in s:
                        ipa = s["ipa"]
                        break
            
            # Extract Gender
            gender = ""
            if "senses" in data:
                for sense in data["senses"]:
                    if not gender and "tags" in sense:
                        for t in sense["tags"]:
                            if t in ["masculine", "feminine", "neuter"]:
                                gender = t
                                break
            
            # Definitions
            definitions = []
            if "senses" in data:
                for sense in data["senses"]:
                    if "glosses" in sense:
                        for g in sense["glosses"]:
                            definitions.append(g)

            if not definitions:
                continue

            # Insert Word
            # Using INSERT OR REPLACE to handle potential duplicates if strict unique constraints were there (not now but good practice)
            c.execute("INSERT INTO words (word, pos, gender, ipa) VALUES (?, ?, ?, ?)",
                      (word, pos, gender, ipa))
            word_id = c.lastrowid
            
            # Insert Definitions
            for d in definitions:
                c.execute("INSERT INTO definitions (word_id, definition) VALUES (?, ?)", (word_id, d))
                
            # Insert Forms
            if "forms" in data:
                for form_data in data["forms"]:
                    form_text = form_data.get("form")
                    tags = json.dumps(form_data.get("tags", []))
                    if form_text:
                        c.execute("INSERT INTO forms (word_id, form, tags) VALUES (?, ?, ?)", (word_id, form_text, tags))

            count += 1
            if count % 1000 == 0:
                print(f"Processed {count} words...")
                conn.commit()
                
    conn.commit()
    print(f"Finished processing {count} words.")

def build_dictionary():
    # Ensure assets dir exists
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    
    # 1. Download
    if not os.path.exists(TEMP_JSONL):
        print(f"Downloading {URL}...")
        with requests.get(URL, stream=True) as r:
            r.raise_for_status()
            with open(TEMP_JSONL, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
        print("Download complete.")
    else:
        print("Using existing JSONL file.")

    # 2. Build DB
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
        
    conn = sqlite3.connect(DB_PATH)
    setup_database(conn)
    process_file(TEMP_JSONL, conn)
    conn.close()
    
    print(f"Database saved to {DB_PATH}")

if __name__ == "__main__":
    build_dictionary()
