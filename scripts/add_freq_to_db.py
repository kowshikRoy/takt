#!/usr/bin/env python3
"""
Populate freq_rank column in SQLite dictionary database using scripts/german_freq_30k.txt
"""
import sqlite3
import os
import sys

DB_PATH = os.path.join(os.path.dirname(__file__), "../assets/german_dictionary_v17.db")
FREQ_PATH = os.path.join(os.path.dirname(__file__), "german_freq_30k.txt")

def populate_frequency(db_path=DB_PATH, freq_path=FREQ_PATH):
    if not os.path.exists(db_path):
        print(f"Error: Database not found at {db_path}")
        return
    if not os.path.exists(freq_path):
        print(f"Error: Frequency file not found at {freq_path}")
        return

    conn = sqlite3.connect(db_path)
    c = conn.cursor()

    # Check if freq_rank column exists
    c.execute("PRAGMA table_info(words)")
    cols = [row[1] for row in c.fetchall()]
    if 'freq_rank' not in cols:
        print("Adding freq_rank column to words table...")
        c.execute("ALTER TABLE words ADD COLUMN freq_rank INTEGER")

    print(f"Loading frequency ranks from {freq_path}...")
    freq_map = {}
    rank = 1
    with open(freq_path, 'r', encoding='utf-8') as f:
        for line in f:
            parts = line.strip().split()
            if parts:
                w = parts[0]
                if w not in freq_map:
                    freq_map[w] = rank
                    freq_map[w.toLowerCase() if hasattr(w, 'toLowerCase') else w.lower()] = rank
                    rank += 1

    print(f"Loaded {len(freq_map)} frequency mappings.")

    c.execute("SELECT id, word FROM words")
    words = c.fetchall()
    matched = 0
    updates = []
    for wid, word in words:
        r = freq_map.get(word) or freq_map.get(word.lower())
        if r:
            updates.append((r, wid))
            matched += 1

    c.executemany("UPDATE words SET freq_rank = ? WHERE id = ?", updates)
    conn.commit()
    conn.close()

    print(f"Successfully updated {matched} words out of {len(words)} total words in {db_path}!")

if __name__ == "__main__":
    populate_frequency()
