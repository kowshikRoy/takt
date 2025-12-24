import sqlite3
import json
import collections
import sys

db_path = 'assets/german_dictionary_v14.db'

def analyze_forms():
    if not os.path.exists(db_path):
        print(f"Error: Database not found at {db_path}")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    print("Fetching tag map...")
    cursor.execute("SELECT id, tags FROM tags")
    tag_map = {row[0]: json.loads(row[1]) for row in cursor.fetchall()}

    print("Counting forms by POS...")
    
    # We want to see which POS has the most forms
    query = """
        SELECT w.pos, COUNT(*) 
        FROM forms f
        JOIN words w ON f.word_id = w.id
        GROUP BY w.pos
        ORDER BY COUNT(*) DESC
    """
    cursor.execute(query)
    pos_counts = cursor.fetchall()
    
    print("\n--- Form Counts by POS ---")
    for pos, count in pos_counts:
        print(f"{pos}: {count}")

    # Now let's dig into the top POS (usually verb, noun, adj)
    for pos, _ in pos_counts[:3]: # check top 3
        print(f"\n--- Top 20 Tag Sets for {pos} ---")
        
        query = f"""
            SELECT f.tag_id, COUNT(*) 
            FROM forms f
            JOIN words w ON f.word_id = w.id
            WHERE w.pos = ?
            GROUP BY f.tag_id
            ORDER BY COUNT(*) DESC
            LIMIT 20
        """
        cursor.execute(query, (pos,))
        results = cursor.fetchall()
        
        for tag_id, count in results:
            tags = tag_map.get(tag_id, [])
            print(f"{count}: {tags}")

    conn.close()

import os
if __name__ == "__main__":
    analyze_forms()
