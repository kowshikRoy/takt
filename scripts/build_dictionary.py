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
            word TEXT NOT NULL,
            pos TEXT,
            gender TEXT,
            ipa TEXT,
            base_form TEXT
        )
    """)

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
    
    # Indexes
    c.execute("CREATE INDEX idx_word ON words(word)")
    c.execute("CREATE INDEX idx_base_form ON words(base_form)") # Useful for finding all forms of a base
    c.execute("CREATE INDEX idx_def_word_id ON definitions(word_id)")
    
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
            
            # Extract Gender (Only for Nouns)
            gender = ""
            if pos == "noun" and "senses" in data:
                for sense in data["senses"]:
                    if not gender and "tags" in sense:
                        for t in sense["tags"]:
                            if t in ["masculine", "feminine", "neuter"]:
                                gender = t
                                break
            
            # Extract Base Form (if it's an inflection)
            base_form = None
            if "senses" in data:
                for sense in data["senses"]:
                    if "form_of" in sense:
                        for f_of in sense["form_of"]:
                            if "word" in f_of:
                                base_form = f_of["word"]
                                break
                    if base_form: break

            # Definitions
            definitions = []
            # ONLY extract definitions if this is a base word (no base_form found)
            if not base_form and "senses" in data:
                for sense in data["senses"]:
                    if "glosses" in sense:
                        for g in sense["glosses"]:
                            definitions.append(g)

            # Filter definitions: if we have "comparative degree/form of", keep ONLY those.
            # (Only relevant if we are keeping definitions, which we aren't for base_form words anymore 
            #  because they would have had base_form set and thus definitions skipped above. 
            #  But logic holds for words without explicit base_form link but that are comparatives.)
            if definitions:
                comparative_defs = [d for d in definitions if "comparative degree of" in d or "comparative form of" in d]
                if comparative_defs:
                     definitions = comparative_defs

            # If no definitions AND no base_form, skip this word (useless entry)
            # If we have base_form, we KEEP it even if definitions is empty (because it redirects)
            if not definitions and not base_form:
                continue

            # Insert Word
            c.execute("INSERT INTO words (word, pos, gender, ipa, base_form) VALUES (?, ?, ?, ?, ?)",
                      (word, pos, gender, ipa, base_form))
            word_id = c.lastrowid
            
            # Insert Definitions
            for d in definitions:
                c.execute("INSERT INTO definitions (word_id, definition) VALUES (?, ?)", (word_id, d))
                
            # Insert Forms (Simplified)
            if "forms" in data:
                for form_data in data["forms"]:
                    form_text = form_data.get("form")
                    tags = form_data.get("tags", [])
                    
                    if not form_text: continue
                    
                    # Form Filtering Logic
                    keep_form = False
                    
                    if pos == "adj":
                        # Keep only positive, comparative, superlative (without extra declension tags)
                        # Identify declension vs basic forms.
                        # Complex tags example: ["masculine", "genitive", "singular", "positive"]
                        # Simple tags: ["positive"], ["comparative"], ["superlative"] (or empty/predicative)
                        if len(tags) <= 2: # heuristic: usually essential forms have few tags
                             # Check for declension tags to exclude
                             declension_tags = ["masculine", "feminine", "neuter", "genitive", "dative", "accusative", "nominative", "plural", "singular"]
                             if not any(t in declension_tags for t in tags):
                                 keep_form = True
                    
                    elif pos == "verb":
                        # Keep infinitive, present, past, participle
                        # Filter out subjunctive, imperative if desired, or keep basics.
                        # User's script kept: present, past/preterite, perfect, pluperfect.
                        # We will aggressively filter to keep table size down.
                        valid_tenses = ["present", "past", "preterite", "perfect", "participle"]
                        if any(t in valid_tenses for t in tags) and not any(t.startswith("subjunctive") for t in tags):
                             keep_form = True
                        if "infinitive" in tags:
                            keep_form = True

                    elif pos == "noun":
                        # Keep singular/plural nominative?
                        # Noun forms are often voluminous too.
                        if "nominative" in tags or "plural" in tags or "singular" in tags:
                             # Exclude oblique cases if possible
                             oblique = ["genitive", "dative", "accusative"]
                             if not any(t in oblique for t in tags):
                                 keep_form = True
                    else:
                        # For other POS, keep all or aggressive filter?
                        # Let's keep all for typically smaller classes (adverbs etc)
                        keep_form = True

                    if keep_form:
                        tags_json = json.dumps(tags)
                        c.execute("INSERT INTO forms (word_id, form, tags) VALUES (?, ?, ?)", (word_id, form_text, tags_json))

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

    if not os.path.exists("../assets"):
        os.makedirs("../assets")
    
    db_path = "../assets/german_dictionary_v7.db"
    
    if os.path.exists(db_path):
        os.remove(db_path)
        
    conn = sqlite3.connect(db_path)
    setup_database(conn)
    
    if os.path.exists(TEMP_JSONL):
        print("Using existing JSONL file.")
        process_file(TEMP_JSONL, conn)
    else:
        download_dictionary()
        process_file(TEMP_JSONL, conn)
        
    conn.close()
    print(f"Database saved to {db_path}")

if __name__ == "__main__":
    build_dictionary()
