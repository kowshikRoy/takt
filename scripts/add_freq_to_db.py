#!/usr/bin/env python3
"""
Populate freq_rank column in SQLite dictionary database using lemma-aggregated frequency
derived from scripts/german_freq_30k.txt and grammatical inflections in the forms table.
"""
import sqlite3
import os
import sys

FREQ_PATH = os.path.join(os.path.dirname(__file__), "german_freq_30k.txt")

def populate_frequency(db_path, freq_path=FREQ_PATH):
    if not os.path.exists(db_path):
        print(f"Error: Database not found at {db_path}")
        return
    if not os.path.exists(freq_path):
        print(f"Error: Frequency file not found at {freq_path}")
        return

    print(f"Loading raw token frequency counts from {freq_path}...")
    token_counts = {}
    with open(freq_path, 'r', encoding='utf-8') as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 2:
                try:
                    token_counts[parts[0].lower()] = int(parts[1])
                except ValueError:
                    pass

    print(f"Loaded {len(token_counts)} token frequency counts.")

    conn = sqlite3.connect(db_path)
    c = conn.cursor()

    # Check if freq_rank column exists
    c.execute("PRAGMA table_info(words)")
    cols = [row[1] for row in c.fetchall()]
    if 'freq_rank' not in cols:
        print("Adding freq_rank column to words table...")
        c.execute("ALTER TABLE words ADD COLUMN freq_rank INTEGER")

    # Fetch all words
    print("Fetching words from database...")
    c.execute("SELECT id, word, pos, base_form FROM words")
    words = c.fetchall()
    print(f"Found {len(words)} word entries in {db_path}.")

    # Fetch all forms grouped by word_id
    print("Fetching grammatical forms for lemma aggregation...")
    c.execute("SELECT word_id, form FROM forms")
    word_forms = {}
    for wid, form in c.fetchall():
        if form:
            word_forms.setdefault(wid, set()).add(form.lower())

    # Compute aggregated count for each word
    word_scores = []
    for wid, word, pos, base_form in words:
        w_lower = word.lower() if word else ""
        forms = word_forms.get(wid, set())
        
        # Aggregate base word count + all inflected forms
        total_count = token_counts.get(w_lower, 0)
        for f in forms:
            total_count += token_counts.get(f, 0)
            
        word_scores.append((wid, word, total_count))

    # Sort words with counts > 0 descending
    words_with_counts = [w for w in word_scores if w[2] > 0]
    words_with_counts.sort(key=lambda x: x[2], reverse=True)

    print(f"Assigning lemma-aggregated frequency ranks to {len(words_with_counts)} words...")
    updates = []
    for rank, (wid, word, count) in enumerate(words_with_counts, start=1):
        updates.append((rank, wid))

    # For words with 0 corpus counts, set freq_rank to NULL
    words_zero = [(None, w[0]) for w in word_scores if w[2] == 0]

    print("Updating database...")
    c.executemany("UPDATE words SET freq_rank = ? WHERE id = ?", updates)
    c.executemany("UPDATE words SET freq_rank = ? WHERE id = ?", words_zero)

    conn.commit()
    conn.close()

    print(f"Successfully updated lemma-aggregated frequency ranks for {db_path}!")

if __name__ == "__main__":
    v18_path = os.path.join(os.path.dirname(__file__), "../assets/german_dictionary_v18.db")
    if os.path.exists(v18_path):
        populate_frequency(v18_path)
    lite_path = os.path.join(os.path.dirname(__file__), "../assets/german_dictionary_v18_lite.db")
    if os.path.exists(lite_path):
        populate_frequency(lite_path)

