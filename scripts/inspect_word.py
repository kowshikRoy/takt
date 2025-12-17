import sqlite3
import sys
import os

DB_PATH = "assets/german_dictionary_v7.db"

def inspect_word(word):
    if not os.path.exists(DB_PATH):
        print(f"Error: Database not found at {DB_PATH}")
        return

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()

    print(f"Inspecting word: '{word}'\n" + "="*40)

    # 1. Get Word Info
    c.execute("SELECT * FROM words WHERE word = ? COLLATE NOCASE", (word,))
    words = c.fetchall()

    if not words:
        print("No entry found in 'words' table.")
        return

    for w in words:
        word_id = w['id']
        print(f"\n[ID: {word_id}] Word: {w['word']}")
        print(f"  Pos: {w['pos']}")
        print(f"  Gender: {w['gender']}")
        print(f"  IPA: {w['ipa']}")
        print(f"  Base Form: {w['base_form']}")

        # 2. Get Definitions
        c.execute("SELECT definition FROM definitions WHERE word_id = ?", (word_id,))
        defs = c.fetchall()
        print(f"  Definitions ({len(defs)}):")
        for d in defs:
            print(f"    - {d['definition']}")

        # 3. Get Forms
        c.execute("SELECT form, tags FROM forms WHERE word_id = ?", (word_id,))
        forms = c.fetchall()
        print(f"  Forms ({len(forms)}):")
        for f in forms:
            print(f"    - {f['form']} {f['tags']}")
            
    conn.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/inspect_word.py <word>")
    else:
        inspect_word(sys.argv[1])
