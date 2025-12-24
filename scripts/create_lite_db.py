#!/usr/bin/env python3
"""
Create a lite database with ~30K most common words using heuristics:
- Keep ALL verbs and adjectives (they're important for learning)
- Keep shorter nouns (more likely to be common)
- Keep all adverbs, prepositions, conjunctions (small set, all important)
"""
import sqlite3
import os

SOURCE_DB = "../assets/german_dictionary_v16.db"
TARGET_DB = "../assets/german_dictionary_v16_lite.db"

def create_lite_database():
    print(f"Creating lite database from {SOURCE_DB}...")
    
    if os.path.exists(TARGET_DB):
        os.remove(TARGET_DB)
    
    # Connect to both databases
    source_conn = sqlite3.connect(SOURCE_DB)
    target_conn = sqlite3.connect(TARGET_DB)
    
    source_c = source_conn.cursor()
    target_c = target_conn.cursor()
    
    # Copy schema (skip sqlite_sequence)
    source_c.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name != 'sqlite_sequence'")
    for row in source_c.fetchall():
        if row[0]:
            target_c.execute(row[0])
    
    # Copy indexes
    source_c.execute("SELECT sql FROM sqlite_master WHERE type='index' AND sql IS NOT NULL")
    for row in source_c.fetchall():
        try:
            target_c.execute(row[0])
        except:
            pass
    
    target_conn.commit()
    
    # Selection criteria for base words
    print("Selecting words to include...")
    
    # Get word IDs based on criteria
    word_ids = set()
    
    # 1. ALL verbs (essential for learning)
    source_c.execute("SELECT id FROM words WHERE pos = 'verb' AND base_form IS NULL")
    verb_count = 0
    for row in source_c.fetchall():
        word_ids.add(row[0])
        verb_count += 1
    print(f"  Verbs: {verb_count}")
    
    # 2. ALL adjectives (essential for learning)
    source_c.execute("SELECT id FROM words WHERE pos = 'adj' AND base_form IS NULL")
    adj_count = 0
    for row in source_c.fetchall():
        word_ids.add(row[0])
        adj_count += 1
    print(f"  Adjectives: {adj_count}")
    
    # 3. ALL adverbs, prepositions, conjunctions, pronouns (small sets, all important)
    for pos in ['adv', 'prep', 'conj', 'pron', 'det', 'particle']:
        source_c.execute("SELECT id FROM words WHERE pos = ? AND base_form IS NULL", (pos,))
        count = 0
        for row in source_c.fetchall():
            word_ids.add(row[0])
            count += 1
        if count > 0:
            print(f"  {pos}: {count}")
    
    # 4. Shorter nouns (length <= 10 chars, more likely to be common)
    source_c.execute("""
        SELECT id FROM words 
        WHERE pos = 'noun' 
        AND base_form IS NULL 
        AND LENGTH(word) <= 10
        ORDER BY LENGTH(word), word
        LIMIT 15000
    """)
    noun_count = 0
    for row in source_c.fetchall():
        word_ids.add(row[0])
        noun_count += 1
    print(f"  Nouns (short, common-looking): {noun_count}")
    
    print(f"\\nTotal base words selected: {len(word_ids)}")
    
    # Also include inflected forms that point to these base words
    print("Including inflected forms...")
    inflected_ids = set()
    for word_id in word_ids:
        source_c.execute("SELECT word FROM words WHERE id = ?", (word_id,))
        result = source_c.fetchone()
        if result:
            base_word = result[0]
            source_c.execute("SELECT id FROM words WHERE base_form = ?", (base_word,))
            for row in source_c.fetchall():
                inflected_ids.add(row[0])
    
    all_word_ids = word_ids | inflected_ids
    print(f"Total words (including inflections): {len(all_word_ids)}")
    
    # Copy data
    print("Copying data...")
    
    # Copy words
    for word_id in all_word_ids:
        source_c.execute("SELECT * FROM words WHERE id = ?", (word_id,))
        row = source_c.fetchone()
        if row:
            target_c.execute("INSERT INTO words VALUES (?, ?, ?, ?, ?, ?)", row)
    
    # Copy definitions
    for word_id in all_word_ids:
        source_c.execute("SELECT * FROM definitions WHERE word_id = ?", (word_id,))
        for row in source_c.fetchall():
            target_c.execute("INSERT INTO definitions VALUES (?, ?, ?)", row)
    
    # Copy forms
    for word_id in all_word_ids:
        source_c.execute("SELECT * FROM forms WHERE word_id = ?", (word_id,))
        for row in source_c.fetchall():
            target_c.execute("INSERT INTO forms VALUES (?, ?, ?)", row)
    
    # Copy tags (get unique tag_ids used in forms)
    target_c.execute("SELECT DISTINCT tag_id FROM forms")
    used_tag_ids = {row[0] for row in target_c.fetchall() if row[0]}
    
    for tag_id in used_tag_ids:
        source_c.execute("SELECT * FROM tags WHERE id = ?", (tag_id,))
        row = source_c.fetchone()
        if row:
            try:
                target_c.execute("INSERT INTO tags VALUES (?, ?)", row)
            except:
                pass
    
    # Copy relations
    for word_id in all_word_ids:
        source_c.execute("SELECT * FROM relations WHERE word_id = ?", (word_id,))
        for row in source_c.fetchall():
            target_c.execute("INSERT INTO relations VALUES (?, ?, ?)", row)
    
    target_conn.commit()
    
    # Get stats
    target_c.execute("SELECT COUNT(*) FROM words WHERE base_form IS NULL")
    base_words = target_c.fetchone()[0]
    target_c.execute("SELECT COUNT(*) FROM words")
    total_words = target_c.fetchone()[0]
    target_c.execute("SELECT COUNT(*) FROM forms")
    total_forms = target_c.fetchone()[0]
    target_c.execute("SELECT COUNT(*) FROM relations")
    total_relations = target_c.fetchone()[0]
    
    print(f"\\nLite database created:")
    print(f"  Base words: {base_words}")
    print(f"  Total words (with inflections): {total_words}")
    print(f"  Forms: {total_forms}")
    print(f"  Relations: {total_relations}")
    
    source_conn.close()
    target_conn.close()
    
    # VACUUM to reduce size
    print("\\nOptimizing database size...")
    conn = sqlite3.connect(TARGET_DB)
    conn.execute("VACUUM")
    conn.close()
    
    # Show file sizes
    source_size = os.path.getsize(SOURCE_DB) / (1024 * 1024)
    target_size = os.path.getsize(TARGET_DB) / (1024 * 1024)
    print(f"\\nFile sizes:")
    print(f"  Original: {source_size:.1f} MB")
    print(f"  Lite: {target_size:.1f} MB")
    print(f"  Reduction: {100 * (1 - target_size/source_size):.1f}%")

if __name__ == "__main__":
    create_lite_database()
    print("\\nDone!")
