import sqlite3
import json
import requests
import os
import sys

# Configuration
# Using a smaller subset/test URL or the full one?
# The user wants "process it and integrate it". Let's use the full URL but maybe limit for testing if it takes too long.
# However, usually we want the full thing. I'll add a limit arg.
MAX_WORDS = None

URL = "https://kaikki.org/dictionary/German/kaikki.org-dictionary-German.jsonl"
DB_PATH = "../assets/german_dictionary_v16.db"
TEMP_JSONL = "temp_dictionary.jsonl"

def setup_database(conn):
    c = conn.cursor()
    c.execute("DROP TABLE IF EXISTS words")
    c.execute("DROP TABLE IF EXISTS definitions")
    c.execute("DROP TABLE IF EXISTS forms")
    c.execute("DROP TABLE IF EXISTS tags")
    c.execute("DROP TABLE IF EXISTS relations")

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
    
    c.execute("""
        CREATE TABLE tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tags TEXT UNIQUE
        )
    """)

    # Forms (Declensions/Conjugations) - Modified for Recommendation 2
    c.execute("""
        CREATE TABLE forms (
            word_id INTEGER,
            form TEXT,
            tag_id INTEGER,
            FOREIGN KEY(word_id) REFERENCES words(id),
            FOREIGN KEY(tag_id) REFERENCES tags(id)
        )
    """)
    
    # Relations (Synonyms, Antonyms, Related)
    c.execute("""
        CREATE TABLE relations (
            word_id INTEGER,
            relation_type TEXT,
            related_word TEXT,
            FOREIGN KEY(word_id) REFERENCES words(id)
        )
    """)
    
    # Indexes
    c.execute("CREATE INDEX idx_word ON words(word)")
    c.execute("CREATE INDEX idx_base_form ON words(base_form)") # Useful for finding all forms of a base
    c.execute("CREATE INDEX idx_def_word_id ON definitions(word_id)")
    c.execute("CREATE INDEX idx_forms_word_id ON forms(word_id)")
    c.execute("CREATE INDEX idx_forms_tag_id ON forms(tag_id)")
    c.execute("CREATE INDEX idx_relations_word_id ON relations(word_id)")
    
    conn.commit()



def process_file(file_path, conn):
    c = conn.cursor()
    count = 0
    tag_cache = {} # Map JSON string -> ID
    
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
                                # Recommendation 3: Normalize Gender
                                if t == "masculine": gender = "m"
                                elif t == "feminine": gender = "f"
                                elif t == "neuter": gender = "n"
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
            
            # Extract and Insert Relations (Synonyms, Antonyms, Related)
            relations = set()  # Use set to deduplicate
            if not base_form and "senses" in data:  # Only for base words
                for sense in data["senses"]:
                    # Extract synonyms
                    if "synonyms" in sense:
                        for syn in sense["synonyms"]:
                            if isinstance(syn, dict) and "word" in syn:
                                relations.add(("synonym", syn["word"]))
                    
                    # Extract antonyms
                    if "antonyms" in sense:
                        for ant in sense["antonyms"]:
                            if isinstance(ant, dict) and "word" in ant:
                                relations.add(("antonym", ant["word"]))
                    
                    # Extract related words
                    if "related" in sense:
                        for rel in sense["related"]:
                            if isinstance(rel, dict) and "word" in rel:
                                relations.add(("related", rel["word"]))
            
            # Insert relations
            for relation_type, related_word in relations:
                c.execute("INSERT INTO relations (word_id, relation_type, related_word) VALUES (?, ?, ?)", 
                         (word_id, relation_type, related_word))
                
            # Insert Forms (Simplified)
            if "forms" in data:
                seen_forms = set()
                for form_data in data["forms"]:
                    form_text = form_data.get("form")
                    tags = form_data.get("tags", [])
                    
                    if not form_text: continue
                    
                    # Recommendation 1: Filter "Junk" Rows (Metadata)
                    if "inflection-template" in tags or "table-tags" in tags:
                        continue
                    
                    # Recommendation 2: Filter forms
                    tags_set = set(tags)
                    remove_markers = {
                        'future-i', 'future-ii',
                        'perfect', 'pluperfect',
                        'subjunctive-i',
                        'rare', 'archaic', 'obsolete', 'proscribed', 'nonstandard',
                        'subordinate-clause',
                        'multiword-construction', 'future',
                                            }

                    should_remove = False

                    if not tags_set.isdisjoint(remove_markers):
                        should_remove = True
                    
                    # Exception: Keep Subjunctive II (unless it's multiword/future)
                    if 'subjunctive-ii' in tags_set:
                        if 'multiword-construction' in tags_set or 'future' in tags_set or 'future-ii' in tags_set:
                            pass # Don't rescue
                        else:
                            should_remove = False

                    if should_remove:
                        continue
                    
                    # Noun Optimizations (v13)
                    if pos == "noun":
                        # 1. Filter Diminutives (Redundant, exist as standalone words)
                        if "diminutive" in tags_set:
                            continue
                        
                        if "definite" in tags: tags.remove("definite")
                        if "indefinite" in tags: tags.remove("indefinite")
                        
                    # Adjective Optimizations (v14)
                    if pos == "adj":
                        # NEW: Remove multi-word forms (e.g. "der schwere", "am schwersten")
                        if " " in form_text:
                            continue

                        # Remove redundant declension info
                        tags_to_remove = {
                            "strong", "weak", "mixed",
                            "includes-article", "without-article",
                            "definite", "indefinite"
                        }
                        # Keep only tags NOT in the remove list
                        tags = [t for t in tags if t not in tags_to_remove]
                    
                    # Recommendation 4: Enable Full Declension
                    # We KEEP all case forms.
                    
                    # Normalize tags & Get ID
                    # Sort tags to ensure uniqueness for same set
                    tags.sort()
                    tags_json = json.dumps(tags)

                    # Deduplication (v13)
                    # Avoid inserting exact same form + tag combo for the same word
                    # (e.g. if trimming 'definite' made two entries identical)
                    form_key = (form_text, tags_json)
                    if form_key in seen_forms:
                        continue
                    seen_forms.add(form_key)
                    
                    tag_id = tag_cache.get(tags_json)
                    if tag_id is None:
                        # Insert new tag set
                        # Use INSERT OR IGNORE just in case, though cache handles it mostly
                        try:
                            c.execute("INSERT INTO tags (tags) VALUES (?)", (tags_json,))
                            tag_id = c.lastrowid
                            tag_cache[tags_json] = tag_id
                        except sqlite3.IntegrityError:
                            # It existed (race condition unlikely here but good practice), fetch it
                            c.execute("SELECT id FROM tags WHERE tags = ?", (tags_json,))
                            tag_id = c.fetchone()[0]
                            tag_cache[tags_json] = tag_id
                    
                    c.execute("INSERT INTO forms (word_id, form, tag_id) VALUES (?, ?, ?)", (word_id, form_text, tag_id))

            count += 1
            if count % 1000 == 0:
                print(f"Processed {count} words...")
                conn.commit()
                
    conn.commit()
    print(f"Finished processing {count} words.")

def download_dictionary():
    print(f"Downloading dictionary from {URL}...")
    try:
        r = requests.get(URL, stream=True)
        r.raise_for_status()
        with open(TEMP_JSONL, 'wb') as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)
        print("Download complete.")
    except Exception as e:
        print(f"Error downloading: {e}")
        sys.exit(1)

def build_dictionary():
    # Ensure assets dir exists
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    
    # 1. Download

    if not os.path.exists("../assets"):
        os.makedirs("../assets")
    
    db_path = DB_PATH
    
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
