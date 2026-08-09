import sqlite3
import sys
import os
import glob

import re

def get_latest_db():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    assets_dir = os.path.join(script_dir, "../assets")
    
    candidates = []
    for f in glob.glob(os.path.join(assets_dir, "german_dictionary_v*.db")):
        # Skip Git LFS pointer stubs (< 100KB)
        if os.path.getsize(f) < 100 * 1024:
            continue
        match = re.search(r'german_dictionary_v(\d+)(_lite)?\.db$', os.path.basename(f))
        if match:
            ver = int(match.group(1))
            is_lite = 1 if match.group(2) else 0
            candidates.append((ver, is_lite, f))
    
    if candidates:
        # Sort by version DESC, then lite DESC (so v18_lite before v18)
        candidates.sort(key=lambda x: (x[0], x[1]), reverse=True)
        return candidates[0][2]

    fallback = os.path.join(assets_dir, "dict.db")
    if os.path.exists(fallback) and os.path.getsize(fallback) > 100 * 1024:
        return fallback
    return os.path.join(assets_dir, "german_dictionary_v18_lite.db")

DB_PATH = get_latest_db()

def inspect_word(word, db_path=None):
    target_db = db_path or DB_PATH
    if not os.path.exists(target_db):
        print(f"Error: Database not found at {target_db}")
        return

    conn = sqlite3.connect(target_db)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()

    print(f"Using database: {os.path.basename(target_db)}")
    print(f"Inspecting word: '{word}'\n" + "="*40)

    # 1. Get Word Info
    c.execute("SELECT * FROM words WHERE word = ? COLLATE NOCASE", (word,))
    words = c.fetchall()

    if not words:
        print("No entry found in 'words' table (local database).")
        print("\nChecking WiktAPI (Wiktionary Online Fallback)...")
        try:
            import urllib.request
            import urllib.parse
            import json

            url = f"https://api.wiktapi.dev/v1/en/word/{urllib.parse.quote(word)}?lang=de"
            req = urllib.request.Request(url, headers={'User-Agent': 'TaktApp/1.0', 'Accept': 'application/json'})
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status == 200:
                    data = json.loads(response.read().decode('utf-8'))
                    entries = data.get('entries', [])
                    if entries:
                        print(f"Found {len(entries)} entry/entries in Wiktionary API:")
                        for idx, entry in enumerate(entries, 1):
                            sounds = entry.get('sounds', [])
                            ipa = next((s.get('ipa') for s in sounds if s.get('ipa')), 'N/A')
                            print(f"\n[Online Sense #{idx}] Word: {word}")
                            print(f"  IPA: {ipa}")
                            senses = entry.get('senses', [])
                            for s in senses:
                                tags = s.get('tags', [])
                                glosses = s.get('glosses', [])
                                form_of = s.get('form_of', [])
                                if tags:
                                    print(f"  Tags: {', '.join(tags)}")
                                if form_of:
                                    print(f"  Form Of: {', '.join(f.get('word', '') for f in form_of)}")
                                if glosses:
                                    print("  Definitions:")
                                    for g in glosses:
                                        print(f"    - {g}")
                    else:
                        print("No entries returned from WiktAPI.")
                else:
                    print(f"WiktAPI returned status {response.status}.")
        except Exception as e:
            print(f"Could not connect to WiktAPI: {e}")
        conn.close()
        return

    for w in words:
        word_id = w['id']
        keys = w.keys()
        print(f"\n[ID: {word_id}] Word: {w['word']}")
        freq = w['freq_rank'] if 'freq_rank' in keys else 'N/A'
        print(f"  Pos: {w['pos']}")
        print(f"  Gender: {w['gender']}")
        print(f"  IPA: {w['ipa']}")
        print(f"  Base Form: {w['base_form']}")
        
        if 'verb_class' in keys:
            v_class = w['verb_class']
            if v_class:
                label_map = {
                    'weak': 'weak / Regular (Schwach)',
                    'strong': 'strong / Irregular (Stark)',
                    'mixed': 'mixed / Irregular (Gemischt)',
                    'irregular': 'irregular / Auxiliary (Hilfsverb/Unregelmäßig)',
                    'modal': 'modal / Modalverb',
                }
                display_strength = label_map.get(v_class.lower(), v_class)
                print(f"  Verb Strength: {display_strength}")
            else:
                print(f"  Verb Strength: None")

        print(f"  Frequency Rank: #{freq}" if freq != 'N/A' and freq is not None else "  Frequency Rank: N/A")

        # 2. Get Definitions
        c.execute("SELECT definition FROM definitions WHERE word_id = ?", (word_id,))
        defs = c.fetchall()
        print(f"  Definitions ({len(defs)}):")
        for d in defs:
            print(f"    - {d['definition']}")

        # 3. Get Examples
        try:
            c.execute("SELECT de, en FROM examples WHERE word_id = ?", (word_id,))
            examples = c.fetchall()
            if examples:
                print(f"  Examples ({len(examples)}):")
                for ex in examples:
                    en_text = f" ({ex['en']})" if ex['en'] else ""
                    print(f"    - {ex['de']}{en_text}")
        except Exception:
            pass

        # 4. Get Forms
        c.execute("SELECT f.form, t.tags FROM forms f LEFT JOIN tags t ON f.tag_id = t.id WHERE f.word_id = ?", (word_id,))
        forms = c.fetchall()
        print(f"  Forms ({len(forms)}):")
        for f in forms[:15]:
            print(f"    - {f['form']} {f['tags']}")
        if len(forms) > 15:
            print(f"    ... and {len(forms) - 15} more forms")
        
        # 5. Get Relations
        try:
            c.execute("SELECT relation_type, related_word FROM relations WHERE word_id = ?", (word_id,))
            relations = c.fetchall()
            if relations:
                print(f"  Relations ({len(relations)}):")
                synonyms = [r['related_word'] for r in relations if r['relation_type'] == 'synonym']
                antonyms = [r['related_word'] for r in relations if r['relation_type'] == 'antonym']
                related = [r['related_word'] for r in relations if r['relation_type'] == 'related']
                
                if synonyms:
                    print(f"    Synonyms: {', '.join(synonyms)}")
                if antonyms:
                    print(f"    Antonyms: {', '.join(antonyms)}")
                if related:
                    print(f"    Related: {', '.join(related)}")
        except Exception:
            pass
            
    conn.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/inspect_word.py <word> [optional_db_path]")
    else:
        db_arg = sys.argv[2] if len(sys.argv) > 2 else None
        inspect_word(sys.argv[1], db_arg)
